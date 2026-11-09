@tool
extends Node2D
## Plays one sheet of an AnvilFX effect: every layer of the sheet stacked on its pivot, each with its blend mode
## (multiply holdouts first, additive light on top), read from the effect's JSON.
##
## Most games use AnvilFXEffect (effect.gd), which wraps this. Use it directly to build effects in code:
##
##     const SheetPlayer = preload("res://addons/anvilfx/sheet_player.gd")
##     var dir := "res://effects/anvilfx-starter/pulse-laser"
##     var hit := SheetPlayer.new()
##     var sheets: Array = SheetPlayer.load_effect(dir)["sheets"]   # listed by name in effect.json
##     hit.setup(sheets.filter(func(s): return s["name"] == "hit")[0], dir)
##     hit.free_when_finished = true
##     add_child(hit)
##     hit.global_position = contact
##     hit.play()

signal finished

const SHADERS = {
	"additive": preload("add.gdshader"),
	"multiply": preload("mul.gdshader"),
	"normal": preload("mix.gdshader"),
}
const CROP_FEATHER = 0.06   # share of the cell over which a cropped strip's cut edge fades

@export var free_when_finished: bool = false

var sheet: Dictionary = {}
var frames: int = 1
var fps: float = 60.0
var looping: bool = false
var loop_offset_ms: float = 0.0
var speed_scale: float = 1.0
## Extra seconds to hold/loop the active middle window (`sustainMs`) before playing the exit.
var sustain_seconds: float = 0.0
## When true, hold/loop the active middle window (`sustainMs`) indefinitely until `release_sustain()` is called.
var sustain_hold: bool = false
var _sustain_from_ms: float = 0.0
var _sustain_to_ms: float = 0.0
## Fade or mute dark multiply holdout layers (smoke, soot, scorch, shadow): 1 as made, 0 hides them.
var holdout_opacity: float = 1.0:
	set(value):
		holdout_opacity = clampf(value, 0.0, 2.0)
		_apply_shader()
## Fade or boost additive/normal light layers (fire, plasma, glow, sparks): 1 as made, 0 hides them.
var light_opacity: float = 1.0:
	set(value):
		light_opacity = clampf(value, 0.0, 2.0)
		_apply_shader()
## Skip this many ms from the start of the sheet.
var trim_start_ms: float = 0.0
## Cut off this many ms from the end of the sheet.
var trim_end_ms: float = 0.0
## Delay before the sheet starts (ms): positive waits before showing frame 0; negative starts partway in.
var delay_ms: float = 0.0
## Per-piece overrides when playing a single sheet.
var piece_enabled: bool = true:
	set(value):
		piece_enabled = value
		_apply_shader()
var piece_scale: float = 1.0
var piece_speed: float = 1.0
var piece_opacity: float = 1.0:
	set(value):
		piece_opacity = clampf(value, 0.0, 2.0)
		_apply_shader()
## Advance in real time, through hit-stops and Engine.time_scale (frame_clock.gd).
var unscaled_time: bool = false:
	set(value):
		unscaled_time = value
		_clock.unscaled = value

var _clock = preload("frame_clock.gd").new()
var playing: bool = false
var time_ms: float = 0.0
var _cell := Vector2.ONE
var _draw_size := Vector2.ONE
var _pivot_px := Vector2.ZERO
var _columns: int = 1
var _sprites: Array[Sprite2D] = []
var _layer_names := PackedStringArray()
var _layer_blends := PackedStringArray()
var _layer_enabled: Dictionary = {}
var _layer_opacity: Dictionary = {}
var _frame: int = -1
var _opacity: float = 1.0
var _crop: float = 1.0


## The effect's JSON (effect.json in its folder) as a Dictionary; empty if the folder has none.
static func load_effect(effect_dir: String) -> Dictionary:
	var resource = load(effect_dir.path_join("effect.json"))
	if resource is JSON and resource.data is Dictionary:
		return resource.data
	return {}


## Build the layers. draw_size: the drawn cell in px (zero = the sheet's own on-screen size, aspect kept;
## a strip such as a beam is stretched to its length by giving a different width).
func setup(p_sheet: Dictionary, effect_dir: String, draw_size: Vector2 = Vector2.ZERO) -> void:
	sheet = p_sheet
	frames = int(sheet["frames"])
	fps = float(sheet["fps"])
	looping = bool(sheet["loop"])
	var duration := float(sheet.get("durationMs", frames * 1000.0 / maxf(fps, 1.0)))
	var sustain: Array = sheet.get("sustainMs", [duration * 0.2, duration * 0.65])
	_sustain_from_ms = float(sustain[0]) if sustain.size() >= 2 else duration * 0.2
	_sustain_to_ms = float(sustain[1]) if sustain.size() >= 2 else duration * 0.65
	var grid: Dictionary = sheet["grid"]
	_columns = int(grid["columns"])
	_cell = Vector2(float(grid["cellWidth"]), float(grid["cellHeight"]))
	_pivot_px = Vector2(float(sheet["pivot"]["px"][0]), float(sheet["pivot"]["px"][1]))
	if draw_size == Vector2.ZERO:
		draw_size = _cell * (float(sheet["onScreenPx"]) / _cell.x)
	_draw_size = draw_size
	for sprite in _sprites:
		sprite.queue_free()
	_sprites.clear()
	_layer_names.clear()
	_layer_blends.clear()
	for layer in sheet["layers"]:
		var sprite := Sprite2D.new()
		sprite.texture = load(effect_dir.path_join(layer["file"]))
		sprite.centered = false
		sprite.offset = -_pivot_px
		sprite.region_enabled = true
		sprite.scale = draw_size / _cell
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var material := ShaderMaterial.new()
		material.shader = SHADERS.get(layer["blend"], SHADERS["normal"])
		sprite.material = material
		add_child(sprite)
		_sprites.append(sprite)
		_layer_names.append(String(layer.get("name", "")))
		_layer_blends.append(String(layer.get("blend", "normal")))
	_frame = -1
	show_frame(_start_frame())


## The layer names of this sheet, in draw order (e.g. ["holdout", "light"]).
func layer_names() -> PackedStringArray:
	return _layer_names.duplicate()


func set_layer_enabled(layer_name: String, enabled: bool) -> void:
	_layer_enabled[layer_name] = enabled
	_apply_shader()


func is_layer_enabled(layer_name: String) -> bool:
	return bool(_layer_enabled.get(layer_name, true))


func set_layer_opacity(layer_name: String, value: float) -> void:
	_layer_opacity[layer_name] = clampf(value, 0.0, 2.0)
	_apply_shader()


func get_layer_opacity(layer_name: String) -> float:
	return float(_layer_opacity.get(layer_name, 1.0))


func _start_frame() -> int:
	if trim_start_ms <= 0.0:
		return 0
	return clampi(int(floor(trim_start_ms * fps / 1000.0 + 0.000001)), 0, maxi(0, frames - 1))


func _end_frame() -> int:
	var start := _start_frame()
	if trim_end_ms <= 0.0:
		return frames
	var cut := int(floor(trim_end_ms * fps / 1000.0 + 0.000001))
	return clampi(frames - cut, start + 1, frames)


## Start playing from frame 0 (one-shots hide and emit `finished` after their last frame).
func play() -> void:
	time_ms = 0.0
	playing = true
	var first := frame_at(0.0)
	visible = piece_enabled and first >= 0
	if first >= 0:
		show_frame(first)


func stop() -> void:
	playing = false


## Carry on from the frame showing (after stop() or seek_frame()).
func resume() -> void:
	playing = true
	visible = piece_enabled


## Frames in one pass (after trim_start_ms and trim_end_ms).
func frame_count() -> int:
	return maxi(1, _end_frame() - _start_frame())


func current_frame() -> int:
	return clampi(maxi(_frame, 0) - _start_frame(), 0, frame_count() - 1)


## Hold frame `index` (wrapping), shown: stepping through the sheet.
func seek_frame(index: int) -> void:
	var count := frame_count()
	var local_idx := posmod(index, count)
	var actual_idx := _start_frame() + local_idx
	playing = false
	visible = piece_enabled
	time_ms = local_idx * 1000.0 / maxf(fps * maxf(0.05, piece_speed), 1.0) - (loop_offset_ms if looping else 0.0) + maxf(0.0, delay_ms)
	show_frame(actual_idx)


## Show the middle frame, still (the editor's preview when animation is off).
func show_still() -> void:
	playing = false
	visible = piece_enabled
	show_frame(_start_frame() + int(frame_count() / 2.0))


## The drawn area around the pivot (the node origin), in local px.
func bounds() -> Rect2:
	return Rect2(-_pivot_px * (_draw_size / _cell), _draw_size)


## Release an active `sustain_hold` (or remaining `sustain_seconds`) so the sheet immediately plays its exit phase.
func release_sustain() -> void:
	var was_holding := sustain_hold
	var extra_ms := maxf(0.0, sustain_seconds * 1000.0)
	var shifted := (time_ms - delay_ms) * maxf(0.05, piece_speed)
	var eff := _effective_ms(shifted)
	sustain_hold = false
	sustain_seconds = 0.0
	if not looping and _sustain_to_ms > _sustain_from_ms and shifted >= _sustain_from_ms and (was_holding or shifted < _sustain_to_ms + extra_ms):
		time_ms = delay_ms + eff / maxf(0.05, piece_speed)


## Map elapsed playback `ms` into the authored sheet clock, Ping-Pong looping `[sustain_from_ms..sustain_to_ms]`
## while `sustain_hold` is true or for `sustain_seconds` of extra middle linger.
func _effective_ms(ms: float) -> float:
	if looping or _sustain_to_ms <= _sustain_from_ms:
		return ms
	var extra_ms := maxf(0.0, sustain_seconds * 1000.0)
	if not sustain_hold and extra_ms <= 0.0:
		return ms
	if ms <= _sustain_from_ms:
		return ms
	var span := _sustain_to_ms - _sustain_from_ms
	if sustain_hold or ms < _sustain_from_ms + span + extra_ms:
		var into := ms - _sustain_from_ms
		var cycle := fposmod(into, span * 2.0)
		var ping_pong := cycle if cycle <= span else (span * 2.0 - cycle)
		return _sustain_from_ms + ping_pong
	return ms - extra_ms


## The frame showing `ms` after the start: loops wrap; one-shots return -2 while waiting for delay_ms, and -1 once over.
func frame_at(ms: float) -> int:
	var shifted := (ms - delay_ms) * maxf(0.05, piece_speed)
	if shifted < 0.0 and not looping:
		return -2
	var start := _start_frame()
	var count := frame_count()
	var start_ms := start * 1000.0 / maxf(fps, 1.0)
	var eff := _effective_ms(shifted + start_ms) - start_ms
	var played := eff + (loop_offset_ms if looping else 0.0)
	var index := int(floor(played * fps / 1000.0 + 0.000001))
	if looping:
		return start + posmod(index, count)
	return (start + index) if index < count else -1


func show_frame(index: int) -> void:
	index = clampi(index, 0, frames - 1)
	if index == _frame:
		_apply_shader()
		return
	_frame = index
	var origin := Vector2(index % _columns, index / _columns) * _cell
	for sprite in _sprites:
		sprite.region_rect = Rect2(origin, _cell)
	_apply_shader()


## 0..1 fade of the whole sheet (multiply layers fade toward white, light toward black).
func set_opacity(value: float) -> void:
	_opacity = value
	_apply_shader()


## Show only the right-hand share of the cell (a trail strip revealed from its head), feathered.
func set_crop(share: float) -> void:
	_crop = share
	_apply_shader()


func set_flip_y(flip: bool) -> void:
	for sprite in _sprites:
		sprite.flip_v = flip


func _apply_shader() -> void:
	for i in _sprites.size():
		var sprite := _sprites[i]
		var lname := _layer_names[i] if i < _layer_names.size() else ""
		var blend := _layer_blends[i] if i < _layer_blends.size() else "normal"
		var enabled := piece_enabled and bool(_layer_enabled.get(lname, true))
		var kind_op := holdout_opacity if blend == "multiply" else light_opacity
		var layer_op := _opacity * piece_opacity * kind_op * float(_layer_opacity.get(lname, 1.0))
		sprite.visible = enabled and layer_op > 0.001
		if sprite.texture == null:
			continue
		var size := Vector2(sprite.texture.get_width(), sprite.texture.get_height())
		var cell_u := _cell.x / size.x
		var left_u := sprite.region_rect.position.x / size.x
		var material := sprite.material as ShaderMaterial
		material.set_shader_parameter("opacity", layer_op)
		material.set_shader_parameter("cut_u", left_u + (1.0 - _crop) * cell_u if _crop < 1.0 else -1.0)
		material.set_shader_parameter("feather_u", CROP_FEATHER * cell_u)


func _process(delta: float) -> void:
	if not playing:
		return
	time_ms += _clock.step(delta) * 1000.0 * speed_scale
	var index := frame_at(time_ms)
	if index == -2:
		visible = false
		return
	if index < 0:
		playing = false
		visible = false
		finished.emit()
		if free_when_finished and not Engine.is_editor_hint():
			queue_free()
		return
	visible = piece_enabled
	show_frame(index)
