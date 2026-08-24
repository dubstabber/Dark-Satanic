class_name MovementSolver
## Pure Quake-style movement math. Stateless: takes a velocity, returns the next one.
## The caller (MovementController) feeds the result to CharacterBody3D.move_and_slide().

const EPSILON := 0.000001


## Quake acceleration: only adds speed along `wish_dir` while the velocity component
## along it is below `wish_speed`. Safe for a zero-length `wish_dir`.
static func accelerate(
	vel: Vector3, wish_dir: Vector3, wish_speed: float, accel: float, dt: float
) -> Vector3:
	if wish_dir.length_squared() < EPSILON or wish_speed <= 0.0:
		return vel
	var add := wish_speed - vel.dot(wish_dir)
	if add <= 0.0:
		return vel
	return vel + wish_dir * minf(accel * wish_speed * dt, add)


## Ground friction on the horizontal plane only; y is untouched.
static func apply_friction(vel: Vector3, friction: float, stop_speed: float, dt: float) -> Vector3:
	var horizontal := Vector3(vel.x, 0.0, vel.z)
	var speed := horizontal.length()
	if speed < EPSILON:
		return Vector3(0.0, vel.y, 0.0)
	var control := maxf(speed, stop_speed)
	var drop := control * friction * dt
	var scale := maxf(speed - drop, 0.0) / speed
	return Vector3(vel.x * scale, vel.y, vel.z * scale)


## True when this tick starts a jump.
static func wants_jump(
	on_floor: bool, jump_pressed: bool, jump_held: bool, stats: PlayerMovementStats
) -> bool:
	return on_floor and (jump_pressed or (jump_held and stats.auto_bhop))


## Sets the vertical jump velocity and applies the bunny-hop horizontal boost. The boost
## never pushes past `max_bhop_speed` and never slows a player already faster than that.
static func jump(vel: Vector3, stats: PlayerMovementStats) -> Vector3:
	var horizontal := Vector3(vel.x, 0.0, vel.z)
	var speed := horizontal.length()
	if speed > EPSILON:
		var target := minf(speed * stats.jump_horizontal_boost, maxf(stats.max_bhop_speed, speed))
		horizontal *= target / speed
	return Vector3(horizontal.x, stats.jump_velocity, horizontal.z)


## Air movement: capped strafe acceleration plus weak full-speed air control.
static func air_accelerate(
	vel: Vector3, wish_dir: Vector3, stats: PlayerMovementStats, dt: float
) -> Vector3:
	var result := accelerate(
		vel, wish_dir, minf(stats.walk_speed, stats.air_speed_cap), stats.air_accel, dt
	)
	return accelerate(result, wish_dir, stats.walk_speed, stats.air_control_accel, dt)


## One physics tick, deciding the jump from the raw input edges.
## `wish_dir` is world-space; its y is ignored and it is normalised.
static func step(
	vel: Vector3,
	wish_dir: Vector3,
	on_floor: bool,
	jump_pressed: bool,
	jump_held: bool,
	stats: PlayerMovementStats,
	dt: float
) -> Vector3:
	var jumping := wants_jump(on_floor, jump_pressed, jump_held, stats)
	return step_with_jump(vel, wish_dir, on_floor, jumping, stats, dt)


## One physics tick with the jump decision already made — the form MovementController
## uses, because coyote time and jump buffering can start a jump on a tick where
## `on_floor` is false and must not also switch the tick to ground friction.
## Gravity is always applied; move_and_slide() cancels it against the floor.
static func step_with_jump(
	vel: Vector3, wish_dir: Vector3, on_floor: bool, jumping: bool, stats: PlayerMovementStats, dt: float
) -> Vector3:
	var dir := flatten(wish_dir)
	var result := vel
	if jumping:
		# No friction on the jump tick so bunny hopping keeps its speed.
		result = jump(result, stats)
		result = air_accelerate(result, dir, stats, dt)
	elif on_floor:
		result = apply_friction(result, stats.friction, stats.stop_speed, dt)
		result = accelerate(result, dir, stats.walk_speed, stats.ground_accel, dt)
	else:
		result = air_accelerate(result, dir, stats, dt)
	result.y -= stats.gravity * dt
	return result


## Height above the launch point reached by a full jump (continuous-time ideal).
static func jump_apex_height(stats: PlayerMovementStats) -> float:
	if stats.gravity <= 0.0:
		return INF
	return stats.jump_velocity * stats.jump_velocity / (2.0 * stats.gravity)


## Drops y and normalises; zero in gives zero out (never NaN).
static func flatten(dir: Vector3) -> Vector3:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < EPSILON:
		return Vector3.ZERO
	return flat.normalized()


static func horizontal_speed(vel: Vector3) -> float:
	return Vector2(vel.x, vel.z).length()
