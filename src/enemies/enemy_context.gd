class_name EnemyContext
extends RefCounted
## Everything a behaviour may look at while steering. Rebuilt/refreshed by the enemy each tick
## so behaviours stay stateless with respect to the world.

var body: Node3D
var stats: EnemyStats
var target: Node3D
## Fresh from `arena.info()` every tick, or a default ArenaInfo when there is no arena.
var arena_info: ArenaInfo = ArenaInfo.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Callable() -> Array[Node3D]: other enemies to keep distance from.
var neighbors_provider: Callable = Callable()
## Callable() -> Array[Node3D]: gems lying around (anything with `consume`).
var gems_provider: Callable = Callable()
## Seconds since the enemy spawned.
var elapsed: float = 0.0
var spawn_position: Vector3 = Vector3.ZERO


func target_position() -> Vector3:
	if target != null and is_instance_valid(target) and target.is_inside_tree():
		return target.global_position
	return arena_info.target_position if arena_info != null else Vector3.ZERO


## Vector from the body to the target (Vector3.ZERO when either is missing).
func to_target() -> Vector3:
	if body == null:
		return Vector3.ZERO
	return target_position() - body.global_position


func body_position() -> Vector3:
	return body.global_position if body != null else Vector3.ZERO


func neighbors() -> Array[Node3D]:
	var result: Array[Node3D] = []
	if neighbors_provider.is_valid():
		var raw: Variant = neighbors_provider.call()
		if raw is Array:
			for node in raw:
				if is_instance_valid(node) and node is Node3D and node != body:
					result.append(node)
	elif body != null and body.get_parent() != null:
		for sibling in body.get_parent().get_children():
			if sibling != body and sibling is Enemy:
				result.append(sibling)
	return result


func gems() -> Array[Node3D]:
	var result: Array[Node3D] = []
	if gems_provider.is_valid():
		var raw: Variant = gems_provider.call()
		if raw is Array:
			for node in raw:
				if is_instance_valid(node) and node is Node3D:
					result.append(node)
	elif body != null and body.get_parent() != null:
		for sibling in body.get_parent().get_children():
			if sibling is Node3D and sibling.has_method("consume"):
				result.append(sibling)
	return result


func floor_y() -> float:
	return arena_info.floor_y if arena_info != null else 0.0


func center() -> Vector3:
	return arena_info.center if arena_info != null else Vector3.ZERO
