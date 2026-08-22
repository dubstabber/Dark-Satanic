extends GameTest

const Tier3 := preload("res://src/weapons/resources/tiers/tier_3.tres")


func test_defaults() -> void:
	var params := ProjectileParams.new()
	assert_eq(params.speed, 60.0)
	assert_eq(params.damage, 1.0)
	assert_eq(params.lifetime, 1.0)
	assert_false(params.homing)
	assert_eq(params.homing_turn_rate_deg, 0.0)
	assert_eq(params.homing_acquire_range, 0.0)
	assert_eq(params.collision_mask, PhysicsLayers.ENEMY_HURTBOX | PhysicsLayers.WORLD)
	assert_eq(params.scale, 1.0)
	assert_eq(params.emission_energy, 1.0)
	assert_eq(params.cause, &"dagger")


func test_from_tier_copies_every_projectile_field() -> void:
	var tier := DaggerUpgradeTier.new()
	tier.damage = 3.5
	tier.projectile_speed = 80.0
	tier.projectile_lifetime = 2.5
	tier.homing = true
	tier.homing_turn_rate_deg = 180.0
	tier.homing_acquire_range = 12.0
	tier.dagger_scale = 1.5
	tier.emission_energy = 4.0
	var params := ProjectileParams.from_tier(tier)
	assert_eq(params.damage, 3.5)
	assert_eq(params.speed, 80.0)
	assert_eq(params.lifetime, 2.5)
	assert_true(params.homing)
	assert_eq(params.homing_turn_rate_deg, 180.0)
	assert_eq(params.homing_acquire_range, 12.0)
	assert_eq(params.scale, 1.5)
	assert_eq(params.emission_energy, 4.0)
	assert_eq(params.cause, &"dagger", "cause is not a tier field")
	assert_eq(params.collision_mask, PhysicsLayers.ENEMY_HURTBOX | PhysicsLayers.WORLD)


func test_from_authored_tier_resource() -> void:
	var params := ProjectileParams.from_tier(Tier3)
	assert_eq(params.damage, 2.0)
	assert_eq(params.scale, 1.2)
	assert_eq(params.emission_energy, 1.8)


func test_from_null_tier_gives_defaults() -> void:
	var params := ProjectileParams.from_tier(null)
	assert_eq(params.speed, 60.0)
	assert_eq(params.damage, 1.0)
