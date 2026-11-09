extends Camera2D
## The starter scenes' camera: when the scene runs, the mouse wheel zooms, a middle- or right-drag pans and the arrow
## keys pan. Keep it, or replace it with your game's own camera.

const ZOOM_STEP = 1.15
const ZOOM_RANGE = Vector2(0.25, 4.0)
const PAN_SPEED = 900.0   # px per second at zoom 1, for the arrow keys


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.0 / ZOOM_STEP)
	elif event is InputEventMouseMotion and event.button_mask & (MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT):
		position -= event.relative / zoom


func _process(delta: float) -> void:
	var pan := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	position += pan * PAN_SPEED * delta / zoom


func _zoom_by(factor: float) -> void:
	zoom = (zoom * factor).clamp(Vector2.ONE * ZOOM_RANGE.x, Vector2.ONE * ZOOM_RANGE.y)
