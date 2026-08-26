class_name WindupVisual
extends Node
## Lights a mesh while a RangedAttackComponent winds up, so the shot is announced
## before it leaves. Purely cosmetic; the attack fires on its own clock either way.
##
## The material is duplicated per instance, because a Cantor charging up must not
## light every other Cantor sharing the archetype's material.

@export var attack: RangedAttackComponent
## Mesh whose emission swells; usually the singing mouth.
@export var glow: MeshInstance3D
@export_range(0.0, 16.0, 0.1) var charged_emission: float = 3.0
## Emission the mesh falls back to between shots; -1 keeps whatever it was authored with.
@export_range(-1.0, 16.0, 0.1) var rest_emission: float = -1.0
## Seconds the flash after firing takes to die back down.
@export_range(0.05, 3.0, 0.05) var release_time: float = 0.35

var _material: Material
var _rest: float = 0.0
var _tween: Tween


func _ready() -> void:
	_material = _own_material()
	if _material != null:
		_rest = rest_emission if rest_emission >= 0.0 else MaterialEnergy.get_energy(_material)
		MaterialEnergy.set_energy(_material, _rest)
	if attack == null:
		return
	attack.windup_started.connect(on_windup_started)
	attack.fired.connect(_on_fired)


func emission() -> float:
	return MaterialEnergy.get_energy(_material) if _material != null else 0.0


func on_windup_started() -> void:
	if _material == null or attack == null:
		return
	_retune(charged_emission, maxf(attack.windup, 0.05), Tween.EASE_IN)


func _on_fired(_shards: Array[Node3D]) -> void:
	_retune(_rest, release_time, Tween.EASE_OUT)


func _retune(to: float, duration: float, ease: Tween.EaseType) -> void:
	if _material == null or not is_inside_tree():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_material, MaterialEnergy.property(_material), to, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(ease)


## A per-instance copy of the glow mesh's material, so one enemy's tell stays its own.
func _own_material() -> Material:
	if glow == null:
		return null
	var source: Material = glow.material_override
	if source == null and glow.mesh != null:
		source = glow.mesh.surface_get_material(0)
	if source == null or not MaterialEnergy.supports(source):
		return null
	var copy: Material = source.duplicate()
	glow.material_override = copy
	return copy
