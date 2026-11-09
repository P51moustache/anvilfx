@tool
extends SubViewportContainer
## A little floor with one AnvilFXEffect on it, drawn in its own viewport so the effect's blends land on the
## floor colour, as in a game. The cards and the preview pane both use it.
##
## zoom 0 fits the effect to the stage (cards); a positive zoom draws it at that multiple of its game size.

const Effect = preload("../effect.gd")
const GRID_STEP = 32.0   # floor grid spacing in px, as the sample project's floor
const FIT_MAX = 4.0      # cards may enlarge a small effect this much so it reads at card size

var effect: Effect = null
var floor_color := Color("0b1626"):
	set(value):
		floor_color = value
		_floor.queue_redraw()
var zoom: float = 0.0:
	set(value):
		zoom = value
		_place()
var show_grid := true:
	set(value):
		show_grid = value
		_floor.queue_redraw()

var _viewport := SubViewport.new()
var _floor := _Floor.new()


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.audio_listener_enable_2d = false
	_floor.stage = self
	_viewport.add_child(_floor)
	add_child(_viewport)
	resized.connect(_place)


## Show `json_path` (an effect.json), `sheet` of it ("" the whole effect). Returns the effect node.
func show_effect(json_path: String, sheet: String = "", editor_replay: bool = true) -> Effect:
	if effect:
		effect.queue_free()
	effect = Effect.new()
	effect.editor_replay = editor_replay
	effect.effect = load(json_path)
	effect.sheet = sheet
	_viewport.add_child(effect)
	_place()
	return effect


func clear() -> void:
	if effect:
		effect.queue_free()
		effect = null


func _place() -> void:
	if effect == null or not effect.is_inside_tree():
		return
	var room := size
	var box: Rect2 = effect.bounds()
	var k := zoom
	if zoom <= 0.0:
		k = 1.0
		if box.size.x > 0.0 and box.size.y > 0.0:
			k = minf(FIT_MAX, minf(room.x * 0.9 / box.size.x, room.y * 0.8 / box.size.y))
	effect.scale = Vector2.ONE * k
	effect.position = (room / 2.0 - box.get_center() * k).round()
	_floor.queue_redraw()


class _Floor extends Node2D:
	var stage

	func _draw() -> void:
		var area: Vector2 = stage.size
		draw_rect(Rect2(Vector2.ZERO, area), stage.floor_color)
		if not stage.show_grid:
			return
		var line: Color = stage.floor_color.lightened(0.09) if stage.floor_color.get_luminance() < 0.5 \
				else stage.floor_color.darkened(0.08)
		var x := fposmod(area.x / 2.0, GRID_STEP)
		while x < area.x:
			draw_line(Vector2(x, 0), Vector2(x, area.y), line)
			x += GRID_STEP
		var y := fposmod(area.y / 2.0, GRID_STEP)
		while y < area.y:
			draw_line(Vector2(0, y), Vector2(area.x, y), line)
			y += GRID_STEP
