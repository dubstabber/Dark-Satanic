extends GameTest
## Shotgun jumping through the real player: firing into the floor shoves the player
## off it, and doing that while already airborne is what turns a jump into a launch.

const WeaponScene := preload("res://src/weapons/dagger_weapon.tscn")
const DT := 1.0 / 60.0

var _world: Node3D
var _input: FakeInputReader
var _player: Player
var _knockback: SelfKnockback


func before_each() -> void:
	super.before_each()
	_world = make_world()
	PlayerTestWorld.add_floor(_world)
	_input = FakeInputReader.new()
	_player = PlayerTestWorld.spawn_player(_world, _input)
	var weapon: DaggerWeapon = WeaponScene.instantiate()
	_player.weapon_holder.add_child(weapon)
	_player.weapon_holder.weapon = weapon
	_knockback = _player.self_knockback
	watch_signals(_knockback)


func after_each() -> void:
	for child in _world.get_children():
		if child is DaggerProjectile:
			child.autonomous = false
	super.after_each()


func _aim_down() -> void:
	_player.camera_rig.rotation.x = -PI / 2.0


func _settle() -> void:
	await wait_physics_frames(30)


func _fire_secondary() -> void:
	_input.push(FakeInputReader.frame(Vector3.ZERO, false, false, false, true))


func test_scene_wires_the_knockback_to_movement_and_camera() -> void:
	assert_not_null(_knockback)
	assert_same(_knockback.movement, _player.movement)
	assert_same(_knockback.aim_source, _player.camera)
	assert_true(_player.weapon_holder.weapon_fired.is_connected(_knockback.on_fired))


func test_shooting_the_floor_while_standing_gives_a_small_shove() -> void:
	await _settle()
	_aim_down()
	assert_true(_player.movement.is_on_floor())
	_fire_secondary()
	_player.advance(DT)
	assert_signal_emitted(_knockback, "knocked")
	var impulse: Vector3 = _knockback.last_impulse
	assert_gt(impulse.y, 0.0, "pushed up off the floor")
	assert_almost_eq(
		impulse.y, _knockback.shotgun_impulse * _knockback.grounded_scale, 0.01, "the ground eats most of it"
	)


func test_shooting_the_floor_mid_jump_gives_the_full_launch() -> void:
	await _settle()
	_aim_down()
	_input.push(FakeInputReader.frame(Vector3.ZERO, false, true))
	_player.advance(DT)
	assert_false(_player.movement.is_on_floor(), "the jump tick already left the floor")
	_fire_secondary()
	_player.advance(DT)
	assert_almost_eq(_knockback.last_impulse.y, _knockback.shotgun_impulse, 0.01)


func test_the_launch_actually_reaches_a_higher_apex_than_a_plain_jump() -> void:
	await _settle()
	var plain := await _jump_apex(false)
	_player.global_position = Vector3(0, 0.05, 0)
	_player.velocity = Vector3.ZERO
	await _settle()
	var boosted := await _jump_apex(true)
	assert_gt(boosted, plain * 2.0, "shotgun jump %f vs plain jump %f" % [boosted, plain])
	assert_lt(boosted, 12.0, "and not into orbit")


func test_a_shot_at_the_open_sky_pushes_nothing() -> void:
	await _settle()
	_player.camera_rig.rotation.x = PI / 2.0  # straight up, nothing above the arena
	_fire_secondary()
	_player.advance(DT)
	assert_eq(_knockback.last_distance, -1.0, "clear ray")
	assert_eq(_knockback.last_impulse, Vector3.ZERO)
	assert_signal_not_emitted(_knockback, "knocked")


func test_a_floor_further_than_max_range_pushes_nothing() -> void:
	await _settle()
	_aim_down()
	_player.global_position = Vector3(0, 40.0, 0)
	await wait_physics_frames(1)
	_fire_secondary()
	_player.advance(DT)
	assert_eq(_knockback.last_impulse, Vector3.ZERO, "too high to push off the floor")


func test_the_stream_does_not_shove_the_player_by_default() -> void:
	await _settle()
	_aim_down()
	assert_eq(_knockback.stream_impulse, 0.0)
	_input.push(FakeInputReader.frame(Vector3.ZERO, false, false, true, false))
	_player.advance(DT)
	assert_eq(_knockback.last_impulse, Vector3.ZERO)


func test_strength_for_scales_the_volley_but_counts_stream_daggers() -> void:
	_knockback.stream_impulse = 0.5
	assert_almost_eq(_knockback.strength_for(12, &"shotgun", false), _knockback.shotgun_impulse, 0.0001)
	assert_almost_eq(_knockback.strength_for(1, &"shotgun", false), _knockback.shotgun_impulse, 0.0001)
	assert_almost_eq(_knockback.strength_for(3, &"stream", false), 1.5, 0.0001)
	assert_almost_eq(
		_knockback.strength_for(12, &"shotgun", true), _knockback.shotgun_impulse * _knockback.grounded_scale, 0.0001
	)


func test_upward_speed_is_capped_however_many_volleys_land() -> void:
	await _settle()
	_aim_down()
	for i in 8:
		_knockback.on_fired(12, &"shotgun")
		_player.advance(DT)
	assert_true(_player.velocity.y <= _knockback.max_up_speed + 0.01, "capped at %f" % _player.velocity.y)


## Jumps, optionally shotgunning the floor on the way up, and returns the peak height.
func _jump_apex(shotgun: bool) -> float:
	var start := _player.global_position.y
	_input.push(FakeInputReader.frame(Vector3.ZERO, false, true))
	_player.advance(DT)
	if shotgun:
		_aim_down()
		_fire_secondary()
		_player.advance(DT)
	var peak := 0.0
	for i in 240:
		await wait_physics_frames(1)
		peak = maxf(peak, _player.global_position.y - start)
		if i > 10 and _player.movement.is_on_floor():
			break
	return peak
