extends GameTest

var _world: Node3D
var _spawner: ProjectileSpawner


func before_each() -> void:
	super.before_each()
	_world = make_world()
	_spawner = WeaponTargets.spawner(_world, 8, 11)


func _angle_to(projectile: DaggerProjectile, direction: Vector3) -> float:
	return rad_to_deg(projectile.velocity.angle_to(direction))


func test_finds_child_pool_and_seeds_rng() -> void:
	assert_not_null(_spawner.pool)
	assert_true(_spawner.pool is ProjectilePool)
	var other := RandomNumberGenerator.new()
	other.seed = 11
	assert_eq(_spawner.rng.randf(), other.randf(), "rng_seed applied")


func test_spawn_count_and_all_launched() -> void:
	var launched := _spawner.spawn(Vector3(0, 1, 0), Vector3.FORWARD, 5, 0.0, ProjectileParams.new())
	assert_eq(launched.size(), 5)
	assert_eq(_spawner.pool.active_count(), 5)
	for projectile in launched:
		assert_true(projectile.active)
		assert_true(projectile.visible)
		assert_eq(projectile.global_position, Vector3(0, 1, 0))
		assert_almost_eq(projectile.velocity, Vector3(0, 0, -60), Vector3.ONE * 0.001, "zero spread is exact")
	for projectile in launched:
		projectile.autonomous = false


func test_spawn_grows_past_pool_size() -> void:
	var launched := _spawner.spawn(Vector3.ZERO, Vector3.FORWARD, 12, 0.0, ProjectileParams.new())
	assert_eq(launched.size(), 12)
	assert_eq(_spawner.pool.total_count(), 12)
	for projectile in launched:
		projectile.autonomous = false


func test_cone_spread_within_half_angle() -> void:
	var direction := Vector3(1, 0.5, -1).normalized()
	var params := ProjectileParams.new()
	params.speed = 40.0
	var launched := _spawner.spawn(Vector3.ZERO, direction, 40, 12.0, params)
	var max_angle := 0.0
	for projectile in launched:
		projectile.autonomous = false
		var angle := _angle_to(projectile, direction)
		assert_lte(angle, 12.0 + 0.01)
		max_angle = maxf(max_angle, angle)
		assert_almost_eq(projectile.velocity.length(), 40.0, 0.01)
	assert_gt(max_angle, 3.0, "spread actually scatters")


func test_spread_is_deterministic_with_seed() -> void:
	var a := WeaponTargets.spawner(_world, 4, 99)
	var b := WeaponTargets.spawner(_world, 4, 99)
	var la := a.spawn(Vector3.ZERO, Vector3.FORWARD, 4, 10.0, ProjectileParams.new())
	var lb := b.spawn(Vector3.ZERO, Vector3.FORWARD, 4, 10.0, ProjectileParams.new())
	for i in 4:
		la[i].autonomous = false
		lb[i].autonomous = false
		assert_almost_eq(la[i].velocity, lb[i].velocity, Vector3.ONE * 0.0001)


func test_explicit_rng_overrides_own() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var before := _spawner.rng.state
	var launched := _spawner.spawn(Vector3.ZERO, Vector3.FORWARD, 3, 5.0, ProjectileParams.new(), rng)
	assert_eq(_spawner.rng.state, before, "own rng untouched")
	for projectile in launched:
		projectile.autonomous = false


func test_forwards_source_and_target_provider() -> void:
	var weapon := Node.new()
	_world.add_child(weapon)
	_spawner.source = weapon
	_spawner.target_provider = func() -> Array[Node3D]: return []
	var launched := _spawner.spawn(Vector3.ZERO, Vector3.FORWARD, 2, 0.0, ProjectileParams.new())
	for projectile in launched:
		projectile.autonomous = false
		assert_same(projectile.source, weapon)
		assert_true(projectile.target_provider.is_valid())


func test_zero_count_or_missing_pool() -> void:
	assert_eq(_spawner.spawn(Vector3.ZERO, Vector3.FORWARD, 0, 0.0, ProjectileParams.new()).size(), 0)
	var lonely := ProjectileSpawner.new()
	_world.add_child(lonely)
	assert_eq(lonely.spawn(Vector3.ZERO, Vector3.FORWARD, 3, 0.0, ProjectileParams.new()).size(), 0)


func test_cone_direction_static_handles_vertical_forward() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 20:
		var d := ProjectileSpawner.cone_direction(Vector3.UP, 20.0, rng)
		assert_true(d.is_finite())
		assert_almost_eq(d.length(), 1.0, 0.001)
		assert_lte(rad_to_deg(d.angle_to(Vector3.UP)), 20.01)
