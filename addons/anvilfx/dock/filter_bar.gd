@tool
extends VBoxContainer
## What the grid shows: the search box with how many effects match, All effects and Favourites, then the packs found
## in the project and the categories as lines of pills. A line too long for the panel scrolls sideways under the
## mouse wheel. Choosing one filters the grid.

signal filter_chosen(kind: String, value: String)
signal query_changed(text: String)

const Look = preload("look.gd")
const HEAD_WIDTH = 72   # lines the PACKS and CATEGORIES pills up

var _search := LineEdit.new()
var _count := Label.new()
var _all := Button.new()
var _favourites := Button.new()
var _packs := HBoxContainer.new()
var _categories := HBoxContainer.new()
var _chosen := ["all", ""]


func _ready() -> void:
	add_theme_constant_override("separation", int(Look.px(self, 6)))
	var line := HBoxContainer.new()
	_search.placeholder_text = "Search effects..."
	_search.clear_button_enabled = true
	_search.right_icon = Look.icon(self, "Search")
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(text: String) -> void: query_changed.emit(text))
	line.add_child(_search)
	_count.modulate = Look.MUTED
	_count.theme_type_variation = Look.SMALL
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(_count)
	_setup_pill(_all, "all", "", "All effects", "Every effect in the project")
	line.add_child(_all)
	_setup_pill(_favourites, "favourites", "", "Favourites", "The effects you starred")
	line.add_child(_favourites)
	add_child(line)
	add_child(_pill_line("Packs", _packs))
	add_child(_pill_line("Categories", _categories))


func query() -> String:
	return _search.text


## How many effects the current filter shows.
func show_count(count: int) -> void:
	_count.text = "%d effect%s" % [count, "" if count == 1 else "s"]


## Rebuild the pills. all and favourites: how many effects each holds; packs and categories: [name, count] pairs.
func show_counts(all: int, favourites: int, packs: Array, categories: Array) -> void:
	_all.tooltip_text = "Every effect in the project: %d" % all
	_favourites.tooltip_text = "The effects you starred: %d" % favourites
	_fill(_packs, "pack", packs)
	_fill(_categories, "category", categories)


func choose(kind: String, value: String) -> void:
	_chosen = [kind, value]
	for pill in [_all, _favourites] + _packs.get_children() + _categories.get_children():
		var on: bool = pill.get_meta("filter") == _chosen
		pill.set_pressed_no_signal(on)
		if on:
			_reveal(pill)
	for line in [_packs, _categories]:
		if not line.get_children().any(func(pill: Button) -> bool: return pill.button_pressed):
			(line.get_parent() as ScrollContainer).scroll_horizontal = 0   # a row with no choice rests at its start
	filter_chosen.emit(kind, value)


func _reveal(pill: Button) -> void:
	var parent := pill.get_parent().get_parent()
	if parent is ScrollContainer:
		(parent as ScrollContainer).ensure_control_visible(pill)


func _fill(line: HBoxContainer, kind: String, pairs: Array) -> void:
	for child in line.get_children():
		line.remove_child(child)   # gone now, not at frame end: choose() must never see a stale pill
		child.queue_free()
	for pair in pairs:
		var pill := Button.new()
		_setup_pill(pill, kind, pair[0], pair[0], "%s: %d effect%s" % [pair[0], pair[1], "" if pair[1] == 1 else "s"])
		line.add_child(pill)


func _setup_pill(pill: Button, kind: String, value: String, text: String, tip: String) -> void:
	pill.text = text
	pill.tooltip_text = tip
	pill.toggle_mode = true
	pill.theme_type_variation = Look.PILL
	pill.focus_mode = Control.FOCUS_NONE
	pill.set_meta("filter", [kind, value])
	pill.button_pressed = [kind, value] == _chosen
	pill.pressed.connect(func() -> void: choose(kind, value))


func _pill_line(head: String, pills: HBoxContainer) -> Control:
	var line := HBoxContainer.new()
	var label := Look.section(head)
	label.custom_minimum_size.x = Look.px(self, HEAD_WIDTH)
	line.add_child(label)
	pills.add_theme_constant_override("separation", int(Look.px(self, 5)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(pills)
	line.add_child(scroll)
	return line
