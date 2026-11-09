@tool
extends EditorPlugin
## The AnvilFX editor dock: a bottom-panel tab that browses every AnvilFX pack in the project and adds an
## effect under the node selected in the Scene tree. The effects themselves need no plugin (effect.gd runs alone);
## this is the browser and the installer.
##
## Adding: the dock's Add button or a double-clicked card adds under the selected node; a card dragged into the 2D
## view adds where it lands (DropZone). None of these opens the effect's scene.
##
## Starter scenes (starters/): a camera, a floor and stand-in units for top-down, isometric and side-view games, to
## open or instance as a place to try effects.
##
## Speed: the preview's Speed plays the effect faster or slower and says what that does at the frame rate it was
## painted for; effects added from the dock take that speed. Import sprite sheet: any PNG of frames in a grid
## becomes an effect in res://effects/imported/ (dock/sheet_import.gd).
##
## Installing: drop a pack's zip, as downloaded, anywhere on the editor (or use the dock's Install pack button).
## Its packs go to res://effects/<pack>/. Godot also copies any dropped file into the FileSystem dock's folder; for a
## pack zip that copy is removed again, so a 200 MB download never ends up inside the game.

const Dock = preload("dock/dock.gd")
const Favourites = preload("dock/favourites.gd")
const Placer = preload("dock/placer.gd")
const Installer = preload("dock/installer.gd")
const DropZone = preload("dock/drop_zone.gd")
const SheetImport = preload("dock/sheet_import.gd")
const Brand = preload("dock/brand.gd")
const TOAST_INFO = 0      # EditorToaster.SEVERITY_INFO
const TOAST_WARNING = 1   # EditorToaster.SEVERITY_WARNING

var _dock: Dock
var _drop_zone: DropZone


func _enter_tree() -> void:
	_dock = Dock.new()
	_dock.setup(Favourites.new(EditorInterface.get_editor_settings()))
	_dock.add_effect = _add_effect
	_dock.install_packs = _install
	_dock.import_sheet = _import_sheet
	add_control_to_bottom_panel(_dock, "AnvilFX").icon = Brand.glyph(_dock)
	_drop_zone = DropZone.new()
	_drop_zone.attach(EditorInterface.get_editor_viewport_2d())
	_drop_zone.dropped.connect(_add_effect)
	EditorInterface.get_selection().selection_changed.connect(_update_target)
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_dock.reload)
	scene_changed.connect(func(_root: Node) -> void: _update_target())
	get_window().files_dropped.connect(_on_files_dropped)
	if not EditorInterface.get_resource_filesystem().is_scanning():
		_dock.reload()   # else the scan's filesystem_changed fills the dock, once new atlases are imported
	_update_target()


func _exit_tree() -> void:
	EditorInterface.get_selection().selection_changed.disconnect(_update_target)
	EditorInterface.get_resource_filesystem().filesystem_changed.disconnect(_dock.reload)
	get_window().files_dropped.disconnect(_on_files_dropped)
	remove_control_from_bottom_panel(_dock)
	_drop_zone.queue_free()
	_drop_zone = null
	_dock.queue_free()
	_dock = null


## The node an effect goes under: the one selected in the Scene tree, else the scene's root.
func _parent() -> Node:
	var root := EditorInterface.get_edited_scene_root()
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if root and not selected.is_empty() and (selected[0] == root or root.is_ancestor_of(selected[0])):
		return selected[0]
	return root


func _update_target() -> void:
	if _dock == null:
		return
	var parent := _parent()
	if parent == null:
		_dock.set_target("", "Open a scene to add effects to it")
	else:
		_dock.set_target(parent.name)


## Add the effect under the selected node (at `canvas_point` on the scene's canvas, when it was dropped there), at the
## dock's playback speed and with any piece/layer customizations from the preview pane.
func _add_effect(scene_path: String, canvas_point: Variant = null) -> void:
	var parent := _parent()
	var node := Placer.add(scene_path, parent, EditorInterface.get_edited_scene_root(), get_undo_redo(), canvas_point,
			_dock.speed(), _dock.customizations())
	if node:
		EditorInterface.get_selection().clear()
		EditorInterface.get_selection().add_node(node)


## Import a sprite sheet as an effect (res://effects/imported/), then show it in the dock once the rescan lists it.
func _import_sheet(source: String, settings: Dictionary) -> void:
	var result := SheetImport.write(source, settings)
	if not result["ok"]:
		_toast(result["error"], false)
		return
	_toast("Imported %s" % settings["title"], true)
	_dock.show_pack(SheetImport.PACK_TITLE, result["scene"])
	EditorInterface.get_resource_filesystem().scan()


## Files dropped on the editor from the OS: install the AnvilFX pack zips among them.
func _on_files_dropped(files: PackedStringArray) -> void:
	var zips := PackedStringArray()
	for path in files:
		if not Installer.packs_in(path).is_empty():
			zips.append(path)
	if zips.is_empty():
		return
	var copies_in := EditorInterface.get_current_directory()
	_install(zips)
	_remove_copies.call_deferred(zips, copies_in)


func _install(zips: PackedStringArray) -> void:
	var last_title := ""
	for zip in zips:
		var result := Installer.install(ProjectSettings.globalize_path(zip) if zip.begins_with("res://") else zip)
		_toast(Installer.summary(result), result["ok"])
		if result["ok"]:
			last_title = result["packs"][-1]["title"]
	if last_title == "":
		return
	make_bottom_panel_item_visible(_dock)
	_dock.show_pack(last_title)
	EditorInterface.get_resource_filesystem().scan()


## Remove the copy Godot made of each dropped zip (same name and size, in the FileSystem dock's folder).
func _remove_copies(zips: PackedStringArray, folder: String) -> void:
	for zip in zips:
		var copy := ProjectSettings.globalize_path(folder.path_join(zip.get_file()))
		if copy == zip or not FileAccess.file_exists(copy):
			continue
		var original := FileAccess.open(zip, FileAccess.READ)
		var copied := FileAccess.open(copy, FileAccess.READ)
		if original and copied and original.get_length() == copied.get_length():
			copied.close()
			DirAccess.remove_absolute(copy)
	EditorInterface.get_resource_filesystem().scan()


func _toast(message: String, ok: bool) -> void:
	if EditorInterface.has_method("get_editor_toaster"):   # Godot 4.4+; called by name so 4.3 still parses this
		EditorInterface.call("get_editor_toaster").push_toast("AnvilFX: " + message, TOAST_INFO if ok else TOAST_WARNING)
	elif ok:
		print("AnvilFX: ", message)
	else:
		push_warning("AnvilFX: " + message)
