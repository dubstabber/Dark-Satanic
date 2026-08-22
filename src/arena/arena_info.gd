class_name ArenaInfo
extends RefCounted
## Read-only snapshot of the arena handed to spawners, enemies and patterns.

var center: Vector3 = Vector3.ZERO
var radius: float = 30.0
var floor_y: float = 0.0
## Where the player currently is (Vector3.ZERO when unknown).
var target_position: Vector3 = Vector3.ZERO


func _init(p_center: Vector3 = Vector3.ZERO, p_radius: float = 30.0, p_floor_y: float = 0.0, p_target: Vector3 = Vector3.ZERO) -> void:
	center = p_center
	radius = p_radius
	floor_y = p_floor_y
	target_position = p_target


## Clamps a horizontal position to the platform (keeps y unchanged).
func clamp_to_platform(position: Vector3, margin: float = 0.0) -> Vector3:
	var flat := Vector3(position.x - center.x, 0.0, position.z - center.z)
	var limit := maxf(radius - margin, 0.0)
	if flat.length() > limit:
		flat = flat.normalized() * limit
	return Vector3(center.x + flat.x, position.y, center.z + flat.z)


func is_on_platform(position: Vector3) -> bool:
	return Vector2(position.x - center.x, position.z - center.z).length() <= radius
