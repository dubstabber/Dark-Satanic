extends GameTest

const DT := 1.0 / 60.0
const FORWARD := Vector3(0, 0, -1)

var _stats: PlayerMovementStats


func before_each() -> void:
	super.before_each()
	_stats = load("res://src/player/resources/default_movement.tres")


func _speed(vel: Vector3) -> float:
	return MovementSolver.horizontal_speed(vel)


func test_default_resource_matches_design_numbers() -> void:
	assert_eq(_stats.walk_speed, 9.0)
	assert_eq(_stats.ground_accel, 10.0)
	assert_eq(_stats.friction, 6.0)
	assert_eq(_stats.stop_speed, 1.0)
	assert_eq(_stats.air_accel, 12.0)
	assert_eq(_stats.air_speed_cap, 1.0)
	assert_eq(_stats.air_control_accel, 0.8)
	assert_eq(_stats.gravity, 18.0)
	assert_eq(_stats.jump_velocity, 7.0)
	assert_eq(_stats.jump_horizontal_boost, 1.08)
	assert_eq(_stats.max_bhop_speed, 14.0)
	assert_true(_stats.auto_bhop)
	assert_eq(_stats.coyote_time, 0.1)
	assert_eq(_stats.jump_buffer_time, 0.15)
	assert_eq(_stats.pitch_limit_deg, 89.0)
	assert_eq(_stats.camera_height, 1.6)


func test_accelerate_adds_along_wish_dir_up_to_wish_speed() -> void:
	var vel := Vector3.ZERO
	for i in 600:
		vel = MovementSolver.accelerate(vel, FORWARD, 9.0, 10.0, DT)
	assert_almost_eq(vel.z, -9.0, 0.001, "capped at wish speed")
	assert_eq(vel.x, 0.0)
	assert_eq(vel.y, 0.0)


func test_accelerate_single_tick_is_accel_times_wish_speed_times_dt() -> void:
	var vel := MovementSolver.accelerate(Vector3.ZERO, FORWARD, 9.0, 10.0, DT)
	assert_almost_eq(vel.z, -9.0 * 10.0 * DT, 0.0001)


func test_accelerate_does_nothing_when_already_faster_along_wish_dir() -> void:
	var vel := Vector3(0, 0, -12)
	assert_eq(MovementSolver.accelerate(vel, FORWARD, 9.0, 10.0, DT), vel)


func test_accelerate_ignores_zero_wish_dir_and_zero_wish_speed() -> void:
	var vel := Vector3(1, 2, 3)
	assert_eq(MovementSolver.accelerate(vel, Vector3.ZERO, 9.0, 10.0, DT), vel)
	assert_eq(MovementSolver.accelerate(vel, FORWARD, 0.0, 10.0, DT), vel)


func test_friction_decays_to_zero_and_leaves_y_alone() -> void:
	var vel := Vector3(6, -3, 6)
	var previous := _speed(vel)
	for i in 120:
		vel = MovementSolver.apply_friction(vel, 6.0, 1.0, DT)
		assert_true(_speed(vel) <= previous, "friction never adds speed")
		previous = _speed(vel)
		assert_eq(vel.y, -3.0)
	assert_eq(_speed(vel), 0.0, "stop_speed makes the last bit of speed drop to exactly zero")


func test_friction_on_zero_velocity_is_zero() -> void:
	assert_eq(MovementSolver.apply_friction(Vector3(0, 5, 0), 6.0, 1.0, DT), Vector3(0, 5, 0))


func test_friction_never_reverses_direction() -> void:
	var vel := MovementSolver.apply_friction(Vector3(0.001, 0, 0), 6.0, 1.0, 1.0)
	assert_eq(vel, Vector3.ZERO)


func test_air_accel_gains_less_than_ground_accel() -> void:
	var ground := MovementSolver.step(Vector3.ZERO, FORWARD, true, false, false, _stats, DT)
	var air := MovementSolver.step(Vector3.ZERO, FORWARD, false, false, false, _stats, DT)
	assert_gt(_speed(ground), _speed(air))
	assert_almost_eq(_speed(air), (12.0 * 1.0 + 0.8 * 9.0) * DT, 0.0001)


func test_air_strafe_speed_is_capped_at_air_speed_cap_along_wish() -> void:
	var vel := Vector3.ZERO
	for i in 600:
		vel = MovementSolver.air_accelerate(vel, FORWARD, _stats, DT)
	assert_almost_eq(vel.z, -9.0, 0.01, "air control still climbs slowly to walk speed")
	var fast := MovementSolver.accelerate(Vector3(0, 0, -5), FORWARD, 1.0, 12.0, DT)
	assert_eq(fast, Vector3(0, 0, -5), "strafe term adds nothing past the cap")


func test_ground_walk_converges_to_walk_speed() -> void:
	var vel := Vector3.ZERO
	for i in 300:
		vel = MovementSolver.step(vel, FORWARD, true, false, false, _stats, DT)
	assert_almost_eq(_speed(vel), 9.0, 0.05)


func test_ground_tick_applies_friction_and_gravity() -> void:
	var vel := MovementSolver.step(Vector3(5, 0, 0), Vector3.ZERO, true, false, false, _stats, DT)
	assert_lt(vel.x, 5.0)
	assert_almost_eq(vel.y, -18.0 * DT, 0.0001)


func test_jump_tick_skips_friction_and_boosts_horizontal_speed() -> void:
	var vel := Vector3(0, 0, -9)
	var out := MovementSolver.step(vel, Vector3.ZERO, true, true, false, _stats, DT)
	assert_almost_eq(_speed(out), 9.0 * 1.08, 0.0001)
	assert_almost_eq(out.y, 7.0 - 18.0 * DT, 0.0001)


func test_jump_boost_is_clamped_to_max_bhop_speed() -> void:
	var out := MovementSolver.jump(Vector3(0, 0, -13.5), _stats)
	assert_almost_eq(_speed(out), 14.0, 0.0001)
	var faster := MovementSolver.jump(Vector3(0, 0, -16.0), _stats)
	assert_almost_eq(_speed(faster), 16.0, 0.0001, "already past the cap: no boost, no slowdown")


func test_jump_from_standstill_has_no_horizontal_speed() -> void:
	var out := MovementSolver.jump(Vector3.ZERO, _stats)
	assert_eq(out, Vector3(0, 7, 0))


func test_no_nan_on_zero_wish_dir_in_every_mode() -> void:
	for on_floor in [true, false]:
		for jump in [true, false]:
			var out := MovementSolver.step(Vector3.ZERO, Vector3.ZERO, on_floor, jump, jump, _stats, DT)
			assert_true(out.is_finite(), "finite for floor=%s jump=%s" % [on_floor, jump])
	assert_eq(MovementSolver.flatten(Vector3.ZERO), Vector3.ZERO)
	assert_eq(MovementSolver.flatten(Vector3(0, 3, 0)), Vector3.ZERO)


func test_step_normalises_and_flattens_wish_dir() -> void:
	var out := MovementSolver.step(Vector3.ZERO, Vector3(0, 5, -4), true, false, false, _stats, DT)
	assert_eq(out.x, 0.0)
	assert_almost_eq(out.z, -9.0 * 10.0 * DT, 0.0001, "(0,5,-4) is treated as unit -Z")


func test_integrated_jump_reaches_apex_height() -> void:
	var dt := 0.001
	var vel := MovementSolver.step(Vector3.ZERO, Vector3.ZERO, true, true, false, _stats, dt)
	var height := vel.y * dt
	var peak := height
	for i in 5000:
		vel = MovementSolver.step(vel, Vector3.ZERO, false, false, false, _stats, dt)
		height += vel.y * dt
		peak = maxf(peak, height)
		if vel.y < 0.0 and height < peak:
			break
	var ideal := MovementSolver.jump_apex_height(_stats)
	assert_almost_eq(ideal, 49.0 / 36.0, 0.0001)
	assert_almost_eq(peak, ideal, ideal * 0.01)


func test_jump_apex_height_with_zero_gravity_is_infinite() -> void:
	var stats := PlayerMovementStats.new()
	stats.gravity = 0.0
	assert_eq(MovementSolver.jump_apex_height(stats), INF)


func test_held_jump_with_auto_bhop_rejumps_on_landing() -> void:
	assert_true(MovementSolver.wants_jump(true, false, true, _stats))
	var out := MovementSolver.step(Vector3(0, 0, -9), Vector3.ZERO, true, false, true, _stats, DT)
	assert_gt(out.y, 0.0)


func test_auto_bhop_off_needs_a_press() -> void:
	var stats := PlayerMovementStats.new()
	stats.auto_bhop = false
	assert_false(MovementSolver.wants_jump(true, false, true, stats))
	assert_true(MovementSolver.wants_jump(true, true, true, stats))
	var held := MovementSolver.step(Vector3(0, 0, -9), Vector3.ZERO, true, false, true, stats, DT)
	assert_lt(held.y, 0.0, "held only: stays grounded (gravity)")
	assert_lt(_speed(held), 9.0, "friction applied on a non-jump ground tick")


func test_cannot_jump_in_the_air() -> void:
	assert_false(MovementSolver.wants_jump(false, true, true, _stats))
	var out := MovementSolver.step(Vector3(0, -2, 0), Vector3.ZERO, false, true, true, _stats, DT)
	assert_lt(out.y, -2.0)


func test_step_with_jump_matches_step_for_every_input_edge() -> void:
	for on_floor in [true, false]:
		for pressed in [true, false]:
			for held in [true, false]:
				var vel := Vector3(3, 1, -7)
				var expected := MovementSolver.step(vel, FORWARD, on_floor, pressed, held, _stats, DT)
				var jumping := MovementSolver.wants_jump(on_floor, pressed, held, _stats)
				var got := MovementSolver.step_with_jump(vel, FORWARD, on_floor, jumping, _stats, DT)
				assert_almost_eq(got, expected, Vector3.ONE * 0.000001, "floor=%s press=%s held=%s" % [on_floor, pressed, held])


func test_a_coyote_jump_is_a_jump_tick_not_a_ground_tick() -> void:
	# Airborne but jumping: MovementController's coyote grace. It must take the jump
	# branch and skip friction, not fall through to the ground branch.
	var vel := Vector3(0, -1, -9)
	var out := MovementSolver.step_with_jump(vel, Vector3.ZERO, false, true, _stats, DT)
	assert_almost_eq(out.y, _stats.jump_velocity - _stats.gravity * DT, 0.0001)
	assert_almost_eq(_speed(out), 9.0 * _stats.jump_horizontal_boost, 0.0001, "no friction on the jump tick")


func test_step_with_jump_false_on_the_floor_is_an_ordinary_ground_tick() -> void:
	var out := MovementSolver.step_with_jump(Vector3(5, 0, 0), Vector3.ZERO, true, false, _stats, DT)
	assert_lt(out.x, 5.0, "friction applied")
	assert_almost_eq(out.y, -_stats.gravity * DT, 0.0001)


func test_bunny_hopping_ends_faster_than_walk_speed_but_under_cap() -> void:
	var vel := Vector3(0, 0, -9)
	var on_floor := true
	var height := 0.0
	for i in 600:
		vel = MovementSolver.step(vel, FORWARD, on_floor, false, true, _stats, DT)
		height = maxf(height + vel.y * DT, 0.0)
		on_floor = height <= 0.0 and vel.y <= 0.0
	assert_gt(_speed(vel), 9.0)
	assert_true(_speed(vel) <= 14.0 + 0.01)
