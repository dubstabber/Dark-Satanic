@abstract
class_name SpawnPattern
extends Resource
## Where a SpawnEvent places its enemies. Implementations must return positions
## that lie on the platform (use ArenaInfo.clamp_to_platform).

@abstract func positions(count: int, arena: ArenaInfo, rng: RandomNumberGenerator) -> Array[Vector3]


## Shared helper: a point on the platform at `fraction` of the radius, `angle` radians around the centre.
static func on_circle(arena: ArenaInfo, fraction: float, angle: float, height: float) -> Vector3:
	var r := arena.radius * clampf(fraction, 0.0, 1.0)
	var point := arena.center + Vector3(cos(angle) * r, 0.0, sin(angle) * r)
	point.y = arena.floor_y + height
	return arena.clamp_to_platform(point)
