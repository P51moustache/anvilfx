@tool
extends Node2D
## A dark floor so effects read at game size, in the editor and when running: a square grid (top-down), a diamond
## grid (isometric) or a ground line with a horizon (side view). It only draws; it never collides.

enum Grid { SQUARE, DIAMOND, SIDE }

@export var grid := Grid.SQUARE:
	set(v):
		grid = v
		queue_redraw()
@export var size := Vector2(1600, 900):
	set(v):
		size = v
		queue_redraw()
@export var tile := 96.0:
	set(v):
		tile = maxf(v, 8.0)
		queue_redraw()
@export var ground_y := 700.0:   ## the side view's ground line
	set(v):
		ground_y = v
		queue_redraw()
@export var ground := Color("0b1626"):
	set(v):
		ground = v
		queue_redraw()
@export var line := Color("16283a"):
	set(v):
		line = v
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), ground)
	match grid:
		Grid.SQUARE:
			_square()
		Grid.DIAMOND:
			_diamond()
		Grid.SIDE:
			_side()


func _square() -> void:
	var x := 0.0
	while x <= size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), line, 1.0)
		x += tile
	var y := 0.0
	while y <= size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), line, 1.0)
		y += tile


## Lines at the isometric 2:1 slope, clipped to the floor.
func _diamond() -> void:
	var run := size.y * 2.0
	var x := -run
	while x < size.x + run:
		_clipped(Vector2(x, 0), Vector2(x + run, size.y))
		_clipped(Vector2(x, size.y), Vector2(x + run, 0))
		x += tile


func _side() -> void:
	draw_rect(Rect2(0, ground_y, size.x, size.y - ground_y), line)
	draw_line(Vector2(0, ground_y), Vector2(size.x, ground_y), line.lightened(0.25), 2.0)
	var x := 0.0
	while x <= size.x:
		draw_line(Vector2(x, ground_y), Vector2(x, ground_y + 10), line.lightened(0.25), 1.0)
		x += tile


func _clipped(a: Vector2, b: Vector2) -> void:
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	for axis in 2:
		if is_zero_approx(d[axis]):
			continue
		var lo := (0.0 - a[axis]) / d[axis]
		var hi := (size[axis] - a[axis]) / d[axis]
		t0 = maxf(t0, minf(lo, hi))
		t1 = minf(t1, maxf(lo, hi))
	if t0 < t1:
		draw_line(a + d * t0, a + d * t1, line, 1.0)
