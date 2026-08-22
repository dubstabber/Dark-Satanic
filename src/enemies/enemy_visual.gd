class_name EnemyVisual
extends Node3D
## Spawn scale-in, hit flash and death pop for an enemy mesh. Driven by enemy.gd through
## `spawn_in`, `flash` and `death`; the material is duplicated so flashes never leak.

## Mesh whose material flashes; when null the first MeshInstance3D descendant is used.
@export var mesh_instance: MeshInstance3D
@export_range(0.0, 10.0, 0.1) var flash_emission: float = 2.0
@export_range(0.01, 2.0, 0.01) var flash_duration: float = 0.12
@export_range(0.0, 2.0, 0.01) var death_duration: float = 0.25
@export_range(1.0, 3.0, 0.05) var death_pop_scale: float = 1.3

var base_scale: Vector3 = Vector3.ONE
var _material: StandardMaterial3D
var _base_emission: float = 0.0
var _tween: Tween
var _death_tween: Tween


func _ready() -> void:
	base_scale = scale
	if mesh_instance == null:
		mesh_instance = _find_mesh(self)
	if mesh_instance != null and mesh_instance.material_override is StandardMaterial3D:
		_material = mesh_instance.material_override.duplicate() as StandardMaterial3D
		mesh_instance.material_override = _material
		_base_emission = _material.emission_energy_multiplier


func material() -> StandardMaterial3D:
	return _material


## Scales from zero to the resting scale over `duration` seconds (instant when 0).
func spawn_in(duration: float) -> void:
	_kill(_tween)
	if duration <= 0.0:
		scale = base_scale
		return
	scale = Vector3.ONE * 0.001
	_tween = create_tween()
	_tween.tween_property(self, "scale", base_scale, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Brief emission bump (or a scale bump when there is no material).
func flash() -> void:
	if _death_tween != null and _death_tween.is_valid():
		return
	_kill(_tween)
	_tween = create_tween()
	if _material != null:
		_material.emission_enabled = true
		_material.emission_energy_multiplier = flash_emission
		_tween.tween_property(_material, "emission_energy_multiplier", _base_emission, flash_duration)
	else:
		scale = base_scale * 1.15
		_tween.tween_property(self, "scale", base_scale, flash_duration)


## Pops then shrinks to nothing.
func death() -> void:
	_kill(_tween)
	_kill(_death_tween)
	_death_tween = create_tween()
	_death_tween.tween_property(self, "scale", base_scale * death_pop_scale, death_duration * 0.4)
	_death_tween.tween_property(self, "scale", Vector3.ONE * 0.001, death_duration * 0.6)


func is_animating() -> bool:
	return (_tween != null and _tween.is_valid() and _tween.is_running()) \
		or (_death_tween != null and _death_tween.is_valid() and _death_tween.is_running())


func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


static func _find_mesh(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		var nested := _find_mesh(child)
		if nested != null:
			return nested
	return null
