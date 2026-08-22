class_name OrbitDiveBehavior
extends EnemyBehavior
## Vesper movement: ORBIT the target at a distance, then DIVE at where the target will be,
## RETREAT to a safe radius, and orbit again. DIVE and RETREAT are exclusive.

enum Phase { ORBIT, DIVE, RETREAT }

@export_range(0.0, 50.0, 0.5) var orbit_radius: float = 12.0
@export_range(0.0, 100.0, 0.5) var orbit_speed: float = 11.0
@export_range(0.0, 60.0, 0.1) var orbit_time_min: float = 3.0
@export_range(0.0, 60.0, 0.1) var orbit_time_max: float = 6.0
## Height above the floor while orbiting/retreating.
@export_range(0.0, 30.0, 0.1) var altitude: float = 4.0
@export_range(0.0, 100.0, 0.5) var dive_speed: float = 16.0
## Seconds of target motion to lead the dive by.
@export_range(0.0, 3.0, 0.05) var dive_lead: float = 0.35
## Distance to the aim point (or the live target) that ends the dive.
@export_range(0.1, 10.0, 0.1) var dive_hit_distance: float = 1.0
## Safety cap so a dive at an unreachable point still ends.
@export_range(0.1, 30.0, 0.1) var dive_max_time: float = 3.0
@export_range(0.0, 50.0, 0.5) var retreat_radius: float = 15.0
@export_range(0.0, 30.0, 0.1) var retreat_time: float = 2.0
@export_range(0.0, 10.0, 0.1) var radius_correction: float = 1.5
## Strength of the pull back to `altitude` while orbiting/retreating (m/s per metre of error).
@export_range(0.0, 20.0, 0.1) var altitude_gain: float = 2.0

var phase: Phase = Phase.ORBIT
var phase_time: float = 0.0
var orbit_direction: float = 1.0
var aim_point: Vector3 = Vector3.ZERO

var _orbit_duration: float = -1.0
var _last_target_position: Vector3 = Vector3.ZERO
var _has_last_target: bool = false
var _target_velocity: Vector3 = Vector3.ZERO


func is_exclusive() -> bool:
	return enabled and phase != Phase.ORBIT


func steer(ctx: EnemyContext, delta: float) -> Vector3:
	_update_target_velocity(ctx, delta)
	phase_time += delta
	match phase:
		Phase.ORBIT:
			return _orbit(ctx)
		Phase.DIVE:
			return _dive(ctx)
		_:
			return _retreat(ctx)


func _orbit(ctx: EnemyContext) -> Vector3:
	if _orbit_duration < 0.0:
		_orbit_duration = ctx.rng.randf_range(orbit_time_min, orbit_time_max)
		orbit_direction = 1.0 if ctx.rng.randf() < 0.5 else -1.0
	if phase_time >= _orbit_duration:
		aim_point = ctx.target_position() + _target_velocity * dive_lead
		_enter(Phase.DIVE)
		return _dive(ctx)
	return _circle(ctx, orbit_radius, orbit_speed)


func _dive(ctx: EnemyContext) -> Vector3:
	var origin := ctx.body_position()
	var to_aim := aim_point - origin
	var close := to_aim.length() <= dive_hit_distance
	close = close or ctx.to_target().length() <= dive_hit_distance
	if close or phase_time >= dive_max_time:
		_enter(Phase.RETREAT)
		return _retreat(ctx)
	return to_aim.normalized() * dive_speed


func _retreat(ctx: EnemyContext) -> Vector3:
	if phase_time >= retreat_time:
		_orbit_duration = -1.0
		_enter(Phase.ORBIT)
		return _orbit(ctx)
	var origin := ctx.body_position()
	var away := origin - ctx.target_position()
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = Vector3.RIGHT
	var velocity := Vector3.ZERO
	if away.length() < retreat_radius:
		velocity = away.normalized() * dive_speed
	else:
		velocity = _circle(ctx, retreat_radius, orbit_speed)
	velocity.y = _lift(ctx, dive_speed)
	return velocity


## Tangential motion around the target at `radius`, pulled back onto the circle.
func _circle(ctx: EnemyContext, radius: float, speed: float) -> Vector3:
	var offset := ctx.body_position() - ctx.target_position()
	offset.y = 0.0
	if offset.length_squared() < 0.0001:
		offset = Vector3.RIGHT
	var tangent := Vector3(-offset.z, 0.0, offset.x).normalized() * orbit_direction
	var radial := offset.normalized() * (radius - offset.length()) * radius_correction
	var velocity := (tangent * speed + radial).limit_length(speed)
	velocity.y = _lift(ctx, speed)
	return velocity


func _lift(ctx: EnemyContext, cap: float) -> float:
	var goal_y := ctx.floor_y() + altitude
	return clampf((goal_y - ctx.body_position().y) * altitude_gain, -cap, cap)


func _update_target_velocity(ctx: EnemyContext, delta: float) -> void:
	var now := ctx.target_position()
	if _has_last_target and delta > 0.0:
		_target_velocity = (now - _last_target_position) / delta
	_last_target_position = now
	_has_last_target = true


func _enter(next: Phase) -> void:
	phase = next
	phase_time = 0.0
	phase_changed.emit(phase_name(next))


static func phase_name(value: Phase) -> StringName:
	match value:
		Phase.ORBIT:
			return &"ORBIT"
		Phase.DIVE:
			return &"DIVE"
		_:
			return &"RETREAT"
