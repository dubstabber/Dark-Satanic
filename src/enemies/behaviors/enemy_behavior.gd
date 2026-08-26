@abstract
class_name EnemyBehavior
extends Node
## One steering rule. `steer` returns a desired-velocity contribution (m/s) that EnemyMover
## blends by `weight`; an exclusive behaviour silences the others while it is exclusive.

signal phase_changed(phase: StringName)

@export_range(0.0, 10.0, 0.05) var weight: float = 1.0
@export var enabled: bool = true


@abstract func steer(ctx: EnemyContext, delta: float) -> Vector3


func is_exclusive() -> bool:
	return false


## True while the body is allowed below floor_y + min_height (e.g. a nest rising out of the ground).
func ignores_floor() -> bool:
	return false


## Turns a flight heading toward `desired` in 3D: the compass bearing swings at
## `yaw_deg_per_s`, while the climb angle chases separately at `pitch_deg_per_s` and never
## passes `max_pitch_deg`. Keeping the two apart is what lets a body bank slowly — a wide,
## dodgeable turn circle — and still climb, dive and level off briskly, instead of
## recovering every overshoot by looping over the top and ending up far above the arena.
static func turn_toward_flight(
	heading: Vector3, desired: Vector3, yaw_deg_per_s: float, pitch_deg_per_s: float,
	max_pitch_deg: float, delta: float
) -> Vector3:
	if desired.length_squared() < 0.000001:
		return heading
	var bearing := turn_toward(heading, desired, yaw_deg_per_s, delta)
	bearing = Vector3(bearing.x, 0.0, bearing.z)
	if bearing.length_squared() < 0.000001:
		# Straight up or down with nowhere to point: hold the heading until it has a bearing.
		bearing = Vector3(heading.x, 0.0, heading.z)
		if bearing.length_squared() < 0.000001:
			return heading
	bearing = bearing.normalized()
	var limit := deg_to_rad(clampf(max_pitch_deg, 0.0, 89.0))
	var goal_pitch := clampf(asin(clampf(desired.normalized().y, -1.0, 1.0)), -limit, limit)
	var pitch := goal_pitch
	if heading.length_squared() > 0.000001:
		pitch = move_toward(asin(clampf(heading.normalized().y, -1.0, 1.0)), goal_pitch, deg_to_rad(pitch_deg_per_s) * delta)
	return (bearing * cos(pitch) + Vector3.UP * sin(pitch)).normalized()


## Rotates `heading` toward `desired` by at most `max_deg_per_s * delta` (horizontal plane).
static func turn_toward(heading: Vector3, desired: Vector3, max_deg_per_s: float, delta: float) -> Vector3:
	var flat_desired := Vector3(desired.x, 0.0, desired.z)
	if flat_desired.length_squared() < 0.000001:
		return heading
	flat_desired = flat_desired.normalized()
	var flat_heading := Vector3(heading.x, 0.0, heading.z)
	if flat_heading.length_squared() < 0.000001:
		return flat_desired
	flat_heading = flat_heading.normalized()
	var max_step := deg_to_rad(max_deg_per_s) * delta
	var angle := flat_heading.signed_angle_to(flat_desired, Vector3.UP)
	var step := clampf(angle, -max_step, max_step)
	return flat_heading.rotated(Vector3.UP, step).normalized()
