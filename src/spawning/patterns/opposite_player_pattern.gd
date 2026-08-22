class_name OppositePlayerPattern
extends SpawnPattern
## Positions on the far side of the arena from the target (player), spread
## evenly across an arc of `spread_deg` centred on the opposite direction.

@export_range(0.0, 1.0, 0.01) var radius_fraction: float = 0.9
@export_range(0.0, 360.0, 1.0) var spread_deg: float = 40.0
@export_range(0.0, 20.0, 0.1) var height: float = 1.5


func positions(count: int, arena: ArenaInfo, rng: RandomNumberGenerator) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if count <= 0:
		return result
	var to_target := Vector2(arena.target_position.x - arena.center.x, arena.target_position.z - arena.center.z)
	var base: float = atan2(-to_target.y, -to_target.x) if to_target.length_squared() > 0.0001 else rng.randf_range(0.0, TAU)
	var spread := deg_to_rad(spread_deg)
	for i in count:
		var t: float = (float(i) + 0.5) / float(count) - 0.5 if count > 1 else 0.0
		result.append(SpawnPattern.on_circle(arena, radius_fraction, base + t * spread, height))
	return result
