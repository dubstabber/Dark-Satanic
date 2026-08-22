class_name GemDropComponent
extends Node
## Spawns gem pickups next to the owner when its HealthComponent dies.

signal gems_dropped(gems: Array[Node3D])

@export var gem_scene: PackedScene
@export_range(0, 64) var count: int = 1
@export_range(0.0, 5.0, 0.1) var scatter_radius: float = 0.5
## Health to watch; when null the first HealthComponent sibling is used.
@export var health: HealthComponent
## Node the gems are added to; when null, the anchor's parent is used.
@export var spawn_root: Node
## World position source; when null the parent is used.
@export var anchor: Node3D
## Handed to each gem that declares `arena` so it stays on the platform; optional.
@export var arena: Node
@export var rng_seed: int = 0

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	if rng_seed != 0:
		rng.seed = rng_seed
	if health == null:
		health = _find_sibling_health()
	if health != null:
		health.died.connect(_on_died)


func drop() -> Array[Node3D]:
	var gems: Array[Node3D] = []
	if gem_scene == null or count <= 0:
		return gems
	var origin := _anchor_node()
	var root := spawn_root if spawn_root != null else (origin.get_parent() if origin != null else null)
	if root == null:
		return gems
	var center := origin.global_position if origin != null else Vector3.ZERO
	for i in count:
		var gem := gem_scene.instantiate() as Node3D
		if gem == null:
			continue
		var offset := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * scatter_radius
		var world_position := center + offset
		gem.position = root.to_local(world_position) if root is Node3D else world_position
		if arena != null and "arena" in gem:
			gem.set("arena", arena)
		root.add_child.call_deferred(gem)
		if gem.has_method("scatter"):
			gem.call("scatter", rng)
		gems.append(gem)
	gems_dropped.emit(gems)
	return gems


func _on_died(_hit: HitInfo) -> void:
	drop()


func _anchor_node() -> Node3D:
	if anchor != null:
		return anchor
	return get_parent() as Node3D


func _find_sibling_health() -> HealthComponent:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is HealthComponent:
			return child
	return null
