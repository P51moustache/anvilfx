@tool
extends VBoxContainer
## The dock's left half: the chosen effect playing on one big stage. Its name and facts, the zoom and the Pieces button
## lie over the top of the stage, the floor colours and sheets over the bottom, and the player controls run beneath it.

signal changed            # the speed, sheet or split changed: what the Add button says may change
signal pieces_toggled(open: bool)

const Library = preload("library.gd")
const Look = preload("look.gd")
const Effect = preload("../effect.gd")
const Stage = preload("stage.gd")
const Speed = preload("speed.gd")
const Transport = preload("transport.gd")
const FLOORS = [["Pack floor", ""], ["Slate", "2b3645"], ["Grey", "8c9198"], ["Sand", "d9c49c"]]   # "" = the pack's
const ZOOMS = [0.0, 1.0, 2.0, 4.0]   # 0 fits the stage (stage.gd)
const SWATCH_SIZE = 20
const STAGE_MIN_HEIGHT = 120
const OVERLAY_MARGIN = 10
const CONTROL_HEIGHT = 24
const LIGHT_TEXT_LIMIT = 0.4   # a floor this bright or brighter takes dark words
const DEFAULT_GROUND = "#0b1626"

var _entry: Dictionary = {}
var _sheet := ""
var _floor := 0
var _pieces = null        # pieces_panel.gd, shared with the dock
var _title := Label.new()
var _facts := Label.new()
var _note := Label.new()
var _floor_label := Label.new()
var _zoom := OptionButton.new()
var _pieces_button := Button.new()
var _stage := Stage.new()
var _swatches := HBoxContainer.new()
var _sheets := HBoxContainer.new()
var _transport := Transport.new()


## The panel holding this effect's piece and layer choices. Set before the pane joins the tree.
func use_pieces(panel) -> void:
	_pieces = panel
	_pieces.changed.connect(_apply_pieces)


func _ready() -> void:
	add_theme_constant_override("separation", int(Look.px(self, 4)))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_build_theatre())
	_transport.attach(_stage)
	_transport.loop_changed.connect(func(_on: bool) -> void: _restage())
	_transport.speed_changed.connect(_on_speed)
	add_child(_transport)
	show_entry({})


## Playback speed for the preview and for effects added from the dock.
func speed() -> float:
	return _transport.speed


## The chosen sheet ("" the whole effect).
func sheet() -> String:
	return _sheet


func close_pieces() -> void:
	_pieces_button.button_pressed = false


## Show `entry` (a Library entry; empty shows nothing chosen).
func show_entry(entry: Dictionary) -> void:
	_entry = entry
	_sheet = ""
	var chosen := not entry.is_empty()
	_title.text = entry["title"] if chosen else "Pick an effect"
	_facts.text = Library.size_line(entry) if chosen else ""
	_pieces_button.disabled = not chosen
	_pieces.show_entry(entry)
	for child in _sheets.get_children():
		_sheets.remove_child(child)   # gone now, not at frame end: a stale button must never be pressed
		child.queue_free()
	if chosen and entry["sheets"].size() > 1:
		var group := ButtonGroup.new()
		_sheets.add_child(_sheet_button("All", "", group))
		for sheet_name in entry["sheets"]:
			_sheets.add_child(_sheet_button(sheet_name, sheet_name, group))
	_restage()
	_paint_floor()
	changed.emit()


func _build_theatre() -> Control:
	var theatre := MarginContainer.new()
	theatre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	theatre.mouse_filter = Control.MOUSE_FILTER_PASS
	_stage.custom_minimum_size.y = Look.px(self, STAGE_MIN_HEIGHT)
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	theatre.add_child(_stage)
	var over := VBoxContainer.new()
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(_build_top_line())
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(gap)
	over.add_child(_build_bottom_line())
	var margin := Look.margin(self, over, OVERLAY_MARGIN)
	theatre.add_child(margin)
	return theatre


## The name and facts on the left; zoom and Pieces on the right. All of it floats, so nothing moves the stage.
func _build_top_line() -> Control:
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", 0)
	_title.theme_type_variation = Look.STAGE_TITLE
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(_title)
	_facts.theme_type_variation = Look.STAGE_SMALL
	_facts.clip_text = true
	words.add_child(_facts)
	_note.theme_type_variation = Look.STAGE_SMALL
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(_note)
	line.add_child(words)
	for zoom in ZOOMS:
		_zoom.add_item("Fit" if zoom == 0.0 else ("1:1" if zoom == 1.0 else "%d×" % int(zoom)))
	_zoom.tooltip_text = "Preview scale: Fit fills the stage, 1:1 is the effect's size in the game"
	_zoom.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_zoom.focus_mode = Control.FOCUS_NONE
	_zoom.custom_minimum_size.y = Look.px(self, CONTROL_HEIGHT)
	_zoom.item_selected.connect(_on_zoom)
	line.add_child(_zoom)
	_pieces_button.text = "Pieces"
	_pieces_button.toggle_mode = true
	_pieces_button.theme_type_variation = Look.PILL
	_pieces_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_pieces_button.focus_mode = Control.FOCUS_NONE
	_pieces_button.custom_minimum_size.y = Look.px(self, CONTROL_HEIGHT)
	_pieces_button.tooltip_text = "Customize individual animation pieces (sheets and layers): toggle, scale, speed, delay, offset, holdout/light mix and splitting into child nodes"
	_pieces_button.toggled.connect(func(open: bool) -> void: pieces_toggled.emit(open))
	line.add_child(_pieces_button)
	_on_zoom(0)
	return line


## Floor colours and the effect's sheets, wrapping upward when the stage is narrow.
func _build_bottom_line() -> Control:
	var line := HFlowContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var floors := HBoxContainer.new()
	floors.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floor_label.text = "Floor"
	_floor_label.theme_type_variation = Look.STAGE_SMALL
	floors.add_child(_floor_label)
	_swatches.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_swatches.add_theme_constant_override("separation", int(Look.px(self, 5)))
	for i in FLOORS.size():
		_swatches.add_child(_swatch(i))
	floors.add_child(_swatches)
	line.add_child(floors)
	_sheets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheets.add_theme_constant_override("separation", int(Look.px(self, 5)))
	line.add_child(_sheets)
	return line


func _swatch(i: int) -> Button:
	var swatch := Button.new()
	swatch.custom_minimum_size = Vector2.ONE * Look.px(self, SWATCH_SIZE)
	swatch.tooltip_text = FLOORS[i][0]
	swatch.focus_mode = Control.FOCUS_NONE
	for state in ["hover", "pressed"]:
		swatch.add_theme_stylebox_override(state, _swatch_style(i, true))
	swatch.pressed.connect(func() -> void:
		_floor = i
		_paint_floor())
	return swatch


func _swatch_style(i: int, hover: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	var hex: String = FLOORS[i][1]
	box.bg_color = _floor_colour(hex)
	box.set_corner_radius_all(int(Look.px(self, 4)))
	box.set_border_width_all(int(Look.px(self, 1.5)))
	var chosen_edge := Look.INK if _stage.floor_color.get_luminance() >= LIGHT_TEXT_LIMIT else Look.TEXT
	box.border_color = chosen_edge if i == _floor else (Color(1, 1, 1, 0.5) if hover else Color(1, 1, 1, 0.25))
	return box


func _floor_colour(hex: String) -> Color:
	return Color(hex) if hex != "" else Look.pack_floor(_entry.get("ground", DEFAULT_GROUND))


func _sheet_button(text: String, sheet_name: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = Look.PILL
	button.toggle_mode = true
	button.button_group = group
	button.button_pressed = sheet_name == _sheet
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "The whole effect, every sheet timed as in the pack's preview" if sheet_name == "" \
			else "Only the %s sheet: \"Add to selected node\" adds this sheet's scene" % sheet_name
	button.pressed.connect(func() -> void:
		_sheet = sheet_name
		if sheet_name != "":
			_pieces.edit_piece(sheet_name)
		_restage()
		changed.emit())
	return button


func _on_zoom(index: int) -> void:
	_stage.zoom = ZOOMS[index]
	_stage.show_grid = ZOOMS[index] > 0.0   # the grid is a size reference, which a fitted effect doesn't have


func _restage() -> void:
	if _entry.is_empty():
		_stage.clear()
		return
	var effect = _stage.show_effect(_entry["json"], _sheet, false)
	effect.repeat = Effect.Repeat.LOOP if _transport.looping() else Effect.Repeat.ONCE
	effect.speed_scale = speed()
	_apply_pieces()
	effect.play()
	_show_speed()


func _apply_pieces() -> void:
	var effect = _stage.effect
	if effect:
		_pieces.apply_to(effect)
	_pieces_button.text = "Pieces •" if not _pieces.customizations(_sheet).is_empty() else "Pieces"
	changed.emit()


func _paint_floor() -> void:
	var hex: String = FLOORS[_floor][1]
	_stage.floor_color = _floor_colour(hex)
	for i in _swatches.get_child_count():
		_swatches.get_child(i).add_theme_stylebox_override("normal", _swatch_style(i))
	_match_words_to_floor()


## Light words with a dark edge on a dark floor; plain dark words on a light one, where an edge only smears them.
func _match_words_to_floor() -> void:
	var light := _stage.floor_color.get_luminance() >= LIGHT_TEXT_LIMIT
	for label in [_title, _facts, _floor_label]:
		label.add_theme_color_override("font_color", Look.INK if light else Look.TEXT)
		label.add_theme_constant_override("outline_size", 0 if light else int(Look.px(self, Look.STAGE_OUTLINE)))


func _on_speed(value: float) -> void:
	if _stage.effect:
		_stage.effect.speed_scale = value
	_show_speed()
	changed.emit()


## What the speed does at the frame rate the effect was painted for. At 1× there is nothing to warn about, so the
## words stay in the slider's tooltip and off the stage.
func _show_speed() -> void:
	var effect = _stage.effect
	var fps: float = effect.authored_fps() if effect else 0.0
	var seconds: float = effect.frame_count() / fps if effect and fps > 0.0 else 0.0
	var note := Speed.note(fps, speed(), seconds, Speed.screen_hz())
	_transport.set_speed_tip(note[0])
	_note.text = "" if is_equal_approx(speed(), 1.0) else note[0]
	if note[1]:
		_note.add_theme_color_override("font_color", Look.WARN)
	else:
		_note.remove_theme_color_override("font_color")
