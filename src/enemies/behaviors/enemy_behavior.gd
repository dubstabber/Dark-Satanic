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
