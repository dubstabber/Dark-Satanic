class_name GemSeekBehavior
extends EnemyBehavior
## Heads for the nearest gem; with nothing to eat it circles the arena centre at `idle_radius`.

@export_range(0.0, 50.0, 0.5) var idle_radius: float = 10.0
## 0 = use stats.move_speed.
@export_range(0.0, 100.0, 0.1) var speed: float = 0.0
@export_range(0.0, 10.0, 0.1) var radius_correction: float = 1.0

var current_gem: Node3D


func steer(ctx: EnemyContext, _delta: float) -> Vector3:
	var max_speed: float = speed if speed > 0.0 else (ctx.stats.move_speed if ctx.stats != null else 3.0)
	var origin := ctx.body_position()
	current_gem = _nearest_gem(ctx, origin)
	if current_gem != null:
		var to_gem := current_gem.global_position - origin
		to_gem.y = 0.0
		if to_gem.length_squared() < 0.0001:
			return Vector3.ZERO
		return to_gem.normalized() * max_speed
	var offset := origin - ctx.center()
	offset.y = 0.0
	if offset.length_squared() < 0.0001:
		return Vector3.RIGHT * max_speed
	var tangent := Vector3(-offset.z, 0.0, offset.x).normalized()
	var correction := offset.normalized() * (idle_radius - offset.length()) * radius_correction
	return (tangent * max_speed + correction).limit_length(max_speed)


func _nearest_gem(ctx: EnemyContext, origin: Vector3) -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for gem in ctx.gems():
		if not is_instance_valid(gem) or not gem.is_inside_tree() or gem.is_queued_for_deletion():
			continue
		var distance := origin.distance_squared_to(gem.global_position)
		if distance < best_distance:
			best_distance = distance
			best = gem
	return best
