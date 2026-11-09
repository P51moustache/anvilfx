@tool
extends RefCounted
## The AnvilFX brand inside the editor (drawn in code): the anvil glyph, the
## wordmark (white "Anvil", orange "FX") and the version line under it. The glyph is icon.svg, which is also the
## AnvilFXEffect node icon in the Scene tree; it is drawn from the SVG at run time, so it needs no import and stays
## sharp at any editor scale. Everything else in the dock keeps the editor's own colours.

const Look = preload("look.gd")
const ADDON = "res://addons/anvilfx"
const ORANGE = Color("ff5a36")     # the FX orange
const STUDIO = "thepixelgoblin"
const WORDMARK_SIZE = 22
const EMBOLDEN = 0.8               # the wordmark is heavier than the editor's bold face


## The anvil glyph at `size` editor pixels (16 is a node or tab icon), or null when the SVG can't be read.
static func glyph(control: Control, size: float = 16.0) -> Texture2D:
	var image := Image.new()
	var svg := FileAccess.get_file_as_string(ADDON.path_join("icon.svg"))
	if svg.is_empty() or image.load_svg_from_string(svg, size / 16.0 * Look.display_scale(control)) != OK:
		return null
	return ImageTexture.create_from_image(image)


## The installed plugin's version, from plugin.cfg ("" when it can't be read).
static func version() -> String:
	var config := ConfigFile.new()
	if config.load(ADDON.path_join("plugin.cfg")) != OK:
		return ""
	return str(config.get_value("plugin", "version", ""))


## "v1.3.1 · by thepixelgoblin".
static func byline() -> String:
	var shown := version()
	return ("v%s · by %s" % [shown, STUDIO]) if shown != "" else "by %s" % STUDIO


## The wordmark: "Anvil" in the editor's font colour, "FX" in the brand orange, both heavy.
static func wordmark(control: Control) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for part in [["Anvil", null], ["FX", ORANGE]]:
		var label := Label.new()
		label.text = part[0]
		label.add_theme_font_override("font", _heavy(control))
		label.add_theme_font_size_override("font_size", int(Look.px(control, WORDMARK_SIZE)))
		if part[1] != null:
			label.add_theme_color_override("font_color", part[1])
		line.add_child(label)
	return line


static func _heavy(control: Control) -> Font:
	var heavy := FontVariation.new()
	heavy.base_font = control.get_theme_font("bold", "EditorFonts") if control.has_theme_font("bold", "EditorFonts") \
			else control.get_theme_default_font()
	heavy.variation_embolden = EMBOLDEN
	return heavy
