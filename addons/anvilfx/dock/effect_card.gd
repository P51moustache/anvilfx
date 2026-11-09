@tool
extends PanelContainer
## One effect in the dock's grid: the effect playing on its pack's floor with its star and loop tag over it, then its
## name, size and length. Click it to preview it; double-click it to add it under the selected node, or drag it into
## the 2D view to add it where it lands. Adding never opens the effect's own scene (effect_drag.gd says why).

signal chosen(entry: Dictionary)
signal add_requested(entry: Dictionary)
signal favourite_toggled(id: String)

const Library = preload("library.gd")
const Stage = preload("stage.gd")
const Look = preload("look.gd")
const Effect = preload("../effect.gd")
const EffectDrag = preload("effect_drag.gd")
const STAGE_SIZE = Vector2(150, 88)

var entry: Dictionary = {}
var selected: bool = false:
	set(value):
		selected = value
		_restyle()

var _stage := Stage.new()
var _star := Button.new()
var _favourite := false


func setup(p_entry: Dictionary) -> void:
	entry = p_entry
	tooltip_text = "%s\n%s · %s\nClick to preview. Double-click to add it to the selected node, or drag it into the 2D view." % [
		entry["title"], entry["pack"], entry["category"]]
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_filter = Control.MOUSE_FILTER_PASS   # a zip dropped on a card reaches the dock, which installs it


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(Look.px(self, 2)))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_build_stage())
	var title := Label.new()
	title.text = entry["title"]
	title.clip_text = true
	box.add_child(_padded(title))
	box.add_child(_padded(Look.small(Library.size_line(entry))))
	add_child(box)
	_restyle()
	var effect := _stage.show_effect(entry["json"])
	effect.repeat = Effect.Repeat.LOOP   # replay with no gap, so a card is never an empty floor


## Stop drawing while filtered out of the grid (hidden viewports skip rendering, the effect stops ticking).
func set_shown(shown: bool) -> void:
	visible = shown
	if _stage.effect:
		_stage.effect.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED


func set_favourite(favourite: bool) -> void:
	_favourite = favourite
	_show_star()


func _build_stage() -> Control:
	var holder := MarginContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.custom_minimum_size = Vector2(Look.px(self, STAGE_SIZE.x), Look.px(self, STAGE_SIZE.y))
	_stage.floor_color = Look.pack_floor(entry["ground"])
	_stage.show_grid = false
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_stage)
	var over := HBoxContainer.new()
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if entry["loops"]:
		var tag := Look.tag(self, "loop")
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		over.add_child(tag)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(gap)
	_star.theme_type_variation = Look.FLAT
	_star.focus_mode = Control.FOCUS_NONE
	_star.pressed.connect(func() -> void: favourite_toggled.emit(entry["id"]))
	_show_star()
	over.add_child(_star)
	holder.add_child(Look.margin(self, over, 2))
	return holder


func _show_star() -> void:
	_star.icon = Look.icon(self, "Favorites" if _favourite else "NonFavorite")
	_star.tooltip_text = "Remove from Favourites" if _favourite else "Add to Favourites"


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			add_requested.emit(entry)
		else:
			chosen.emit(entry)
		accept_event()


func _get_drag_data(_at: Vector2) -> Variant:
	var label := Label.new()
	label.text = entry["title"]
	set_drag_preview(label)
	return EffectDrag.data(entry)


func _padded(control: Control) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, int(Look.px(self, 7)))
	margin.add_child(control)
	return margin


func _restyle() -> void:
	if is_inside_tree():
		add_theme_stylebox_override("panel", Look.card_style(self, selected))
