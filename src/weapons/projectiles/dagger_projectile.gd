class_name DaggerProjectile
extends Node3D
## A pooled dagger with no physics body: every tick it sweeps a ray from its
## previous to its next position and reports what it crossed.

signal hit(hurtbox: HurtboxComponent, hit_info: HitInfo)
signal hit_world(position: Vector3, normal: Vector3)
signal released(projectile: DaggerProjectile)

## Absorbs float drift so N ticks of 1/N seconds expire a 1 s lifetime exactly.
const LIFETIME_EPSILON := 0.0001

## Optional one-shot effect instantiated (deferred) under this node's parent at the hit point.
@export var hit_vfx: PackedScene
## Advance on the engine clock; tests switch this off and call advance() themselves.
@export var autonomous: bool = true

var velocity: Vector3 = Vector3.ZERO
var params: ProjectileParams = ProjectileParams.new()
var source: Node
## Callable() -> Array[Node3D] of homing candidates; unset means no homing.
var target_provider: Callable = Callable()
var active: bool = false
var age: float = 0.0

var _material: StandardMaterial3D


func _ready() -> void:
	var mesh := _find_mesh()
	if mesh != null:
		var shared := mesh.get_surface_override_material(0) as StandardMaterial3D
		if shared == null:
			shared = mesh.mesh.surface_get_material(0) as StandardMaterial3D if mesh.mesh != null else null
		if shared != null:
			_material = shared.duplicate() as StandardMaterial3D
			mesh.set_surface_override_material(0, _material)
	if not active:
		_deactivate()


func _physics_process(delta: float) -> void:
	if autonomous and active:
		advance(delta)


func launch(origin: Vector3, direction: Vector3, p_params: ProjectileParams, p_source: Node = null) -> void:
	params = p_params if p_params != null else ProjectileParams.new()
	source = p_source
	age = 0.0
	var dir := direction.normalized() if direction.length_squared() > 0.0 else Vector3.FORWARD
	velocity = dir * params.speed
	global_position = origin
	scale = Vector3.ONE * params.scale
	if _material != null:
		_material.emission_energy_multiplier = params.emission_energy
	active = true
	visible = true
	set_physics_process(true)
	_orient()


func advance(delta: float) -> void:
	if not active or delta <= 0.0:
		return
	age += delta
	_steer(delta)
	var prev := global_position
	var next := prev + velocity * delta
	var result := _sweep(prev, next)
	if not result.is_empty():
		_resolve(result)
		return
	global_position = next
	_orient()
	if age >= params.lifetime - LIFETIME_EPSILON:
		release()


func release() -> void:
	if not active:
		return
	_deactivate()
	released.emit(self)


func _deactivate() -> void:
	active = false
	visible = false
	set_physics_process(false)


func _sweep(from: Vector3, to: Vector3) -> Dictionary:
	if not is_inside_tree() or from.is_equal_approx(to):
		return {}
	var world := get_world_3d()
	if world == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, to, params.collision_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	return world.direct_space_state.intersect_ray(query)


func _resolve(result: Dictionary) -> void:
	var collider: Object = result.get("collider")
	var position: Vector3 = result.get("position", global_position)
	var normal: Vector3 = result.get("normal", Vector3.UP)
	global_position = position
	_spawn_vfx(position)
	if collider is HurtboxComponent:
		var direction := velocity.normalized() if velocity.length_squared() > 0.0 else Vector3.ZERO
		var info := HitInfo.new(params.damage, position, direction, normal, source, params.cause)
		(collider as HurtboxComponent).receive_hit(info)
		hit.emit(collider, info)
	else:
		hit_world.emit(position, normal)
	release()


func _steer(delta: float) -> void:
	if not params.homing or not target_provider.is_valid() or velocity.length_squared() == 0.0:
		return
	var target := _nearest_target()
	if target == null:
		return
	var desired := (target.global_position - global_position).normalized()
	var forward := velocity.normalized()
	var angle := forward.angle_to(desired)
	if angle <= 0.0001:
		return
	var axis := forward.cross(desired)
	if axis.length_squared() <= 0.000001:
		return
	var step := minf(angle, deg_to_rad(params.homing_turn_rate_deg) * delta)
	velocity = forward.rotated(axis.normalized(), step) * velocity.length()


func _nearest_target() -> Node3D:
	var candidates: Array = target_provider.call()
	var best: Node3D = null
	var best_distance := params.homing_acquire_range
	var forward := velocity.normalized()
	for candidate in candidates:
		if not is_instance_valid(candidate) or not candidate is Node3D:
			continue
		var node := candidate as Node3D
		var offset := node.global_position - global_position
		var distance := offset.length()
		if distance > best_distance or forward.dot(offset) <= 0.0:
			continue
		best = node
		best_distance = distance
	return best


func _orient() -> void:
	if velocity.length_squared() == 0.0:
		return
	var forward := velocity.normalized()
	var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.999 else Vector3.RIGHT
	global_basis = Basis.looking_at(forward, up).scaled(scale)


func _spawn_vfx(position: Vector3) -> void:
	if hit_vfx == null or get_parent() == null:
		return
	var vfx := hit_vfx.instantiate()
	_add_vfx.call_deferred(vfx, position)


func _add_vfx(vfx: Node, position: Vector3) -> void:
	var parent := get_parent()
	if parent == null:
		vfx.queue_free()
		return
	parent.add_child(vfx)
	if vfx is Node3D:
		(vfx as Node3D).global_position = position


func _find_mesh() -> MeshInstance3D:
	for child in get_children():
		if child is MeshInstance3D:
			return child
	return null
