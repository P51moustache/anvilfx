extends RefCounted
## The time a player advances each frame. Scaled by default, like every node (Engine.time_scale slows it, so a
## hit-stop freezes it too). Unscaled measures real time instead, so an effect keeps playing through a hit-stop or a
## slow-motion moment.

const MAX_STEP = 0.1   # s; a longer gap (a pause, a hitch) advances one tenth of a second, never jumps ahead

var unscaled: bool = false:
	set(value):
		unscaled = value
		_last_usec = 0

var _last_usec: int = 0


## Seconds to advance for this frame, given the `delta` the node's _process received.
func step(delta: float) -> float:
	if not unscaled:
		return delta
	var now := Time.get_ticks_usec()
	var real := delta if _last_usec == 0 else minf((now - _last_usec) / 1000000.0, MAX_STEP)
	_last_usec = now
	return real
