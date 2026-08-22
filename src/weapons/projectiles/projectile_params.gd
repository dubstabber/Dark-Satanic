class_name ProjectileParams
extends RefCounted
## Plain bundle of numbers a projectile needs for one flight. Built from a
## DaggerUpgradeTier so the projectile never touches weapon resources itself.

var speed: float = 60.0
var damage: float = 1.0
var lifetime: float = 1.0
var homing: bool = false
var homing_turn_rate_deg: float = 0.0
var homing_acquire_range: float = 0.0
var collision_mask: int = PhysicsLayers.ENEMY_HURTBOX | PhysicsLayers.WORLD
var scale: float = 1.0
var emission_energy: float = 1.0
var cause: StringName = &"dagger"


static func from_tier(tier: DaggerUpgradeTier) -> ProjectileParams:
	var params := ProjectileParams.new()
	if tier == null:
		return params
	params.speed = tier.projectile_speed
	params.damage = tier.damage
	params.lifetime = tier.projectile_lifetime
	params.homing = tier.homing
	params.homing_turn_rate_deg = tier.homing_turn_rate_deg
	params.homing_acquire_range = tier.homing_acquire_range
	params.scale = tier.dagger_scale
	params.emission_energy = tier.emission_energy
	return params
