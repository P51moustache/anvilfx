@tool
@icon("res://addons/anvilfx/icon.svg")
class_name AnvilFXEffect
extends Node2D
## A drop-in effect from an AnvilFX pack. Drag an effect's scene (the .tscn files in its pack folder) into a
## level, or make it a child of a character's Marker2D (a barrel tip, the feet) so it moves with the character.
## Or add an AnvilFXEffect node yourself and pick an effect.json.
##
## The node's origin is the sheet's pivot, the point the effect is attached at (a contact point, a muzzle); a
## whole multi-sheet effect is centred on its sample frame instead. Sheets are drawn at their in-game size. Rotate
## the node to aim it and scale it to resize, but never squash it: ground sheets are already projected for the
## view. `modulate` tints and fades it.
##
## Every piece (sheet) and layer of an effect can be customized in the Inspector under Pieces and Layers, in the
## AnvilFX dock, or from code via `set_piece_*()`, `set_layer_*()`, `unpack_pieces()`, or `AnvilFX.spawn()`:
##
##     AnvilFX.spawn("pulse-laser/hit", contact, {"direction": velocity})
##     AnvilFX.spawn("shell-impact", contact, {"holdout": 0.6, "pieces": {"scuff": {"scale": 1.3}}})

## Emitted when a one-pass effect ends (never for one that repeats).
signal finished

## AS_MADE: looping sheets loop and one-shots play once. LOOP: replay forever. ONCE: one pass, then `finished`.
enum Repeat { AS_MADE, LOOP, ONCE }

const SheetPlayer = preload("sheet_player.gd")
const SamplePlayer = preload("sample_player.gd")
const EDITOR_PAUSE_MS = 700.0   # bare gap before a one-shot replays in the editor, so its end reads
const PIECE_DEFAULTS = {
	"enabled": true,
	"offset": Vector2.ZERO,
	"scale": 1.0,
	"speed": 1.0,
	"delay_ms": 0.0,
	"opacity": 1.0,
	"modulate": Color.WHITE,
}

## The effect's effect.json, in its pack folder.
@export var effect: JSON:
	set(value):
		effect = value
		notify_property_list_changed()
		update_configuration_warnings()
		_rebuild()
## One sheet of the effect, by name. Empty plays the whole effect (every sheet, timed as in the pack's preview).
@export var sheet: String = "":
	set(value):
		sheet = value
		notify_property_list_changed()
		update_configuration_warnings()
		_rebuild()
## Start playing when the node enters the scene tree.
@export var autoplay: bool = true
@export var repeat: Repeat = Repeat.AS_MADE
## Playback speed. Each sheet was painted for a frame rate (authored_fps()); 1 plays it as made. Faster shows each
## frame for less time and slower holds each frame longer: no frames are added, so far below 1 the motion steps.
@export_range(0.05, 4.0, 0.05, "or_greater") var speed_scale: float = 1.0:
	set(value):
		speed_scale = value
		if _player:
			_player.speed_scale = value
## Extra seconds to hold/loop the effect's active middle window (`sustainMs`) before playing its natural exit.
@export_range(0.0, 30.0, 0.1, "or_greater") var sustain_seconds: float = 0.0:
	set(value):
		sustain_seconds = maxf(0.0, value)
		if _player:
			_player.sustain_seconds = sustain_seconds
## Hold/loop the effect's active middle window (`sustainMs`) indefinitely until `release_sustain()` is called.
@export var sustain_hold: bool = false:
	set(value):
		sustain_hold = value
		if _player:
			_player.sustain_hold = value
@export_group("Layers & Timing")
## Fade or mute dark multiply holdout layers (smoke, soot, scorch, shadow): 1 as made, 0 hides them.
@export_range(0.0, 1.0, 0.05) var holdout_opacity: float = 1.0:
	set(value):
		holdout_opacity = clampf(value, 0.0, 2.0)
		_apply_customizations()
## Fade or boost additive/normal light layers (fire, plasma, glow, sparks): 1 as made, 0 hides them, >1 boosts glow.
@export_range(0.0, 2.0, 0.05, "or_greater") var light_opacity: float = 1.0:
	set(value):
		light_opacity = clampf(value, 0.0, 2.0)
		_apply_customizations()
## Skip this many ms from the start of the effect (e.g. skip a windup or implosion phase).
@export_range(0.0, 5000.0, 10.0, "or_greater", "suffix:ms") var trim_start_ms: float = 0.0:
	set(value):
		trim_start_ms = maxf(0.0, value)
		_apply_customizations()
## Cut off this many ms from the end of the effect (e.g. shorten a lingering smoke tail).
@export_range(0.0, 5000.0, 10.0, "or_greater", "suffix:ms") var trim_end_ms: float = 0.0:
	set(value):
		trim_end_ms = maxf(0.0, value)
		_apply_customizations()
@export_group("")
## Mirror the effect left to right around its origin, for a character facing left in a side view. Use it rather
## than a negative scale.x, which also mirrors the node's children.
@export var flip_h: bool = false:
	set(value):
		flip_h = value
		_apply_flip()
## Play in real time, ignoring Engine.time_scale: the effect keeps moving through a hit-stop or slow motion.
## (A paused tree still stops it, unless process_mode is Always.)
@export var ignore_time_scale: bool = false:
	set(value):
		ignore_time_scale = value
		if _player:
			_player.unscaled_time = value
## Free this node when a one-pass effect ends (never in the editor).
@export var free_when_finished: bool = false
## Animate in the editor viewport. Off shows a still frame.
@export var preview_in_editor: bool = true:
	set(value):
		preview_in_editor = value
		_rebuild()
## Per-piece (sheet) overrides: {sheet_name: {enabled, offset, scale, speed, delay_ms, opacity, modulate}}.
## Edited in the Inspector under Pieces, or set via set_piece_*() or AnvilFX.spawn(..., {"pieces": ...}).
@export var pieces: Dictionary = {}:
	set(value):
		pieces = value.duplicate(true) if value != null else {}
		_apply_customizations()

## The editor replays an effect when it ends, so it keeps reading in the viewport. The AnvilFX dock's preview
## turns this off so its Loop box is honoured.
var editor_replay: bool = true

var _player = null            # a SheetPlayer or SamplePlayer
var _restart_ms: float = -1.0
var _layer_enabled: Dictionary = {}
var _layer_opacity: Dictionary = {}


func _ready() -> void:
	_rebuild()


## Play from the start (shows the node's effect if it was hidden).
func play() -> void:
	for child in _unpacked_pieces():
		child.play()
	if _player == null:
		return
	_restart_ms = -1.0
	_apply_customizations()
	_player.sustain_seconds = sustain_seconds
	_player.sustain_hold = sustain_hold
	if _player is SheetPlayer:   # ONCE plays a looping sheet for one cycle
		_player.looping = bool(_player.sheet["loop"]) and repeat != Repeat.ONCE
	_player.play()


## Stop and hide.
func stop() -> void:
	_restart_ms = -1.0
	for child in _unpacked_pieces():
		child.stop()
	if _player:
		_player.stop()
		_player.visible = false


func is_playing() -> bool:
	if _player != null and _player.playing:
		return true
	for child in _unpacked_pieces():
		if child.is_playing():
			return true
	return false


## Hold the frame showing; resume() carries on from it, play() starts over.
func pause() -> void:
	_restart_ms = -1.0
	for child in _unpacked_pieces():
		child.pause()
	if _player:
		_player.stop()


## Carry on after pause() or seek_frame(); starts over if the effect had ended.
func resume() -> void:
	for child in _unpacked_pieces():
		child.resume()
	if _player == null:
		return
	if not _player.visible:
		play()
		return
	_restart_ms = -1.0
	_player.resume()


## Frames in one pass: the sheet's, or the sample timeline's for a whole multi-sheet effect.
func frame_count() -> int:
	return _player.frame_count() if _player else 0


func current_frame() -> int:
	return _player.current_frame() if _player else 0


## Release an active `sustain_hold` (or remaining `sustain_seconds`) on the current play so the effect immediately
## plays its exit phase. Calling `play()` again later reuses the node's `sustain_seconds` and `sustain_hold`.
func release_sustain() -> void:
	for child in _unpacked_pieces():
		child.release_sustain()
	if _player and _player.has_method("release_sustain"):
		_player.release_sustain()


## Hold frame `index` (wrapping), for stepping through the effect.
func seek_frame(index: int) -> void:
	_restart_ms = -1.0
	for child in _unpacked_pieces():
		child.seek_frame(index)
	if _player:
		_player.seek_frame(index)


## The frame rate the effect was painted for: its sheet's, or the sample timeline's for a whole multi-sheet effect.
## Playing at a set rate: `speed_scale = wanted_fps / authored_fps()`.
func authored_fps() -> float:
	return float(_player.fps) if _player else 0.0


## The sheet names of the chosen effect, in pack order.
func sheet_names() -> PackedStringArray:
	var names := PackedStringArray()
	for entry in _data().get("sheets", []):
		names.append(String(entry["name"]))
	return names


## The layer names of the chosen effect (or sheet), in draw order (e.g. ["holdout", "light"]).
func layer_names() -> PackedStringArray:
	var names := PackedStringArray()
	for entry in _data().get("sheets", []):
		if sheet != "" and String(entry["name"]) != sheet:
			continue
		for layer in entry.get("layers", []):
			var lname := String(layer.get("name", ""))
			if lname != "" and not lname in names:
				names.append(lname)
	return names


func set_layer_enabled(layer_name: String, enabled: bool) -> void:
	if enabled:
		_layer_enabled.erase(layer_name)
	else:
		_layer_enabled[layer_name] = false
	_apply_customizations()


func is_layer_enabled(layer_name: String) -> bool:
	return bool(_layer_enabled.get(layer_name, true))


func set_layer_opacity(layer_name: String, value: float) -> void:
	var clamped := clampf(value, 0.0, 2.0)
	if is_equal_approx(clamped, 1.0):
		_layer_opacity.erase(layer_name)
	else:
		_layer_opacity[layer_name] = clamped
	_apply_customizations()


func get_layer_opacity(layer_name: String) -> float:
	return float(_layer_opacity.get(layer_name, 1.0))


## Set one property (`enabled`, `offset`, `scale`, `speed`, `delay_ms`, `opacity`, `modulate`) on a sheet piece.
func set_piece_property(sheet_name: String, key: String, value: Variant) -> void:
	if not PIECE_DEFAULTS.has(key):
		return
	var cfg: Dictionary = pieces.get(sheet_name, {}).duplicate()
	if _is_default_piece_value(key, value):
		cfg.erase(key)
	else:
		cfg[key] = value
	if cfg.is_empty():
		pieces.erase(sheet_name)
	else:
		pieces[sheet_name] = cfg
	_apply_customizations()


func get_piece_property(sheet_name: String, key: String) -> Variant:
	var cfg: Dictionary = pieces.get(sheet_name, {})
	return cfg.get(key, PIECE_DEFAULTS.get(key))


func set_piece_enabled(sheet_name: String, enabled: bool) -> void:
	set_piece_property(sheet_name, "enabled", enabled)


func is_piece_enabled(sheet_name: String) -> bool:
	return bool(get_piece_property(sheet_name, "enabled"))


func set_piece_offset(sheet_name: String, offset: Vector2) -> void:
	set_piece_property(sheet_name, "offset", offset)


func get_piece_offset(sheet_name: String) -> Vector2:
	return get_piece_property(sheet_name, "offset") as Vector2


func set_piece_scale(sheet_name: String, piece_scale: float) -> void:
	set_piece_property(sheet_name, "scale", maxf(0.05, piece_scale))


func get_piece_scale(sheet_name: String) -> float:
	return float(get_piece_property(sheet_name, "scale"))


func set_piece_speed(sheet_name: String, piece_speed: float) -> void:
	set_piece_property(sheet_name, "speed", maxf(0.05, piece_speed))


func get_piece_speed(sheet_name: String) -> float:
	return float(get_piece_property(sheet_name, "speed"))


func set_piece_delay_ms(sheet_name: String, delay_ms: float) -> void:
	set_piece_property(sheet_name, "delay_ms", delay_ms)


func get_piece_delay_ms(sheet_name: String) -> float:
	return float(get_piece_property(sheet_name, "delay_ms"))


func set_piece_opacity(sheet_name: String, opacity: float) -> void:
	set_piece_property(sheet_name, "opacity", clampf(opacity, 0.0, 2.0))


func get_piece_opacity(sheet_name: String) -> float:
	return float(get_piece_property(sheet_name, "opacity"))


func set_piece_modulate(sheet_name: String, color: Color) -> void:
	set_piece_property(sheet_name, "modulate", color)


func get_piece_modulate(sheet_name: String) -> Color:
	return get_piece_property(sheet_name, "modulate") as Color


## Clear all per-piece overrides back to their authored defaults.
func reset_pieces() -> void:
	pieces.clear()
	_apply_customizations()


## Authored + customized placement for `sheet_name` in in-game px relative to this effect's origin.
func piece_placement(sheet_name: String) -> Dictionary:
	if _player is SamplePlayer:
		return _player.track_placement(sheet_name)
	var data := _data()
	if data.has("sample") and data.get("sheets", []).size() > 1 and effect != null:
		var sample := SamplePlayer.new()
		sample.setup(data, effect.resource_path.get_base_dir())
		sample.pieces = pieces.duplicate(true)
		var out := sample.track_placement(sheet_name)
		sample.free()
		return out
	var cfg: Dictionary = pieces.get(sheet_name, {})
	return {
		"enabled": bool(cfg.get("enabled", true)),
		"position": cfg.get("offset", Vector2.ZERO) as Vector2,
		"scale": maxf(0.05, float(cfg.get("scale", 1.0))),
		"speed": maxf(0.05, float(cfg.get("speed", 1.0))),
		"delay_ms": float(cfg.get("delay_ms", 0.0)),
		"opacity": clampf(float(cfg.get("opacity", 1.0)), 0.0, 2.0),
		"modulate": cfg.get("modulate", Color.WHITE) as Color,
		"flip_v": false,
	}


## Split a multi-sheet effect into editable child `AnvilFXEffect` nodes (one per enabled sheet), placed and scaled to
## match the composite assembly. When `target_parent` is null, adds the piece nodes as children of `self` and hides the
## internal combined player so each piece can be selected, moved, Z-sorted or animated independently in the Scene tree.
func unpack_pieces(target_parent: Node = null) -> Array[AnvilFXEffect]:
	var parent: Node = target_parent if target_parent != null else self
	var created: Array[AnvilFXEffect] = []
	for sname in sheet_names():
		var placement := piece_placement(sname)
		if not bool(placement.get("enabled", true)):
			continue
		var child := AnvilFXEffect.new()
		child.name = _piece_node_name(sname)
		child.effect = effect
		child.sheet = sname
		child.autoplay = autoplay
		child.repeat = repeat
		child.speed_scale = speed_scale * float(placement.get("speed", 1.0))
		child.sustain_seconds = sustain_seconds
		child.sustain_hold = sustain_hold
		child.holdout_opacity = holdout_opacity
		child.light_opacity = light_opacity
		child.trim_start_ms = trim_start_ms
		child.trim_end_ms = trim_end_ms
		child.flip_h = flip_h
		child.ignore_time_scale = ignore_time_scale
		child.preview_in_editor = preview_in_editor
		child.editor_replay = editor_replay
		child.position = placement.get("position", Vector2.ZERO) as Vector2
		child.scale = Vector2.ONE * float(placement.get("scale", 1.0))
		child.modulate = placement.get("modulate", Color.WHITE) as Color
		var delay := float(placement.get("delay_ms", 0.0))
		if not is_zero_approx(delay):
			child.set_piece_delay_ms(sname, delay)
		var op := float(placement.get("opacity", 1.0))
		if not is_equal_approx(op, 1.0):
			child.set_piece_opacity(sname, op)
		parent.add_child(child, true)
		created.append(child)
	if parent == self and _player != null:
		remove_child(_player)
		_player.queue_free()
		_player = null
	return created


## The drawn area around the node's origin, in local px before the node's own scale.
func bounds() -> Rect2:
	if _player == null:
		return Rect2()
	var box: Rect2 = _player.bounds()
	return Rect2(box.position * _player.scale, box.size * _player.scale).abs()   # abs: flip_h mirrors x


func _unpacked_pieces() -> Array[AnvilFXEffect]:
	var out: Array[AnvilFXEffect] = []
	for child in get_children():
		if child is AnvilFXEffect:
			out.append(child)
	return out


static func _piece_node_name(sheet_name: String) -> String:
	var words := PackedStringArray()
	for part in sheet_name.replace("_", "-").replace(" ", "-").split("-", false):
		words.append(part.capitalize())
	return "".join(words) if not words.is_empty() else "Piece"


static func _is_default_piece_value(key: String, value: Variant) -> bool:
	var def = PIECE_DEFAULTS.get(key)
	if def is float and (value is float or value is int):
		return is_equal_approx(float(value), float(def))
	if def is Vector2 and value is Vector2:
		return (value as Vector2).is_equal_approx(def as Vector2)
	if def is Color and value is Color:
		return (value as Color).is_equal_approx(def as Color)
	return value == def


func _data() -> Dictionary:
	if effect != null and effect.data is Dictionary:
		return effect.data
	return {}


func _rebuild() -> void:
	if not is_node_ready():
		return
	if _player:
		remove_child(_player)
		_player.queue_free()
		_player = null
	_restart_ms = -1.0
	if not _unpacked_pieces().is_empty():
		return
	_player = _make_player()
	if _player == null:
		return
	_player.speed_scale = speed_scale
	_player.sustain_seconds = sustain_seconds
	_player.sustain_hold = sustain_hold
	_player.unscaled_time = ignore_time_scale
	_apply_customizations()
	_player.finished.connect(_on_player_finished)
	add_child(_player)
	_apply_flip()
	if Engine.is_editor_hint():
		if preview_in_editor:
			play()
		else:
			_player.show_still()
	elif autoplay:
		play()
	else:
		_player.visible = false


func _make_player() -> Node2D:
	var data := _data()
	if data.is_empty():
		return null
	var dir := effect.resource_path.get_base_dir()
	var sheets: Array = data["sheets"]
	if sheet == "" and sheets.size() > 1:
		var sample := SamplePlayer.new()
		sample.setup(data, dir)
		sample.scale = Vector2.ONE * sample.game_scale()
		return sample
	var wanted := sheet if sheet != "" else String(sheets[0]["name"])
	for entry in sheets:
		if entry["name"] == wanted:
			var player := SheetPlayer.new()
			player.setup(entry, dir)
			return player
	return null


func _apply_customizations() -> void:
	for child in _unpacked_pieces():
		child.holdout_opacity = holdout_opacity
		child.light_opacity = light_opacity
		child.trim_start_ms = trim_start_ms
		child.trim_end_ms = trim_end_ms
	if _player == null:
		return
	_player.holdout_opacity = holdout_opacity
	_player.light_opacity = light_opacity
	_player.trim_start_ms = trim_start_ms
	_player.trim_end_ms = trim_end_ms
	if _player is SamplePlayer:
		_player._layer_enabled = _layer_enabled.duplicate()
		_player._layer_opacity = _layer_opacity.duplicate()
		_player.pieces = pieces.duplicate(true)
	elif _player is SheetPlayer:
		var sname := String(_player.sheet.get("name", sheet))
		var cfg: Dictionary = pieces.get(sname, {})
		_player.piece_enabled = bool(cfg.get("enabled", true))
		_player.position = cfg.get("offset", Vector2.ZERO) as Vector2
		_player.piece_scale = maxf(0.05, float(cfg.get("scale", 1.0)))
		_player.piece_speed = maxf(0.05, float(cfg.get("speed", 1.0)))
		_player.delay_ms = float(cfg.get("delay_ms", 0.0))
		_player.piece_opacity = clampf(float(cfg.get("opacity", 1.0)), 0.0, 2.0)
		_player.modulate = cfg.get("modulate", Color.WHITE) as Color
		_player._layer_enabled = _layer_enabled.duplicate()
		_player._layer_opacity = _layer_opacity.duplicate()
		_apply_flip()
		_player._apply_shader()


func _apply_flip() -> void:
	if _player == null:
		return
	if _player is SheetPlayer:
		var sc: float = _player.piece_scale
		_player.scale = Vector2(-sc if flip_h else sc, sc)
	else:
		_player.scale.x = -absf(_player.scale.x) if flip_h else absf(_player.scale.x)


## Whether the player starts over when it ends, rather than the node finishing.
func _repeats() -> bool:
	match repeat:
		Repeat.LOOP:
			return true
		Repeat.ONCE:
			return false
	return _player is SamplePlayer and bool(_data().get("loops", false))


func _on_player_finished() -> void:
	if Engine.is_editor_hint() and editor_replay:
		_restart_ms = 0.0 if _repeats() else EDITOR_PAUSE_MS
		return
	if _repeats():
		play()
		return
	finished.emit()
	if free_when_finished and not Engine.is_editor_hint():
		queue_free()


func _process(delta: float) -> void:
	if _restart_ms < 0.0:
		return
	_restart_ms -= delta * 1000.0
	if _restart_ms <= 0.0:
		play()


func _validate_property(property: Dictionary) -> void:
	if property.name == "sheet":
		property.hint = PROPERTY_HINT_ENUM_SUGGESTION
		property.hint_string = ",".join(sheet_names())
	elif property.name == "pieces":
		property.usage = PROPERTY_USAGE_STORAGE


func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	var names := sheet_names()
	if names.is_empty():
		return props
	props.append({
		"name": "Pieces",
		"type": TYPE_NIL,
		"hint_string": "pieces/",
		"usage": PROPERTY_USAGE_GROUP,
	})
	for sname in names:
		if sheet != "" and sname != sheet:
			continue
		var prefix := "pieces/%s/" % sname
		props.append({
			"name": sname,
			"type": TYPE_NIL,
			"hint_string": prefix,
			"usage": PROPERTY_USAGE_SUBGROUP,
		})
		props.append({"name": prefix + "enabled", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_EDITOR})
		props.append({"name": prefix + "offset", "type": TYPE_VECTOR2, "hint": PROPERTY_HINT_NONE, "hint_string": "suffix:px", "usage": PROPERTY_USAGE_EDITOR})
		props.append({"name": prefix + "scale", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.1,4.0,0.05,or_greater", "usage": PROPERTY_USAGE_EDITOR})
		props.append({"name": prefix + "speed", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.1,4.0,0.05,or_greater", "usage": PROPERTY_USAGE_EDITOR})
		props.append({"name": prefix + "delay_ms", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "-1000.0,3000.0,10.0,or_less,or_greater,suffix:ms", "usage": PROPERTY_USAGE_EDITOR})
		props.append({"name": prefix + "opacity", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.05", "usage": PROPERTY_USAGE_EDITOR})
		props.append({"name": prefix + "modulate", "type": TYPE_COLOR, "usage": PROPERTY_USAGE_EDITOR})
	return props


func _get(property: StringName) -> Variant:
	var path := String(property)
	if path.begins_with("pieces/"):
		var parts := path.split("/", false)
		if parts.size() == 3 and PIECE_DEFAULTS.has(parts[2]):
			return get_piece_property(parts[1], parts[2])
	return null


func _set(property: StringName, value: Variant) -> bool:
	var path := String(property)
	if path.begins_with("pieces/"):
		var parts := path.split("/", false)
		if parts.size() == 3 and PIECE_DEFAULTS.has(parts[2]):
			set_piece_property(parts[1], parts[2], value)
			return true
	return false


func _property_can_revert(property: StringName) -> bool:
	var path := String(property)
	if path.begins_with("pieces/"):
		var parts := path.split("/", false)
		return parts.size() == 3 and PIECE_DEFAULTS.has(parts[2])
	return false


func _property_get_revert(property: StringName) -> Variant:
	var path := String(property)
	if path.begins_with("pieces/"):
		var parts := path.split("/", false)
		if parts.size() == 3 and PIECE_DEFAULTS.has(parts[2]):
			return PIECE_DEFAULTS[parts[2]]
	return null


func _get_configuration_warnings() -> PackedStringArray:
	if effect == null:
		return PackedStringArray(["Pick an effect.json from an AnvilFX pack folder."])
	if _data().is_empty():
		return PackedStringArray(["This effect.json could not be read."])
	if sheet != "" and not sheet in sheet_names():
		return PackedStringArray(["No sheet named \"%s\". This effect has: %s." % [sheet, ", ".join(sheet_names())]])
	return PackedStringArray()
