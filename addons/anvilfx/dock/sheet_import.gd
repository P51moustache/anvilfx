@tool
extends RefCounted
## Turns any sprite sheet (one PNG, frames in a grid, row by row) into an AnvilFX effect: an effect.json, the
## image and a drop-in scene in res://effects/imported/<name>/, listed in that folder's index.json. The dock then
## shows it like any pack effect: a card, the preview, speed, and adding it to a scene. Pure file work, no editor
## calls, so it is tested headless.
##
## settings: {title, columns, rows, frames, fps, loop, blend ("normal" | "additive"), pivot (Vector2, 0..1 of a
## cell), px (drawn width in game)}

const Library = preload("library.gd")
const ROOT = "res://effects/imported"
const PACK_TITLE = "Imported"
const GROUND = "#0b1626"
const GRID_LINE = "#1d3b4f"
const MAX_GUESS_FRAMES = 64   # a square-cell guess with more frames than this is likely wrong; fall back to 1x1
const BLENDS = ["normal", "additive"]
const PIVOTS = [["Centre", Vector2(0.5, 0.5)], ["Bottom centre (feet, ground)", Vector2(0.5, 1.0)],
		["Left centre (muzzle, beam start)", Vector2(0.0, 0.5)]]


## [columns, rows] for a sheet `size` px: a horizontal or vertical strip of square cells, else square cells of the
## largest size that divides both sides, else one cell.
static func guess_grid(size: Vector2i) -> Vector2i:
	if size.x <= 0 or size.y <= 0:
		return Vector2i.ONE
	if size.x % size.y == 0:
		return Vector2i(size.x / size.y, 1)
	if size.y % size.x == 0:
		return Vector2i(1, size.y / size.x)
	var cell := _gcd(size.x, size.y)
	var grid := Vector2i(size.x / cell, size.y / cell)
	return grid if grid.x * grid.y <= MAX_GUESS_FRAMES else Vector2i.ONE


## The effect id for a title: "Fire Ball 2" -> "fire-ball-2" ("sheet" when nothing is left).
static func id_for(title: String) -> String:
	var id := Library._file_id(title)
	return id if id != "" else "sheet"


## effect.json for the sheet: one sheet, "main", the image as its only layer.
static func record(id: String, settings: Dictionary, image_size: Vector2i, image_file: String) -> Dictionary:
	var columns := maxi(1, int(settings["columns"]))
	var rows := maxi(1, int(settings["rows"]))
	var cell := Vector2(image_size.x / columns, image_size.y / rows)
	var frames := clampi(int(settings["frames"]), 1, columns * rows)
	var fps := maxf(1.0, float(settings["fps"]))
	var pivot: Vector2 = settings["pivot"]
	var px := maxf(1.0, float(settings["px"]))
	var ms := frames * 1000.0 / fps
	var blend: String = settings["blend"] if settings["blend"] in BLENDS else "normal"
	return {
		"id": id, "title": String(settings["title"]), "category": PACK_TITLE, "durationMs": ms,
		"loops": bool(settings["loop"]), "onScreenPx": px,
		"sheets": [{
			"name": "main", "frames": frames, "fps": fps, "loop": bool(settings["loop"]), "durationMs": ms,
			"grid": {"columns": columns, "rows": rows, "cellWidth": cell.x, "cellHeight": cell.y,
				"order": "row-major: frame 0 top-left, left to right, then top to bottom"},
			"pivot": {"x": pivot.x, "y": pivot.y, "px": [pivot.x * cell.x, pivot.y * cell.y]},
			"onScreenPx": px, "drawScale": px / cell.x,
			"layers": [{"name": "sheet", "blend": blend, "file": image_file}], "blend": blend,
		}],
	}


## The drop-in scene: one AnvilFXEffect node playing `json_path`.
static func scene_text(id: String, json_path: String) -> String:
	return "\n".join([
		"[gd_scene load_steps=3 format=3]", "",
		"[ext_resource type=\"Script\" path=\"res://addons/anvilfx/effect.gd\" id=\"1\"]",
		"[ext_resource type=\"JSON\" path=\"%s\" id=\"2\"]" % json_path, "",
		"[node name=\"%s\" type=\"Node2D\"]" % _node_name(id), "script = ExtResource(\"1\")",
		"effect = ExtResource(\"2\")", ""])


## Write the effect for `source_png` (an OS or res:// path) under `root`. Returns {ok, id, scene, error}. An id
## already taken gets a number, so importing never overwrites an earlier import.
static func write(source_png: String, settings: Dictionary, root: String = ROOT) -> Dictionary:
	if not FileAccess.file_exists(source_png):
		return {"ok": false, "error": "%s is not there any more." % source_png.get_file()}
	var image := Image.load_from_file(source_png)
	if image == null or image.is_empty():
		return {"ok": false, "error": "Could not read %s as an image." % source_png.get_file()}
	var id := _free_id(root, id_for(String(settings["title"])))
	var folder := root.path_join(id)
	DirAccess.make_dir_recursive_absolute(folder)
	var image_file := "sheet.png"
	if image.save_png(folder.path_join(image_file)) != OK:
		return {"ok": false, "error": "Could not write %s." % folder.path_join(image_file)}
	var data := record(id, settings, image.get_size(), image_file)
	var json_path := folder.path_join("effect.json")
	_write_text(json_path, JSON.stringify(data, " "))
	var scene := folder.path_join(id + ".tscn")
	_write_text(scene, scene_text(id, json_path))
	_list(root, id)
	return {"ok": true, "id": id, "scene": scene, "error": ""}


## Add `id` to root/index.json (made on the first import) so the dock lists it under "Imported".
static func _list(root: String, id: String) -> void:
	var path := root.path_join(Library.INDEX)
	var index = Library._read_json(path)
	if not index is Dictionary:
		index = {"title": PACK_TITLE, "ground": GROUND, "grid": GRID_LINE, "effects": []}
	var ids: Array = index["effects"]
	if not id in ids:
		ids.append(id)
	index["packs"] = [{"title": PACK_TITLE, "effects": ids}]
	_write_text(path, JSON.stringify(index, " "))


static func _free_id(root: String, wanted: String) -> String:
	var id := wanted
	var n := 2
	while DirAccess.dir_exists_absolute(root.path_join(id)):
		id = "%s-%d" % [wanted, n]
		n += 1
	return id


static func _node_name(id: String) -> String:
	var name := id.capitalize().replace(" ", "")
	return name if name != "" else "Sheet"


static func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


static func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t := b
		b = a % b
		a = t
	return a
