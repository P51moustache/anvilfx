@tool
extends RefCounted
## The AnvilFX effects in a project: every pack folder (one holding an index.json) found under res://, and each
## effect in it with what the dock shows and drops. Pure data: no nodes, no editor calls, so it is tested headless.
##
## An entry is a Dictionary:
##   id, title, category, pack (the pack title it is listed under), ground (the pack's floor colour),
##   json (res:// path of effect.json), scene (the whole effect's .tscn), sheets (names, pack order),
##   sheet_scenes ({sheet: .tscn}, for multi-sheet effects), px (in-game size), seconds, loops

const INDEX = "index.json"
const SKIP = [".godot", ".import", "addons"]   # never hold packs; skipping them keeps the scan quick


## Every effect under `root`, in pack order. An effect a bundle and a pack both hold is listed once per pack.
static func scan(root: String = "res://") -> Array:
	var entries: Array = []
	for index_path in _index_files(root):
		entries.append_array(_pack_entries(index_path))
	return entries


## [title, count] per pack, in the order packs were found.
static func packs(entries: Array) -> Array:
	return _tally(entries, "pack")


## [title, count] per category, in the order categories were met.
static func categories(entries: Array) -> Array:
	return _tally(entries, "category")


## The entries that match: `kind` is "all", "favourites", "pack" or "category" (with `value`), then the search
## words, all of which must appear in the title, category or pack.
static func filter(entries: Array, kind: String, value: String, query: String, favourites: Array) -> Array:
	var words := query.to_lower().split(" ", false)
	var out: Array = []
	for entry in entries:
		if not _in_group(entry, kind, value, favourites):
			continue
		var text := ("%s %s %s %s" % [entry["title"], entry["category"], entry["pack"], entry["id"]]).to_lower()
		var hit := true
		for word in words:
			if not word in text:
				hit = false
				break
		if hit:
			out.append(entry)
	return out


## "96 px · 0.42 s": the card's size and length line.
static func size_line(entry: Dictionary) -> String:
	return "%d px  ·  %.2f s" % [int(entry["px"]), float(entry["seconds"])]


## The scene to instance for an entry and a sheet ("" is the whole effect).
static func scene_for(entry: Dictionary, sheet: String) -> String:
	return entry["sheet_scenes"].get(sheet, entry["scene"])


static func _in_group(entry: Dictionary, kind: String, value: String, favourites: Array) -> bool:
	match kind:
		"favourites":
			return entry["id"] in favourites
		"pack":
			return entry["pack"] == value
		"category":
			return entry["category"] == value
	return true


static func _tally(entries: Array, key: String) -> Array:
	var order: Array = []
	var counts := {}
	for entry in entries:
		var name: String = entry[key]
		if not counts.has(name):
			order.append(name)
			counts[name] = 0
		counts[name] += 1
	var out: Array = []
	for name in order:
		out.append([name, counts[name]])
	return out


static func _index_files(dir_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	if dir.file_exists(INDEX):
		found.append(dir_path.path_join(INDEX))
	for sub in dir.get_directories():
		if not sub.begins_with(".") and not sub in SKIP:
			found.append_array(_index_files(dir_path.path_join(sub)))
	return found


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func _pack_entries(index_path: String) -> Array:
	var index = _read_json(index_path)
	if not index is Dictionary or not index.get("effects") is Array:
		return []
	var dir := index_path.get_base_dir()
	var groups: Array = index.get("packs", [{"title": index.get("title", dir.get_file()), "effects": index["effects"]}])
	var out: Array = []
	for group in groups:
		for id in group["effects"]:
			var entry := _entry(dir.path_join(id), String(group["title"]), String(index.get("ground", "#0b1626")))
			if not entry.is_empty():
				out.append(entry)
	return out


static func _entry(folder: String, pack: String, ground: String) -> Dictionary:
	var json_path := folder.path_join("effect.json")
	var data = _read_json(json_path)
	if not data is Dictionary or not data.get("sheets") is Array:
		return {}
	var id := String(data["id"])
	var names: Array = []
	var sheet_scenes := {}
	for sheet in data["sheets"]:
		names.append(String(sheet["name"]))
	if names.size() > 1:
		for name in names:
			sheet_scenes[name] = folder.path_join("%s-%s.tscn" % [id, _file_id(name)])
	return {
		"id": id, "title": String(data.get("title", id)), "category": String(data.get("category", "Other")),
		"pack": pack, "ground": ground, "json": json_path, "scene": folder.path_join(id + ".tscn"),
		"sheets": names, "sheet_scenes": sheet_scenes, "px": float(data.get("onScreenPx", 0.0)),
		"seconds": float(data.get("durationMs", 0.0)) / 1000.0, "loops": bool(data.get("loops", false)),
	}


## As the pack build names files: "Hit Spark" -> "hit-spark".
static func _file_id(name: String) -> String:
	var out := ""
	for c in name.to_lower():
		out += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "-"
	while "--" in out:
		out = out.replace("--", "-")
	return out.strip_edges().trim_prefix("-").trim_suffix("-")
