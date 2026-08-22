class_name KillZone
extends Area3D
## Kills anything with a HealthComponent child that falls below the platform. Collision
## objects without one (an enemy's Hurtbox area) are resolved through their parent.

signal killed(node: Node)

## Cause passed to HealthComponent.kill().
@export var cause: StringName = &"void"


func _ready() -> void:
	body_entered.connect(_on_entered)
	area_entered.connect(_on_entered)


## Kills `node` when it owns a HealthComponent child; returns true when it did.
func try_kill(node: Node) -> bool:
	var health := find_health(node)
	if health == null or health.is_dead():
		return false
	health.kill(cause, self)
	killed.emit(node)
	return true


static func find_health(node: Node) -> HealthComponent:
	if node == null:
		return null
	var direct := _health_child(node)
	if direct != null:
		return direct
	if node is CollisionObject3D:
		return _health_child(node.get_parent())
	return null


static func _health_child(node: Node) -> HealthComponent:
	if node == null:
		return null
	for child in node.get_children():
		if child is HealthComponent:
			return child
	return null


func _on_entered(node: Node) -> void:
	try_kill(node)
