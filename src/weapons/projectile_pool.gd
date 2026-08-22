class_name ProjectilePool
extends Node
## Keeps DaggerProjectile instances in the tree (hidden, not processing) and
## hands them out; grows when the free list runs dry.

const DEFAULT_SCENE := preload("res://src/weapons/projectiles/dagger_projectile.tscn")

@export var projectile_scene: PackedScene = DEFAULT_SCENE
@export_range(0, 1024) var initial_size: int = 64
## Node the projectiles live under; null means this pool.
@export var container: Node:
	set(value):
		container = value
		_move_all()

var _free: Array[DaggerProjectile] = []
var _all: Array[DaggerProjectile] = []


func _ready() -> void:
	while _all.size() < initial_size:
		_free.append(_create())


func acquire() -> DaggerProjectile:
	var projectile: DaggerProjectile = _free.pop_back() if not _free.is_empty() else _create()
	return projectile


func release(projectile: DaggerProjectile) -> void:
	if projectile == null:
		return
	if projectile.active:
		projectile.release()  # emits released → _on_released
		return
	_on_released(projectile)


func active_count() -> int:
	return _all.size() - _free.size()


func free_count() -> int:
	return _free.size()


func total_count() -> int:
	return _all.size()


func effective_container() -> Node:
	return container if container != null else self


func _create() -> DaggerProjectile:
	var projectile: DaggerProjectile = null
	if projectile_scene != null:
		projectile = projectile_scene.instantiate() as DaggerProjectile
	if projectile == null:
		projectile = DaggerProjectile.new()
	projectile.visible = false
	projectile.released.connect(_on_released)
	_all.append(projectile)
	effective_container().add_child(projectile)
	return projectile


func _on_released(projectile: DaggerProjectile) -> void:
	if projectile in _free or projectile not in _all:
		return
	_free.append(projectile)


func _move_all() -> void:
	var target := effective_container()
	for projectile in _all:
		if not is_instance_valid(projectile) or projectile.get_parent() == target:
			continue
		if projectile.get_parent() != null:
			projectile.get_parent().remove_child(projectile)
		target.add_child(projectile)
