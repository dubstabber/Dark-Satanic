extends GameTest

const DOWN := Vector3(0, -1, 0)


func test_falloff_is_full_up_to_full_range() -> void:
	assert_eq(KnockbackSolver.falloff(0.0, 3.0, 8.0), 1.0)
	assert_eq(KnockbackSolver.falloff(3.0, 3.0, 8.0), 1.0)


func test_falloff_is_linear_between_the_two_ranges() -> void:
	assert_almost_eq(KnockbackSolver.falloff(5.5, 3.0, 8.0), 0.5, 0.0001)
	assert_almost_eq(KnockbackSolver.falloff(4.0, 3.0, 8.0), 0.8, 0.0001)


func test_falloff_is_zero_past_max_range_and_on_a_clear_ray() -> void:
	assert_eq(KnockbackSolver.falloff(8.0, 3.0, 8.0), 0.0)
	assert_eq(KnockbackSolver.falloff(80.0, 3.0, 8.0), 0.0)
	assert_eq(KnockbackSolver.falloff(-1.0, 3.0, 8.0), 0.0, "nothing hit: nothing to push off")


func test_falloff_survives_a_degenerate_range_pair() -> void:
	assert_eq(KnockbackSolver.falloff(1.0, 5.0, 2.0), 1.0, "inside the full range either way")
	assert_eq(KnockbackSolver.falloff(6.0, 5.0, 5.0), 0.0)
	assert_true(is_finite(KnockbackSolver.falloff(5.0, 5.0, 5.0)))


func test_impulse_pushes_back_along_the_shot() -> void:
	var impulse := KnockbackSolver.impulse(DOWN, 1.6, 7.0, 3.0, 8.0)
	assert_almost_eq(impulse, Vector3(0, 7, 0), Vector3.ONE * 0.0001, "shoot the floor, go up")


func test_impulse_scales_with_the_falloff() -> void:
	var impulse := KnockbackSolver.impulse(DOWN, 5.5, 7.0, 3.0, 8.0)
	assert_almost_eq(impulse.y, 3.5, 0.0001)


func test_impulse_normalises_the_shot_direction() -> void:
	var impulse := KnockbackSolver.impulse(Vector3(0, -9, 0), 1.0, 4.0, 3.0, 8.0)
	assert_almost_eq(impulse, Vector3(0, 4, 0), Vector3.ONE * 0.0001)


func test_a_diagonal_shot_pushes_up_and_back() -> void:
	var impulse := KnockbackSolver.impulse(Vector3(0, -1, -1).normalized(), 1.0, 10.0, 3.0, 8.0)
	assert_gt(impulse.y, 0.0)
	assert_gt(impulse.z, 0.0, "shoved away from where the shot went")
	assert_almost_eq(impulse.length(), 10.0, 0.0001)


func test_no_impulse_without_strength_range_or_direction() -> void:
	assert_eq(KnockbackSolver.impulse(DOWN, 1.0, 0.0, 3.0, 8.0), Vector3.ZERO)
	assert_eq(KnockbackSolver.impulse(DOWN, 20.0, 7.0, 3.0, 8.0), Vector3.ZERO)
	assert_eq(KnockbackSolver.impulse(DOWN, -1.0, 7.0, 3.0, 8.0), Vector3.ZERO)
	assert_eq(KnockbackSolver.impulse(Vector3.ZERO, 1.0, 7.0, 3.0, 8.0), Vector3.ZERO)


func test_clamp_limits_horizontal_speed_without_changing_its_heading() -> void:
	var out := KnockbackSolver.clamp_velocity(Vector3(30, 2, 40), 10.0, 0.0)
	assert_almost_eq(Vector2(out.x, out.z).length(), 10.0, 0.0001)
	assert_almost_eq(Vector2(out.x, out.z).angle(), Vector2(30, 40).angle(), 0.0001)
	assert_eq(out.y, 2.0, "no vertical cap asked for")


func test_clamp_limits_rising_but_never_falling() -> void:
	assert_eq(KnockbackSolver.clamp_velocity(Vector3(0, 40, 0), 0.0, 15.0).y, 15.0)
	assert_eq(KnockbackSolver.clamp_velocity(Vector3(0, -40, 0), 0.0, 15.0).y, -40.0, "falling is never slowed")


func test_clamp_leaves_a_velocity_inside_the_caps_alone() -> void:
	var velocity := Vector3(3, 4, 5)
	assert_almost_eq(KnockbackSolver.clamp_velocity(velocity, 40.0, 40.0), velocity, Vector3.ONE * 0.0001)
	assert_almost_eq(KnockbackSolver.clamp_velocity(velocity, 0.0, 0.0), velocity, Vector3.ONE * 0.0001)
