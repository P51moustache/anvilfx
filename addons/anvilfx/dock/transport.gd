@tool
extends HFlowContainer
## The player controls under the stage: step and play, a scrubber with the frame count, Loop, and playback Speed. Its
## two groups share a line when the panel is wide enough and take a line each when it is not. It plays whatever
## effect the attached stage shows. Pressing the speed's value puts it back to 1×.

signal speed_changed(value: float)
signal loop_changed(on: bool)

const Look = preload("look.gd")
const Speed = preload("speed.gd")
const WIDEST_SPEED = "0.25×"  # the widest label the Speed slider shows; its box never grows past this
const SCRUB_MIN_WIDTH = 80
const SPEED_MIN_WIDTH = 70

## Playback speed for the preview and for effects added from the dock (their speed_scale).
var speed: float = 1.0

var _stage = null        # stage.gd
var _play: Button
var _scrub := HSlider.new()
var _frame := Label.new()
var _loop := CheckBox.new()
var _speed := HSlider.new()
var _speed_value := Button.new()


func attach(stage) -> void:
	_stage = stage


func looping() -> bool:
	return _loop.button_pressed


func set_speed(value: float) -> void:
	_speed.value = value


## What the current speed does to the current effect, on the slider's tooltip.
func set_speed_tip(text: String) -> void:
	_speed.tooltip_text = "Playback speed of the preview and of effects you add. It never adds frames: faster shows " \
			+ "each frame for less time, slower holds each one longer.\n" + text


func _ready() -> void:
	add_child(_build_player())
	add_child(_build_options())
	_speed_value.custom_minimum_size.x = Look.text_width(_speed_value, WIDEST_SPEED) + Look.px(self, 16)
	_show_speed()


func _process(_delta: float) -> void:
	var effect = _stage.effect if _stage else null
	if effect == null or not is_visible_in_tree():
		_frame.text = "-- / --"
		return
	var count: int = effect.frame_count()
	_frame.text = "%02d / %02d" % [effect.current_frame() + 1, count]
	_scrub.max_value = maxi(count - 1, 1)
	_scrub.set_value_no_signal(effect.current_frame())
	_play.icon = Look.icon(self, "Pause" if effect.is_playing() else "Play")


func _build_player() -> Control:
	var line := HBoxContainer.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_constant_override("separation", int(Look.px(self, 3)))
	var back := _button("NextFrame", "Previous frame", func() -> void: _step(-1))
	back.icon = Look.icon_mirrored(self, "NextFrame")
	line.add_child(back)
	_play = _button("Play", "Play / pause", _toggle_play)
	line.add_child(_play)
	line.add_child(_button("NextFrame", "Next frame", func() -> void: _step(1)))
	_scrub.step = 1.0
	_scrub.custom_minimum_size.x = Look.px(self, SCRUB_MIN_WIDTH)
	_scrub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scrub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_scrub.tooltip_text = "Scrub through the effect, frame by frame"
	_scrub.focus_mode = Control.FOCUS_NONE
	_scrub.value_changed.connect(func(frame: float) -> void:
		var effect = _stage.effect if _stage else null
		if effect:
			effect.seek_frame(int(frame)))
	line.add_child(_scrub)
	_frame.theme_type_variation = Look.SMALL
	_frame.custom_minimum_size.x = Look.px(self, 54)
	_frame.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(_frame)
	return line


func _build_options() -> Control:
	var line := HBoxContainer.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loop.text = "Loop"
	_loop.button_pressed = true
	_loop.tooltip_text = "Replay the effect when it ends"
	_loop.toggled.connect(func(on: bool) -> void: loop_changed.emit(on))
	line.add_child(_loop)
	line.add_child(Look.muted("Speed"))
	_speed.name = "Speed"   # the store's editor tour finds the slider by this name
	_speed.min_value = Speed.MIN
	_speed.max_value = Speed.MAX
	_speed.step = Speed.STEP
	_speed.value = 1.0
	_speed.custom_minimum_size.x = Look.px(self, SPEED_MIN_WIDTH)
	_speed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speed.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_speed.focus_mode = Control.FOCUS_NONE
	_speed.value_changed.connect(_set_speed)
	set_speed_tip("")
	line.add_child(_speed)
	_speed_value.theme_type_variation = Look.FLAT
	_speed_value.tooltip_text = "Play as made"
	_speed_value.focus_mode = Control.FOCUS_NONE
	_speed_value.pressed.connect(func() -> void: _speed.value = 1.0)
	line.add_child(_speed_value)
	return line


func _button(icon_name: String, tip: String, action: Callable) -> Button:
	var button := Button.new()
	button.icon = Look.icon(self, icon_name)
	button.tooltip_text = tip
	button.theme_type_variation = Look.FLAT
	button.focus_mode = Control.FOCUS_NONE
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.pressed.connect(action)
	return button


func _toggle_play() -> void:
	var effect = _stage.effect if _stage else null
	if effect == null:
		return
	if effect.is_playing():
		effect.pause()
	else:
		effect.resume()


func _step(by: int) -> void:
	var effect = _stage.effect if _stage else null
	if effect:
		effect.seek_frame(effect.current_frame() + by)


func _set_speed(value: float) -> void:
	speed = value
	_show_speed()
	speed_changed.emit(value)


func _show_speed() -> void:
	_speed_value.text = Speed.label(speed)
