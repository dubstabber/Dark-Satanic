class_name DeathHandlerComponent
extends Node
## When the owner's HealthComponent dies: stop it colliding, spawn a VFX, play a cue,
## and free it after `free_delay` seconds.

signal handled

@export var health: HealthComponent
@export var death_vfx: PackedScene
@export var death_cue: AudioCue
@export_range(0.0, 5.0, 0.05) var free_delay: float = 0.0
## Node to disable and free; when null the parent is used.
@export var target: Node


func _ready() -> void:
	if health == null:
		health = _find_sibling_health()
	if health != null:
		health.died.connect(_on_died)


func handle_death() -> void:
	var node := target if target != null else get_parent()
	if node == null:
		return
	_disable_collisions(node)
	var position: Vector3 = node.global_position if node is Node3D else Vector3.ZERO
	if death_vfx != null and node.get_parent() != null:
		var vfx := death_vfx.instantiate()
		if vfx is Node3D:
			vfx.position = position
		node.get_parent().add_child.call_deferred(vfx)
	if death_cue != null:
		AudioManager.play(death_cue, position)
	if free_delay <= 0.0:
		node.queue_free()
	else:
		get_tree().create_timer(free_delay).timeout.connect(node.queue_free)
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
