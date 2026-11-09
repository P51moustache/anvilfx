@tool
extends RefCounted
## The effects starred in the dock, by id, kept per project in the editor's project metadata (not in the project's
## files, so they never ship). The store is any object with EditorSettings' get/set_project_metadata, so tests can
## pass a stand-in.

const SECTION = "anvilfx"
const KEY = "favourites"

var _store: Object
var _ids: Array = []


func _init(store: Object) -> void:
	_store = store
	if _store:
		_ids = Array(_store.get_project_metadata(SECTION, KEY, []))


func ids() -> Array:
	return _ids.duplicate()


func has(id: String) -> bool:
	return id in _ids


## Star or unstar `id`; returns whether it is starred now.
func toggle(id: String) -> bool:
	if id in _ids:
		_ids.erase(id)
	else:
		_ids.append(id)
	if _store:
		_store.set_project_metadata(SECTION, KEY, _ids)
	return id in _ids
