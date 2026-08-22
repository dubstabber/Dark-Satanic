class_name HitInfo
extends RefCounted
## Everything a hurtbox needs to know about one hit.

var damage: float
var position: Vector3
var direction: Vector3
var normal: Vector3
var source: Node
var cause: StringName


func _init(
	p_damage: float,
	p_position: Vector3 = Vector3.ZERO,
	p_direction: Vector3 = Vector3.ZERO,
	p_normal: Vector3 = Vector3.UP,
	p_source: Node = null,
	p_cause: StringName = &"hit"
) -> void:
	damage = p_damage
	position = p_position
	direction = p_direction
	normal = p_normal
	source = p_source
	cause = p_cause


func scaled(multiplier: float) -> HitInfo:
	return HitInfo.new(damage * multiplier, position, direction, normal, source, cause)
