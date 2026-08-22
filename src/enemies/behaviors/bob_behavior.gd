class_name BobBehavior
extends EnemyBehavior
## Sinusoidal vertical wobble. Returns the vertical velocity of a sine of the given
## amplitude/frequency so the body oscillates around its resting height.

@export_range(0.0, 10.0, 0.01) var amplitude: float = 0.25
@export_range(0.0, 10.0, 0.01) var frequency: float = 1.5

var phase: float = 0.0
var _phase_picked: bool = false


func steer(ctx: EnemyContext, _delta: float) -> Vector3:
	if not _phase_picked:
		phase = ctx.rng.randf_range(0.0, TAU)
		_phase_picked = true
	var omega := TAU * frequency
	return Vector3(0.0, amplitude * omega * cos(omega * ctx.elapsed + phase), 0.0)
