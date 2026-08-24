class_name SpawnerComponent
extends Node
## Periodically emits copies of a scene around an anchor (nests emitting skulls),
## optionally also a burst when the owner dies. Time is driven through advance().

signal spawned(node: Node3D)

@export var scene: PackedScene
@export_range(0.1, 60.0, 0.1) var interval: float = 8.0
@export_range(1, 32) var burst: int = 3
@export_range(0.0, 60.0, 0.1) var initial_delay: float = 3.0
## Cap on this spawner's living children (0 = unlimited).
@export_range(0, 256) var max_alive: int = 12
## Total bursts this spawner may emit (0 = unlimited).
@export_range(0, 256) var max_emissions: int = 0
## Extra copies emitted when the owner's HealthComponent dies.
@export_range(0, 32) var death_burst: int = 0
@export_range(0.0, 10.0, 0.1) var spawn_radius: float = 1.5
## Place children at the arena floor (plus their own `stats.min_height`) instead of the
## anchor's height; for elevated anchors such as hovering nests. The floor comes from the
## anchor's `arena.info()` when it has one, otherwise y = 0.
@export var spawn_on_floor: bool = false
@export var enabled: bool = true
## Run on the engine clock instead of waiting for advance() calls.
@export var autonomous: bool = false
## Node the copies are added to; when null the anchor's parent is used.
@export var spawn_root: Node
## Position source; when null the parent is used.
@export var anchor: Node3D
@export var health: HealthComponent
@export var rng_seed: int = 0
## Properties copied from the anchor onto each child when both declare them.
@export var inherited_properties: Array[StringName] = [&"target", &"arena"]
## Played at the spawn origin whenever a burst actually emits (no-op when null).
@export var emit_cue: AudioCue

var rng := RandomNumberGenerator.new()
var emissions: int = 0
## Optional veto from a director: Callable() -> bool, true when spawning is allowed.
var can_spawn: Callable = Callable()

var _elapsed: float = 0.0
var _next_time: float = 0.0
var _children: Array[Node] = []


func _ready() -> void:
	if rng_seed != 0:
		rng.seed = rng_seed
	_next_time = initial_delay
	if health == null:
		health = _find_sibling_health()
	if health != null and death_burst > 0:
		health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if autonomous:
		advance(delta)


func alive_count() -> int:
	var alive: Array[Node] = []
	for node in _children:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			alive.append(node)
	_children = alive
	return _children.size()


func advance(delta: float) -> int:
	if not enabled or delta <= 0.0:
		return 0
	_elapsed += delta
	var total := 0
	while _elapsed >= _next_time and _emissions_left():
		_next_time += interval
		total += spawn_burst(burst).size()
	return total


func spawn_burst(amount: int) -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	if scene == null or amount <= 0 or (can_spawn.is_valid() and not can_spawn.call()):
		return nodes
	var origin := anchor if anchor != null else get_parent() as Node3D
	var root := spawn_root if spawn_root != null else (origin.get_parent() if origin != null else null)
	if root == null:
		return nodes
	for i in amount:
		if max_alive > 0 and alive_count() >= max_alive:
			break
		var node := scene.instantiate() as Node3D
		if node == null:
			continue
		var angle := rng.randf_range(0.0, TAU)
		var world_position := origin.global_position + Vector3(cos(angle), 0.0, sin(angle)) * spawn_radius
		if spawn_on_floor:
			world_position.y = _floor_y(origin) + _min_height(node)
		node.position = root.to_local(world_position) if root is Node3D else world_position
		_inherit(origin, node)
		root.add_child.call_deferred(node)
		_children.append(node)
		nodes.append(node)
		spawned.emit(node)
	if not nodes.is_empty():
		emissions += 1
		AudioManager.play(emit_cue, origin.global_position)
	return nodes


func _emissions_left() -> bool:
	return max_emissions <= 0 or emissions < max_emissions


func _inherit(from: Node, to: Node) -> void:
	if from == null:
		return
	for property in inherited_properties:
		if property in from and property in to:
			to.set(property, from.get(property))


func _floor_y(origin: Node) -> float:
	if origin == null or not ("arena" in origin):
		return 0.0
	var arena: Variant = origin.get("arena")
	if arena is Node and is_instance_valid(arena) and arena.has_method("info"):
		var info: Variant = arena.call("info")
		if info is ArenaInfo:
			return info.floor_y
	return 0.0


func _min_height(node: Node) -> float:
	if "stats" in node:
		var stats: Variant = node.get("stats")
		if stats is EnemyStats:
			return stats.min_height
	return 0.0


func _on_died(_hit: HitInfo) -> void:
	spawn_burst(death_burst)


func _find_sibling_health() -> HealthComponent:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is HealthComponent:
			return child
	return null
