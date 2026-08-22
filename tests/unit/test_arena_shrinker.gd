extends GameTest


func _shrinker() -> ArenaShrinker:
	var shrinker := ArenaShrinker.new()
	autofree(shrinker)
	return shrinker


func test_linear_schedule() -> void:
	var shrinker := _shrinker()
	assert_eq(shrinker.start_time, 60.0)
	assert_eq(shrinker.end_time, 420.0)
	assert_eq(shrinker.end_radius, 12.0)
	assert_almost_eq(shrinker.radius_at(0.0, 30.0), 30.0, 0.001)
	assert_almost_eq(shrinker.radius_at(60.0, 30.0), 30.0, 0.001)
	assert_almost_eq(shrinker.radius_at(240.0, 30.0), 21.0, 0.001, "halfway")
	assert_almost_eq(shrinker.radius_at(420.0, 30.0), 12.0, 0.001)
	assert_almost_eq(shrinker.radius_at(9999.0, 30.0), 12.0, 0.001)


func test_monotonic() -> void:
	var shrinker := _shrinker()
	var previous := shrinker.radius_at(0.0, 30.0)
	for i in range(1, 500):
		var current := shrinker.radius_at(float(i), 30.0)
		assert_true(current <= previous + 0.0001, "never grows at t=%d" % i)
		previous = current


func test_curve_respected() -> void:
	var shrinker := _shrinker()
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.5, 1.0))
	curve.add_point(Vector2(1.0, 1.0))
	shrinker.curve = curve
	assert_almost_eq(shrinker.shrink_fraction(240.0), 1.0, 0.01, "curve hits 1 at half progress")
	assert_almost_eq(shrinker.radius_at(240.0, 30.0), 12.0, 0.2)
	assert_almost_eq(shrinker.radius_at(60.0, 30.0), 30.0, 0.2)


func test_degenerate_window() -> void:
	var shrinker := _shrinker()
	shrinker.start_time = 100.0
	shrinker.end_time = 100.0
	assert_almost_eq(shrinker.radius_at(99.0, 30.0), 30.0, 0.001)
	assert_almost_eq(shrinker.radius_at(100.0, 30.0), 12.0, 0.001)


func test_without_arena_uses_default_start_radius() -> void:
	var shrinker := _shrinker()
	assert_almost_eq(shrinker.radius_at(0.0), 30.0, 0.001)
	shrinker.advance(500.0)
	pass_test("advance without an arena is a no-op")
