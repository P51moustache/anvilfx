@tool
extends ScrollContainer
## The cards. They are made once per library scan and shown or hidden by the filter, so their previews keep playing
## while the person searches.

signal chosen(entry: Dictionary)
signal add_requested(entry: Dictionary)
signal favourite_toggled(id: String)

const Card = preload("effect_card.gd")
const Look = preload("look.gd")
const CARD_GAP = 8
const CARD_PADDING = 6   # a card's edge around its stage
const GUTTER = 10        # kept free for the scroll bar

var _flow := GridContainer.new()
var _cards := {}          # key(entry) -> Card
var _selected := ""


func _init() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER   # disabled would make the columns the panel's minimum
	mouse_filter = Control.MOUSE_FILTER_PASS
	_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_flow)
	resized.connect(_fit_columns)


func _ready() -> void:
	_flow.add_theme_constant_override("h_separation", int(Look.px(self, CARD_GAP)))
	_flow.add_theme_constant_override("v_separation", int(Look.px(self, CARD_GAP)))
	_fit_columns()


## As many columns as fit at the cards' smallest width, sharing the room between them.
func _fit_columns() -> void:
	if not is_inside_tree():
		return
	var gap := Look.px(self, CARD_GAP)
	var card := Look.px(self, Card.STAGE_SIZE.x + CARD_PADDING)
	_flow.columns = maxi(1, int((size.x - Look.px(self, GUTTER) + gap) / (card + gap)))


static func key(entry: Dictionary) -> String:
	return "%s|%s" % [entry["json"], entry["pack"]]


## Make a card for every entry (after a scan), dropping the old ones.
func set_entries(entries: Array) -> void:
	for card in _cards.values():
		card.queue_free()
	_cards.clear()
	for entry in entries:
		var card := Card.new()
		card.setup(entry)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.chosen.connect(func(e: Dictionary) -> void: chosen.emit(e))
		card.add_requested.connect(func(e: Dictionary) -> void: add_requested.emit(e))
		card.favourite_toggled.connect(func(id: String) -> void: favourite_toggled.emit(id))
		_flow.add_child(card)
		_cards[key(entry)] = card
	select(_selected)


## Show only `entries`, in the library's order.
func show_only(entries: Array) -> void:
	var keep := {}
	for entry in entries:
		keep[key(entry)] = true
	for k in _cards:
		_cards[k].set_shown(keep.has(k))


func select(entry_key: String) -> void:
	_selected = entry_key
	for k in _cards:
		_cards[k].selected = k == entry_key


## Which cards wear a filled star. ids: the favourite effects' ids.
func show_favourites(ids: Array) -> void:
	for card in _cards.values():
		card.set_favourite(card.entry["id"] in ids)
