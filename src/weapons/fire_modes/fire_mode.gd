@abstract
class_name FireMode
extends Node
## One way of turning input into dagger launches. Subclasses store the numbers
## they need from a DaggerUpgradeTier in configure() and react in update().

signal fired(count: int)

## Spawner to launch through; when null a ProjectileSpawner sibling is used.
@export var spawner: ProjectileSpawner
## Optional sound for this mode (the weapon plays it when a tick fires).
@export var cue: AudioCue

var params: ProjectileParams = ProjectileParams.new()


func _ready() -> void:
	if spawner == null:
		spawner = _find_sibling_spawner()


func configure(tier: DaggerUpgradeTier) -> void:
	params = ProjectileParams.from_tier(tier)
	_configure(tier)


## Returns the number of projectiles launched this tick.
@abstract func update(
	held: bool, just_pressed: bool, origin: Vector3, direction: Vector3, delta: float
) -> int


## Subclasses copy their mode-specific numbers here.
func _configure(_tier: DaggerUpgradeTier) -> void:
	pass


func _launch(origin: Vector3, direction: Vector3, count: int, spread_deg: float) -> int:
	if spawner == null or count <= 0:
		return 0
	var launched := spawner.spawn(origin, direction, count, spread_deg, params).size()
	if launched > 0:
		fired.emit(launched)
	return launched


func _find_sibling_spawner() -> ProjectileSpawner:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is ProjectileSpawner:
			return child
	return null
