@tool
extends RefCounted
## The Theme the dock's controls read: Look's palette and type sizes at the editor's display scale. One place for
## text sizes, spacing and button shapes, so nothing in the dock can drift from the scale. Dialogs stay outside it and
## keep the editor's own look. Pure: build() takes the scale, so a test can ask for any scale.

const Look = preload("look.gd")

const BODY_SIZE = 13
const SMALL_SIZE = 11
const TITLE_SIZE = 17
const HEADLINE_SIZE = 25
const SEPARATION = 8
const CHECK_UNCHECKED = "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16'><rect x='1.5' y='1.5' width='13' height='13' rx='3' fill='none' stroke='#fff' stroke-opacity='.45'/></svg>"
const CHECK_CHECKED = "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16'><rect x='1' y='1' width='14' height='14' rx='3' fill='#f1efea'/><path d='M4.5 8.2 7 10.7l4.6-5.2' fill='none' stroke='#141416' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'/></svg>"
const GRABBER = "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16'><circle cx='8' cy='8' r='5.5' fill='#f1efea'/></svg>"
const TEXT_COLOURS = ["font_color", "font_hover_color", "font_focus_color", "font_hover_pressed_color", "font_pressed_color"]
const ICON_COLOURS = ["icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_hover_pressed_color", "icon_pressed_color"]


static func build(scale: float) -> Theme:
	var theme := Theme.new()
	theme.default_base_scale = scale
	_text(theme, scale)
	_spacing(theme, scale)
	_buttons(theme, scale)
	_fields(theme, scale)
	_sliders(theme, scale)
	_scrolling(theme, scale)
	return theme


static func _px(scale: float, value: float) -> int:
	return roundi(value * scale)


static func _box(scale: float, fill: Color, radius: float, border := Color(0, 0, 0, 0), across := 10.0, down := 4.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(_px(scale, radius))
	if border.a > 0.0:
		box.set_border_width_all(maxi(1, _px(scale, 0.75)))
		box.border_color = border
	box.content_margin_left = _px(scale, across)
	box.content_margin_right = _px(scale, across)
	box.content_margin_top = _px(scale, down)
	box.content_margin_bottom = _px(scale, down)
	return box


static func _text(theme: Theme, scale: float) -> void:
	for type in ["Label", "Button", "CheckBox", "OptionButton", "LineEdit", "SpinBox", "PopupMenu"]:
		theme.set_font_size("font_size", type, _px(scale, BODY_SIZE))
	theme.set_color("font_color", "Label", Look.TEXT)
	theme.set_stylebox("normal", "Label", StyleBoxEmpty.new())   # the editor's pads each side, splitting the wordmark
	for pair in [[Look.SMALL, SMALL_SIZE], [Look.SECTION, SMALL_SIZE], [Look.TITLE, TITLE_SIZE], [Look.HEADLINE, HEADLINE_SIZE]]:
		theme.set_type_variation(pair[0], "Label")
		theme.set_font_size("font_size", pair[0], _px(scale, pair[1]))
	# Text over the stage: an outline keeps it readable on every floor, the Sand one included.
	for pair in [[Look.STAGE_TITLE, TITLE_SIZE], [Look.STAGE_SMALL, SMALL_SIZE]]:
		theme.set_type_variation(pair[0], "Label")
		theme.set_font_size("font_size", pair[0], _px(scale, pair[1]))
		theme.set_color("font_outline_color", pair[0], Color(0, 0, 0, 0.7))
		theme.set_constant("outline_size", pair[0], _px(scale, Look.STAGE_OUTLINE))


static func _spacing(theme: Theme, scale: float) -> void:
	for type in ["HBoxContainer", "VBoxContainer"]:
		theme.set_constant("separation", type, _px(scale, SEPARATION))
	for type in ["HFlowContainer", "VFlowContainer"]:
		theme.set_constant("h_separation", type, _px(scale, SEPARATION))
		theme.set_constant("v_separation", type, _px(scale, 6))
	theme.set_constant("h_separation", "GridContainer", _px(scale, 16))
	theme.set_constant("v_separation", "GridContainer", _px(scale, 6))
	for type in ["HSeparator", "VSeparator"]:
		var line := StyleBoxLine.new()
		line.color = Look.LINE
		line.vertical = type == "VSeparator"
		theme.set_stylebox("separator", type, line)
		theme.set_constant("separation", type, _px(scale, 1))


static func _button_type(theme: Theme, scale: float, type: String, styles: Dictionary, text: Color, pressed_text: Color) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		theme.set_stylebox(state, type, styles.get(state, styles["normal"]))
	theme.set_stylebox("focus", type, StyleBoxEmpty.new())
	for colour in TEXT_COLOURS:
		theme.set_color(colour, type, pressed_text if "pressed" in colour else text)
	theme.set_color("font_disabled_color", type, Color(text, 0.35))
	for colour in ICON_COLOURS:
		theme.set_color(colour, type, pressed_text if "pressed" in colour else text)
	theme.set_color("icon_disabled_color", type, Color(text, 0.35))
	theme.set_constant("h_separation", type, _px(scale, 6))


static func _buttons(theme: Theme, scale: float) -> void:
	var clear := Color(0, 0, 0, 0)
	_button_type(theme, scale, "Button", {
		"normal": _box(scale, clear, Look.RADIUS, Look.LINE),
		"hover": _box(scale, Look.RAISED, Look.RADIUS, Look.LINE),
		"pressed": _box(scale, Look.RAISED, Look.RADIUS, Look.TEXT),
		"hover_pressed": _box(scale, Look.RAISED, Look.RADIUS, Look.TEXT),
		"disabled": _box(scale, clear, Look.RADIUS, Color(Look.LINE, 0.07)),
	}, Look.TEXT, Look.TEXT)
	for type in [Look.FLAT, Look.PRIMARY, Look.PILL]:
		theme.set_type_variation(type, "Button")
	_button_type(theme, scale, Look.FLAT, {
		"normal": _box(scale, clear, Look.RADIUS, clear, 7.0),
		"hover": _box(scale, Look.RAISED, Look.RADIUS, clear, 7.0),
		"pressed": _box(scale, Look.RAISED, Look.RADIUS, clear, 7.0),
	}, Look.TEXT, Look.TEXT)
	_button_type(theme, scale, Look.PRIMARY, {
		"normal": _box(scale, Look.TEXT, Look.RADIUS, clear, 14.0, 5.0),
		"hover": _box(scale, Color.WHITE, Look.RADIUS, clear, 14.0, 5.0),
		"pressed": _box(scale, Look.TEXT.darkened(0.12), Look.RADIUS, clear, 14.0, 5.0),
		"disabled": _box(scale, Color(Look.TEXT, 0.2), Look.RADIUS, clear, 14.0, 5.0),
	}, Look.INK, Look.INK)
	var pill_fill := Color(0, 0, 0, 0.45)   # over a stage as well as over the room
	_button_type(theme, scale, Look.PILL, {
		"normal": _box(scale, pill_fill, 999.0, Look.LINE, 8.0, 2.0),
		"hover": _box(scale, Look.RAISED, 999.0, Look.LINE, 8.0, 2.0),
		"pressed": _box(scale, Look.TEXT, 999.0, clear, 8.0, 2.0),
		"hover_pressed": _box(scale, Look.TEXT, 999.0, clear, 8.0, 2.0),
	}, Look.TEXT, Look.INK)


static func _fields(theme: Theme, scale: float) -> void:
	var clear := Color(0, 0, 0, 0)
	for state in ["normal", "read_only"]:
		theme.set_stylebox(state, "LineEdit", _box(scale, Look.PANEL, Look.RADIUS, Look.LINE))
	theme.set_stylebox("focus", "LineEdit", _box(scale, clear, Look.RADIUS, Color(Look.TEXT, 0.55)))
	theme.set_color("font_color", "LineEdit", Look.TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", Color(Look.TEXT, 0.45))
	theme.set_color("caret_color", "LineEdit", Look.TEXT)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill := Look.RAISED if state != "normal" else Color(0, 0, 0, 0.45)
		theme.set_stylebox(state, "OptionButton", _box(scale, fill, Look.RADIUS, Look.LINE, 9.0, 2.0))
	theme.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	for colour in TEXT_COLOURS:
		theme.set_color(colour, "OptionButton", Look.TEXT)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		theme.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
	for colour in TEXT_COLOURS:
		theme.set_color(colour, "CheckBox", Look.TEXT)
	var size := _px(scale, 16)
	theme.set_icon("checked", "CheckBox", Look.svg_icon(CHECK_CHECKED, 16.0, size))
	theme.set_icon("unchecked", "CheckBox", Look.svg_icon(CHECK_UNCHECKED, 16.0, size))
	theme.set_constant("h_separation", "CheckBox", _px(scale, 5))


static func _sliders(theme: Theme, scale: float) -> void:
	var thickness := _px(scale, 1.5)
	var track := _box(scale, Color(1, 1, 1, 0.2), 2.0, Color(0, 0, 0, 0), 0.0, 0.0)
	track.content_margin_top = thickness
	track.content_margin_bottom = thickness
	theme.set_stylebox("slider", "HSlider", track)
	var filled := track.duplicate()
	filled.bg_color = Look.TEXT
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var dot := Look.svg_icon(GRABBER, 16.0, _px(scale, 14))
	theme.set_icon("grabber", "HSlider", dot)
	theme.set_icon("grabber_highlight", "HSlider", dot)
	theme.set_icon("grabber_disabled", "HSlider", dot)


static func _scrolling(theme: Theme, scale: float) -> void:
	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	for type in ["VScrollBar", "HScrollBar"]:
		var gutter := StyleBoxEmpty.new()
		gutter.set_content_margin_all(_px(scale, 2))
		theme.set_stylebox("scroll", type, gutter)
		theme.set_stylebox("scroll_focus", type, gutter)
		var thumb := _box(scale, Color(1, 1, 1, 0.22), 3.0, Color(0, 0, 0, 0), 2.0, 2.0)
		theme.set_stylebox("grabber", type, thumb)
		var lit := thumb.duplicate()
		lit.bg_color = Color(1, 1, 1, 0.42)
		theme.set_stylebox("grabber_highlight", type, lit)
		theme.set_stylebox("grabber_pressed", type, lit)
