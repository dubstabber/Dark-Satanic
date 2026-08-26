class_name HoverBehavior
extends EnemyBehavior
## Holds a flight altitude: the vertical velocity that closes the gap to `height` above the
## arena floor, capped at `max_climb`. Paired with a horizontal behaviour (Seek) it makes a
## flyer that never settles on the ground and glides back down when something releases it
## high up. HoverDriftBehavior is the nest's own rise-then-orbit version, which also steers
## horizontally; this one only ever moves on Y.

## Metres above the arena floor the body flies at.
@export_range(0.0, 30.0, 0.05) var height: float = 1.5
## Vertical speed per metre of altitude error (1/s).
@export_range(0.0, 20.0, 0.1) var gain: float = 2.0
## Cap on that speed, so a long drop reads as a glide instead of a fall.
@export_range(0.0, 50.0, 0.1) var max_climb: float = 6.0


func steer(ctx: EnemyContext, _delta: float) -> Vector3:
	var error := ctx.floor_y() + height - ctx.body_position().y
	return Vector3(0.0, clampf(error * gain, -max_climb, max_climb), 0.0)
