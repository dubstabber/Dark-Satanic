class_name PointPattern
extends SpawnPattern
## Fixed point (relative to the arena centre) with optional horizontal jitter.

@export var point: Vector3 = Vector3.ZERO
@export_range(0.0, 30.0, 0.1) var jitter: float = 0.0
## Height above the floor; when < 0 the point's own y is used.
@export_range(-1.0, 20.0, 0.1) var height: float = -1.0


func positions(count: int, arena: ArenaInfo, rng: RandomNumberGenerator) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for i in maxi(count, 0):
		var p := arena.center + point
		if height >= 0.0:
			p.y = arena.floor_y + height
		if jitter > 0.0:
			p.x += rng.randf_range(-jitter, jitter)
			p.z += rng.randf_range(-jitter, jitter)
		result.append(arena.clamp_to_platform(p))
	return result
