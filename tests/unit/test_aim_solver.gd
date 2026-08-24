extends GameTest

const FORWARD := Vector3(0, 0, -1)


func test_clear_ray_converges_at_max_distance() -> void:
	var point := AimSolver.convergence_point(Vector3.ZERO, FORWARD, -1.0, 40.0, 1.5)
	assert_almost_eq(point, Vector3(0, 0, -40), Vector3.ONE * 0.0001)


func test_hit_distance_wins_over_max_distance() -> void:
	var point := AimSolver.convergence_point(Vector3.ZERO, FORWARD, 6.0, 40.0, 1.5)
	assert_almost_eq(point, Vector3(0, 0, -6), Vector3.ONE * 0.0001)


func test_near_hit_is_clamped_to_min_distance() -> void:
	var point := AimSolver.convergence_point(Vector3.ZERO, FORWARD, 0.2, 40.0, 1.5)
	assert_almost_eq(point, Vector3(0, 0, -1.5), Vector3.ONE * 0.0001, "a wall on the face never swings the aim")


func test_far_hit_is_clamped_to_max_distance() -> void:
	var point := AimSolver.convergence_point(Vector3.ZERO, FORWARD, 900.0, 40.0, 1.5)
	assert_almost_eq(point, Vector3(0, 0, -40), Vector3.ONE * 0.0001)


func test_min_distance_above_max_distance_does_not_invert_the_clamp() -> void:
	var point := AimSolver.convergence_point(Vector3.ZERO, FORWARD, 5.0, 2.0, 10.0)
	assert_almost_eq(point, Vector3(0, 0, -2), Vector3.ONE * 0.0001)


func test_origin_and_unnormalised_forward_are_respected() -> void:
	var point := AimSolver.convergence_point(Vector3(1, 2, 3), Vector3(0, 0, -7), -1.0, 10.0, 1.0)
	assert_almost_eq(point, Vector3(1, 2, -7), Vector3.ONE * 0.0001)


func test_zero_forward_falls_back_to_minus_z() -> void:
	var point := AimSolver.convergence_point(Vector3.ZERO, Vector3.ZERO, -1.0, 5.0, 1.0)
	assert_almost_eq(point, Vector3(0, 0, -5), Vector3.ONE * 0.0001)


func test_direction_points_the_muzzle_at_the_convergence_point() -> void:
	var dir := AimSolver.direction(Vector3(1, 0, 0), Vector3(0, 0, -1), FORWARD)
	assert_almost_eq(dir, Vector3(-1, 0, -1).normalized(), Vector3.ONE * 0.0001)
	assert_almost_eq(dir.length(), 1.0, 0.0001)


func test_direction_falls_back_when_muzzle_sits_on_the_point() -> void:
	var dir := AimSolver.direction(Vector3(2, 2, 2), Vector3(2, 2, 2), Vector3(0, 0, -3))
	assert_almost_eq(dir, FORWARD, Vector3.ONE * 0.0001, "normalised fallback")
	assert_almost_eq(AimSolver.direction(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), FORWARD, Vector3.ONE * 0.0001)


func test_offset_muzzle_crosses_the_crosshair_line() -> void:
	# A muzzle 0.3 m right of the camera, converging 40 m out: the launch direction
	# must lean left so the flight path meets the crosshair line at the target.
	var camera := Vector3.ZERO
	var muzzle := Vector3(0.3, -0.2, -0.9)
	var point := AimSolver.convergence_point(camera, FORWARD, -1.0, 40.0, 1.5)
	var dir := AimSolver.direction(muzzle, point, FORWARD)
	assert_lt(dir.x, 0.0, "leans back toward the crosshair")
	assert_gt(dir.y, 0.0)
	var arrival := muzzle + dir * muzzle.distance_to(point)
	assert_almost_eq(arrival, point, Vector3.ONE * 0.0001, "the flight path lands on the crosshair point")
