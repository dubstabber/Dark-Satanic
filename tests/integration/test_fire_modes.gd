extends GameTest

const Tier1 := preload("res://src/weapons/resources/tiers/tier_1.tres")
const Tier3 := preload("res://src/weapons/resources/tiers/tier_3.tres")
const DT := 1.0 / 60.0

var _world: Node3D
var _spawner: ProjectileSpawner
var _stream: StreamFire
var _shotgun: ShotgunFire


func before_each() -> void:
	super.before_each()
	_world = make_world()
	var holder := Node.new()
	_world.add_child(holder)
	_spawner = WeaponTargets.spawner(holder, 16, 5)
	_stream = StreamFire.new()
	_shotgun = ShotgunFire.new()
	holder.add_child(_stream)
	holder.add_child(_shotgun)
	_stream.configure(Tier1)
	_shotgun.configure(Tier1)
	watch_signals(_stream)
	watch_signals(_shotgun)


func after_each() -> void:
	# Projectiles fly autonomously; stop them so the world frees cleanly.
	for projectile in _spawner.pool.get_children():
		projectile.autonomous = false
	super.after_each()


func _hold_stream(ticks: int) -> int:
	var total := 0
	for i in ticks:
		total += _stream.update(true, i == 0, Vector3.ZERO, Vector3.FORWARD, DT)
	return total


func test_modes_find_sibling_spawner() -> void:
	assert_same(_stream.spawner, _spawner)
	assert_same(_shotgun.spawner, _spawner)


func test_configure_stores_tier_numbers_and_params() -> void:
	assert_eq(_stream.rate, 15.0)
	assert_eq(_stream.daggers_per_shot, 1)
	assert_eq(_stream.spread_deg, 1.5)
	assert_eq(_shotgun.pellets, 12)
	assert_eq(_shotgun.spread_deg, 12.0)
	assert_eq(_shotgun.cooldown, 0.6)
	assert_eq(_stream.params.damage, 1.0)
	_stream.configure(Tier3)
	assert_eq(_stream.params.damage, 2.0)
	assert_eq(_stream.daggers_per_shot, 2)


func test_stream_one_second_at_tier_one_is_about_fifteen() -> void:
	var total := _hold_stream(60)
	assert_between(total, 14, 16)
	assert_eq(_spawner.pool.active_count(), total)
	assert_signal_emit_count(_stream, "fired", total)


func test_stream_fires_instantly_on_press_and_after_release() -> void:
	assert_eq(_stream.update(true, true, Vector3.ZERO, Vector3.FORWARD, DT), 1, "first tick fires")
	assert_eq(_stream.update(true, false, Vector3.ZERO, Vector3.FORWARD, DT), 0)
	assert_eq(_stream.update(false, false, Vector3.ZERO, Vector3.FORWARD, DT), 0, "released")
	assert_eq(_stream.update(true, true, Vector3.ZERO, Vector3.FORWARD, DT), 1, "instant again")


func test_stream_not_held_never_fires() -> void:
	var total := 0
	for i in 120:
		total += _stream.update(false, false, Vector3.ZERO, Vector3.FORWARD, DT)
	assert_eq(total, 0)
	assert_signal_not_emitted(_stream, "fired")


func test_stream_two_per_shot_at_tier_three() -> void:
	_stream.configure(Tier3)
	assert_eq(_stream.update(true, true, Vector3.ZERO, Vector3.FORWARD, DT), 2)
	var total := 2 + _hold_stream(59)
	assert_between(total, 40, 42, "20/s x 2 daggers")
	assert_eq(total % 2, 0)


func test_stream_big_delta_catches_up() -> void:
	assert_eq(_stream.update(true, true, Vector3.ZERO, Vector3.FORWARD, 0.5), 8, "1 primed + 7.5 accumulated")


func test_stream_uses_stream_spread() -> void:
	_stream.update(true, true, Vector3.ZERO, Vector3.FORWARD, 0.5)
	for projectile in _spawner.pool.get_children():
		if projectile.active:
			assert_lte(rad_to_deg(projectile.velocity.angle_to(Vector3.FORWARD)), 1.51)


func test_shotgun_fires_pellets_on_press_only() -> void:
	assert_eq(_shotgun.update(true, true, Vector3.ZERO, Vector3.FORWARD, DT), 12)
	assert_signal_emit_count(_shotgun, "fired", 1)
	assert_eq(get_signal_parameters(_shotgun, "fired")[0], 12)
	var held := 0
	for i in 10:
		held += _shotgun.update(true, false, Vector3.ZERO, Vector3.FORWARD, DT)
	assert_eq(held, 0, "holding does not fire")


func test_shotgun_cooldown_blocks_then_allows() -> void:
	_shotgun.update(true, true, Vector3.ZERO, Vector3.FORWARD, DT)
	var blocked := 0
	for i in 30:
		blocked += _shotgun.update(true, true, Vector3.ZERO, Vector3.FORWARD, DT)
	assert_eq(blocked, 0, "0.5 s into a 0.6 s cooldown")
	assert_gt(_shotgun.cooldown_remaining(), 0.0)
	var later := 0
	for i in 12:
		later += _shotgun.update(true, true, Vector3.ZERO, Vector3.FORWARD, DT)
	assert_eq(later, 12, "fires exactly once more after the cooldown elapses")
	assert_signal_emit_count(_shotgun, "fired", 2)


func test_shotgun_pellets_within_spread_and_tier_change() -> void:
	_shotgun.update(true, true, Vector3.ZERO, Vector3.FORWARD, DT)
	for projectile in _spawner.pool.get_children():
		if projectile.active:
			assert_lte(rad_to_deg(projectile.velocity.angle_to(Vector3.FORWARD)), 12.01)
	_shotgun.configure(Tier3)
	_shotgun.update(true, true, Vector3.ZERO, Vector3.FORWARD, 10.0)
	assert_eq(get_signal_parameters(_shotgun, "fired")[0], 24)


func test_mode_without_spawner_fires_nothing() -> void:
	var lonely := StreamFire.new()
	_world.add_child(lonely)
	lonely.configure(Tier1)
	assert_null(lonely.spawner)
	assert_eq(lonely.update(true, true, Vector3.ZERO, Vector3.FORWARD, DT), 0)
