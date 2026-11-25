extends Node
## Reuses effect nodes for heavy fire: a minigun's muzzle flashes, a swarm's hits, hundreds of effects a second.
## Spawning a fresh effect builds its sheet players, sprites and shader materials, then frees them all when it
## ends; at a few hundred a second that churn shows up as frame spikes. AnvilFX.spawn(..., {"pool": true}) takes
## an idle node from here instead and gives it back when its one pass ends (or when AnvilFX.release() is called on
## a looping one), so after warm-up nothing is built or freed during play.
##
## A node coming back is stopped, taken out of the tree, and set back to how its scene made it: transform, tint,
## draw order, every playback and layer option, and any `finished` connections its last user made. So a reused node
## behaves exactly like a fresh one. AnvilFX.spawn() puts one of these under the tree's root the first time.

const NODE_NAME = "AnvilFXPool"
## Idle nodes kept per effect scene. A heavy-fire effect lives about half a second, so 256 covers ~500 spawns a
## second of one effect; past it, returning nodes are freed rather than hoarded.
const MAX_IDLE_PER_SCENE = 256
const POOL_META = &"anvilfx_pool_scene"   # set on every node this pool made; holds its scene's key
const IDLE_META = &"anvilfx_pool_idle"     # set while the node sits idle here, so a double release is harmless
## The node properties a spawn can change, put back on release. Layer overrides are reset with reset_layers().
const RESET_PROPERTIES = ["position", "rotation", "scale", "skew", "visible", "modulate", "self_modulate",
		"z_index", "z_as_relative", "process_mode", "autoplay", "repeat", "flip_h", "speed_scale",
		"sustain_seconds", "sustain_hold", "holdout_opacity", "light_opacity", "trim_start_ms", "trim_end_ms",
		"ignore_time_scale", "free_when_finished", "pieces"]

static var _current: Node = null   # the live pool, found before its deferred add lands

var _idle := {}       # scene key -> Array of idle AnvilFXEffect nodes, out of the tree
var _built: int = 0  # nodes this pool has made, for tuning the warm count
var _pristine := {}   # scene key -> {property: value} from a fresh instance of the scene


func _init() -> void:
	name = NODE_NAME


## The pool under `tree`'s root, made the first time (added at the end of the frame, usable at once).
static func of(tree: SceneTree) -> Node:
	if is_instance_valid(_current) and not _current.is_queued_for_deletion():
		return _current
	_current = tree.root.get_node_or_null(NODE_NAME)
	if _current == null:
		_current = load("res://addons/anvilfx/effect_pool.gd").new()
		tree.root.add_child.call_deferred(_current)
	return _current


## An effect node for `scene`, out of the tree: an idle one when there is one, else a new one. Returns null when
## the scene's root is not an AnvilFXEffect.
func take(scene: PackedScene) -> AnvilFXEffect:
	var key := _key(scene)
	var idle: Array = _idle.get(key, [])
	while not idle.is_empty():
		var reused = idle.pop_back()
		if is_instance_valid(reused):
			reused.remove_meta(IDLE_META)
			return reused
	return _make(scene)


## Make `count` idle nodes for `scene` now, so the first burst in play builds nothing.
func fill(scene: PackedScene, count: int) -> void:
	var have: int = _idle.get(_key(scene), []).size()
	for i in range(have, mini(count, MAX_IDLE_PER_SCENE)):
		var node := _make(scene)
		if node == null:
			return
		_park(node)


func _make(scene: PackedScene) -> AnvilFXEffect:
	var key := _key(scene)
	var node := scene.instantiate() as AnvilFXEffect
	if node == null:
		return null
	_built += 1
	if not _pristine.has(key):
		_pristine[key] = _snapshot(node)
	node.set_meta(POOL_META, key)
	node.finished.connect(_on_finished.bind(node))
	return node


## Whether `node` came from a pool (and so goes back to one rather than being freed).
static func is_pooled(node: Node) -> bool:
	return node != null and node.has_meta(POOL_META)


## Stop `node` and keep it for the next spawn of its scene. Safe to call twice or on a node being freed.
func release(node: AnvilFXEffect) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion() or node.has_meta(IDLE_META):
		return
	if not is_pooled(node):
		node.queue_free()
		return
	node.stop()
	var parent := node.get_parent()
	if parent:
		parent.remove_child(node)
	_reset(node)
	_park(node)


## Idle nodes held for `scene` (for tests and tuning).
func idle_count(scene: PackedScene) -> int:
	return _idle.get(_key(scene), []).size()


## Nodes this pool has made so far. If it keeps rising during play, warm more.
func built_count() -> int:
	return _built


func _park(node: AnvilFXEffect) -> void:
	var key = node.get_meta(POOL_META)
	var idle: Array = _idle.get(key, [])
	if idle.size() >= MAX_IDLE_PER_SCENE:
		node.free()
		return
	node.set_meta(IDLE_META, true)
	idle.append(node)
	_idle[key] = idle


func _reset(node: AnvilFXEffect) -> void:
	var pristine: Dictionary = _pristine.get(node.get_meta(POOL_META), {})
	for property in pristine:   # only what changed: each effect setter re-applies the layers
		var value = pristine[property]
		if node.get(property) != value:
			node.set(property, value.duplicate(true) if value is Dictionary else value)
	if node.has_layer_overrides():
		node.reset_layers()
	for connection in node.finished.get_connections():   # drop the last user's hooks, keep the pool's own
		var callable: Callable = connection["callable"]
		if callable.get_object() != self:
			node.finished.disconnect(callable)


static func _snapshot(node: AnvilFXEffect) -> Dictionary:
	var out := {}
	for property in RESET_PROPERTIES:
		var value = node.get(property)
		out[property] = value.duplicate(true) if value is Dictionary else value
	return out


func _on_finished(node: AnvilFXEffect) -> void:
	release.call_deferred(node)   # it ends inside its own _process; leave the tree after that


static func _key(scene: PackedScene) -> String:
	return scene.resource_path if scene.resource_path != "" else str(scene.get_instance_id())


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for key in _idle:
			for node in _idle[key]:
				if is_instance_valid(node):
					node.free()
		_idle.clear()
