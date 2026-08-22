class_name RingPattern
extends SpawnPattern
## Evenly spaced positions on a circle around the arena centre.

@export_range(0.0, 1.0, 0.01) var radius_fraction: float = 0.9
@export_range(0.0, 20.0, 0.1) var height: float = 1.5
## Rotation of the first position in degrees; -1 picks a random offset per call.
@export_range(-1.0, 360.0, 0.5) var angle_offset_deg: float = -1.0
## Random angular jitter (degrees) applied to every position.
@export_range(0.0, 180.0, 0.5) var jitter: float = 0.0


func positions(count: int, arena: ArenaInfo, rng: RandomNumberGenerator) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if count <= 0:
		return result
	var offset: float = deg_to_rad(angle_offset_deg) if angle_offset_deg >= 0.0 else rng.randf_range(0.0, TAU)
	var step := TAU / float(count)
	for i in count:
		var angle := offset + step * float(i)
		if jitter > 0.0:
			angle += deg_to_rad(rng.randf_range(-jitter, jitter))
		result.append(SpawnPattern.on_circle(arena, radius_fraction, angle, height))
	return result
