@tool
extends PanelContainer
## The AnvilFX bottom panel: the wordmark and actions along the top, the chosen effect on a big stage on the left, the
## filters, playing cards and Add button on the right. With no packs yet, one empty stage takes the whole panel. It
## browses; adding to the scene goes through `add_effect` and installing a pack zip through `install_packs` and
## importing a sprite sheet through `import_sheet`, all supplied by the plugin, so the dock never touches the edited
## scene or the project's files itself. A zip dragged from the FileSystem dock onto it installs too. The preview's
## Speed applies to every effect added from the dock (speed()).

const Library = preload("library.gd")
const Look = preload("look.gd")
const DockTheme = preload("dock_theme.gd")
const TopBar = preload("top_bar.gd")
const FilterBar = preload("filter_bar.gd")
const Grid = preload("effect_grid.gd")
const Preview = preload("preview_pane.gd")
const PiecesPanel = preload("pieces_panel.gd")
const ActionBar = preload("action_bar.gd")
const EmptyState = preload("empty_state.gd")
const SpawnCode = preload("spawn_code.gd")
const ImportDialog = preload("import_dialog.gd")
const MIN_HEIGHT = 360   # room for the filters, one whole row of cards and the Add button
const PREVIEW_MIN_WIDTH = 300
const BROWSER_MIN_WIDTH = 340
const BROWSER_STRETCH = 1.15   # the browser has more to fit on one line than the stage
const PANE_MARGIN = 8
const SHOP_URL = "https://thepixelgoblin.itch.io"   # more AnvilFX effect packs
const FEEDBACK_URL = "https://thepixelgoblin.itch.io/anvilfx/community"   # requests and feedback

## Called with a scene path when the person adds an effect; the plugin's placer does the work.
var add_effect: Callable = func(_scene: String) -> void: pass
## Called with zip paths (OS or res://) when the person installs packs from the dock.
var install_packs: Callable = func(_zips: PackedStringArray) -> void: pass
## Called with a sheet's image path and the import settings (sheet_import.gd) when the person imports a sheet.
var import_sheet: Callable = func(_source: String, _settings: Dictionary) -> void: pass

var _favourites = null    # favourites.gd
var _entries: Array = []
var _filter := ["all", ""]
var _chosen: Dictionary = {}
var _themed := VBoxContainer.new()   # everything but the dialogs, which keep the editor's look
var _top_bar := TopBar.new()
var _main := HBoxContainer.new()
var _empty := EmptyState.new()
var _preview := Preview.new()
var _browser := VBoxContainer.new()
var _filters := FilterBar.new()
var _grid := Grid.new()
var _pieces := PiecesPanel.new()
var _actions := ActionBar.new()
var _dialog: EditorFileDialog = null
var _import: ImportDialog = null
var _pending_pack := ""   # a pack just installed: shown once the rescan lists it
var _pending_scene := ""  # an effect just imported: chosen once the rescan lists it


func _init() -> void:
	name = "AnvilFX"
	_preview.use_pieces(_pieces)
	_filters.filter_chosen.connect(_on_filter)
	_filters.query_changed.connect(func(_text: String) -> void: _refilter())
	_grid.chosen.connect(_choose)
	_grid.add_requested.connect(func(entry: Dictionary) -> void: add_effect.call(entry["scene"]))
	_grid.favourite_toggled.connect(_on_favourite)
	_preview.changed.connect(_show_actions)
	_preview.pieces_toggled.connect(_show_pieces)
	_pieces.closed.connect(func() -> void: _preview.close_pieces())
	_actions.add_pressed.connect(_add_chosen)
	_actions.copy_pressed.connect(_copy_chosen)
	_top_bar.install_pressed.connect(_browse)
	_empty.install_pressed.connect(_browse)
	_top_bar.import_pressed.connect(_open_import)
	_top_bar.shop_pressed.connect(func() -> void: OS.shell_open(SHOP_URL))
	_top_bar.feedback_pressed.connect(func() -> void: OS.shell_open(FEEDBACK_URL))


## Built here, not in _init: the sizes need the editor's display scale, which a control has only in the tree, and the
## children's _ready run after this.
func _enter_tree() -> void:
	if _themed.get_parent() != null:
		return
	var scale := Look.display_scale(self)
	custom_minimum_size.y = Look.px(self, MIN_HEIGHT)
	var room := StyleBoxFlat.new()
	room.bg_color = Look.BG
	add_theme_stylebox_override("panel", room)
	_themed.theme = DockTheme.build(scale)
	_themed.add_theme_constant_override("separation", 0)
	_themed.add_child(_top_bar)
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_themed.add_child(_empty)
	_main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.custom_minimum_size.x = Look.px(self, PREVIEW_MIN_WIDTH)
	_main.add_child(_preview)
	_main.add_child(_build_browser())
	_themed.add_child(Look.margin(self, _main, PANE_MARGIN))
	_themed.get_child(-1).size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_themed)
	_show_state()


func setup(favourites) -> void:
	_favourites = favourites


## Scan the project for packs again (the plugin calls this when the FileSystem changes).
func reload() -> void:
	var fresh := Library.scan()
	if fresh == _entries and not _entries.is_empty():
		return   # an unrelated file changed: keep the cards playing
	_entries = fresh
	_grid.set_entries(_entries)
	_grid.show_favourites(_favourite_ids())
	_show_counts()
	_refilter()
	_show_state()
	if _chosen.is_empty() and not _entries.is_empty():
		_choose(_entries[0])
	show_pack(_pending_pack, _pending_scene)


## Filter to the pack titled `title` (after installing it) and preview its effect whose scene is `scene` (else its
## first); remembered until a scan lists it.
func show_pack(title: String, scene: String = "") -> void:
	_pending_pack = title
	_pending_scene = scene
	for pack in Library.packs(_entries):
		if pack[0] != title:
			continue
		var found := {}
		for entry in _entries:
			if entry["pack"] == title and (found.is_empty() or entry["scene"] == scene):
				found = entry
		if scene != "" and found.get("scene", "") != scene:
			return   # the pack is listed but the new effect isn't yet: wait for the next scan
		_pending_pack = ""
		_pending_scene = ""
		_filters.choose("pack", title)
		_choose(found)
		return


## The playback speed effects are added at: the preview's Speed.
func speed() -> float:
	return _preview.speed()


## Active piece/layer customizations from the Pieces panel.
func customizations() -> Dictionary:
	return _pieces.customizations(_preview.sheet())


## The Scene tree's selection, for the "Selected node" line.
func set_target(node_name: String, blocked_reason: String = "") -> void:
	_actions.set_target(node_name, blocked_reason)


func _build_browser() -> Control:
	_browser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_browser.custom_minimum_size.x = Look.px(self, BROWSER_MIN_WIDTH)
	_browser.size_flags_stretch_ratio = BROWSER_STRETCH
	_browser.add_child(_filters)
	_browser.add_child(_grid)
	_pieces.visible = false
	_browser.add_child(_pieces)
	_browser.add_child(HSeparator.new())
	_browser.add_child(_actions)
	return _browser


## An empty project sees only the empty stage.
func _show_state() -> void:
	var has_packs := not _entries.is_empty()
	_empty.visible = not has_packs
	_main.get_parent().visible = has_packs


## The Pieces panel takes the browser's place while it is open; the stage stays in view to show what each slider does.
func _show_pieces(open: bool) -> void:
	_pieces.visible = open
	_filters.visible = not open
	_grid.visible = not open


func _show_actions() -> void:
	_actions.show_state(not _chosen.is_empty(), speed(), _pieces.splits(_preview.sheet()))


func _add_chosen() -> void:
	if not _chosen.is_empty():
		add_effect.call(Library.scene_for(_chosen, _preview.sheet()))


## Put the AnvilFX.spawn() code for the chosen effect, sheet, speed and customizations on the clipboard.
func _copy_chosen() -> void:
	if _chosen.is_empty():
		return
	DisplayServer.clipboard_set(SpawnCode.spawn_code(_chosen, _preview.sheet(), speed(), customizations()))
	_actions.flash_copied()


func _open_import() -> void:
	if _import == null:
		_import = ImportDialog.new()
		_import.import_requested.connect(func(source: String, settings: Dictionary) -> void:
			import_sheet.call(source, settings))
		add_child(_import)
	_import.open()


func _browse() -> void:
	if _dialog == null:
		_dialog = EditorFileDialog.new()
		_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILES
		_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
		_dialog.title = "Install AnvilFX packs"
		_dialog.add_filter("*.zip", "AnvilFX pack (as downloaded)")
		_dialog.files_selected.connect(func(paths: PackedStringArray) -> void: install_packs.call(paths))
		add_child(_dialog)
	_dialog.popup_file_dialog()


static func _zips(data: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if data is Dictionary and data.get("type") == "files":
		for path in data.get("files", []):
			if String(path).get_extension().to_lower() == "zip":
				out.append(path)
	return out


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return not _zips(data).is_empty()


func _drop_data(_at: Vector2, data: Variant) -> void:
	install_packs.call(_zips(data))


func _favourite_ids() -> Array:
	return _favourites.ids() if _favourites else []


func _show_counts() -> void:
	var favourite_count := Library.filter(_entries, "favourites", "", "", _favourite_ids()).size()
	_filters.show_counts(_entries.size(), favourite_count, Library.packs(_entries), Library.categories(_entries))
	_filters.choose(_filter[0], _filter[1])


func _on_filter(kind: String, value: String) -> void:
	_filter = [kind, value]
	_refilter()


func _refilter() -> void:
	var shown := Library.filter(_entries, _filter[0], _filter[1], _filters.query(), _favourite_ids())
	_grid.show_only(shown)
	_filters.show_count(shown.size())


func _choose(entry: Dictionary) -> void:
	_chosen = entry
	_grid.select(Grid.key(entry))
	_preview.show_entry(entry)
	_show_actions()


func _on_favourite(id: String) -> void:
	if _favourites == null:
		return
	_favourites.toggle(id)
	_grid.show_favourites(_favourite_ids())
	_show_counts()
	_refilter()
