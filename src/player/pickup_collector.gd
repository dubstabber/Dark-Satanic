class_name PickupCollector
extends Area3D
## The player's gem magnet target. Passive (`monitorable` only): gems overlap it and
## call collect(self). This is the only contract between player and pickups.

signal gem_collected(value: int)

var collected_total: int = 0


func _ready() -> void:
	collision_layer = PhysicsLayers.PICKUP
	collision_mask = 0
	monitorable = true
	monitoring = false


## Reads `gem.value`, reports it, then lets the gem consume itself.
func collect(gem: Node) -> void:
	if gem == null:
		return
	var value: int = int(gem.get("value")) if gem.get("value") != null else 0
	collected_total += value
	gem_collected.emit(value)
	if gem.has_method("consume"):
		gem.consume()
