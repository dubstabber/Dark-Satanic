class_name WeaponHolder
extends Node
## Bridges player input to whatever weapon node is plugged in (a DaggerWeapon in
## production). Duck-typed: every weapon call is guarded by has_method so the player
## runs with no weapon at all.

## Anything with setup(aim_source, muzzle, projectile_root), update_fire(primary_held,
## secondary_pressed, delta) and apply_tier(tier). Assigning after _ready re-runs setup.
@export var weapon: Node:
	set(value):
		weapon = value
		if is_node_ready():
			_setup_weapon()
## Where aim rays originate (the camera).
@export var aim_source: Node3D
## Where projectiles visually spawn (HandViewModel/Muzzle).
@export var muzzle: Node3D
## Projectiles are parented here; defaults to the player's parent.
@export var projectile_root: Node

var _tier: DaggerUpgradeTier


func _ready() -> void:
	if projectile_root == null:
		var player := get_parent()
		if player != null and player.get_parent() != null:
			projectile_root = player.get_parent()
	_setup_weapon()


## Forwards this tick's fire input to the weapon.
func update(frame: PlayerInputFrame, delta: float) -> void:
	if weapon == null or frame == null or not weapon.has_method("update_fire"):
		return
	weapon.update_fire(frame.primary_held, frame.secondary_pressed, delta)


## Called by Game on RunState.tier_changed; remembered so a later weapon gets it too.
func set_tier(tier: DaggerUpgradeTier) -> void:
	_tier = tier
	if weapon != null and weapon.has_method("apply_tier"):
		weapon.apply_tier(tier)


func tier() -> DaggerUpgradeTier:
	return _tier


func _setup_weapon() -> void:
	if weapon == null:
		return
	if weapon.has_method("setup"):
		weapon.setup(aim_source, muzzle, projectile_root)
	if _tier != null and weapon.has_method("apply_tier"):
		weapon.apply_tier(_tier)
