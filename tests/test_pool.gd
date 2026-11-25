extends SceneTree
## Headless checks for pooled spawns: godot --headless -s tests/test_pool.gd (exits 1 on a failure).

const Pool = preload("res://addons/anvilfx/effect_pool.gd")

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		printerr("FAIL: ", what)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _run() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	current_scene = stage
	var scene: PackedScene = load(AnvilFX.scene_path("shell-impact"))
	var pool = Pool.of(self)

	# a pooled one-shot goes back to the pool when it ends, and the next spawn reuses that same node
	var first := AnvilFX.spawn("shell-impact", Vector2(10, 20), {"pool": true, "scale": 2.0, "holdout": 0.3,
			"modulate": Color.RED, "z_index": 5, "layers": {"light": false}, "pieces": {"scuff": false}})
	_check(first != null and first.is_inside_tree() and first.is_playing(), "pooled spawn plays")
	var hooked := [0]
	first.finished.connect(func(): hooked[0] += 1)
	await _frames(240)
	_check(hooked[0] == 1, "finished fired once")
	_check(is_instance_valid(first) and not first.is_inside_tree(), "finished node left the tree, not freed")
	_check(pool.idle_count(scene) == 1, "finished node is idle in the pool")

	var second := AnvilFX.spawn("shell-impact", Vector2(5, 5), {"pool": true})
	_check(second == first, "next spawn reuses the idle node")
	_check(second.is_inside_tree() and second.is_playing(), "reused node plays")
	_check(second.scale == Vector2.ONE and second.holdout_opacity == 1.0, "scale and holdout reset")
	_check(second.modulate == Color.WHITE and second.z_index == 0 and second.z_as_relative, "tint and draw order reset")
	_check(second.is_layer_enabled("light") and second.is_piece_enabled("scuff"), "layer and piece overrides reset")
	_check(second.finished.get_connections().size() == 1, "last user's finished hook dropped")
	_check(second.global_position == Vector2(5, 5), "reused node placed")

	# release() ends a looping pooled effect; a double release is harmless
	var looping := AnvilFX.spawn("shell-impact", Vector2.ZERO, {"pool": true, "loop": true})
	AnvilFX.release(looping)
	AnvilFX.release(looping)
	_check(pool.idle_count(scene) == 1 and not looping.is_inside_tree(), "release parks a looping node once")
	var after := AnvilFX.spawn("shell-impact", Vector2.ZERO, {"pool": true})
	_check(after.repeat == AnvilFXEffect.Repeat.AS_MADE, "loop setting reset on reuse")

	# warm fills the pool; unpooled spawns still free themselves
	AnvilFX.warm(["shell-impact"], 8)
	_check(pool.idle_count(scene) == 8, "warm fills the pool")
	var plain := AnvilFX.spawn("shell-impact", Vector2.ZERO)
	_check(not Pool.is_pooled(plain) and plain.free_when_finished, "unpooled spawn unchanged")
	await _frames(240)
	_check(not is_instance_valid(plain), "unpooled spawn frees itself")

	print("pool tests: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)
