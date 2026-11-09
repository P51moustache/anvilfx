@tool
extends RefCounted
## Adds an effect's scene to the edited scene as a child of a node, as one undoable action, the way dragging a scene
## from the FileSystem dock does: the child is an instance of the scene (so pack updates reach it), owned by the
## edited scene so it saves, named after the effect and placed on the parent's origin (its attach point), or where it
## was dropped in the 2D view. The effect's own scene is only loaded, never opened in the editor.

## Instance `scene_path` under `parent` (in the scene whose root is `root`) through `undo`, at `canvas_point` (a point
## on the scene's canvas) when one is given, playing at `speed` (its speed_scale) with any piece/layer `custom` settings.
## Returns the new node, or null when the scene can't be loaded.
static func add(scene_path: String, parent: Node, root: Node, undo: EditorUndoRedoManager,
		canvas_point: Variant = null, speed: float = 1.0, custom: Dictionary = {}) -> Node:
	if root == null:
		return null
	var node := instance(scene_path, parent, canvas_point, speed, custom)
	if node == null:
		return null
	undo.create_action("Add effect %s" % node.name, UndoRedo.MERGE_DISABLE, root)
	undo.add_do_method(parent, "add_child", node, true)
	undo.add_do_method(node, "set_owner", root)
	for child in node.get_children():
		if child is AnvilFXEffect:
			undo.add_do_method(child, "set_owner", root)
	undo.add_do_reference(node)
	undo.add_undo_method(parent, "remove_child", node)
	undo.commit_action()
	return node


## The new effect node for `add`, not yet in the tree: named free among `parent`'s children, placed and configured
## with `speed` and any piece/layer `custom` settings.
static func instance(scene_path: String, parent: Node, canvas_point: Variant = null, speed: float = 1.0,
		custom: Dictionary = {}) -> Node:
	var scene := load(scene_path) as PackedScene
	if scene == null or parent == null:
		return null
	var node := scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	node.name = unique_name(parent, node.name)
	if canvas_point is Vector2 and node is Node2D:
		node.position = local_point(parent, canvas_point)
	if not is_equal_approx(speed, 1.0) and "speed_scale" in node:
		node.speed_scale = speed
	apply_custom(node, custom)
	return node


## Apply dock customization settings (`holdout`, `light`, `sustain`, `trim_start`, `trim_end`, `pieces`, `split_pieces`)
## to an effect node.
static func apply_custom(node: Node, custom: Dictionary) -> void:
	if custom.is_empty():
		return
	if custom.has("holdout") and "holdout_opacity" in node:
		node.holdout_opacity = float(custom["holdout"])
	if custom.has("light") and "light_opacity" in node:
		node.light_opacity = float(custom["light"])
	if custom.has("sustain") and "sustain_seconds" in node:
		node.sustain_seconds = float(custom["sustain"])
	if custom.has("trim_start") and "trim_start_ms" in node:
		node.trim_start_ms = float(custom["trim_start"])
	if custom.has("trim_end") and "trim_end_ms" in node:
		node.trim_end_ms = float(custom["trim_end"])
	if custom.has("pieces") and custom["pieces"] is Dictionary and "pieces" in node:
		node.pieces = (custom["pieces"] as Dictionary).duplicate(true)
	if bool(custom.get("split_pieces", false)) and node.has_method("unpack_pieces") and node.get("sheet") == "":
		if node.has_method("sheet_names") and node.sheet_names().size() > 1:
			node.unpack_pieces()


## `wanted`, or `wanted2`, `wanted3`... so siblings keep readable names.
static func unique_name(parent: Node, wanted: String) -> String:
	if not parent.has_node(NodePath(wanted)):
		return wanted
	var i := 2
	while parent.has_node(NodePath("%s%d" % [wanted, i])):
		i += 1
	return "%s%d" % [wanted, i]


## `canvas_point` in `parent`'s own space, where a child's position is measured (a non-2D parent adds no transform).
static func local_point(parent: Node, canvas_point: Vector2) -> Vector2:
	if parent is CanvasItem:
		return (parent as CanvasItem).get_global_transform().affine_inverse() * canvas_point
	return canvas_point
