@tool
extends RefCounted
## What a card carries while it is dragged, and where a drop lands in the scene. The payload is AnvilFX's own type,
## not a FileSystem "files" drag: Godot's own drop targets (the scene tabs, the FileSystem dock, an empty editor) open
## a dropped .tscn, and adding an effect must never open its scene. Only the AnvilFX drop zone accepts it.

const TYPE = "anvilfx_effect"


## The drag data for `entry`'s main scene.
static func data(entry: Dictionary) -> Dictionary:
	return {"type": TYPE, "scene": entry["scene"], "title": entry["title"]}


## The scene a drag carries, or "" when it is not an AnvilFX effect.
static func scene_of(drag: Variant) -> String:
	if drag is Dictionary and drag.get("type", "") == TYPE:
		return str(drag.get("scene", ""))
	return ""


## A point in the 2D editor's view (`at`, local to a control of size `shown` that displays a viewport of size
## `pixels` drawn through `canvas`, the editor's view transform) as a point on the edited scene's canvas.
static func to_canvas(at: Vector2, shown: Vector2, pixels: Vector2, canvas: Transform2D) -> Vector2:
	var scale := pixels / shown if shown.x > 0 and shown.y > 0 else Vector2.ONE
	return canvas.affine_inverse() * (at * scale)
