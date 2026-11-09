@tool
extends Node2D
## Replays an effect's `sample` timeline from its JSON: every sheet where and when the pack's preview shows it
## (a muzzle, then the bolt flying along its path, then the hit; a beam starting, holding, stopping).
## The node's origin is the centre of the sample frame; scale it by game_scale() to draw it at in-game size.
## AnvilFXEffect plays whole multi-sheet effects with this. It is also a reference for wiring the sheets in a game.

signal finished

const SheetPlayer = preload("sheet_player.gd")

var effect: Dictionary = {}
var speed_scale: float = 1.0
## Extra seconds to hold/loop the active middle window (`sustainMs`) before playing the exit.
var sustain_seconds: float = 0.0
## When true, hold/loop the active middle window (`sustainMs`) indefinitely until `release_sustain()` is called.
var sustain_hold: bool = false
var _sustain_from_ms: float = 0.0
var _sustain_to_ms: float = 0.0
## Fade or mute dark multiply holdout layers across every sheet: 1 as made, 0 hides them.
var holdout_opacity: float = 1.0:
	set(value):
		holdout_opacity = clampf(value, 0.0, 2.0)
		_update()
## Fade or boost additive/normal light layers across every sheet: 1 as made, 0 hides them.
var light_opacity: float = 1.0:
	set(value):
		light_opacity = clampf(value, 0.0, 2.0)
		_update()
## Skip this many ms from the start of the sample timeline.
var trim_start_ms: float = 0.0:
	set(value):
		trim_start_ms = maxf(0.0, value)
		_update()
## Cut off this many ms from the end of the sample timeline.
var trim_end_ms: float = 0.0:
	set(value):
		trim_end_ms = maxf(0.0, value)
		_update()
## Per-piece (sheet) overrides: {sheet_name: {enabled, offset, scale, speed, delay_ms, opacity, modulate}}.
var pieces: Dictionary = {}:
	set(value):
		pieces = value.duplicate(true) if value != null else {}
		_update()
## Advance in real time, through hit-stops and Engine.time_scale (frame_clock.gd).
var unscaled_time: bool = false:
	set(value):
		unscaled_time = value
		_clock.unscaled = value

var _clock = preload("frame_clock.gd").new()
var playing: bool = false
var time_ms: float = 0.0
var duration_ms: float = 0.0
var fps: float = 60.0           # the sample's frame rate: what stepping moves by
var _tracks: Array = []          # [track Dictionary, SheetPlayer] pairs
var _size := Vector2.ZERO
var _layer_enabled: Dictionary = {}
var _layer_opacity: Dictionary = {}


func setup(p_effect: Dictionary, effect_dir: String) -> void:
	effect = p_effect
	var sample: Dictionary = effect["sample"]
	_size = Vector2(float(sample["width"]), float(sample["height"]))
	duration_ms = float(sample["durationMs"])
	fps = float(sample.get("fps", 60.0))
	var sustain: Array = sample.get("sustainMs", [duration_ms * 0.2, duration_ms * 0.65])
	_sustain_from_ms = float(sustain[0]) if sustain.size() >= 2 else duration_ms * 0.2
	_sustain_to_ms = float(sustain[1]) if sustain.size() >= 2 else duration_ms * 0.65
	var sheets := {}
	for entry in effect["sheets"]:
		sheets[entry["name"]] = entry
	for track in sample["tracks"]:
		var node := SheetPlayer.new()
		node.setup(sheets[track["sheet"]], effect_dir, Vector2(float(track["w"]), float(track["h"])))
		node.set_flip_y(bool(track["flipY"]))
		node.visible = false
		add_child(node)
		_tracks.append([track, node])


func layer_names() -> PackedStringArray:
	var names := PackedStringArray()
	for pair in _tracks:
		for lname in pair[1].layer_names():
			if not lname in names:
				names.append(lname)
	return names


func set_layer_enabled(layer_name: String, enabled: bool) -> void:
	_layer_enabled[layer_name] = enabled
	_update()


func is_layer_enabled(layer_name: String) -> bool:
	return bool(_layer_enabled.get(layer_name, true))


func set_layer_opacity(layer_name: String, value: float) -> void:
	_layer_opacity[layer_name] = clampf(value, 0.0, 2.0)
	_update()


func get_layer_opacity(layer_name: String) -> float:
	return float(_layer_opacity.get(layer_name, 1.0))


func _authored_end_ms() -> float:
	if pieces.is_empty():
		return duration_ms
	var end_ms := 0.0
	var any_custom := false
	for pair in _tracks:
		var track: Dictionary = pair[0]
		var sname := String(track["sheet"])
		var cfg: Dictionary = pieces.get(sname, {})
		if not cfg.is_empty():
			any_custom = true
		if not bool(cfg.get("enabled", true)):
			continue
		var delay := float(cfg.get("delay_ms", 0.0))
		var p_speed := maxf(0.05, float(cfg.get("speed", 1.0)))
		var base_span := float(track["toMs"]) - float(track["fromMs"])
		var to := (float(track["toMs"]) + delay) if bool(track["loop"]) else (float(track["fromMs"]) + delay + base_span / p_speed)
		end_ms = maxf(end_ms, to)
	if not any_custom:
		return duration_ms
	return end_ms if end_ms > 0.0 else duration_ms


func _start_ms() -> float:
	if trim_start_ms <= 0.0:
		return 0.0
	var step_ms := 1000.0 / maxf(fps, 1.0)
	return clampf(trim_start_ms, 0.0, maxf(0.0, _authored_end_ms() - step_ms))


func _end_ms() -> float:
	var authored := _authored_end_ms()
	if trim_end_ms <= 0.0:
		return authored
	var step_ms := 1000.0 / maxf(fps, 1.0)
	return maxf(_start_ms() + step_ms, authored - trim_end_ms)


func play() -> void:
	time_ms = _start_ms()
	playing = true
	visible = true
	_update()


func stop() -> void:
	playing = false


## Carry on from where it stands (after stop() or seek_frame()).
func resume() -> void:
	playing = true
	visible = true


## Sample frames in one pass (after trim_start_ms, trim_end_ms and piece timing).
func frame_count() -> int:
	var span_ms := maxf(0.0, _end_ms() - _start_ms())
	return maxi(1, int(ceil(span_ms * fps / 1000.0)))


func current_frame() -> int:
	var into_ms := maxf(0.0, _effective_ms(time_ms) - _start_ms())
	return clampi(int(floor(into_ms * fps / 1000.0 + 0.000001)), 0, frame_count() - 1)


## Hold sample frame `index` (wrapping), shown: stepping through the timeline.
func seek_frame(index: int) -> void:
	playing = false
	visible = true
	time_ms = _start_ms() + posmod(index, frame_count()) * 1000.0 / fps
	_update()


## Show the middle of the timeline, still (the editor's preview when animation is off).
func show_still() -> void:
	playing = false
	visible = true
	time_ms = (_start_ms() + _end_ms()) * 0.5
	_update()


## The scale that draws the sample's sheets at their in-game size (the largest sheet sets it).
func game_scale() -> float:
	var best := 0.0
	var result := 1.0
	for pair in _tracks:
		var on_screen := float(pair[1].sheet["onScreenPx"])
		if on_screen > best:
			best = on_screen
			result = on_screen / float(pair[0]["w"])
	return result


## Authored + customized placement for `sheet_name` in in-game px relative to the effect's origin.
func track_placement(sheet_name: String) -> Dictionary:
	var g_scale := maxf(game_scale(), 0.001)
	var cfg: Dictionary = pieces.get(sheet_name, {})
	var p_scale := maxf(0.05, float(cfg.get("scale", 1.0)))
	var p_offset: Vector2 = cfg.get("offset", Vector2.ZERO)
	for pair in _tracks:
		var track: Dictionary = pair[0]
		var node = pair[1]
		if String(track["sheet"]) != sheet_name:
			continue
		var centre := Vector2(float(track["x"]), float(track["y"]))
		if not track["path"].is_empty():
			centre = Vector2(float(track["path"][0][1]), float(track["path"][0][2]))
		var cell_size := Vector2(float(track["w"]), float(track["h"]))
		var pivot := Vector2(float(node.sheet["pivot"]["x"]), float(node.sheet["pivot"]["y"]))
		var pos: Vector2 = (centre - _size / 2.0 + (pivot - Vector2(0.5, 0.5)) * cell_size) * g_scale + p_offset
		var on_screen := maxf(1.0, float(node.sheet.get("onScreenPx", track["w"])))
		var ratio := (float(track["w"]) * g_scale / on_screen) * p_scale
		return {
			"enabled": bool(cfg.get("enabled", true)),
			"position": pos,
			"scale": ratio,
			"speed": maxf(0.05, float(cfg.get("speed", 1.0))),
			"delay_ms": float(cfg.get("delay_ms", 0.0)) + float(track["fromMs"]),
			"opacity": clampf(float(cfg.get("opacity", 1.0)), 0.0, 2.0),
			"modulate": cfg.get("modulate", Color.WHITE),
			"flip_v": bool(track.get("flipY", false)),
		}
	return {
		"enabled": bool(cfg.get("enabled", true)),
		"position": p_offset,
		"scale": p_scale,
		"speed": maxf(0.05, float(cfg.get("speed", 1.0))),
		"delay_ms": float(cfg.get("delay_ms", 0.0)),
		"opacity": clampf(float(cfg.get("opacity", 1.0)), 0.0, 2.0),
		"modulate": cfg.get("modulate", Color.WHITE),
		"flip_v": false,
	}


## The sample frame around the node origin, in local px (before the node's scale).
func bounds() -> Rect2:
	return Rect2(-_size / 2.0, _size)


static func interp(keys: Array, t: float, column: int) -> float:
	if t <= float(keys[0][0]):
		return float(keys[0][column])
	for k in range(1, keys.size()):
		if t <= float(keys[k][0]):
			var a: Array = keys[k - 1]
			var b: Array = keys[k]
			var span := float(b[0]) - float(a[0])
			if span <= 0.0:
				return float(b[column])
			return lerpf(float(a[column]), float(b[column]), (t - float(a[0])) / span)
	return float(keys[keys.size() - 1][column])


## Release an active `sustain_hold` (or remaining `sustain_seconds`) so the sample immediately plays its exit phase.
func release_sustain() -> void:
	var was_holding := sustain_hold
	var extra_ms := maxf(0.0, sustain_seconds * 1000.0)
	var eff := _effective_ms(time_ms)
	sustain_hold = false
	sustain_seconds = 0.0
	if _sustain_to_ms > _sustain_from_ms and time_ms >= _sustain_from_ms and (was_holding or time_ms < _sustain_to_ms + extra_ms):
		time_ms = eff


func _effective_ms(ms: float) -> float:
	if _sustain_to_ms <= _sustain_from_ms:
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


func _total_duration_ms() -> float:
	return _end_ms() + (maxf(0.0, sustain_seconds * 1000.0) if _sustain_to_ms > _sustain_from_ms else 0.0)


func _update() -> void:
	if _tracks.is_empty():
		return
	var eff_ms := _effective_ms(time_ms)
	var g_scale := maxf(game_scale(), 0.001)
	for pair in _tracks:
		var track: Dictionary = pair[0]
		var node = pair[1]
		var sname := String(track["sheet"])
		var cfg: Dictionary = pieces.get(sname, {})
		if not bool(cfg.get("enabled", true)):
			node.visible = false
			continue
		var delay := float(cfg.get("delay_ms", 0.0))
		var p_speed := maxf(0.05, float(cfg.get("speed", 1.0)))
		var p_scale := maxf(0.05, float(cfg.get("scale", 1.0)))
		var p_offset: Vector2 = cfg.get("offset", Vector2.ZERO)
		var p_opacity := clampf(float(cfg.get("opacity", 1.0)), 0.0, 2.0)
		var p_modulate: Color = cfg.get("modulate", Color.WHITE)
		var from := float(track["fromMs"]) + delay
		var base_span := float(track["toMs"]) - float(track["fromMs"])
		var track_loops := bool(track["loop"])
		var to := (float(track["toMs"]) + delay) if track_loops else (from + base_span / p_speed)
		var showing := eff_ms >= from and eff_ms < to
		var track_ms := float(track["fromMs"]) + (eff_ms - from) * p_speed
		var opacity := (interp(track["opacity"], track_ms, 1) if not track["opacity"].is_empty() else 1.0) * p_opacity
		node.visible = showing and opacity > 0.002
		if not node.visible:
			continue
		node.holdout_opacity = holdout_opacity
		node.light_opacity = light_opacity
		for lname in _layer_enabled:
			node.set_layer_enabled(String(lname), bool(_layer_enabled[lname]))
		for lname in _layer_opacity:
			node.set_layer_opacity(String(lname), float(_layer_opacity[lname]))
		# As the pack's previews: a looping track wraps (from its offset), a one-shot holds its last frame.
		var played := (eff_ms - from) * p_speed
		if track_loops:
			played += float(track["loopOffsetMs"])
		var index := int(floor(played * node.fps / 1000.0 + 0.000001))
		node.show_frame(posmod(index, node.frames) if track_loops else clampi(index, 0, node.frames - 1))
		node.set_opacity(opacity)
		node.set_crop(interp(track["crop"], track_ms, 1) if not track["crop"].is_empty() else 1.0)
		node.modulate = p_modulate
		node.scale = Vector2.ONE * p_scale
		var centre := Vector2(float(track["x"]), float(track["y"]))
		if not track["path"].is_empty():
			centre = Vector2(interp(track["path"], track_ms, 1), interp(track["path"], track_ms, 2))
		var cell_size := Vector2(float(track["w"]), float(track["h"]))
		var pivot := Vector2(float(node.sheet["pivot"]["x"]), float(node.sheet["pivot"]["y"]))
		# The sample places each cell by its centre; the sheet node sits on the cell's pivot.
		node.position = centre - _size / 2.0 + (pivot - Vector2(0.5, 0.5)) * cell_size + p_offset / g_scale


func _process(delta: float) -> void:
	if not playing:
		return
	time_ms += _clock.step(delta) * 1000.0 * speed_scale
	if not sustain_hold and time_ms >= _total_duration_ms():
		playing = false
		for pair in _tracks:
			pair[1].visible = false
		finished.emit()
		return
	_update()
