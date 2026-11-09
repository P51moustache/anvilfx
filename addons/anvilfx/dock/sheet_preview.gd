@tool
extends Control
## The import dialog's live preview: a sheet's frames cycling on a floor at the chosen frame rate and blend, fitted
## to the box, with the pivot marked. It reads the grid as typed, so a wrong column count shows at once.

const PIVOT_MARK = 6.0
const PIVOT_COLOR = Color(1.0, 0.45, 0.35, 0.9)

var texture: Texture2D:
	set(value):
		texture = value
		_time = 0.0
var columns: int = 1
var rows: int = 1
var frames: int = 1
var fps: float = 12.0
var speed: float = 1.0
var loop: bool = true
var additive: bool = false:
	set(value):
		additive = value
		(_sprite.material as CanvasItemMaterial).blend_mode = \
				CanvasItemMaterial.BLEND_MODE_ADD if value else CanvasItemMaterial.BLEND_MODE_MIX
var pivot := Vector2(0.5, 0.5)
var floor_color := Color("0b1626")

var _time := 0.0
var _sprite := _Frame.new()


func _init() -> void:
	clip_contents = true
	_sprite.view = self
	_sprite.material = CanvasItemMaterial.new()
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_sprite)


## The frame showing now: loops wrap; a one-shot holds its last frame for a beat, then starts over.
func frame() -> int:
	var index := int(floor(_time * fps * speed))
	var count := maxi(1, frames)
	if loop:
		return posmod(index, count)
	return mini(index % (count + int(fps)), count - 1)


func cell() -> Vector2:
	if texture == null:
		return Vector2.ONE
	return Vector2(texture.get_width() / maxi(1, columns), texture.get_height() / maxi(1, rows))


func _process(delta: float) -> void:
	if texture == null or not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()
	_sprite.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), floor_color)


## Where the cell is drawn: fitted to the box, centred.
func cell_rect() -> Rect2:
	var c := cell()
	var k := minf(size.x * 0.9 / c.x, size.y * 0.9 / c.y)
	return Rect2((size - c * k) / 2.0, c * k)


class _Frame extends Control:
	var view

	func _draw() -> void:
		if view.texture == null:
			return
		var index: int = view.frame()
		var c: Vector2 = view.cell()
		var source := Rect2(Vector2(index % maxi(1, view.columns), index / maxi(1, view.columns)) * c, c)
		var at: Rect2 = view.cell_rect()
		draw_texture_rect_region(view.texture, at, source)
		var p: Vector2 = at.position + at.size * view.pivot
		draw_line(p - Vector2(PIVOT_MARK, 0), p + Vector2(PIVOT_MARK, 0), PIVOT_COLOR, 1.5)
		draw_line(p - Vector2(0, PIVOT_MARK), p + Vector2(0, PIVOT_MARK), PIVOT_COLOR, 1.5)
