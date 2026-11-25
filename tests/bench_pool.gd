extends SceneTree
## Heavy-fire benchmark: spawns RATE effects a second for SECONDS, fresh then pooled, and prints the CPU cost of
## the spawns and the slowest frame. godot --headless -s tests/bench_pool.gd

const RATE = 300            # effects a second: a minigun plus a swarm's hits
const SECONDS = 2.0
const FPS = 60
const WARM = 160            # idle nodes made before the pooled run
const EFFECT = "shell-impact"   # the heaviest starter: a multi-sheet effect


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	current_scene = stage
	AnvilFX.warm([EFFECT])
	var fresh := await _measure(false)
	AnvilFX.warm([EFFECT], WARM)
	var pooled := await _measure(true)
	print("fresh : %d spawns, %.1f us each, worst frame %.2f ms, %d nodes built" % fresh)
	print("pooled: %d spawns, %.1f us each, worst frame %.2f ms, %d nodes built (after warm)" % pooled)
	quit()


func _measure(pooled: bool) -> Array:
	var per_frame := RATE / FPS
	var spawn_usec := 0
	var worst_usec := 0
	var count := 0
	var pool = preload("res://addons/anvilfx/effect_pool.gd").of(self)
	var built_before: int = pool.built_count()
	var last := Time.get_ticks_usec()
	for frame in int(SECONDS * FPS):
		var t0 := Time.get_ticks_usec()
		for i in per_frame:
			AnvilFX.spawn(EFFECT, Vector2(randf() * 800, randf() * 600), {"pool": pooled})
		spawn_usec += Time.get_ticks_usec() - t0
		count += per_frame
		await process_frame
		var now := Time.get_ticks_usec()
		if frame > 10:
			worst_usec = maxi(worst_usec, now - last)
		last = now
	for i in 240:   # let them all end before the next run
		await process_frame
	var built: int = pool.built_count() - built_before if pooled else count
	return [count, float(spawn_usec) / count, worst_usec / 1000.0, built]
