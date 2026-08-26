class_name SeparationBehavior
extends EnemyBehavior
## Pushes away from neighbouring enemies closer than `radius` (inverse-distance weighted).

@export_range(0.1, 20.0, 0.1) var radius: float = 1.2
## Push strength in m/s at zero distance.
@export_range(0.0, 100.0, 0.1) var strength: float = 6.0
## Push in 3D, so flyers slide over and under each other instead of only sideways.
@export var vertical: bool = false


func steer(ctx: EnemyContext, _delta: float) -> Vector3:
	var push := Vector3.ZERO
	var origin := ctx.body_position()
	for neighbor in ctx.neighbors():
		if not is_instance_valid(neighbor) or not neighbor.is_inside_tree():
			continue
		var away := origin - neighbor.global_position
		if not vertical:
			away.y = 0.0
		var distance := away.length()
		if distance >= radius:
			continue
		if distance < 0.0001:
			away = Vector3(ctx.rng.randf_range(-1.0, 1.0), 0.0, ctx.rng.randf_range(-1.0, 1.0))
			if away.length_squared() < 0.0001:
				away = Vector3.RIGHT
			distance = 0.0
		push += away.normalized() * (1.0 - distance / radius)
	return push * strength
