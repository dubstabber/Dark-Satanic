extends GameTest
## The weeper's chase contract, flown against a stub target moving at player speed:
## it flies, it cannot be outrun, and its 90 deg/s heading is too slow to follow a strafe.
## The numbers themselves live in `weeper.tres` (see test_enemy_stats_and_context.gd).

const Weeper := preload("res://src/enemies/archetypes/weeper.tscn")

const DT := 1.0 / 60.0
## `default_movement.tres` walk_speed: what a player running flat out does.
const PLAYER_WALK_SPEED := 9.0

var _world: Node3D
var _target: Node3D


func before_each() -> void:
	super.before_each()
	_world = make_world()
	_target = Node3D.new()
	_world.add_child(_target)


func _spawn(position: Vector3) -> Enemy:
	var weeper: Enemy = Weeper.instantiate()
	weeper.target = _target
	weeper.rng_seed = 5
	weeper.position = position
	_world.add_child(weeper)
	weeper.set_physics_process(false)
	return weeper


## Horizontal gap: the weeper flies above a target standing on the floor and overlaps it
## vertically, so contact is decided in the horizontal plane.
func _flat_gap(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()


## Widest distance between any two of the swarm.
func _spread(swarm: Array[Enemy]) -> float:
	var widest := 0.0
	for i in swarm.size():
		for j in range(i + 1, swarm.size()):
			widest = maxf(widest, swarm[i].global_position.distance_to(swarm[j].global_position))
	return widest


func _closest_pair(swarm: Array[Enemy]) -> float:
	var closest := INF
	for i in swarm.size():
		for j in range(i + 1, swarm.size()):
			closest = minf(closest, swarm[i].global_position.distance_to(swarm[j].global_position))
	return closest


## Biggest angle (degrees) between any two of the swarm's velocities.
func _widest_heading_angle(swarm: Array[Enemy]) -> float:
	var widest := 0.0
	for i in swarm.size():
		for j in range(i + 1, swarm.size()):
			widest = maxf(widest, rad_to_deg(swarm[i].mover.velocity.angle_to(swarm[j].mover.velocity)))
	return widest


## A weeper diving in from -Z, up to speed and 5 m off: strafing range.
func _closed_in_weeper() -> Enemy:
	_target.global_position = Vector3.ZERO
	var weeper := _spawn(Vector3(0, 1.5, -14))
	for i in 300:
		weeper.advance(DT)
		if _flat_gap(weeper, _target) <= 5.0:
			break
	assert_almost_eq(_flat_gap(weeper, _target), 5.0, 0.3, "closed head-on to strafing range")
	return weeper


func test_weeper_runs_down_a_target_fleeing_in_a_straight_line() -> void:
	_target.global_position = Vector3.ZERO
	var weeper := _spawn(Vector3(0, 1.5, -14))
	for i in 60:
		weeper.advance(DT)
	var gap := _flat_gap(weeper, _target)
	for i in 150:
		_target.global_position += Vector3.BACK * PLAYER_WALK_SPEED * DT
		weeper.advance(DT)
	assert_lt(_flat_gap(weeper, _target), gap - 1.5,
		"sprinting away in a straight line only delays it (%.2f m -> %.2f m)" % [gap, _flat_gap(weeper, _target)])


## Head-on approach along +Z, then the target steps across it: the weeper cannot bend its
## heading fast enough and sails past the line it was aiming down.
func test_a_strafing_target_is_never_touched() -> void:
	var weeper := _closed_in_weeper()
	var closest := INF
	var flew_past := false
	for i in 150:
		_target.global_position += Vector3.RIGHT * PLAYER_WALK_SPEED * DT
		weeper.advance(DT)
		closest = minf(closest, _flat_gap(weeper, _target))
		flew_past = flew_past or weeper.global_position.z > _target.global_position.z
	assert_gt(closest, 0.8,
		"contact needs 0.45 hitbox + 0.35 hurtbox; the strafe kept it out (closest %.2f m)" % closest)
	assert_true(flew_past, "overshot the line it was aiming down instead of turning with the target")


func test_cutting_back_the_other_way_throws_the_weeper_wide() -> void:
	var weeper := _closed_in_weeper()
	for i in 150:
		var direction := Vector3.RIGHT if i < 30 else Vector3.LEFT
		_target.global_position += direction * PLAYER_WALK_SPEED * DT
		weeper.advance(DT)
	assert_gt(_flat_gap(weeper, _target), 10.0,
		"a 90 deg/s turner needs seconds to come back around after a cut-back (%.1f m away)"
			% _flat_gap(weeper, _target))


## The SKULL I contract: one collective swarm that avoids itself. Five weepers released in a
## line converge into a cloud, fly the same way, and never stack on top of one another.
func test_a_wave_of_weepers_travels_as_one_swarm() -> void:
	_target.global_position = Vector3.ZERO
	var swarm: Array[Enemy] = []
	for i in 5:
		swarm.append(_spawn(Vector3(-8.0 + i * 4.0, 1.5, -24)))
	var start_spread := _spread(swarm)
	var tightest_spread := INF
	var tightest := INF
	var widest_angle := 0.0
	for tick in 210:
		for weeper in swarm:
			weeper.advance(DT)
		tightest = minf(tightest, _closest_pair(swarm))
		tightest_spread = minf(tightest_spread, _spread(swarm))
		if tick == 120:
			widest_angle = _widest_heading_angle(swarm)
	assert_lt(tightest_spread, start_spread * 0.5,
		"the line gathered into a cloud (%.1f m across -> %.1f m)" % [start_spread, tightest_spread])
	assert_gt(tightest, 0.75, "and never stacked up: two 0.45 m skulls touch at 0.9 m, closest was %.2f m" % tightest)
	assert_lt(widest_angle, 40.0, "mid-flight they were all flying much the same way (%.0f deg apart)" % widest_angle)


func test_weeper_flies_at_body_height_without_hovering_or_looping() -> void:
	_target.global_position = Vector3(8, 0, 0)
	var weeper := _spawn(Vector3(0, 3.5, 6))
	assert_false(weeper.stats.grounded, "the weeper flies; nothing pulls it to the floor")
	var lowest := INF
	var highest := -INF
	for i in 300:
		weeper.advance(DT)
		lowest = minf(lowest, weeper.global_position.y)
		highest = maxf(highest, weeper.global_position.y)
	assert_gt(lowest, weeper.stats.min_height - 0.001, "never dropped through its floor guard (%.2f)" % lowest)
	assert_lt(highest, 4.0, "and never recovered an overshoot by looping away over the top (%.2f)" % highest)
	assert_gt(highest - lowest, 0.8,
		"its altitude comes from the chase, not from a hover plane (%.2f..%.2f)" % [lowest, highest])
	assert_between(weeper.global_position.y, 0.5, 2.5, "still flying around body height at the end")


## Nothing pins it to a flight plane: put the target up in the air and it climbs after it.
func test_weeper_climbs_after_a_target_above_it() -> void:
	_target.global_position = Vector3(0, 9, 0)
	var weeper := _spawn(Vector3(0, 1.5, -12))
	var highest := -INF
	var closest := INF
	for i in 400:
		weeper.advance(DT)
		highest = maxf(highest, weeper.global_position.y)
		closest = minf(closest, weeper.global_position.distance_to(_target.global_position + Vector3.UP * 1.2))
	assert_gt(highest, 8.0, "flew up after it (reached %.2f)" % highest)
	assert_lt(closest, 1.5, "and caught it in the air (closest %.2f m)" % closest)
