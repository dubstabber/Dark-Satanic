class_name HitboxComponent
extends Area3D
## Deals contact damage to any HurtboxComponent it overlaps (enemy body vs player).

signal hit_dealt(hurtbox: HurtboxComponent, hit: HitInfo)

@export var damage: float = 1.0
## Reported to the victim as the cause of death ("enemy", "void", ...).
@export var cause: StringName = &"enemy"
## Deactivate after the first hit.
@export var one_shot: bool = false
## Inactive hitboxes ignore overlaps (used while an enemy is still spawning).
@export var active: bool = true:
	set(value):
		active = value
		if active and is_inside_tree():
			_check_current_overlaps()


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func deal(hurtbox: HurtboxComponent) -> void:
	var direction := hurtbox.global_position - global_position
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
	var hit := HitInfo.new(damage, hurtbox.global_position, direction, -direction, get_parent(), cause)
	hurtbox.receive_hit(hit)
	hit_dealt.emit(hurtbox, hit)
	if one_shot:
		active = false


func _on_area_entered(area: Area3D) -> void:
	if active and area is HurtboxComponent:
		deal(area)


func _check_current_overlaps() -> void:
	for area in get_overlapping_areas():
		_on_area_entered(area)
