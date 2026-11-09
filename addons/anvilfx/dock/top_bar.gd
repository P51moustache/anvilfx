@tool
extends PanelContainer
## The dock's top line: the AnvilFX wordmark and version (brand.gd) on the left; Install pack, Import sprite sheet,
## Get more packs and Send feedback on the right. When the panel is too narrow for their words the buttons show
## only their icons, so the bar never forces the editor's bottom panel wider.

signal install_pressed
signal import_pressed
signal shop_pressed
signal feedback_pressed

const Look = preload("look.gd")
const Brand = preload("brand.gd")
const GLYPH_SIZE = 28
const ICON_SIZE = 16
const ICON_HEAD = "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' fill='none' stroke='#f1efea' stroke-width='1.3' stroke-linecap='round' stroke-linejoin='round'>"
const ICON_INSTALL = "<path d='M8 2v8M4.8 7 8 10.2 11.2 7M2.5 10.5v3h11v-3'/>"
const ICON_IMPORT = "<path d='m8 2 6 3-6 3-6-3zM2 8l6 3 6-3M2 11l6 3 6-3'/>"
const ICON_SHOP = "<path d='M9 2.5h4.5V7M13.5 2.5 7.5 8.5M7 3.5H2.5v10h10V9'/>"
const ICON_FEEDBACK = "<path d='M8 2.5c3.3 0 6 2.1 6 4.8s-2.7 4.8-6 4.8c-.8 0-1.5-.1-2.2-.3L2.8 13.5l.8-2.8C2.6 9.800 2 8.600 2 7.300 2 4.600 4.700 2.500 8 2.500z'/>"
const ACTIONS = [
	["Install pack...", ICON_INSTALL, "Install packs from the zips you downloaded (or drop a zip anywhere on Godot)", "install_pressed"],
	["Import sprite sheet...", ICON_IMPORT, "Turn any sprite sheet (a PNG of frames in a grid) into an effect you can preview and add", "import_pressed"],
	["Get more packs", ICON_SHOP, "Open the AnvilFX packs page in your browser: weapons, explosions, swords, auras and more", "shop_pressed"],
	["Send feedback", ICON_FEEDBACK, "Open the AnvilFX community board: request an effect or a feature, report a problem, say what you think", "feedback_pressed"],
]

var _brand := HBoxContainer.new()
var _room := ScrollContainer.new()   # measures the space left for the buttons without demanding any
var _actions := HBoxContainer.new()
var _full_width := 0.0


func _ready() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = Look.LINE
	box.border_width_bottom = 1
	box.content_margin_left = Look.px(self, 10)
	box.content_margin_right = Look.px(self, 8)
	box.content_margin_top = Look.px(self, 5)
	box.content_margin_bottom = Look.px(self, 5)
	add_theme_stylebox_override("panel", box)
	var line := HBoxContainer.new()
	_build_brand()
	line.add_child(_brand)
	_room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_room.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_room.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_room.mouse_filter = Control.MOUSE_FILTER_PASS
	_actions.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	_actions.add_theme_constant_override("separation", int(Look.px(self, 2)))
	for action in ACTIONS:
		_actions.add_child(_action(action))
	_room.add_child(_actions)
	line.add_child(_room)
	add_child(line)
	_full_width = _actions.get_combined_minimum_size().x
	_room.resized.connect(_fit_actions)


## The words go when the buttons no longer fit beside the wordmark; their tooltips still say what they do.
func _fit_actions() -> void:
	var compact := _room.size.x < _full_width
	for button in _actions.get_children():
		button.text = "" if compact else button.get_meta("words")


func _action(action: Array) -> Button:
	var button := Button.new()
	button.text = action[0]
	button.set_meta("words", action[0])
	button.icon = Look.svg_icon(ICON_HEAD + action[1] + "</svg>", ICON_SIZE, Look.px(self, ICON_SIZE))
	button.theme_type_variation = Look.FLAT
	button.tooltip_text = action[2]
	button.pressed.connect(func() -> void: emit_signal(action[3]))
	return button


## The anvil glyph beside the wordmark, the version and studio under it.
func _build_brand() -> void:
	_brand.add_theme_constant_override("separation", int(Look.px(self, 7)))
	var mark := TextureRect.new()
	mark.texture = Brand.glyph(self, GLYPH_SIZE)
	mark.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_brand.add_child(mark)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", int(Look.px(self, -2)))
	text.add_child(Brand.wordmark(self))
	text.add_child(Look.small(Brand.byline()))
	_brand.add_child(text)
