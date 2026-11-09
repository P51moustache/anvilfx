@tool
extends CenterContainer
## What a project with no packs shows: a dark stage waiting for its first effect, with one thing to do. A zip dropped
## here reaches the dock, which installs it.

signal install_pressed

const Look = preload("look.gd")
const BOX_ICON = "<svg xmlns='http://www.w3.org/2000/svg' width='48' height='48' fill='none' stroke='#f1efea' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'><path d='M24 18 8 25v14l16 7 16-7V25l-7-3'/><path d='m8 25 16 7 16-7M24 32v14'/><path d='M24 25V3m-7 7 7-7 7 7'/></svg>"
const ICON_SIZE = 46
const BURST_SEED = 7
const SPIKES = 26
const FRAME_INSET = 10
const BRACKET = 13


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", int(Look.px(self, 5)))
	var mark := TextureRect.new()
	mark.texture = Look.svg_icon(BOX_ICON, 48.0, Look.px(self, ICON_SIZE))
	mark.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	box.add_child(mark)
	var head := Label.new()
	head.text = "Your next great effect starts here"
	head.theme_type_variation = Look.HEADLINE
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var line := Look.muted("Drop a pack .zip here. No need to unzip it.")
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(line)
	var button := Button.new()
	button.text = "Install pack..."
	button.theme_type_variation = Look.PRIMARY
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size.y = Look.px(self, 32)
	button.pressed.connect(func() -> void: install_pressed.emit())
	var gap := Control.new()
	gap.custom_minimum_size.y = Look.px(self, 4)
	box.add_child(gap)
	box.add_child(button)
	add_child(box)


func _draw() -> void:
	_draw_burst()
	_draw_frame()


## A faint burst behind the words: the shape of the effect that isn't here yet.
func _draw_burst() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = BURST_SEED
	var centre := size / 2.0
	for i in SPIKES:
		var angle := TAU * (i + random.randf_range(-0.3, 0.3)) / SPIKES
		var reach := Vector2(size.x * 0.5, size.y * 0.5) * random.randf_range(0.5, 1.05)
		var way := Vector2(cos(angle), sin(angle))
		var tip := centre + way * reach
		var side := way.orthogonal() * Look.px(self, random.randf_range(5.0, 16.0))
		var base := centre + way * reach * 0.28
		draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), Color(1, 1, 1, 0.035))


## A dotted drop outline with corner brackets, like a viewfinder.
func _draw_frame() -> void:
	var inset := Look.px(self, FRAME_INSET)
	var box := Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2.0)
	var corners := [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]
	var width := maxf(1.0, Look.px(self, 1))
	var dots := Color(1, 1, 1, 0.26)
	for i in corners.size():
		draw_dashed_line(corners[i], corners[(i + 1) % corners.size()], dots, width, Look.px(self, 2), true)
	var inner := inset + Look.px(self, 8)
	var frame := Rect2(Vector2.ONE * inner, size - Vector2.ONE * inner * 2.0)
	var reach := Look.px(self, BRACKET)
	var ends := [[frame.position, Vector2(1, 1)], [Vector2(frame.end.x, frame.position.y), Vector2(-1, 1)],
			[frame.end, Vector2(-1, -1)], [Vector2(frame.position.x, frame.end.y), Vector2(1, -1)]]
	for corner in ends:
		draw_line(corner[0], corner[0] + Vector2(corner[1].x * reach, 0), Look.TEXT, width)
		draw_line(corner[0], corner[0] + Vector2(0, corner[1].y * reach), Look.TEXT, width)
