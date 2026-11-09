@tool
extends Control
## Lies over the 2D editor's view and takes AnvilFX cards dropped on it. It lets every click through, and catches
## the mouse only while an AnvilFX card is being dragged, so the 2D editor works as before.

signal dropped(scene_path: String, canvas_point: Vector2)

const EffectDrag = preload("effect_drag.gd")

var _view: SubViewport
var _shown: Control      # the SubViewportContainer that shows `_view` in the 2D editor


## Cover the 2D editor's view of `view` (the edited scene's SubViewport). The zone joins the container's parent, last,
## so it lies above the 2D editor's own input layer, which takes only FileSystem drops.
func attach(view: SubViewport) -> void:
	_view = view
	_shown = view.get_parent() as Control
	name = "AnvilFXDropZone"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shown.get_parent().add_child(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var ours := EffectDrag.scene_of(get_viewport().gui_get_drag_data()) != ""
		mouse_filter = Control.MOUSE_FILTER_STOP if ours else Control.MOUSE_FILTER_IGNORE
	elif what == NOTIFICATION_DRAG_END:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return EffectDrag.scene_of(data) != ""


func _drop_data(at: Vector2, data: Variant) -> void:
	var in_view := _shown.get_global_transform().affine_inverse() * (get_global_transform() * at)
	var point := EffectDrag.to_canvas(in_view, _shown.size, Vector2(_view.size), _view.global_canvas_transform)
	dropped.emit(EffectDrag.scene_of(data), point)
