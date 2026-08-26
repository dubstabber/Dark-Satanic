class_name SeekBehavior
extends EnemyBehavior
## Chases the target. The heading is turned at a limited rate so slow turners overshoot.

## Degrees per second; 0 = use stats.turn_speed_deg.
@export_range(0.0, 3600.0, 1.0) var turn_speed_deg: float = 0.0
## 0 = use stats.move_speed.
@export_range(0.0, 100.0, 0.1) var speed: float = 0.0
## Match the target's height as well (otherwise only the horizontal plane).
@export var vertical: bool = false
## Free flight: the heading climbs and dives as well as turning, so the body goes wherever
## it is pointed instead of along a plane. Supersedes `vertical`.
@export var fly: bool = false
## Aim this far above the target's origin — its feet — so a diving flyer goes for the chest.
@export_range(0.0, 10.0, 0.05) var aim_height: float = 0.0
## Flight only. How fast the climb angle chases the target's; 0 = the turn rate. Pitching
## faster than it banks is what gives a wide, dodgeable turn circle a lively vertical arc.
@export_range(0.0, 3600.0, 1.0) var pitch_speed_deg: float = 0.0
## Flight only: steepest climb or dive the heading may hold.
@export_range(1.0, 89.0, 1.0) var max_pitch_deg: float = 45.0

var heading: Vector3 = Vector3.ZERO


func steer(ctx: EnemyContext, delta: float) -> Vector3:
	var to_target := ctx.to_target() + Vector3.UP * aim_height
	var rate: float = turn_speed_deg if turn_speed_deg > 0.0 else (ctx.stats.turn_speed_deg if ctx.stats != null else 540.0)
	var max_speed: float = speed if speed > 0.0 else (ctx.stats.move_speed if ctx.stats != null else 5.0)
	if fly:
		var pitch_rate: float = pitch_speed_deg if pitch_speed_deg > 0.0 else rate
		heading = EnemyBehavior.turn_toward_flight(heading, to_target, rate, pitch_rate, max_pitch_deg, delta)
	else:
		heading = EnemyBehavior.turn_toward(heading, to_target, rate, delta)
	if heading.length_squared() < 0.000001:
		return Vector3.ZERO
	var velocity := heading * max_speed
	if vertical and not fly:
		velocity.y = clampf(to_target.y, -max_speed, max_speed)
	return velocity
