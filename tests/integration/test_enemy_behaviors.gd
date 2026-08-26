extends GameTest

const DT := 1.0 / 60.0

var _world: Node3D
var _body: Node3D
var _target: Node3D
var _ctx: EnemyContext
# Lambdas capture locals by value, so samplers write into these instead.
var _min_y: float = INF
var _max_y: float = -INF
var _closest: float = INF
var _dive_min: float = INF
var _retreat_end: float = 0.0
var _orbit_samples: Array[float] = []
var _phases: Array[StringName] = []
var _gem_list: Array[Node3D] = []


func before_each() -> void:
	super.before_each()
	_world = make_world()
	_body = Node3D.new()
	_target = Node3D.new()
	_world.add_child(_body)
	_world.add_child(_target)
	_ctx = EnemyContext.new()
	_ctx.body = _body
	_ctx.target = _target
	_ctx.stats = EnemyStats.new()
	_ctx.rng.seed = 1234
	_ctx.arena_info = ArenaInfo.new(Vector3.ZERO, 30.0, 0.0)
	_min_y = INF
	_max_y = -INF
	_closest = INF
	_dive_min = INF
	_retreat_end = 0.0
	_orbit_samples = []
	_phases = []
	_gem_list = []


func _behavior(node: EnemyBehavior) -> EnemyBehavior:
	_world.add_child(node)
	watch_signals(node)
	return node


## Integrates the behaviour's desired velocity directly for `seconds`.
func _run(behavior: EnemyBehavior, seconds: float, on_step: Callable = Callable()) -> void:
	var steps := int(round(seconds / DT))
	for i in steps:
		var v := behavior.steer(_ctx, DT)
		_body.global_position += v * DT
		_ctx.elapsed += DT
		if on_step.is_valid():
			on_step.call()


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- Seek -------------------------------------------------------------------

func test_seek_closes_distance_at_move_speed() -> void:
	var seek := _behavior(SeekBehavior.new())
	_ctx.stats.move_speed = 7.0
	_target.position = Vector3(10, 0, 0)
	var v := seek.steer(_ctx, DT)
	assert_almost_eq(v.length(), 7.0, 0.001)
	assert_almost_eq(v.normalized().dot(Vector3.RIGHT), 1.0, 0.001)
	_run(seek, 1.0)
	assert_almost_eq(_body.global_position.distance_to(_target.global_position), 3.0, 0.05)


func test_seek_respects_turn_rate() -> void:
	var seek := _behavior(SeekBehavior.new())
	_ctx.stats.turn_speed_deg = 60.0
	_target.position = Vector3(10, 0, 0)
	seek.steer(_ctx, DT)
	_target.position = Vector3(0, 0, 10)
	var v := seek.steer(_ctx, 0.5)
	assert_almost_eq(rad_to_deg(Vector3.RIGHT.angle_to(v)), 30.0, 0.1, "only 30 degrees in half a second")
	seek.turn_speed_deg = 3600.0
	v = seek.steer(_ctx, 0.5)
	assert_almost_eq(rad_to_deg(Vector3.BACK.angle_to(v)), 0.0, 0.1, "override turn rate snaps")


func test_seek_slow_turner_overshoots() -> void:
	var seek := _behavior(SeekBehavior.new())
	_ctx.stats.move_speed = 7.0
	_ctx.stats.turn_speed_deg = 60.0
	_target.position = Vector3(6, 0, 0)
	_run(seek, 2.0, func() -> void: _closest = minf(_closest, _body.global_position.distance_to(_target.global_position)))
	assert_true(_body.global_position.x > 6.0, "flew past the target")
	assert_true(_body.global_position.distance_to(_target.global_position) > _closest)


func test_seek_in_flight_turns_in_three_dimensions() -> void:
	var seek := _behavior(SeekBehavior.new())
	seek.fly = true
	_ctx.stats.turn_speed_deg = 60.0
	_ctx.stats.move_speed = 6.0
	_target.position = Vector3(10, 0, 0)
	seek.steer(_ctx, DT)
	_target.position = Vector3(0, 10, 0)
	var v := seek.steer(_ctx, 0.5)
	assert_almost_eq(rad_to_deg(Vector3.RIGHT.angle_to(v)), 30.0, 0.1, "pitches up at the same limited rate")
	assert_true(v.y > 0.0, "climbing, not clamping")
	assert_almost_eq(v.length(), 6.0, 0.001, "always full speed, only ever pointed somewhere else")


func test_seek_aim_height_goes_for_the_chest_not_the_feet() -> void:
	var seek := _behavior(SeekBehavior.new())
	seek.fly = true
	seek.aim_height = 1.0
	_body.position = Vector3(0, 4, 0)
	_target.position = Vector3(0, 0, 6)
	var v := seek.steer(_ctx, 1.0)
	var to_chest := (Vector3(0, 1, 6) - _body.position).normalized()
	assert_almost_eq(v.normalized().dot(to_chest), 1.0, 0.001, "dives at 1 m above the target's origin")


func test_seek_without_target_is_still() -> void:
	var seek := _behavior(SeekBehavior.new())
	_ctx.target = null
	_body.position = Vector3.ZERO
	assert_eq(seek.steer(_ctx, DT), Vector3.ZERO)


# --- Separation -------------------------------------------------------------

func test_separation_pushes_apart_only_within_radius() -> void:
	var separation := _behavior(SeparationBehavior.new())
	separation.radius = 1.2
	var neighbor := Node3D.new()
	neighbor.position = Vector3(0.5, 0, 0)
	_world.add_child(neighbor)
	_ctx.neighbors_provider = func() -> Array[Node3D]: return [neighbor]
	var v := separation.steer(_ctx, DT)
	assert_true(v.x < 0.0, "pushed away from the neighbour")
	assert_eq(v.y, 0.0)
	neighbor.position = Vector3(2.0, 0, 0)
	assert_eq(separation.steer(_ctx, DT), Vector3.ZERO, "outside the radius: nothing")


func test_separation_handles_coincident_neighbor() -> void:
	var separation := _behavior(SeparationBehavior.new())
	var neighbor := Node3D.new()
	_world.add_child(neighbor)
	_ctx.neighbors_provider = func() -> Array[Node3D]: return [neighbor]
	var v := separation.steer(_ctx, DT)
	assert_true(v.length() > 0.0, "random push when exactly overlapping")


# --- Flock -------------------------------------------------------------------

func test_flock_pulls_toward_the_centre_of_the_neighbours() -> void:
	var flock := _behavior(FlockBehavior.new())
	flock.alignment = 0.0
	flock.cohesion = 0.5
	var near := Node3D.new()
	near.position = Vector3(2, 1, 0)
	var far := Node3D.new()
	far.position = Vector3(4, 3, 0)
	_world.add_child(near)
	_world.add_child(far)
	_ctx.neighbors_provider = func() -> Array[Node3D]: return [near, far]
	var v := flock.steer(_ctx, DT)
	assert_almost_eq(v.x, 1.5, 0.001, "half the offset to the middle of the pair")
	assert_almost_eq(v.y, 1.0, 0.001, "cohesion works in the air, not just on the ground")
	assert_almost_eq(v.z, 0.0, 0.001)


func test_flock_ignores_neighbours_outside_its_radius() -> void:
	var flock := _behavior(FlockBehavior.new())
	flock.radius = 3.0
	var far := Node3D.new()
	far.position = Vector3(10, 0, 0)
	_world.add_child(far)
	_ctx.neighbors_provider = func() -> Array[Node3D]: return [far]
	assert_eq(flock.steer(_ctx, DT), Vector3.ZERO, "as far as it can tell it is flying alone")


func test_flock_matches_the_velocity_of_the_swarm() -> void:
	var flock := _behavior(FlockBehavior.new())
	flock.cohesion = 0.0
	flock.alignment = 0.5
	var enemy := Enemy.new()
	var mover := EnemyMover.new()
	enemy.add_child(mover)
	enemy.position = Vector3(2, 0, 0)
	_world.add_child(enemy)
	enemy.set_physics_process(false)
	mover.velocity = Vector3(0, 0, 8)
	_ctx.neighbors_provider = func() -> Array[Node3D]: return [enemy]
	assert_almost_eq(flock.steer(_ctx, DT).z, 4.0, 0.001, "matches half of a neighbour's 8 m/s")
	var plain := Node3D.new()
	_world.add_child(plain)
	_ctx.neighbors_provider = func() -> Array[Node3D]: return [plain]
	assert_eq(flock.steer(_ctx, DT), Vector3.ZERO, "anything without a mover contributes no heading")


# --- Bob ---------------------------------------------------------------------

func test_bob_oscillates_around_zero() -> void:
	var bob := _behavior(BobBehavior.new())
	bob.amplitude = 0.25
	bob.frequency = 1.0
	_run(bob, 2.0, func() -> void:
		_min_y = minf(_min_y, _body.global_position.y)
		_max_y = maxf(_max_y, _body.global_position.y))
	assert_almost_eq(_body.global_position.y, 0.0, 0.02, "back where it started after whole periods")
	assert_almost_eq(_max_y - _min_y, 0.5, 0.03, "peak-to-peak is twice the amplitude")
	assert_true(_min_y < 0.0 and _max_y > 0.0)


func test_bob_phase_comes_from_rng() -> void:
	var a := _behavior(BobBehavior.new())
	var b := _behavior(BobBehavior.new())
	_ctx.rng.seed = 7
	a.steer(_ctx, DT)
	_ctx.rng.seed = 7
	b.steer(_ctx, DT)
	assert_eq(a.phase, b.phase)
	assert_true(a.phase >= 0.0 and a.phase <= TAU)


# --- HoverDrift --------------------------------------------------------------

func test_hover_drift_rises_then_orbits_spawn_radius() -> void:
	var hover := _behavior(HoverDriftBehavior.new())
	_body.position = Vector3(10, 0, 0)
	_ctx.spawn_position = _body.global_position
	assert_true(hover.is_exclusive(), "rise is exclusive")
	assert_true(hover.ignores_floor())
	hover.steer(_ctx, DT)
	assert_almost_eq(_body.global_position.y, -4.0, 0.001, "starts buried")
	_run(hover, 2.1)
	assert_eq(hover.phase, HoverDriftBehavior.Phase.DRIFT)
	assert_signal_emitted_with_parameters(hover, "phase_changed", [&"DRIFT"])
	assert_almost_eq(_body.global_position.y, 3.5, 0.05)
	assert_false(hover.is_exclusive())
	assert_false(hover.ignores_floor())
	var start := _body.global_position
	_run(hover, 3.0)
	assert_almost_eq(_flat_distance(_body.global_position, Vector3.ZERO), 10.0, 0.2, "stays on the spawn circle")
	assert_almost_eq(_body.global_position.y, 3.5, 0.05)
	assert_almost_eq(_flat_distance(_body.global_position, start), 1.2 * 3.0, 0.3, "drifts at drift_speed")


func test_hover_drift_direction_is_seeded() -> void:
	var hover := _behavior(HoverDriftBehavior.new())
	_body.position = Vector3(10, 0, 0)
	_ctx.spawn_position = _body.global_position
	hover.steer(_ctx, DT)
	assert_true(absf(hover.drift_direction) == 1.0)


# --- OrbitDive ---------------------------------------------------------------

func test_orbit_dive_cycles_phases_with_distance_invariants() -> void:
	var orbit := _behavior(OrbitDiveBehavior.new())
	_ctx.rng.seed = 42
	_body.position = Vector3(12, 4, 0)
	orbit.phase_changed.connect(func(p: StringName) -> void: _phases.append(p))
	var sample := func() -> void:
		var d := _body.global_position.distance_to(_target.global_position)
		if orbit.phase == OrbitDiveBehavior.Phase.DIVE:
			_dive_min = minf(_dive_min, d)
			assert_true(orbit.is_exclusive())
		elif orbit.phase == OrbitDiveBehavior.Phase.RETREAT:
			_retreat_end = d
			assert_true(orbit.is_exclusive())
		else:
			assert_false(orbit.is_exclusive())
			if _ctx.elapsed > 1.0 and _phases.is_empty():
				_orbit_samples.append(_flat_distance(_body.global_position, _target.global_position))
	_run(orbit, 14.0, sample)
	assert_true(_phases.size() >= 3, "went through DIVE, RETREAT and back to ORBIT: %s" % [_phases])
	assert_eq(_phases[0], &"DIVE")
	assert_eq(_phases[1], &"RETREAT")
	assert_eq(_phases[2], &"ORBIT")
	assert_true(_orbit_samples.size() > 0)
	for d in _orbit_samples:
		assert_almost_eq(d, 12.0, 1.0, "orbits at orbit_radius")
	assert_true(_dive_min <= 1.5, "the dive reached the target (closest %.2f)" % _dive_min)
	assert_true(_retreat_end >= 10.0, "retreated away again (%.2f)" % _retreat_end)


func test_orbit_dive_is_reproducible_with_seed() -> void:
	var a := _behavior(OrbitDiveBehavior.new())
	var b := _behavior(OrbitDiveBehavior.new())
	_ctx.rng.seed = 99
	_body.position = Vector3(12, 4, 0)
	_run(a, 4.0)
	var pos_a := _body.global_position
	_ctx.rng.seed = 99
	_ctx.elapsed = 0.0
	_body.position = Vector3(12, 4, 0)
	_run(b, 4.0)
	assert_almost_eq(pos_a.distance_to(_body.global_position), 0.0, 0.001)


func test_orbit_dive_leads_moving_target() -> void:
	var orbit := _behavior(OrbitDiveBehavior.new())
	orbit.orbit_time_min = 0.5
	orbit.orbit_time_max = 0.5
	_body.position = Vector3(12, 4, 0)
	_run(orbit, 0.45, func() -> void: _target.position.z += 5.0 * DT)
	orbit.steer(_ctx, 0.1)
	assert_eq(orbit.phase, OrbitDiveBehavior.Phase.DIVE)
	assert_true(orbit.aim_point.z > _target.position.z, "aim point is ahead of the target")


# --- GemSeek -----------------------------------------------------------------

func test_gem_seek_heads_for_nearest_gem() -> void:
	var gem_seek := _behavior(GemSeekBehavior.new())
	_ctx.stats.move_speed = 3.0
	var near := Node3D.new()
	near.position = Vector3(2, 0.35, 0)
	var far := Node3D.new()
	far.position = Vector3(-8, 0.35, 0)
	_world.add_child(near)
	_world.add_child(far)
	_gem_list = [far, near]
	_ctx.gems_provider = func() -> Array[Node3D]: return _gem_list
	var v := gem_seek.steer(_ctx, DT)
	assert_same(gem_seek.current_gem, near)
	assert_almost_eq(v.length(), 3.0, 0.001)
	assert_true(v.x > 0.0 and absf(v.y) < 0.001, "horizontal only")
	near.queue_free()
	await wait_process_frames(1)
	v = gem_seek.steer(_ctx, DT)
	assert_same(gem_seek.current_gem, far, "freed gems are skipped")
	assert_true(v.x < 0.0)


func test_gem_seek_idles_on_circle_without_gems() -> void:
	var gem_seek := _behavior(GemSeekBehavior.new())
	_ctx.stats.move_speed = 3.0
	_ctx.gems_provider = func() -> Array[Node3D]: return []
	_body.position = Vector3(10, 0.8, 0)
	var v := gem_seek.steer(_ctx, DT)
	assert_null(gem_seek.current_gem)
	assert_almost_eq(absf(v.z), 3.0, 0.001, "tangential on the idle circle")
	_run(gem_seek, 4.0)
	assert_almost_eq(_flat_distance(_body.global_position, Vector3.ZERO), 10.0, 0.3)
