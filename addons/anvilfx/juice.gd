extends Node
## Hit-stop and camera shake, the two things most games pair with a hit effect. AnvilFX.hit_stop() and
## AnvilFX.shake() (anvilfx.gd) put one of these under the scene tree's root the first time; it runs in real time
## and while paused, so it always ends what it starts. The maths is pure and static, so it is tested headless.
##
## Hit-stop lowers Engine.time_scale and puts it back after `seconds` of real time; a second hit while one is on
## extends it rather than ending it early. Shake moves the current Camera2D's offset (never its position) by up to
## `strength` px, fading out with the square of the time left, then puts the offset back.

const NODE_NAME = "AnvilFXJuice"
const SHAKE_HZ = 30.0          # wobbles per second: fast enough to read as an impact, not a sway
const DEFAULT_STOP_SCALE = 0.05   # near-freeze; 0 also works but stops every scaled timer too

var _stop_until_usec: int = 0
var _restore_scale: float = 1.0
var _shake_strength: float = 0.0
var _shake_total: float = 0.0
var _shake_left: float = 0.0
var _shake_time: float = 0.0
var _camera: Camera2D
var _camera_offset := Vector2.ZERO
var _last_usec: int = 0


func _init() -> void:
	name = NODE_NAME
	process_mode = Node.PROCESS_MODE_ALWAYS


## The juice node under `tree`'s root, made (and added at the end of the frame) the first time.
static func of(tree: SceneTree) -> Node:
	var found := tree.root.get_node_or_null(NODE_NAME)
	if found:
		return found
	var juice = load("res://addons/anvilfx/juice.gd").new()
	tree.root.add_child.call_deferred(juice)
	return juice


## Slow the game to `time_scale` for `seconds` of real time (extending a hit-stop already on).
func hit_stop(seconds: float, time_scale: float = DEFAULT_STOP_SCALE) -> void:
	if seconds <= 0.0:
		return
	var now := Time.get_ticks_usec()
	if not is_stopping():
		_restore_scale = Engine.time_scale
	Engine.time_scale = time_scale
	_stop_until_usec = stop_end(_stop_until_usec, now, seconds)


func is_stopping() -> bool:
	return _stop_until_usec > 0


## Shake `camera` (default: the viewport's current Camera2D) by up to `strength` px for `seconds`. A stronger shake
## takes over a weaker one; a weaker one during a stronger one is ignored.
func shake(strength: float, seconds: float, camera: Camera2D = null) -> void:
	if strength <= 0.0 or seconds <= 0.0:
		return
	if camera == null and is_inside_tree():
		camera = get_viewport().get_camera_2d()
	if camera == null:
		camera = Engine.get_main_loop().root.get_camera_2d() if Engine.get_main_loop() is SceneTree else null
	if camera == null:
		return
	if _shake_left > 0.0 and current_strength(_shake_strength, _shake_left, _shake_total) > strength:
		return
	if camera != _camera:
		_settle_camera()
		_camera = camera
		_camera_offset = camera.offset
	_shake_strength = strength
	_shake_total = seconds
	_shake_left = seconds


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real := 0.0 if _last_usec == 0 else minf((now - _last_usec) / 1000000.0, 0.1)
	_last_usec = now
	if is_stopping() and now >= _stop_until_usec:
		Engine.time_scale = _restore_scale
		_stop_until_usec = 0
	if _shake_left > 0.0:
		_shake_left -= real
		_shake_time += real
		if _shake_left <= 0.0 or not is_instance_valid(_camera):
			_settle_camera()
		else:
			_camera.offset = _camera_offset + shake_offset(_shake_strength, _shake_left, _shake_total, _shake_time)


func _exit_tree() -> void:
	if is_stopping():
		Engine.time_scale = _restore_scale
		_stop_until_usec = 0
	_settle_camera()


func _settle_camera() -> void:
	if is_instance_valid(_camera):
		_camera.offset = _camera_offset
	_camera = null
	_shake_left = 0.0


## When a hit-stop of `seconds` asked for at `now_usec` ends: the later of that and one already running.
static func stop_end(current_end_usec: int, now_usec: int, seconds: float) -> int:
	return maxi(current_end_usec, now_usec + int(seconds * 1000000.0))


## The shake's reach with `left` of `total` seconds to go: full at the start, fading with the square of the time left.
static func current_strength(strength: float, left: float, total: float) -> float:
	if total <= 0.0 or left <= 0.0:
		return 0.0
	var k := clampf(left / total, 0.0, 1.0)
	return strength * k * k


## The camera offset at time `t` (s since the shake began): two out-of-step waves, so it never moves in a line.
static func shake_offset(strength: float, left: float, total: float, t: float) -> Vector2:
	var reach := current_strength(strength, left, total)
	var phase := TAU * SHAKE_HZ * t
	return Vector2(sin(phase), cos(phase * 1.37 + 0.6)) * reach
