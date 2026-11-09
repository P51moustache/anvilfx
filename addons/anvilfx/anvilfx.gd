class_name AnvilFX
extends RefCounted
## Effects from game code in one line. Spawn an effect where something happened; it plays, then frees itself.
## An effect made to loop (a flame, an aura, a bolt in flight) keeps looping until you free the node spawn returns.
##
##     AnvilFX.spawn("shell-impact", hit_point)
##     AnvilFX.spawn("pulse-laser/muzzle", $Muzzle.global_position, {"attach": $Muzzle})
##     AnvilFX.spawn("shell-impact", hit_point, {"hit_stop": 0.06, "shake": 6})
##     AnvilFX.spawn("shell-impact", hit_point, {"holdout": 0.6, "pieces": {"scuff": {"scale": 1.3}}})
##
## An effect is named by its id (its folder name, as the AnvilFX tab's Copy code button writes it), "id/sheet" for
## one sheet of a multi-sheet effect, a res:// path to its .tscn, or a PackedScene. It goes under the current
## scene by default, not under whoever spawned it, so a hit effect outlives the enemy that died. Options:
##
##   attach       Node2D      go under this node and move with it (a muzzle, a hand); `at` is still a global point
##   parent       Node        go under this node instead of the current scene
##   direction    Vector2     point the effect this way (effects are drawn pointing right, +x)
##   rotation     float       or set its global rotation in radians
##   facing       float       below 0 mirrors it (a side-view character facing left); see AnvilFXEffect.flip_h
##   scale        float       size, 1 as made
##   speed        float       playback speed, 1 as made (its speed_scale)
##   sustain      float       extra seconds to hold/loop a one-shot's active middle window before its exit
##   sustain_hold bool        hold a one-shot's middle window until node.release_sustain() is called
##   holdout      float       fade or mute dark multiply holdout layers (smoke, soot, scorch): 1 as made, 0 hides them
##   light        float       fade or boost additive/normal light layers (fire, plasma, glow): 1 as made, 0 hides them
##   trim_start   float       skip this many ms from the start of the effect
##   trim_end     float       cut off this many ms from the end of the effect
##   pieces       Dictionary  per-sheet overrides: {sheet_name: bool or {enabled, offset, scale, speed, delay_ms, opacity, modulate}}
##   layers       Dictionary  per-layer overrides: {layer_name: bool or opacity_float}
##   split_pieces bool        unpack a multi-sheet effect into editable child AnvilFXEffect piece nodes
##   sheet        String      one sheet by name, as "id/sheet" does
##   loop         bool        keep replaying; you free it (spawn returns the node)
##   modulate     Color       tint and fade
##   z_index      int         draw order, absolute (z_as_relative off), so it sits above y-sorted units
##   unscaled     bool        play in real time through hit-stops and slow motion
##   while_paused bool        keep playing when the tree is paused (process_mode Always)
##   hit_stop     float       also freeze the game this many seconds (see hit_stop())
##   shake        float       also shake the current camera by up to this many px (see shake())

const Library = preload("dock/library.gd")
const Juice = preload("juice.gd")
const OPTIONS = ["attach", "parent", "direction", "rotation", "facing", "scale", "speed", "sustain",
		"sustain_hold", "holdout", "light", "trim_start", "trim_end", "pieces", "layers", "split_pieces",
		"sheet", "loop", "modulate", "z_index", "unscaled", "while_paused", "hit_stop", "shake"]
const SHAKE_SECONDS = 0.3   # an impact's shake: long enough to feel, short enough not to blur the next hit

static var _entries := {}   # id -> library entry, filled by the first lookup


## Play the effect `what` at global point `at`. Returns the effect node (null if `what` isn't found).
static func spawn(what: Variant, at: Vector2, options: Dictionary = {}) -> AnvilFXEffect:
	for key in options:
		if not key in OPTIONS:
			push_error("AnvilFX.spawn: unknown option \"%s\". Options: %s." % [key, ", ".join(OPTIONS)])
	var scene := _scene(what, String(options.get("sheet", "")))
	if scene == null:
		push_error("AnvilFX.spawn: no effect \"%s\". Ids are effect folder names; see AnvilFX.ids()." % [what])
		return null
	var node := scene.instantiate() as AnvilFXEffect
	if node == null:
		push_error("AnvilFX.spawn: %s is not an AnvilFX effect scene." % [what])
		return null
	_configure(node, options)
	var parent: Node = options.get("attach", options.get("parent", _default_parent()))
	parent.add_child(node)
	if bool(options.get("split_pieces", false)) and node.sheet == "" and node.sheet_names().size() > 1:
		node.unpack_pieces()
	node.global_position = at
	if options.has("direction") and (options["direction"] as Vector2) != Vector2.ZERO:
		node.global_rotation = (options["direction"] as Vector2).angle()
	elif options.has("rotation"):
		node.global_rotation = float(options["rotation"])
	if options.has("hit_stop"):
		hit_stop(float(options["hit_stop"]))
	if options.has("shake"):
		shake(float(options["shake"]))
	return node


## Freeze the game for `seconds` of real time (Engine.time_scale near 0), the beat that makes a hit land. A second
## call while one is on extends it. Effects spawned with "unscaled" keep playing through it.
static func hit_stop(seconds: float, time_scale: float = Juice.DEFAULT_STOP_SCALE) -> void:
	_juice().hit_stop(seconds, time_scale)


## Shake the current Camera2D (or `camera`) by up to `strength` px, fading over `seconds`. It moves the camera's
## offset and puts it back after.
static func shake(strength: float, seconds: float = SHAKE_SECONDS, camera: Camera2D = null) -> void:
	_juice().shake(strength, seconds, camera)


## Every effect id spawn() knows, with "id/sheet" for each sheet of a multi-sheet effect.
static func ids() -> PackedStringArray:
	_load_entries()
	var out := PackedStringArray()
	for id in _entries:
		out.append(id)
		for sheet in _entries[id]["sheet_scenes"]:
			out.append("%s/%s" % [id, Library._file_id(sheet)])
	return out


## Load these effects now (ids, as spawn() takes them), so the first spawn in play doesn't hitch.
static func warm(names: Array) -> void:
	for name in names:
		_scene(name, "")


## Forget the effect list, after adding or importing effects while the game runs (the editor does it for you).
static func refresh() -> void:
	_entries.clear()


## The scene for `what`: a PackedScene, a res:// path, "id" or "id/sheet".
static func _scene(what: Variant, sheet: String) -> PackedScene:
	if what is PackedScene:
		return what
	var name := String(what)
	if name.begins_with("res://") or name.begins_with("user://"):
		return load(name) as PackedScene if ResourceLoader.exists(name) else null
	var path := scene_path(name, sheet)
	return load(path) as PackedScene if path != "" and ResourceLoader.exists(path) else null


## The .tscn for an id ("id" or "id/sheet"; `sheet` names one too), "" when there's no such effect or sheet.
static func scene_path(name: String, sheet: String = "") -> String:
	_load_entries()
	var id := name.get_slice("/", 0)
	if "/" in name:
		sheet = name.get_slice("/", 1)
	if not _entries.has(id):
		return ""
	var entry: Dictionary = _entries[id]
	if sheet == "":
		return entry["scene"]
	for each in entry["sheets"]:
		if Library._file_id(each) == Library._file_id(sheet):
			# a one-sheet effect's own scene is that sheet
			return entry["sheet_scenes"].get(each, entry["scene"])
	return ""


static func _load_entries() -> void:
	if not _entries.is_empty():
		return
	for entry in Library.scan():
		if not _entries.has(entry["id"]):   # an effect a bundle and a pack both hold is the same files
			_entries[entry["id"]] = entry


static func _configure(node: AnvilFXEffect, options: Dictionary) -> void:
	node.free_when_finished = not bool(options.get("loop", false))
	if bool(options.get("loop", false)):
		node.repeat = AnvilFXEffect.Repeat.LOOP
	if float(options.get("facing", 1.0)) < 0.0:
		node.flip_h = true
	if options.has("scale"):
		node.scale = Vector2.ONE * float(options["scale"])
	if options.has("speed"):
		node.speed_scale = float(options["speed"])
	if options.has("sustain"):
		node.sustain_seconds = float(options["sustain"])
	if bool(options.get("sustain_hold", false)):
		node.sustain_hold = true
	if options.has("holdout"):
		node.holdout_opacity = float(options["holdout"])
	if options.has("light"):
		node.light_opacity = float(options["light"])
	if options.has("trim_start"):
		node.trim_start_ms = float(options["trim_start"])
	if options.has("trim_end"):
		node.trim_end_ms = float(options["trim_end"])
	if options.has("pieces") and options["pieces"] is Dictionary:
		for sheet_name in options["pieces"]:
			var cfg = options["pieces"][sheet_name]
			if cfg is bool:
				node.set_piece_enabled(String(sheet_name), cfg)
			elif cfg is Dictionary:
				for k in cfg:
					node.set_piece_property(String(sheet_name), String(k), cfg[k])
	if options.has("layers") and options["layers"] is Dictionary:
		for layer_name in options["layers"]:
			var lval = options["layers"][layer_name]
			if lval is bool:
				node.set_layer_enabled(String(layer_name), lval)
			elif lval is float or lval is int:
				node.set_layer_opacity(String(layer_name), float(lval))
	if options.has("modulate"):
		node.modulate = options["modulate"]
	if options.has("z_index"):
		node.z_as_relative = false
		node.z_index = int(options["z_index"])
	node.ignore_time_scale = bool(options.get("unscaled", false))
	if bool(options.get("while_paused", false)):
		node.process_mode = Node.PROCESS_MODE_ALWAYS


static func _default_parent() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree.current_scene else tree.root


static func _juice() -> Node:
	return Juice.of(Engine.get_main_loop() as SceneTree)
