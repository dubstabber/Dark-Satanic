extends GameTest

var _arena: ArenaInfo
var _rng: RandomNumberGenerator


func before_each() -> void:
	super.before_each()
	_arena = ArenaInfo.new(Vector3(2, 0, -3), 20.0, 0.0, Vector3(2, 1, -3))
	_rng = RandomNumberGenerator.new()
	_rng.seed = 42


func _radial(p: Vector3) -> float:
	return Vector2(p.x - _arena.center.x, p.z - _arena.center.z).length()


func _assert_all_on_platform(points: Array[Vector3]) -> void:
	for p in points:
		assert_true(_arena.is_on_platform(p), "%s is on the platform" % p)


func test_ring_count_radius_and_spacing() -> void:
	var pattern := RingPattern.new()
	pattern.radius_fraction = 0.5
	pattern.height = 2.0
	pattern.angle_offset_deg = 0.0
	var points := pattern.positions(4, _arena, _rng)
	assert_eq(points.size(), 4)
	_assert_all_on_platform(points)
	for p in points:
		assert_almost_eq(_radial(p), 10.0, 0.001)
		assert_almost_eq(p.y, 2.0, 0.001)
	assert_almost_eq(points[0], _arena.center + Vector3(10, 2, 0), Vector3.ONE * 0.001)
	assert_almost_eq(points[1], _arena.center + Vector3(0, 2, 10), Vector3.ONE * 0.001)
	for i in 4:
		var a := points[i] - _arena.center
		var b := points[(i + 1) % 4] - _arena.center
		assert_almost_eq(a.distance_to(b), 10.0 * sqrt(2.0), 0.001, "neighbours are evenly spaced")


func test_ring_random_offset_is_seeded() -> void:
	var pattern := RingPattern.new()
	var a := pattern.positions(3, _arena, _seeded(7))
	var b := pattern.positions(3, _arena, _seeded(7))
	var c := pattern.positions(3, _arena, _seeded(8))
	assert_eq(a, b)
	assert_ne(a, c)
	for p in a:
		assert_almost_eq(_radial(p), 18.0, 0.001)


func test_ring_jitter_stays_on_radius() -> void:
	var pattern := RingPattern.new()
	pattern.jitter = 30.0
	pattern.angle_offset_deg = 10.0
	var points := pattern.positions(6, _arena, _rng)
	_assert_all_on_platform(points)
	for p in points:
		assert_almost_eq(_radial(p), 18.0, 0.001)


func test_ring_count_zero_and_fraction_clamped() -> void:
	var pattern := RingPattern.new()
	assert_eq(pattern.positions(0, _arena, _rng).size(), 0)
	assert_eq(pattern.positions(-2, _arena, _rng).size(), 0)
	pattern.radius_fraction = 5.0
	for p in pattern.positions(3, _arena, _rng):
		assert_true(_arena.is_on_platform(p))
		assert_almost_eq(_radial(p), 20.0, 0.001)


func test_random_edge_annulus_and_heights() -> void:
	var pattern := RandomEdgePattern.new()
	var points := pattern.positions(50, _arena, _rng)
	assert_eq(points.size(), 50)
	_assert_all_on_platform(points)
	for p in points:
		assert_between(_radial(p), 12.0 - 0.001, 19.0 + 0.001)
		assert_between(p.y, 1.0, 3.0)
	assert_eq(pattern.positions(0, _arena, _rng).size(), 0)


func test_random_edge_is_seeded() -> void:
	var pattern := RandomEdgePattern.new()
	assert_eq(pattern.positions(5, _arena, _seeded(3)), pattern.positions(5, _arena, _seeded(3)))
	assert_ne(pattern.positions(5, _arena, _seeded(3)), pattern.positions(5, _arena, _seeded(4)))


func test_random_edge_swapped_bounds() -> void:
	var pattern := RandomEdgePattern.new()
	pattern.min_radius_fraction = 0.9
	pattern.max_radius_fraction = 0.5
	pattern.height_min = 4.0
	pattern.height_max = 4.0
	for p in pattern.positions(20, _arena, _rng):
		assert_between(_radial(p), 10.0 - 0.001, 18.0 + 0.001)
		assert_almost_eq(p.y, 4.0, 0.001)


func test_opposite_player_is_on_far_side() -> void:
	_arena.target_position = _arena.center + Vector3(10, 1, 0)
	var pattern := OppositePlayerPattern.new()
	var single := pattern.positions(1, _arena, _rng)
	assert_eq(single.size(), 1)
	assert_almost_eq(single[0], _arena.center + Vector3(-18, 1.5, 0), Vector3.ONE * 0.001)
	var many := pattern.positions(5, _arena, _rng)
	_assert_all_on_platform(many)
	for p in many:
		assert_almost_eq(_radial(p), 18.0, 0.001)
		assert_lt(p.x, _arena.center.x - 15.0, "all on the opposite side")
		var angle := rad_to_deg(absf(atan2(p.z - _arena.center.z, -(p.x - _arena.center.x))))
		assert_lte(angle, 20.0 + 0.001, "inside the 40 degree spread")


func test_opposite_player_spread_is_symmetric() -> void:
	_arena.target_position = _arena.center + Vector3(0, 0, 5)
	var pattern := OppositePlayerPattern.new()
	pattern.spread_deg = 90.0
	var points := pattern.positions(2, _arena, _rng)
	assert_almost_eq(points[0].x, -points[1].x + 2.0 * _arena.center.x, 0.001)
	assert_almost_eq(points[0].z, points[1].z, 0.001)
	assert_lt(points[0].z, _arena.center.z)


func test_opposite_player_without_target_is_seeded_random() -> void:
	_arena.target_position = _arena.center
	var pattern := OppositePlayerPattern.new()
	assert_eq(pattern.positions(2, _arena, _seeded(9)), pattern.positions(2, _arena, _seeded(9)))
	assert_eq(pattern.positions(0, _arena, _rng).size(), 0)


func test_point_pattern_fixed_and_jittered() -> void:
	var pattern := PointPattern.new()
	pattern.point = Vector3(0, 1, 5)
	var points := pattern.positions(2, _arena, _rng)
	assert_eq(points.size(), 2)
	assert_eq(points[0], _arena.center + Vector3(0, 1, 5))
	assert_eq(points[1], points[0])
	pattern.height = 3.0
	assert_almost_eq(pattern.positions(1, _arena, _rng)[0].y, 3.0, 0.001)
	pattern.jitter = 2.0
	var jittered := pattern.positions(10, _arena, _rng)
	for p in jittered:
		assert_between(p.x, _arena.center.x - 2.0, _arena.center.x + 2.0)
		assert_between(p.z, _arena.center.z + 3.0, _arena.center.z + 7.0)
	assert_eq(pattern.positions(0, _arena, _rng).size(), 0)


func test_point_pattern_clamped_to_platform() -> void:
	var pattern := PointPattern.new()
	pattern.point = Vector3(100, 1, 0)
	var p := pattern.positions(1, _arena, _rng)[0]
	assert_true(_arena.is_on_platform(p))
	assert_almost_eq(_radial(p), 20.0, 0.001)


func _seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
