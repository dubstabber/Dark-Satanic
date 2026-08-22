class_name GemEaterComponent
extends Area3D
## Glutton mouth: acts as a gem collector (layer PICKUP, monitorable) and grows the owner
## with every gem eaten — more health, a bigger body and a larger gem drop on death.

signal gem_eaten(count: int)

@export var health: HealthComponent
@export var gem_drop: GemDropComponent
## Node scaled per gem; when null the parent is used.
@export var body: Node3D
@export_range(1.0, 2.0, 0.005) var growth_per_gem: float = 1.03
@export_range(0.0, 50.0, 0.5) var health_per_gem: float = 1.0

var eaten: int = 0
var base_gem_count: int = -1


func _ready() -> void:
	if body == null:
		body = get_parent() as Node3D
	var parent := get_parent()
	if parent != null:
		for child in parent.get_children():
			if health == null and child is HealthComponent:
				health = child
			if gem_drop == null and child is GemDropComponent:
				gem_drop = child


## Called by the gem when it overlaps this area (the PickupCollector contract).
func collect(gem: Node) -> void:
	if gem == null or not is_instance_valid(gem):
		return
	if base_gem_count < 0:
		base_gem_count = gem_drop.count if gem_drop != null else 0
	eaten += 1
	if health != null:
		health.max_health += health_per_gem
		health.heal(health_per_gem)
	if body != null:
		body.scale *= growth_per_gem
	if gem_drop != null:
		gem_drop.count = base_gem_count + eaten
	gem_eaten.emit(eaten)
	if gem.has_method("consume"):
		gem.call("consume")
