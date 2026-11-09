@tool
extends RefCounted
## The dock's look, "Screening Room" (docs/packs/dock-concepts/selected-screening-room.png): a near-black room where
## the effects are the only colour. This holds the palette, the display scale every fixed size goes through, and the
## small styled parts; dock_theme.gd turns the same palette into the Theme the dock's controls read.
##
## Every fixed size must go through px() or the Theme. A bare number stays that many physical pixels, so on a Retina
## screen it draws at half the size of everything the editor scales.

const BG = Color("0c0d0f")
const PANEL = Color("15161a")
const RAISED = Color("212329")
const LINE = Color(1, 1, 1, 0.14)
const TEXT = Color("f1efea")
const INK = Color("141416")         # text on the off-white primary button and chosen pills
const MUTED = Color(1, 1, 1, 0.62)  # secondary text (sizes, counts), as a modulate
const WARN = Color("ffb454")        # notes that something will look wrong
const SCREEN = Color("08090b")      # the stage's floor for packs made for a dark one
const LIGHT_FLOOR = 0.25            # a pack's floor this bright or brighter was chosen because its effects need it
const STAGE_OUTLINE = 3             # the dark edge on words over a stage
const RADIUS = 6
const CARD_RADIUS = 8

## Theme type variations, defined in dock_theme.gd.
const SMALL = "AnvilSmall"
const SECTION = "AnvilSection"
const TITLE = "AnvilTitle"
const HEADLINE = "AnvilHeadline"
const STAGE_TITLE = "AnvilStageTitle"
const STAGE_SMALL = "AnvilStageSmall"
const FLAT = "AnvilFlat"
const PRIMARY = "AnvilPrimary"
const PILL = "AnvilPill"


## The editor's display scale (the editor theme's base scale), 1 outside the editor. Needs `control` in the tree.
static func display_scale(control: Control) -> float:
	var base := control.get_theme_default_base_scale()
	return base if base > 0.0 else 1.0


## `value` design pixels in physical pixels. Needs `control` in the tree, so build sizes in _ready, not _init.
static func px(control: Control, value: float) -> float:
	return roundf(value * display_scale(control))


static func icon(control: Control, name: String) -> Texture2D:
	if control.has_theme_icon(name, "EditorIcons"):
		return control.get_theme_icon(name, "EditorIcons")
	return null


## An editor icon mirrored left to right (the theme has "next frame" but no "previous frame").
static func icon_mirrored(control: Control, name: String) -> Texture2D:
	var source := icon(control, name)
	if source == null:
		return null
	var image := source.get_image()
	image.flip_x()
	return ImageTexture.create_from_image(image)


## An icon drawn from SVG text authored `units` wide, at `pixels` physical pixels. Needs no import, stays sharp.
static func svg_icon(svg: String, units: float, pixels: float) -> Texture2D:
	var image := Image.new()
	if image.load_svg_from_string(svg, pixels / units) != OK:
		return null
	return ImageTexture.create_from_image(image)


## The floor a pack's effects play on by default: the screen, unless the pack was made for a light floor (multiply
## smoke, say), which would vanish on near-black.
static func pack_floor(ground: String) -> Color:
	var colour := Color(ground)
	return colour if colour.get_luminance() >= LIGHT_FLOOR else SCREEN


## How wide `text` draws in `control`'s font. Needs `control` in the tree: outside it, it has the default theme's font.
static func text_width(control: Control, text: String) -> float:
	var font := control.get_theme_font("font")
	return ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, control.get_theme_font_size("font_size")).x)


## A card: raised on the room, outlined in off-white when it is the chosen one.
static func card_style(control: Control, selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = BG
	box.set_corner_radius_all(int(px(control, CARD_RADIUS)))
	box.set_border_width_all(int(px(control, 2 if selected else 1)))
	box.border_color = TEXT if selected else LINE
	box.set_content_margin_all(px(control, 2))
	box.content_margin_bottom = px(control, 6)
	return box


## A small outlined tag ("loop").
static func tag(control: Control, text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.55)
	box.set_border_width_all(1)
	box.border_color = LINE
	box.set_corner_radius_all(int(px(control, 3)))
	box.content_margin_left = px(control, 5)
	box.content_margin_right = px(control, 5)
	panel.add_theme_stylebox_override("panel", box)
	var label := small(text)
	label.modulate = TEXT
	panel.add_child(label)
	return panel


## A small upper-case section head ("PACKS").
static func section(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.theme_type_variation = SECTION
	label.modulate = MUTED
	return label


static func muted(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate = MUTED
	return label


static func small(text: String) -> Label:
	var label := muted(text)
	label.theme_type_variation = SMALL
	return label


## A margin all round `child`, in design pixels. It adds `child` and returns the margin.
static func margin(control: Control, child: Control, all: float) -> MarginContainer:
	var box := MarginContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		box.add_theme_constant_override("margin_" + side, int(px(control, all)))
	box.add_child(child)
	return box
