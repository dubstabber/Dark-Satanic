extends GameTest

const FORWARD := Vector3(0, 0, -1)
const WALK_SPEED := 9.0

var _world: Node3D
var _input: FakeInputReader
var _player: Player


func before_each() -> void:
	super.before_each()
	_world = make_world()
	PlayerTestWorld.add_floor(_world)
	_input = FakeInputReader.new()
	_player = PlayerTestWorld.spawn_player(_world, _input)
	watch_signals(_player.movement)


func _speed() -> float:
	return _player.movement.horizontal_speed()


func test_scene_wiring_matches_contract() -> void:
	assert_eq(_player.collision_layer, PhysicsLayers.PLAYER)
	assert_eq(_player.collision_mask, PhysicsLayers.WORLD)
	assert_true(_player.is_in_group("player"))
	assert_not_null(_player.health)
	assert_eq(_player.health.max_health, 1.0)
	assert_not_null(_player.movement)
	assert_same(_player.movement.body, _player)
	assert_not_null(_player.movement.stats)
	assert_not_null(_player.look)
	assert_same(_player.look.yaw_target, _player)
	assert_same(_player.look.pitch_target, _player.camera_rig)
	assert_not_null(_player.weapon_holder)
	assert_same(_player.weapon_holder.aim_source, _player.camera)
	assert_eq(_player.weapon_holder.muzzle.name, "Muzzle")
	assert_same(_player.weapon_holder.projectile_root, _world)
	assert_null(_player.weapon_holder.weapon)
	assert_not_null(_player.pickup_collector)
	assert_eq(_player.pickup_collector.collision_layer, PhysicsLayers.PICKUP)
	assert_eq(_player.camera.fov, 100.0)
	assert_almost_eq(_player.camera_rig.position.y, 1.6, 0.001)
	var hurtbox: HurtboxComponent = _player.get_node("Hurtbox")
	assert_eq(hurtbox.collision_layer, PhysicsLayers.PLAYER_HURTBOX)
	assert_same(hurtbox.health, _player.health)
	assert_same(_player.input_reader, _input)


func test_child_input_reader_is_found_when_not_injected() -> void:
	var player: Player = PlayerTestWorld.PlayerScene.instantiate()
	_world.add_child(player)
	assert_not_null(player.input_reader)
	assert_true(player.input_reader is InputReader)
	assert_eq(player.input_reader.name, "InputReader")


func test_setup_sets_mouse_sensitivity() -> void:
	_player.setup(0.0042)
	assert_almost_eq(_player.look.sensitivity, 0.0042, 0.00001)


func test_lands_on_floor_and_never_falls_through() -> void:
	var lowest := 0.0
	for i in 90:
		await wait_physics_frames(1)
		lowest = minf(lowest, _player.position.y)
	assert_true(_player.is_on_floor())
	assert_gt(lowest, -0.02, "lowest y %f" % lowest)
	assert_signal_emitted(_player.movement, "landed")


func test_walks_forward_at_walk_speed() -> void:
	_input.push(FakeInputReader.frame(FORWARD))
	await wait_physics_frames(120)
	assert_almost_eq(_speed(), WALK_SPEED, 0.3)
	assert_lt(_player.position.z, -10.0, "moved forward")
	assert_almost_eq(_player.position.x, 0.0, 0.01)


func test_stops_when_input_released() -> void:
	_input.push_repeated(FakeInputReader.frame(FORWARD), 90)
	await wait_physics_frames(90)
	assert_gt(_speed(), 8.0)
	_input.push(FakeInputReader.frame())
	await wait_physics_frames(90)
	assert_lt(_speed(), 0.05)
	assert_true(_player.is_on_floor())


func test_bunny_hopping_for_three_seconds_ends_faster_than_walk_speed() -> void:
	# Warm up on the ground, then strafe-jump: hold jump and wiggle the wish dir.
	_input.push_repeated(FakeInputReader.frame(FORWARD), 60)
	var left := FORWARD.rotated(Vector3.UP, deg_to_rad(25.0))
	var right := FORWARD.rotated(Vector3.UP, deg_to_rad(-25.0))
	for i in 180:
		var dir: Vector3 = left if (i / 15) % 2 == 0 else right
		_input.push(FakeInputReader.frame(dir, true))
	await wait_physics_frames(240)
	var lowest := 0.0
	for i in 60:
		await wait_physics_frames(1)
		lowest = minf(lowest, _player.position.y)
	assert_gt(_speed(), WALK_SPEED)
	assert_true(_speed() <= 14.05, "never past max_bhop_speed (%f)" % _speed())
	assert_signal_emitted(_player.movement, "jumped")
	assert_gt(get_signal_emit_count(_player.movement, "jumped"), 2)
	assert_gt(lowest, -0.02, "never fell through the floor")


func test_jump_press_leaves_floor_and_lands_again() -> void:
	await wait_physics_frames(10)
	_input.push(FakeInputReader.frame(Vector3.ZERO, false, true))
	await wait_physics_frames(3)
	assert_false(_player.is_on_floor())
	assert_signal_emit_count(_player.movement, "jumped", 1)
	var peak := 0.0
	for i in 80:
		await wait_physics_frames(1)
		peak = maxf(peak, _player.position.y)
	assert_true(_player.is_on_floor())
	assert_almost_eq(peak, MovementSolver.jump_apex_height(_player.movement.stats), 0.15)
	var fall_speed: float = get_signal_parameters(_player.movement, "landed")[0]
	assert_gt(fall_speed, 3.0)


func test_wish_dir_uses_body_yaw() -> void:
	await wait_physics_frames(5)
	assert_almost_eq(_input.last_yaw_basis.z, Vector3(0, 0, 1), Vector3.ONE * 0.001)
	_player.rotation.y = deg_to_rad(90.0)
	await wait_physics_frames(2)
	assert_almost_eq(_input.last_yaw_basis.z, Vector3(1, 0, 0), Vector3.ONE * 0.001)


func test_camera_bobs_only_while_walking() -> void:
	await wait_physics_frames(120)  # land and let the landing dip recover
	var rest: float = _player.camera.position.y
	assert_almost_eq(rest, 0.0, 0.002, "camera at rest before walking")
	_input.push(FakeInputReader.frame(FORWARD))
	var max_offset := 0.0
	for i in 60:
		await wait_physics_frames(1)
		max_offset = maxf(max_offset, absf(_player.camera.position.y - rest))
	assert_gt(max_offset, 0.005, "camera bobbed")
	_input.push(FakeInputReader.frame())
	await wait_physics_frames(120)
	assert_almost_eq(_player.camera.position.y, rest, 0.002, "settles at rest when stopped")


func test_look_delta_in_frame_rotates_body_and_camera() -> void:
	_player.setup(0.01)
	_input.push(FakeInputReader.frame(Vector3.ZERO, false, false, false, false, Vector2(100, -50)))
	await wait_physics_frames(2)
	assert_almost_eq(_player.rotation.y, -1.0, 0.0001)
	assert_almost_eq(_player.camera_rig.rotation.x, 0.5, 0.0001)
	assert_eq(_input.last_look_delta, Vector2.ZERO, "no real mouse motion was pending")


func test_last_frame_is_kept_for_inspection() -> void:
	_input.push(FakeInputReader.frame(FORWARD, true))
	await wait_physics_frames(2)
	assert_true(_player.last_frame.jump_held)


func test_hands_are_fed_body_space_velocity_not_world_space() -> void:
	# Yawed 90 degrees, "forward" in world space is -X. If the hands were handed world
	# velocity they would read that as a hard strafe and lean; body space reads it as a
	# straight run and does not.
	_player.rotation.y = deg_to_rad(90.0)
	_input.push_repeated(FakeInputReader.frame(Vector3.LEFT), 120)
	await wait_physics_frames(120)
	assert_gt(_player.hands.speed(), 5.0, "the hands can tell it is moving")
	assert_almost_eq(_player.local_velocity().z, -_player.movement.horizontal_speed(), 0.2, "running forward")
	assert_almost_eq(_player.local_velocity().x, 0.0, 0.2, "not strafing")
	assert_almost_eq(_player.hands.lean(), 0.0, 0.005, "so the hands do not lean")


func test_strafing_leans_the_hands_through_the_real_player() -> void:
	_player.rotation.y = deg_to_rad(90.0)
	_input.push_repeated(FakeInputReader.frame(Vector3.FORWARD), 120)  # world -Z = body right
	await wait_physics_frames(120)
	assert_gt(_player.local_velocity().x, 5.0, "strafing right in body space")
	assert_lt(_player.hands.lean(), -0.01, "the hands trail the other way")
	assert_gt(_player.hands.rotation.z, 0.0, "and roll with it")


func test_hands_stop_bobbing_when_the_player_leaves_the_floor() -> void:
	_input.push_repeated(FakeInputReader.frame(FORWARD), 60)
	await wait_physics_frames(60)
	assert_gt(_player.hands.bob_weight(), 0.5, "bobbing along the ground")
	_player.global_position = Vector3(0, 12, 0)
	_input.push_repeated(FakeInputReader.frame(FORWARD), 30)
	await wait_physics_frames(30)
	assert_false(_player.movement.is_on_floor())
	assert_almost_eq(_player.hands.bob_weight(), 0.0, 0.02, "airborne: nothing to bob against")
