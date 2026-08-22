class_name HoverDriftBehavior
extends EnemyBehavior
## Nest movement: RISE from below the floor up to `hover_height` (exclusive), then DRIFT
## slowly around the arena centre on the circle the enemy spawned on.

enum Phase { RISE, DRIFT }

@export_range(0.0, 20.0, 0.1) var hover_height: float = 3.5
## Depth below the floor the rise starts from.
@export_range(0.0, 20.0, 0.1) var rise_depth: float = 4.0
@export_range(0.05, 20.0, 0.05) var rise_duration: float = 2.0
@export_range(0.0, 20.0, 0.05) var drift_speed: float = 1.2
## Strength of the pull back onto the drift circle (m/s per metre of error).
@export_range(0.0, 10.0, 0.1) var radius_correction: float = 1.0
## Strength of the pull back to `hover_height` while drifting (m/s per metre of error).
@export_range(0.0, 20.0, 0.1) var altitude_gain: float = 2.0

var phase: Phase = Phase.RISE
var drift_direction: float = 0.0
var _radius: float = -1.0


func is_exclusive() -> bool:
	return enabled and phase == Phase.RISE


func ignores_floor() -> bool:
	return phase == Phase.RISE


func steer(ctx: EnemyContext, delta: float) -> Vector3:
	var floor_y := ctx.floor_y()
	var center := ctx.center()
	if _radius < 0.0:
		var flat := ctx.spawn_position - center
		flat.y = 0.0
		_radius = flat.length()
		drift_direction = 1.0 if ctx.rng.randf() < 0.5 else -1.0
		# The rise starts buried: place the body below the floor once.
		if ctx.body != null and phase == Phase.RISE:
			var buried := ctx.body.global_position
			buried.y = floor_y - rise_depth
			ctx.body.global_position = buried
	if phase == Phase.RISE:
		var goal_y := floor_y + hover_height
		var y := ctx.body_position().y
		if ctx.elapsed >= rise_duration or y >= goal_y - 0.01:
			phase = Phase.DRIFT
			phase_changed.emit(&"DRIFT")
			return Vector3(0.0, (goal_y - y) / maxf(delta, 0.0001), 0.0)
		var rise_speed := (hover_height + rise_depth) / rise_duration
		return Vector3(0.0, minf(rise_speed, (goal_y - y) / maxf(delta, 0.0001)), 0.0)
	var offset := ctx.body_position() - center
	offset.y = 0.0
	var velocity := Vector3.ZERO
	if offset.length_squared() > 0.0001:
		var tangent := Vector3(-offset.z, 0.0, offset.x).normalized() * drift_direction
		velocity = tangent * drift_speed
		velocity += offset.normalized() * (_radius - offset.length()) * radius_correction
	velocity.y = (floor_y + hover_height - ctx.body_position().y) * altitude_gain
	return velocity
