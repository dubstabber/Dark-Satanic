class_name HurtboxComponent
extends Area3D
## Area that receives hits and forwards them (scaled) to a HealthComponent.
## `monitorable` only: projectiles and hitboxes find it, it never scans.

signal hit_received(hit: HitInfo)

## Health to damage; when null the first HealthComponent sibling is used.
@export var health: HealthComponent
## 0 makes this part armoured (hits are reported but deal nothing).
@export_range(0.0, 10.0, 0.05) var damage_multiplier: float = 1.0


func _ready() -> void:
	if health == null:
		health = _find_sibling_health()


func receive_hit(hit: HitInfo) -> void:
	hit_received.emit(hit)
	var scaled := hit.scaled(effective_multiplier(hit))
	if scaled.damage <= 0.0 or health == null:
		return
	health.take_damage(scaled)


func effective_multiplier(_hit: HitInfo) -> float:
	return damage_multiplier


func _find_sibling_health() -> HealthComponent:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is HealthComponent:
			return child
	return null
