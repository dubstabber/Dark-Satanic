extends GameTest
## The first-person death collapse: the camera rig falls, rolls and settles, stepped by
## advance(delta) so every frame of it is checkable.

const DT := 1.0 / 60.0

var _rig: Node3D
var _collapse: PlayerDeathCollapse


func before_each() -> void:
	super.before_each()
	var world := make_world()
	var body := Node3D.new()
	_rig = Node3D.new()
	_rig.name = "CameraRig"
	_rig.position = Vector3(0, 1.6, 0)
	body.add_child(_rig)
	_collapse = PlayerDeathCollapse.new()
	_collapse.rig = _rig
	_collapse.rng_seed = 3
	_collapse.autonomous = false
	body.add_child(_collapse)
	world.add_child(body)


func _advance(seconds: float) -> void:
	for i in int(round(seconds / DT)):
		_collapse.advance(DT)


func test_nothing_moves_until_the_player_dies() -> void:
	_advance(1.0)
	assert_false(_collapse.is_falling())
	assert_false(_collapse.has_fallen())
	assert_almost_eq(_rig.position.y, 1.6, 0.0001)
	assert_eq(_rig.rotation.z, 0.0)


func test_the_view_drops_to_the_floor_and_rolls_onto_its_side() -> void:
	_collapse.start()
	assert_true(_collapse.is_falling())
	assert_almost_eq(_rig.position.y, 1.6, 0.001, "still upright on the first frame")
	_advance(_collapse.duration)
	assert_almost_eq(_rig.position.y, _collapse.fallen_height, 0.01, "a head lying on the floor")
	assert_almost_eq(absf(rad_to_deg(_rig.rotation.z)), _collapse.roll_deg, 0.5, "rolled onto its side")
	assert_almost_eq(rad_to_deg(_rig.rotation.x), _collapse.pitch_deg, 0.5, "looking along the ground")
	assert_false(_collapse.is_falling())
	assert_true(_collapse.has_fallen())


func test_the_fall_accelerates_and_settles_out_of_a_bounce() -> void:
	var land: float = _collapse.land_fraction
	assert_eq(PlayerDeathCollapse.fall_curve(0.0, land, 0.12), 0.0)
	assert_almost_eq(PlayerDeathCollapse.fall_curve(land * 0.5, land, 0.12), 0.25, 0.001,
		"a quarter of the way down at half the fall: it accelerates like a body, not a lift")
	assert_almost_eq(PlayerDeathCollapse.fall_curve(land, land, 0.12), 1.0, 0.001, "lands")
	var rebound := PlayerDeathCollapse.fall_curve(land + (1.0 - land) * 0.5, land, 0.12)
	assert_lt(rebound, 1.0, "comes back up off the floor a little")
	assert_gt(rebound, 0.9, "but only a little")
	assert_almost_eq(PlayerDeathCollapse.fall_curve(1.0, land, 0.12), 1.0, 0.001, "and settles down again")


func test_which_side_it_falls_on_comes_from_the_seed() -> void:
	var sides := {}
	for seed_value in range(1, 30):
		var collapse := PlayerDeathCollapse.new()
		collapse.rig = _rig
		collapse.rng_seed = seed_value
		collapse.autonomous = false
		add_child_autofree(collapse)
		_rig.rotation.z = 0.0
		collapse.start()
		collapse.advance(collapse.duration)
		sides[signf(_rig.rotation.z)] = true
	assert_eq(sides.size(), 2, "bodies fall both ways across seeds")


func test_a_second_death_never_restarts_the_fall() -> void:
	_collapse.start()
	_advance(_collapse.duration * 0.5)
	var half := _rig.position.y
	_collapse.start()
	assert_almost_eq(_rig.position.y, half, 0.001, "the body is already going down")


func test_a_collapse_without_a_rig_is_a_safe_no_op() -> void:
	var orphan := PlayerDeathCollapse.new()
	orphan.autonomous = false
	add_child_autofree(orphan)
	orphan.start()
	orphan.advance(1.0)
	assert_false(orphan.is_falling(), "nothing to fall")
