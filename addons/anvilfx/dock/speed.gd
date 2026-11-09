@tool
extends RefCounted
## Playback speed, aware of the frame rate an effect was painted for. Speed never makes frames: faster shows each
## frame for less time, slower holds each frame longer. This says what a speed does to a given effect so the dock
## can warn before it looks wrong. Pure, so it is tested headless.

const MIN = 0.25
const MAX = 3.0
const STEP = 0.05
const CHOPPY_FPS = 12.0      # under ~12 distinct frames a second (animation "on twos" at 24) motion reads as steps
const DEFAULT_SCREEN_HZ = 60.0


## The frame rate `speed` plays an effect painted at `authored` fps.
static func shown_fps(authored: float, speed: float) -> float:
	return authored * speed


## The screen's refresh rate, or 60 when the display doesn't say.
static func screen_hz() -> float:
	var hz := DisplayServer.screen_get_refresh_rate()
	return hz if hz > 0.0 else DEFAULT_SCREEN_HZ


## [text, warn] for the dock: what `speed` does to an effect painted at `authored` fps lasting `seconds`, on a
## `hz` screen. warn is true when it will look wrong: stepping motion, or frames the screen can't show.
static func note(authored: float, speed: float, seconds: float, hz: float = DEFAULT_SCREEN_HZ) -> Array:
	if authored <= 0.0:
		return ["", false]
	var fps := shown_fps(authored, speed)
	var made := "Painted for %s fps" % _num(authored)
	if is_equal_approx(speed, 1.0):
		return ["%s. Plays as made." % made, false]
	var timing := "%s fps, %.2f s" % [_num(fps), seconds / speed]
	if fps < CHOPPY_FPS:
		return ["%s; %s: each frame holds %d ms, so the motion steps." % [made, timing, roundi(1000.0 / fps)], true]
	if fps > hz + 0.5:
		return ["%s; %s: faster than a %s Hz screen, so some frames are skipped." % [made, timing, _num(hz)], true]
	if speed < 1.0:
		return ["%s; %s, each frame held longer." % [made, timing], false]
	return ["%s; %s." % [made, timing], false]


## "1.5×" for a speed.
static func label(speed: float) -> String:
	return "%s×" % _num(snappedf(speed, 0.01))


static func _num(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else ("%.2f" % value).rstrip("0").rstrip(".")
