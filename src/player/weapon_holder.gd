class_name WeaponHolder
extends Node
## Bridges player input to whatever weapon node is plugged in (a DaggerWeapon in
## production). Duck-typed: every weapon call is guarded by has_method so the player
## runs with no weapon at all.

## Recoil strength for a tick in which the weapon fired; Player feeds it to the
## camera rig and hands. Emitted once per `fired` with the mode's kick strength.
signal kicked(strength: float)

## Anything with setup(aim_source, muzzle, projectile_root), update_fire(primary_held,
## secondary_pressed, delta) and apply_tier(tier). Assigning after _ready re-runs setup.
@export var weapon: Node:
	set(value):
		_disconnect_fired()
		weapon = value
		if is_node_ready():
			_setup_weapon()
## Where aim rays originate (the camera).
@export var aim_source: Node3D
## Where projectiles visually spawn (HandViewModel/Muzzle).
@export var muzzle: Node3D
## Projectiles are parented here; defaults to the player's parent. Assigning after
## _ready re-runs setup so the weapon's pool moves (Game sets it after the player is ready).
@export var projectile_root: Node:
	set(value):
		projectile_root = value
		if is_node_ready():
			_setup_weapon()

@export_group("Kick")
## Kick strength (1.0 = one stream dagger) per stream tick that fired.
@export_range(0.0, 10.0, 0.1) var stream_kick: float = 1.0
## Kick strength for a shotgun volley.
@export_range(0.0, 10.0, 0.1) var shotgun_kick: float = 4.0

var _tier: DaggerUpgradeTier


func _ready() -> void:
	if projectile_root == null:
		projectile_root = _default_projectile_root()  # the setter runs _setup_weapon
	else:
		_setup_weapon()


func _default_projectile_root() -> Node:
	var player := get_parent()
	return player.get_parent() if player != null else null


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
	if weapon.has_signal("fired") and not weapon.is_connected("fired", _on_weapon_fired):
		weapon.connect("fired", _on_weapon_fired)


func _disconnect_fired() -> void:
	if weapon != null and weapon.has_signal("fired") and weapon.is_connected("fired", _on_weapon_fired):
		weapon.disconnect("fired", _on_weapon_fired)


func _on_weapon_fired(_count: int, mode: StringName) -> void:
	kicked.emit(shotgun_kick if mode == &"shotgun" else stream_kick)
