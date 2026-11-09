@tool
extends HBoxContainer
## The line under the browser: the node the effect will go under, Add to selected node and Copy code. The dock decides
## what those do; this only shows them. Their width never changes as the Add button's label grows or says "Copied".

signal add_pressed
signal copy_pressed

const Look = preload("look.gd")
const Speed = preload("speed.gd")
const COPIED_SECONDS = 1.5       # how long the Copy code button says "Copied"
const WIDEST_ADD = "Add to selected node  ·  1.5×"
const BUTTON_HEIGHT = 30

var _target := Label.new()
var _add := Button.new()
var _copy := Button.new()
var _target_words := ""    # the whole line; only the node's name shows when the words don't fit
var _target_short := ""
var _ready_to_add := false
var _blocked := false


func _ready() -> void:
	_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target.clip_text = true
	_target.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_target.modulate = Look.MUTED
	_target.resized.connect(_fit_target)
	add_child(_target)
	_add.text = "Add to selected node"
	_add.theme_type_variation = Look.PRIMARY
	_add.tooltip_text = "Add this effect's scene as a child of the node selected in the Scene tree (Ctrl+Z undoes it)"
	_add.focus_mode = Control.FOCUS_NONE
	_add.clip_text = true
	_add.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_add.pressed.connect(func() -> void: add_pressed.emit())
	add_child(_add)
	_add.custom_minimum_size = Vector2(Look.text_width(_add, WIDEST_ADD) + Look.px(self, 32), Look.px(self, BUTTON_HEIGHT))
	_copy.text = "Copy code"
	_copy.tooltip_text = "Copy the line that spawns this effect from your game code (AnvilFX.spawn)"
	_copy.focus_mode = Control.FOCUS_NONE
	_copy.pressed.connect(func() -> void: copy_pressed.emit())
	add_child(_copy)
	_copy.custom_minimum_size = Vector2(_copy.get_combined_minimum_size().x, Look.px(self, BUTTON_HEIGHT))
	_refresh()


## What "Add to selected node" adds to: a node name, or why it can't (no scene open).
func set_target(node_name: String, blocked_reason: String = "") -> void:
	_blocked = blocked_reason != ""
	_target_words = blocked_reason if _blocked else "Selected node:  " + node_name
	_target_short = blocked_reason if _blocked else node_name
	_target.tooltip_text = _target_words
	_fit_target()
	_refresh()


## Whether there is an effect to add or copy, and what the Add button says about it.
func show_state(has_effect: bool, speed: float, split: bool) -> void:
	_ready_to_add = has_effect
	var label := "Add to selected node"
	if not is_equal_approx(speed, 1.0):
		label += "  ·  " + Speed.label(speed)
	if split:
		label += "  ·  split"
	_add.text = label
	_refresh()


## The copy happened: say so for a moment.
func flash_copied() -> void:
	_copy.text = "Copied"
	get_tree().create_timer(COPIED_SECONDS, true, false, true).timeout.connect(func() -> void:
		if is_instance_valid(_copy):
			_copy.text = "Copy code")


func _fit_target() -> void:
	_target.text = _target_words if Look.text_width(_target, _target_words) <= _target.size.x else _target_short


func _refresh() -> void:
	_add.disabled = not _ready_to_add or _blocked
	_copy.disabled = not _ready_to_add
