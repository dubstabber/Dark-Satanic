class_name SeekBehavior
extends EnemyBehavior
## Chases the target. The heading is turned at a limited rate so slow turners overshoot.

## Degrees per second; 0 = use stats.turn_speed_deg.
@export_range(0.0, 3600.0, 1.0) var turn_speed_deg: float = 0.0
## 0 = use stats.move_speed.
@export_range(0.0, 100.0, 0.1) var speed: float = 0.0
## Match the target's height as well (otherwise only the horizontal plane).
@export var vertical: bool = false

var heading: Vector3 = Vector3.ZERO


func steer(ctx: EnemyContext, delta: float) -> Vector3:
	var to_target := ctx.to_target()
	var rate: float = turn_speed_deg if turn_speed_deg > 0.0 else (ctx.stats.turn_speed_deg if ctx.stats != null else 540.0)
	var max_speed: float = speed if speed > 0.0 else (ctx.stats.move_speed if ctx.stats != null else 5.0)
	heading = EnemyBehavior.turn_toward(heading, to_target, rate, delta)
	if heading.length_squared() < 0.000001:
		return Vector3.ZERO
	var velocity := heading * max_speed
	if vertical:
		velocity.y = clampf(to_target.y, -max_speed, max_speed)
	return velocity
