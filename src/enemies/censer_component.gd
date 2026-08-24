class_name CenserComponent
extends Node
## Drops burning ground around its owner on a cycle: a SpawnerComponent whose children
## are hazards on the floor rather than enemies.
##
## The point of the Thurible is that it attacks the arena rather than the player, so the
## drops are placed near the *player*, clamped to the platform, and left there. Time is
## driven through advance(delta).

signal dropped(cinders: Array[Node3D])

@export var hazard_scene: PackedScene
## Node the cinders are parented to. Never the enemy container — a hazard is not an enemy,
## and Game announces everything that enters that container as an arrival.
@export var hazard_root: Node
## What it censes at; inherited from the owning enemy when unset.
@export var target: Node3D
## Position source for the fallback drop point; the parent is used when unset.
@export var anchor: Node3D
## Anything with `func info() -> ArenaInfo`, so drops stay on the platform.
@export var arena: Node

@export_group("Cycle")
@export_range(0.5, 60.0, 0.1) var interval: float = 4.0
@export_range(0.0, 60.0, 0.1) var initial_delay: float = 2.0
@export_range(1, 12) var burst: int = 2
## Cap on this censer's living cinders (0 = unlimited).
@export_range(0, 64) var max_alive: int = 8
@export var enabled: bool = true
## Run on the engine clock instead of waiting for advance() calls.
@export var autonomous: bool = false

@export_group("Placement")
## Drops land inside this radius of the target.
@export_range(0.5, 30.0, 0.1) var drop_radius: float = 5.0
## Metres above the floor the cinder sits, so its decal does not z-fight the ground.
@export_range(0.0, 1.0, 0.01) var floor_offset: float = 0.05
## Keeps drops this far inside the platform rim.
@export_range(0.0, 10.0, 0.1) var platform_margin: float = 1.0
@export var rng_seed: int = 0
@export var emit_cue: AudioCue

var rng := RandomNumberGenerator.new()
var drops: int = 0

var _elapsed: float = 0.0
var _next_at: float = 0.0
var _children: Array[Node] = []


func _ready() -> void:
	if rng_seed != 0:
		rng.seed = rng_seed
	if anchor == null:
		anchor = get_parent() as Node3D
	if target == null:
		target = _inherited(&"target") as Node3D
	if arena == null:
		arena = _inherited(&"arena") as Node
	_next_at = initial_delay


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


func advance(delta: float) -> void:
	if not enabled or delta <= 0.0:
		return
	_elapsed += delta
	while _elapsed >= _next_at:
		_next_at += interval
		drop(burst)


## Places up to `amount` cinders around the target. Returns what actually landed.
func drop(amount: int) -> Array[Node3D]:
	var placed: Array[Node3D] = []
	var root := hazard_root if hazard_root != null else _fallback_root()
	if hazard_scene == null or root == null or amount <= 0:
		return placed
	var info := _arena_info()
	var center := target.global_position if target != null and is_instance_valid(target) \
		else (anchor.global_position if anchor != null else Vector3.ZERO)
	for i in amount:
		if max_alive > 0 and alive_count() >= max_alive:
			break
		var cinder := hazard_scene.instantiate() as Node3D
		if cinder == null:
			continue
		cinder.position = root.to_local(drop_point(center, info)) if root is Node3D and root.is_inside_tree() \
			else drop_point(center, info)
		root.add_child(cinder)
		_children.append(cinder)
		placed.append(cinder)
	if placed.is_empty():
		return placed
	drops += 1
	AudioManager.play(emit_cue, center)
	dropped.emit(placed)
	return placed


## A point on the floor within `drop_radius` of `center`, kept on the platform.
func drop_point(center: Vector3, info: ArenaInfo) -> Vector3:
	var angle := rng.randf_range(0.0, TAU)
	var distance := sqrt(rng.randf()) * drop_radius  # uniform over the disc, not the radius
	var point := center + Vector3(cos(angle), 0.0, sin(angle)) * distance
	point.y = info.floor_y + floor_offset
	point = info.clamp_to_platform(point, platform_margin)
	point.y = info.floor_y + floor_offset
	return point


func _arena_info() -> ArenaInfo:
	if arena != null and is_instance_valid(arena) and arena.has_method("info"):
		var info: Variant = arena.call("info")
		if info is ArenaInfo:
			return info
	return ArenaInfo.new()


func _fallback_root() -> Node:
	return anchor.get_parent() if anchor != null else null


func _inherited(property: StringName) -> Variant:
	var parent := get_parent()
	if parent != null and property in parent:
		return parent.get(property)
	return null
