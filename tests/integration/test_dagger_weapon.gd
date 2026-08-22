extends GameTest

const WeaponScene := preload("res://src/weapons/dagger_weapon.tscn")
const Tier1 := preload("res://src/weapons/resources/tiers/tier_1.tres")
const Tier3 := preload("res://src/weapons/resources/tiers/tier_3.tres")
const DT := 1.0 / 60.0

var _world: Node3D
var _aim: Node3D
var _muzzle: Node3D
var _weapon: DaggerWeapon


func before_each() -> void:
	super.before_each()
	_world = make_world()
	_aim = Node3D.new()
	_aim.name = "Aim"
	_world.add_child(_aim)
	_muzzle = Node3D.new()
	_muzzle.name = "Muzzle"
	_muzzle.position = Vector3(0.2, -0.1, -0.3)
	_aim.add_child(_muzzle)
	_weapon = WeaponScene.instantiate()
	_aim.add_child(_weapon)
	_weapon.setup(_aim, _muzzle, _world)
	watch_signals(_weapon)


func after_each() -> void:
	for projectile in _weapon.spawner().pool.get_children():
		projectile.autonomous = false
	super.after_each()


func _active_projectiles() -> Array[DaggerProjectile]:
	var out: Array[DaggerProjectile] = []
	for child in _world.get_children():
		if child is DaggerProjectile and child.active:
			out.append(child)
	return out


func test_scene_structure_and_default_tier() -> void:
	assert_not_null(_weapon.spawner())
	assert_not_null(_weapon.stream_mode())
	assert_not_null(_weapon.shotgun_mode())
	assert_not_null(_weapon.spawner().pool)
	assert_same(_weapon.stream_mode().spawner, _weapon.spawner())
	assert_same(_weapon.shotgun_mode().spawner, _weapon.spawner())
	assert_same(_weapon.tier, Tier1, "tier I applied at _ready from the default ladder")
	assert_eq(_weapon.stream_mode().rate, 15.0)
	assert_eq(_weapon.shotgun_mode().pellets, 12)
	assert_same(_weapon.spawner().source, _weapon)


func test_setup_moves_pool_into_projectile_root() -> void:
	var pool := _weapon.spawner().pool
	assert_same(pool.container, _world)
	assert_eq(pool.get_child_count(), 0)
	var daggers := 0
	for child in _world.get_children():
		if child is DaggerProjectile:
			daggers += 1
	assert_eq(daggers, 64)


func test_update_fire_uses_muzzle_and_aim_direction() -> void:
	_aim.rotation_degrees = Vector3(0, 90, 0)
	var count := _weapon.update_fire(true, false, DT)
	assert_eq(count, 1)
	var projectile := _active_projectiles()[0]
	assert_almost_eq(projectile.global_position, _muzzle.global_position, Vector3.ONE * 0.001)
	assert_almost_eq(projectile.velocity.normalized(), -_aim.global_basis.z, Vector3.ONE * 0.03)
	assert_almost_eq(projectile.velocity.normalized(), Vector3.LEFT, Vector3.ONE * 0.03)


func test_stream_kills_target_end_to_end() -> void:
	var target := WeaponTargets.hurtbox_target(_world, Vector3(0, 0, -3), 1.0)
	await wait_physics_frames(3)
	assert_eq(_weapon.update_fire(true, false, DT), 1)
	assert_signal_emitted(_weapon, "fired")
	assert_eq(get_signal_parameters(_weapon, "fired")[1], &"stream")
	assert_eq(get_signal_parameters(_weapon, "fired")[0], 1)
	await wait_physics_frames(8)
	assert_true(target.health.is_dead(), "dagger flew 3 m and hit the hurtbox")
	assert_eq(_active_projectiles().size(), 0, "projectile returned to the pool")
	assert_eq(_weapon.spawner().pool.active_count(), 0)


func test_hit_info_source_is_weapon_and_cause_dagger() -> void:
	var target := WeaponTargets.hurtbox_target(_world, Vector3(0, 0, -3), 1.0)
	watch_signals(target.hurtbox)
	await wait_physics_frames(3)
	_weapon.update_fire(true, false, DT)
	await wait_physics_frames(8)
	assert_signal_emitted(target.hurtbox, "hit_received")
	var info: HitInfo = get_signal_parameters(target.hurtbox, "hit_received")[0]
	assert_same(info.source, _weapon)
	assert_eq(info.cause, &"dagger")


func test_shotgun_fires_pellets_with_mode_signal() -> void:
	assert_eq(_weapon.update_fire(false, true, DT), 12)
	assert_eq(get_signal_parameters(_weapon, "fired")[1], &"shotgun")
	assert_eq(get_signal_parameters(_weapon, "fired")[0], 12)
	assert_eq(_weapon.update_fire(false, true, DT), 0, "cooling down")
	assert_eq(_active_projectiles().size(), 12)


func test_both_modes_in_one_tick() -> void:
	assert_eq(_weapon.update_fire(true, true, DT), 13)
	assert_signal_emit_count(_weapon, "fired", 2)


func test_idle_tick_fires_nothing() -> void:
	assert_eq(_weapon.update_fire(false, false, DT), 0)
	assert_signal_not_emitted(_weapon, "fired")


func test_apply_tier_changes_rate_and_pellets() -> void:
	_weapon.apply_tier(Tier3)
	assert_same(_weapon.tier, Tier3)
	assert_eq(_weapon.stream_mode().rate, 20.0)
	assert_eq(_weapon.shotgun_mode().pellets, 24)
	assert_eq(_weapon.update_fire(false, true, DT), 24)
	assert_eq(_weapon.update_fire(true, false, DT), 2, "two daggers per stream shot")
	for projectile in _active_projectiles():
		assert_eq(projectile.params.damage, 2.0)
		assert_almost_eq(projectile.scale.x, 1.2, 0.001)
	_weapon.apply_tier(null)
	assert_same(_weapon.tier, Tier3, "null tier ignored")


func test_target_provider_reaches_projectiles() -> void:
	var candidate := Node3D.new()
	_world.add_child(candidate)
	var provider := func() -> Array[Node3D]: return [candidate]
	_weapon.target_provider = provider
	assert_true(_weapon.spawner().target_provider.is_valid())
	_weapon.update_fire(true, false, DT)
	var projectile := _active_projectiles()[0]
	assert_true(projectile.target_provider.is_valid())
	assert_same(projectile.target_provider.call()[0], candidate)


func test_cues_are_authored_and_may_be_null() -> void:
	assert_true(_weapon.stream_cue is AudioCue, "dagger tick authored in the scene")
	assert_true(_weapon.shotgun_cue is AudioCue, "shotgun thump authored in the scene")
	_weapon.stream_cue = null
	_weapon.shotgun_cue = null
	for mode in [_weapon.get_node("StreamFire"), _weapon.get_node("ShotgunFire")]:
		mode.cue = null
	assert_eq(_weapon.update_fire(true, true, DT), 13, "no crash without cues")
	assert_eq(AudioManager.playing_count(), 0)


func test_setup_before_entering_tree() -> void:
	var aim := Node3D.new()
	_world.add_child(aim)
	var root := Node3D.new()
	_world.add_child(root)
	var weapon: DaggerWeapon = WeaponScene.instantiate()
	weapon.setup(aim, null, root)
	aim.add_child(weapon)
	assert_eq(root.get_child_count(), 64, "pool filled straight into the projectile root")
	assert_eq(weapon.muzzle_position(), aim.global_position, "muzzle falls back to the aim source")
	assert_eq(weapon.update_fire(true, false, DT), 1)
	for projectile in root.get_children():
		projectile.autonomous = false


func test_aim_direction_without_setup_uses_own_basis() -> void:
	var weapon: DaggerWeapon = WeaponScene.instantiate()
	weapon.rotation_degrees = Vector3(0, -90, 0)
	_world.add_child(weapon)
	assert_almost_eq(weapon.aim_direction(), Vector3.RIGHT, Vector3.ONE * 0.001)
	assert_eq(weapon.muzzle_position(), weapon.global_position)
