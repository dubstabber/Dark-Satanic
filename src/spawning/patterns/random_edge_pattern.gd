class_name RandomEdgePattern
extends SpawnPattern
## Random positions in an annulus near the edge of the platform.

@export_range(0.0, 1.0, 0.01) var min_radius_fraction: float = 0.6
@export_range(0.0, 1.0, 0.01) var max_radius_fraction: float = 0.95
@export_range(0.0, 20.0, 0.1) var height_min: float = 1.0
@export_range(0.0, 20.0, 0.1) var height_max: float = 3.0


func positions(count: int, arena: ArenaInfo, rng: RandomNumberGenerator) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var low := minf(min_radius_fraction, max_radius_fraction)
	var high := maxf(min_radius_fraction, max_radius_fraction)
	for i in maxi(count, 0):
		var fraction := rng.randf_range(low, high)
		var angle := rng.randf_range(0.0, TAU)
		var height := rng.randf_range(minf(height_min, height_max), maxf(height_min, height_max))
		result.append(SpawnPattern.on_circle(arena, fraction, angle, height))
	return result
