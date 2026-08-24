class_name DeathHandlerComponent
extends Node
## When the owner's HealthComponent dies: stop it colliding, spawn a VFX, play a cue,
## and free it after `free_delay` seconds counted through advance(delta).

signal handled

@export var health: HealthComponent
@export var death_vfx: PackedScene
@export var death_cue: AudioCue
@export_range(0.0, 5.0, 0.05) var free_delay: float = 0.0
## Node to disable and free; when null the parent is used.
@export var target: Node
## Where the death VFX is parented; when null the target's own parent is used. Game
## points this at VfxContainer, because a burst left in EnemyContainer would be
## counted as an enemy ("is this an enemy" means "does it live in there").
@export var vfx_root: Node
## Uniform scale applied to the death VFX. Enemy sets it from stats, so a 1 HP skull
## does not pop like a 12 HP tank.
@export_range(0.1, 6.0, 0.05) var vfx_scale: float = 1.0

var _free_target: Node
var _free_remaining: float = -1.0


func _ready() -> void:
	if health == null:
		health = _find_sibling_health()
	if health != null:
		health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	advance(delta)


## Counts down the free delay; frees the target when it reaches zero.
func advance(delta: float) -> void:
	if _free_remaining < 0.0 or delta <= 0.0:
		return
	_free_remaining -= delta
	if _free_remaining > 0.0:
		return
	_free_remaining = -1.0
	if _free_target != null and is_instance_valid(_free_target):
		_free_target.queue_free()
	_free_target = null


func is_pending_free() -> bool:
	return _free_remaining >= 0.0


func handle_death() -> void:
	var node := target if target != null else get_parent()
	if node == null:
		return
	_disable_collisions(node)
	var position: Vector3 = node.global_position if node is Node3D else Vector3.ZERO
	var root := vfx_root if vfx_root != null else node.get_parent()
	if death_vfx != null and root != null:
		var vfx := death_vfx.instantiate()
		if vfx is Node3D:
			vfx.position = root.to_local(position) if root is Node3D and root.is_inside_tree() else position
			(vfx as Node3D).scale = Vector3.ONE * vfx_scale
		root.add_child.call_deferred(vfx)
	if death_cue != null:
		AudioManager.play(death_cue, position)
	if free_delay <= 0.0:
		node.queue_free()
	else:
		_free_target = node
		_free_remaining = free_delay
	handled.emit()


func _on_died(_hit: HitInfo) -> void:
	handle_death()


func _disable_collisions(node: Node) -> void:
	if node is CollisionShape3D:
		node.set_deferred("disabled", true)
	elif node is Area3D:
		node.set_deferred("monitoring", false)
		node.set_deferred("monitorable", false)
	elif node is CollisionObject3D:
		node.set_deferred("collision_layer", 0)
		node.set_deferred("collision_mask", 0)
	for child in node.get_children():
		_disable_collisions(child)


func _find_sibling_health() -> HealthComponent:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is HealthComponent:
			return child
	return null
