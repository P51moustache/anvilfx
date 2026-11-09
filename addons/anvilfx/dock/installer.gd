@tool
extends RefCounted
## Installs AnvilFX packs straight from a downloaded zip, no unzipping: every pack folder inside it
## (`effects/<pack>/` holding an index.json, wherever it sits, for example under `<pack>/godot/`) is
## copied to `res://effects/<pack>/`, the place its scenes point at. Installing a newer zip of the same pack
## updates it in place; the editor's .import and .uid files are kept, so scenes that use its effects stay linked.
## No editor calls: the plugin rescans the FileSystem afterwards. Tested headless.
##
## Packs built before the addon was renamed (it was SpriteStack, in addons/spritestack/) install too: their scenes
## point at the old addon folder, so those paths are repointed at this one as the scenes are copied. The addon copy
## such a zip carries is never installed (only effects/<pack>/ is), so it cannot clash with this one.

const TARGET = "res://effects"
const INDEX = "index.json"
const ADDON = "res://addons/anvilfx/"
const LEGACY_ADDONS = ["res://addons/spritestack/"]   # the addon's folder in packs built before the rename
const SCENE_EXTENSIONS = ["tscn", "tres"]   # text resources that may name the addon's scripts


## The packs inside `zip_path`: [{slug, title, prefix}] (prefix: the zip folder holding the pack's files).
## Empty when it is not an AnvilFX pack (or not a zip).
static func packs_in(zip_path: String) -> Array:
	var zip := ZIPReader.new()
	if zip_path.get_extension().to_lower() != "zip" or zip.open(zip_path) != OK:
		return []
	var out := _find_packs(zip)
	zip.close()
	return out


## Install every pack in `zip_path` under `target`. Returns {ok, error, packs: [{slug, title, files, updated}]}.
static func install(zip_path: String, target: String = TARGET) -> Dictionary:
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		return {"ok": false, "error": "Could not open %s as a zip." % zip_path.get_file(), "packs": []}
	var packs := _find_packs(zip)
	if packs.is_empty():
		zip.close()
		return {"ok": false, "error": "%s holds no AnvilFX pack (no effects/<pack>/index.json)." % zip_path.get_file(),
				"packs": []}
	var done: Array = []
	for pack in packs:
		var folder := target.path_join(pack["slug"])
		var updated := DirAccess.dir_exists_absolute(folder)
		var count := 0
		for entry in zip.get_files():
			if not entry.begins_with(pack["prefix"]) or entry.ends_with("/"):
				continue
			var rest := entry.trim_prefix(pack["prefix"])
			if not _safe(rest):
				continue
			var path := folder.path_join(rest)
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				zip.close()
				return {"ok": false, "error": "Could not write %s." % path, "packs": done}
			file.store_buffer(_contents(zip, entry))
			file.close()
			count += 1
		done.append({"slug": pack["slug"], "title": pack["title"], "files": count, "updated": updated})
	zip.close()
	return {"ok": true, "error": "", "packs": done}


## "Installed Sci-fi Weapons (7 effects)" style summary of an install result.
static func summary(result: Dictionary) -> String:
	if not result["ok"]:
		return result["error"]
	var names := PackedStringArray()
	for pack in result["packs"]:
		names.append("%s %s in %s" % ["Updated" if pack["updated"] else "Installed", pack["title"],
				TARGET.path_join(pack["slug"])])
	return "; ".join(names)


static func _find_packs(zip: ZIPReader) -> Array:
	var out: Array = []
	for entry in zip.get_files():
		var parts := entry.split("/")
		var n := parts.size()
		if n < 3 or parts[n - 1] != INDEX or parts[n - 3] != "effects":
			continue
		var index = JSON.parse_string(zip.read_file(entry).get_string_from_utf8())
		if not index is Dictionary or not index.get("effects") is Array:
			continue
		var slug := parts[n - 2]
		if not _safe(slug):
			continue
		out.append({"slug": slug, "title": String(index.get("title", slug)),
				"prefix": entry.trim_suffix(INDEX)})
	return out


## The bytes to install for `entry`: scenes from packs built before the rename are repointed at this addon.
static func _contents(zip: ZIPReader, entry: String) -> PackedByteArray:
	var data := zip.read_file(entry)
	if not entry.get_extension().to_lower() in SCENE_EXTENSIONS:
		return data
	var text := data.get_string_from_utf8()
	var repointed := text
	for old in LEGACY_ADDONS:
		repointed = repointed.replace(old, ADDON)
	return data if repointed == text else repointed.to_utf8_buffer()


## A relative path that stays inside the pack folder.
static func _safe(path: String) -> bool:
	return path != "" and not path.begins_with("/") and not ".." in path.split("/") and not ":" in path
