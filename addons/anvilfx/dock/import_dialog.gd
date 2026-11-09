@tool
extends ConfirmationDialog
## "Import sprite sheet": pick any PNG of frames in a grid, check the grid, frame rate, blend, pivot and game size
## against a live preview, and import it as an AnvilFX effect (sheet_import.gd writes the files).

signal import_requested(source_png: String, settings: Dictionary)

const SheetImport = preload("sheet_import.gd")
const SheetPreview = preload("sheet_preview.gd")
const Look = preload("look.gd")
const PREVIEW_SIZE = Vector2(280, 240)
const FIELD_WIDTH = 260
const MIN_WIDTH = 640
const SEPARATION = 16
const DEFAULT_FPS = 12.0

var _source := ""
var _path := LineEdit.new()
var _name := LineEdit.new()
var _columns := SpinBox.new()
var _rows := SpinBox.new()
var _frames := SpinBox.new()
var _fps := SpinBox.new()
var _loop := CheckBox.new()
var _blend := OptionButton.new()
var _pivot := OptionButton.new()
var _px := SpinBox.new()
var _facts := Label.new()
var _preview := SheetPreview.new()
var _picker: EditorFileDialog
var _fields: Array[Control] = []
var _body := HBoxContainer.new()
var _frames_typed := false   # once the person sets Frames, a grid change no longer resets it
var _px_typed := false       # likewise Size in game, which otherwise follows the cell width
var _syncing := false        # Frames or Size is being set from the grid, not typed


func _init() -> void:
	title = "Import sprite sheet"
	ok_button_text = "Import"
	_body.add_theme_constant_override("separation", SEPARATION)
	_body.add_child(_form())
	var right := VBoxContainer.new()
	right.add_child(_preview)
	_facts.modulate = Look.MUTED
	_facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_facts)
	_body.add_child(right)
	add_child(_body)
	confirmed.connect(func() -> void: import_requested.emit(_source, settings()))
	_refresh()


## Show the dialog, asking for an image first when none is chosen yet.
func open() -> void:
	_fit_display_scale()
	popup_centered()
	if _source == "":
		_choose_file()


## Set the fixed sizes for the editor's display scale, which a control has only in the tree.
func _fit_display_scale() -> void:
	min_size = Vector2i(int(Look.px(_preview, MIN_WIDTH)), 0)
	_preview.custom_minimum_size = PREVIEW_SIZE * Look.display_scale(_preview)
	_facts.custom_minimum_size.x = Look.px(_preview, PREVIEW_SIZE.x)
	_body.add_theme_constant_override("separation", int(Look.px(_preview, SEPARATION)))
	for field in _fields:
		field.custom_minimum_size.x = Look.px(_preview, FIELD_WIDTH)


## The form as sheet_import.gd reads it.
func settings() -> Dictionary:
	return {
		"title": _name.text.strip_edges() if _name.text.strip_edges() != "" else _source.get_file().get_basename(),
		"columns": int(_columns.value), "rows": int(_rows.value), "frames": int(_frames.value), "fps": _fps.value,
		"loop": _loop.button_pressed, "blend": SheetImport.BLENDS[_blend.selected],
		"pivot": SheetImport.PIVOTS[_pivot.selected][1], "px": _px.value,
	}


## Load `path` (an OS path) and guess its grid.
func use_file(path: String) -> void:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		_facts.text = "Could not read %s as an image." % path.get_file()
		return
	_source = path
	_path.text = path.get_file()
	if _name.text.strip_edges() == "":
		_name.text = path.get_file().get_basename().capitalize()
	_preview.texture = ImageTexture.create_from_image(image)
	var grid := SheetImport.guess_grid(image.get_size())
	_frames_typed = false
	_px_typed = false
	_columns.value = grid.x
	_rows.value = grid.y
	_refresh()


func _form() -> GridContainer:
	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 10)
	form.add_theme_constant_override("v_separation", 6)
	var file_line := HBoxContainer.new()
	_path.editable = false
	_path.placeholder_text = "No image chosen"
	_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	file_line.add_child(_path)
	var choose := Button.new()
	choose.text = "Choose..."
	choose.pressed.connect(_choose_file)
	file_line.add_child(choose)
	_row(form, "Image", file_line, "A PNG of frames in a grid, read left to right, then top to bottom")
	_name.placeholder_text = "Effect name"
	_row(form, "Name", _name, "How the effect is listed in the AnvilFX tab")
	_spin(_columns, 1, 64, 1)
	_row(form, "Columns", _columns, "Frames across the sheet")
	_spin(_rows, 1, 64, 1)
	_row(form, "Rows", _rows, "Frames down the sheet")
	_spin(_frames, 1, 4096, 1)
	_frames.value_changed.connect(func(_v: float) -> void:
		if not _syncing:
			_frames_typed = true
			_refresh())
	_row(form, "Frames", _frames, "How many cells hold frames (a last row may be part empty)")
	_spin(_fps, 1, 120, DEFAULT_FPS)
	_fps.suffix = "fps"
	_row(form, "Frame rate", _fps, "The rate the frames were drawn for; the dock's Speed changes playback later")
	_loop.text = "Loops"
	_loop.button_pressed = true
	_loop.toggled.connect(func(_on: bool) -> void: _refresh())
	_row(form, "", _loop, "On: a looping effect (a flame, an aura). Off: plays once (a hit, an explosion)")
	_blend.add_item("Normal")
	_blend.add_item("Additive (black is see-through)")
	_blend.item_selected.connect(func(_i: int) -> void: _refresh())
	_row(form, "Blend", _blend, "Additive for glows and fire painted on black; Normal for sheets with transparency")
	for pivot in SheetImport.PIVOTS:
		_pivot.add_item(pivot[0])
	_pivot.item_selected.connect(func(_i: int) -> void: _refresh())
	_row(form, "Pivot", _pivot, "The point that sits on the node it is added to")
	_spin(_px, 1, 4096, 64)
	_px.suffix = "px"
	_px.value_changed.connect(func(_v: float) -> void:
		if not _syncing:
			_px_typed = true)
	_row(form, "Size in game", _px, "How wide one frame is drawn in the game (one cell's width until you change it)")
	for spin in [_columns, _rows]:
		spin.value_changed.connect(func(_v: float) -> void: _refresh())
	_fps.value_changed.connect(func(_v: float) -> void: _refresh())
	return form


func _row(form: GridContainer, label: String, field: Control, tip: String) -> void:
	var name_label := Label.new()
	name_label.text = label
	form.add_child(name_label)
	field.tooltip_text = tip
	_fields.append(field)
	form.add_child(field)


func _spin(spin: SpinBox, low: float, high: float, value: float) -> void:
	spin.min_value = low
	spin.max_value = high
	spin.step = 1
	spin.value = value


func _choose_file() -> void:
	if _picker == null:
		_picker = EditorFileDialog.new()
		_picker.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		_picker.access = EditorFileDialog.ACCESS_FILESYSTEM
		_picker.title = "Choose a sprite sheet"
		_picker.add_filter("*.png, *.webp, *.jpg, *.jpeg", "Images")
		_picker.file_selected.connect(use_file)
		add_child(_picker)
	_picker.popup_file_dialog()


func _refresh() -> void:
	var cells := _columns.value * _rows.value
	_syncing = true
	_frames.max_value = cells   # also clamps a typed count that no longer fits
	if not _frames_typed:
		_frames.value = cells
	_syncing = false
	_preview.columns = int(_columns.value)
	_preview.rows = int(_rows.value)
	_preview.frames = int(_frames.value)
	_preview.fps = _fps.value
	_preview.loop = _loop.button_pressed
	_preview.additive = _blend.selected == 1
	_preview.pivot = SheetImport.PIVOTS[_pivot.selected][1]
	if not _px_typed and _source != "":
		_syncing = true
		_px.value = _preview.cell().x
		_syncing = false
	get_ok_button().disabled = _source == ""
	if _source == "":
		_facts.text = "Choose a PNG to preview it."
		return
	var cell := _preview.cell()
	_facts.text = "Cell %d × %d px  ·  %d frames  ·  %.2f s at %d fps" % [
		cell.x, cell.y, int(_frames.value), _frames.value / _fps.value, int(_fps.value)]
