@tool
extends VBoxContainer
## Customizing the chosen effect, shown in place of the browser while the stage keeps playing: per-sheet toggle, scale,
## speed, delay, offset and opacity, then the holdout and light mix, sustain, and splitting into child nodes. It holds
## these choices; the preview applies them to the stage (apply_to) and the dock adds them to what it places.

signal changed
signal closed

const Effect = preload("../effect.gd")
const Look = preload("look.gd")
const Speed = preload("speed.gd")
const LABEL_WIDTH = 74
const VALUE_WIDTH = 42

var holdout_opacity: float = 1.0
var light_opacity: float = 1.0
var sustain_seconds: float = 0.0

var _entry: Dictionary = {}
var _pieces: Dictionary = {}
var _edit_piece := ""
var _syncing_ui := false
var _piece_bar := HFlowContainer.new()
var _piece_scale := HSlider.new()
var _piece_scale_val := Label.new()
var _piece_speed := HSlider.new()
var _piece_speed_val := Label.new()
var _piece_opacity := HSlider.new()
var _piece_opacity_val := Label.new()
var _piece_delay := SpinBox.new()
var _piece_offset_x := SpinBox.new()
var _piece_offset_y := SpinBox.new()
var _holdout := HSlider.new()
var _holdout_val := Label.new()
var _light := HSlider.new()
var _light_val := Label.new()
var _sustain := HSlider.new()
var _sustain_val := Label.new()
var _split_pieces := CheckBox.new()


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_build_header())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(Look.px(self, 6)))
	body.add_child(_piece_bar)
	body.add_child(_build_grid())
	_split_pieces.text = "Split pieces into child nodes"
	_split_pieces.tooltip_text = "When adding the whole effect, create a child AnvilFXEffect node per sheet so each piece can be moved or Z-sorted in the Scene tree"
	_split_pieces.toggled.connect(func(_on: bool) -> void:
		if not _syncing_ui:
			changed.emit())
	body.add_child(_split_pieces)
	scroll.add_child(body)
	add_child(scroll)
	_rebuild_piece_bar()
	_sync_controls()


## Start over for `entry` (a Library entry; empty for none).
func show_entry(entry: Dictionary) -> void:
	_entry = entry
	_pieces.clear()
	holdout_opacity = 1.0
	light_opacity = 1.0
	sustain_seconds = 0.0
	var sheets: Array = entry.get("sheets", [])
	_edit_piece = String(sheets[0]) if not sheets.is_empty() else ""
	if is_node_ready():
		_rebuild_piece_bar()
		_sync_controls()


## The sheet whose sliders are showing.
func edit_piece(sheet_name: String) -> void:
	_edit_piece = sheet_name
	_sync_controls()


func edited_piece() -> String:
	return _edit_piece


## Active customizations for `sheet` ("" the whole effect), ready for Placer.add() or SpawnCode.spawn_code().
func customizations(sheet: String) -> Dictionary:
	var out := {}
	if not is_equal_approx(holdout_opacity, 1.0):
		out["holdout"] = holdout_opacity
	if not is_equal_approx(light_opacity, 1.0):
		out["light"] = light_opacity
	if sustain_seconds > 0.001:
		out["sustain"] = sustain_seconds
	if not _pieces.is_empty():
		out["pieces"] = _pieces.duplicate(true)
	if splits(sheet):
		out["split_pieces"] = true
	return out


## Whether adding `sheet` makes a child node per piece: only the whole effect of a many-sheet effect can.
func splits(sheet: String) -> bool:
	return _split_pieces.button_pressed and sheet == "" and _entry.get("sheets", []).size() > 1


## Put these choices on the effect the stage shows.
func apply_to(effect) -> void:
	effect.holdout_opacity = holdout_opacity
	effect.light_opacity = light_opacity
	effect.sustain_seconds = sustain_seconds
	effect.pieces = _pieces.duplicate(true)


func set_piece_property(sheet_name: String, key: String, value: Variant) -> void:
	if not Effect.PIECE_DEFAULTS.has(key):
		return
	var cfg: Dictionary = _pieces.get(sheet_name, {}).duplicate()
	if Effect._is_default_piece_value(key, value):
		cfg.erase(key)
	else:
		cfg[key] = value
	if cfg.is_empty():
		_pieces.erase(sheet_name)
	else:
		_pieces[sheet_name] = cfg
	_after_change()


func get_piece_property(sheet_name: String, key: String) -> Variant:
	var cfg: Dictionary = _pieces.get(sheet_name, {})
	return cfg.get(key, Effect.PIECE_DEFAULTS.get(key))


func set_holdout(value: float) -> void:
	holdout_opacity = clampf(value, 0.0, 1.0)
	_after_change()


func set_light(value: float) -> void:
	light_opacity = clampf(value, 0.0, 2.0)
	_after_change()


func set_sustain(value: float) -> void:
	sustain_seconds = maxf(0.0, value)
	_after_change()


func reset() -> void:
	_pieces.clear()
	holdout_opacity = 1.0
	light_opacity = 1.0
	sustain_seconds = 0.0
	_split_pieces.set_pressed_no_signal(false)
	_rebuild_piece_bar()
	_after_change()


func _after_change() -> void:
	_sync_controls()
	changed.emit()


func _build_header() -> Control:
	var line := HBoxContainer.new()
	var head := Label.new()
	head.text = "Pieces"
	head.theme_type_variation = Look.TITLE
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(head)
	var reset_button := Button.new()
	reset_button.text = "Reset"
	reset_button.theme_type_variation = Look.FLAT
	reset_button.tooltip_text = "Reset all piece, layer and sustain adjustments"
	reset_button.pressed.connect(reset)
	line.add_child(reset_button)
	var done := Button.new()
	done.text = "Done"
	done.tooltip_text = "Back to the effects"
	done.pressed.connect(func() -> void: closed.emit())
	line.add_child(done)
	return line


## The sliders in two columns: each rests on the piece being edited, then the whole effect's mix.
func _build_grid() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_slider_row("Piece scale", _piece_scale, _piece_scale_val, 0.25, 2.5, 0.05, 1.0, _on_piece("scale")))
	grid.add_child(_slider_row("Holdout", _holdout, _holdout_val, 0.0, 1.0, 0.05, 1.0, func(v: float) -> void:
		if not _syncing_ui:
			set_holdout(v)))
	grid.add_child(_slider_row("Piece speed", _piece_speed, _piece_speed_val, 0.25, 3.0, 0.05, 1.0, _on_piece("speed")))
	grid.add_child(_slider_row("Light", _light, _light_val, 0.0, 2.0, 0.05, 1.0, func(v: float) -> void:
		if not _syncing_ui:
			set_light(v)))
	grid.add_child(_slider_row("Piece alpha", _piece_opacity, _piece_opacity_val, 0.0, 1.0, 0.05, 1.0, _on_piece("opacity")))
	grid.add_child(_slider_row("Sustain", _sustain, _sustain_val, 0.0, 5.0, 0.1, 0.0, func(v: float) -> void:
		if not _syncing_ui:
			set_sustain(v)))
	grid.add_child(_build_offsets())
	return grid


func _on_piece(key: String) -> Callable:
	return func(v: float) -> void:
		if not _syncing_ui and _edit_piece != "":
			set_piece_property(_edit_piece, key, v)


func _build_offsets() -> Control:
	var offsets := HBoxContainer.new()
	offsets.add_theme_constant_override("separation", int(Look.px(self, 4)))
	offsets.add_child(Look.muted("Offset"))
	_setup_spin(_piece_offset_x, -256.0, 256.0, 2.0, "px", func(v: float) -> void:
		if not _syncing_ui and _edit_piece != "":
			var cur := get_piece_property(_edit_piece, "offset") as Vector2
			set_piece_property(_edit_piece, "offset", Vector2(v, cur.y)))
	_setup_spin(_piece_offset_y, -256.0, 256.0, 2.0, "px", func(v: float) -> void:
		if not _syncing_ui and _edit_piece != "":
			var cur := get_piece_property(_edit_piece, "offset") as Vector2
			set_piece_property(_edit_piece, "offset", Vector2(cur.x, v)))
	offsets.add_child(_piece_offset_x)
	offsets.add_child(_piece_offset_y)
	offsets.add_child(Look.muted("Delay"))
	_setup_spin(_piece_delay, -1000.0, 2000.0, 10.0, "ms", func(v: float) -> void:
		if not _syncing_ui and _edit_piece != "":
			set_piece_property(_edit_piece, "delay_ms", v))
	offsets.add_child(_piece_delay)
	return offsets


func _slider_row(label_text: String, slider: HSlider, val_label: Label, min_v: float, max_v: float, step_v: float,
		def_v: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", int(Look.px(self, 6)))
	var lbl := Look.muted(label_text)
	lbl.custom_minimum_size.x = Look.px(self, LABEL_WIDTH)
	row.add_child(lbl)
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.value = def_v
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	val_label.custom_minimum_size.x = Look.px(self, VALUE_WIDTH)
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_label)
	return row


func _setup_spin(spin: SpinBox, min_v: float, max_v: float, step_v: float, suffix: String, on_change: Callable) -> void:
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step_v
	spin.suffix = suffix
	spin.value_changed.connect(on_change)


func _rebuild_piece_bar() -> void:
	for child in _piece_bar.get_children():
		_piece_bar.remove_child(child)
		child.queue_free()
	var sheets: Array = _entry.get("sheets", [])
	_split_pieces.visible = sheets.size() > 1
	if sheets.is_empty():
		return
	var group := ButtonGroup.new()
	for sname in sheets:
		var sheet_str := String(sname)
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", int(Look.px(self, 2)))
		if sheets.size() > 1:
			var vis := CheckBox.new()
			vis.button_pressed = bool(get_piece_property(sheet_str, "enabled"))
			vis.tooltip_text = "Show / hide %s in the combined effect" % sheet_str
			vis.toggled.connect(func(on: bool) -> void:
				set_piece_property(sheet_str, "enabled", on))
			pair.add_child(vis)
		var pick := Button.new()
		pick.text = sheet_str
		pick.theme_type_variation = Look.PILL
		pick.toggle_mode = true
		pick.button_group = group
		pick.button_pressed = sheet_str == _edit_piece
		pick.tooltip_text = "Adjust %s's scale, speed, delay, offset and opacity" % sheet_str
		pick.pressed.connect(func() -> void: edit_piece(sheet_str))
		pair.add_child(pick)
		_piece_bar.add_child(pair)


func _sync_controls() -> void:
	_syncing_ui = true
	if _edit_piece != "":
		var sc := float(get_piece_property(_edit_piece, "scale"))
		var sp := float(get_piece_property(_edit_piece, "speed"))
		var op := float(get_piece_property(_edit_piece, "opacity"))
		var off := get_piece_property(_edit_piece, "offset") as Vector2
		_piece_scale.value = sc
		_piece_scale_val.text = Speed.label(sc)
		_piece_speed.value = sp
		_piece_speed_val.text = Speed.label(sp)
		_piece_opacity.value = op
		_piece_opacity_val.text = "%d%%" % int(round(op * 100.0))
		_piece_delay.value = float(get_piece_property(_edit_piece, "delay_ms"))
		_piece_offset_x.value = off.x
		_piece_offset_y.value = off.y
	_holdout.value = holdout_opacity
	_holdout_val.text = "%d%%" % int(round(holdout_opacity * 100.0))
	_light.value = light_opacity
	_light_val.text = "%d%%" % int(round(light_opacity * 100.0))
	_sustain.value = sustain_seconds
	_sustain_val.text = "%.1fs" % sustain_seconds
	_syncing_ui = false
