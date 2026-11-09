@tool
extends Node2D
## A stand-in unit to try effects on: a flat token (shadow, hull, turret, barrel) in its side's colour, or a block for
## a building. Select it (or its Muzzle / Hit marker) and add an effect from the AnvilFX tab; the effect lands on that
## node's origin. Swap it for your own sprite when you build on a starter scene.

const PLAYER = {"hull": Color("5f7686"), "rim": Color("e2ecf2"), "turret": Color("8ba2b2")}
const HOSTILE = {"hull": Color("6e3624"), "rim": Color("f2a35a"), "turret": Color("9a4b2c")}

@export var hostile := false:
	set(v):
		hostile = v
		queue_redraw()
@export var structure := false:
	set(v):
		structure = v
		queue_redraw()
@export var radius := 30.0:
	set(v):
		radius = v
		queue_redraw()


func _draw() -> void:
	var c: Dictionary = HOSTILE if hostile else PLAYER
	_ellipse(Vector2(4, 6), radius * 1.15, radius * 0.6, Color(0, 0, 0, 0.35))
	if structure:
		var r := Rect2(-radius, -radius * 1.2, radius * 2, radius * 1.6)
		draw_rect(r, c.hull)
		draw_rect(r, c.rim, false, 2.0)
		draw_rect(Rect2(-radius * 0.5, -radius * 1.6, radius, radius * 0.6), c.turret)
		return
	_ellipse(Vector2.ZERO, radius, radius * 0.62, c.hull)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 48, c.rim, 2.0)
	var dir := Vector2.LEFT if hostile else Vector2.RIGHT
	draw_line(Vector2.ZERO, dir * radius * 1.5, c.turret, radius * 0.22)
	draw_circle(Vector2.ZERO, radius * 0.45, c.turret)


func _ellipse(at: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		points.append(at + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(points, color)
