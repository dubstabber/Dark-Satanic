extends GameTest
## HandViewModel: mouse sway, walk bob, idle drift, strafe lean and the firing kick,
## all summed as offsets from the rest transform recorded at _ready.

const DT := 1.0 / 60.0
const REST := Vector3(0.2, -0.2, -0.4)
const FORWARD := Vector3(0, 0, -9)

var _hands: HandViewModel


func before_each() -> void:
	super.before_each()
	var world := make_world()
	_hands = HandViewModel.new()
	_hands.position = REST
	world.add_child(_hands)


## Most tests want one effect at a time; the breathing drift never stops otherwise.
func _still_hands() -> void:
	_hands.idle_amount = 0.0


func _advance(ticks: int) -> void:
	for i in ticks:
		_hands.advance(DT)


func _walk(speed: float = 9.0, ticks: int = 120) -> void:
	_hands.set_motion(FORWARD.normalized() * speed, true)
	_advance(ticks)


func test_rest_transform_is_the_scene_transform() -> void:
	_still_hands()
	_advance(30)
	assert_almost_eq(_hands.position, REST, Vector3.ONE * 0.0001)
	assert_almost_eq(_hands.rotation, Vector3.ZERO, Vector3.ONE * 0.0001)


func test_sway_opposite_to_look_and_returns_to_rest() -> void:
	_still_hands()
	_hands.apply_look_delta(Vector2(50, 0))
	assert_lt(_hands.sway().x, 0.0)
	_hands.advance(DT)
	assert_lt(_hands.position.x, REST.x)
	_advance(180)
	assert_almost_eq(_hands.position, REST, Vector3.ONE * 0.0005)


func test_sway_is_capped() -> void:
	_hands.apply_look_delta(Vector2(100000, 100000))
	assert_almost_eq(_hands.sway().length(), _hands.sway_max, 0.0001)


func test_sway_turns_the_wrist_as_well_as_sliding_it() -> void:
	_still_hands()
	_hands.apply_look_delta(Vector2(80, -80))
	_hands.advance(DT)
	assert_ne(_hands.rotation.y, 0.0, "yaws into a horizontal drag")
	assert_ne(_hands.rotation.x, 0.0, "pitches into a vertical drag")
	assert_almost_eq(_hands.rotation.y, _hands.sway().x * _hands.sway_tilt, 0.0001)
	_advance(180)
	assert_almost_eq(_hands.rotation, Vector3.ZERO, Vector3.ONE * 0.0005)


func test_kick_pushes_back_then_tweens_home() -> void:
	_still_hands()
	_hands.kick(1.0)
	assert_almost_eq(_hands.kick_offset(), _hands.kick_distance, 0.0001)
	_hands.advance(DT)
	assert_gt(_hands.position.z, REST.z)
	for i in 10:
		_hands.kick(1.0)
	assert_true(_hands.kick_offset() <= _hands.kick_max)
	await wait_seconds(_hands.kick_return_time + 0.1)
	_hands.advance(DT)
	assert_almost_eq(_hands.position.z, REST.z, 0.0005)


func test_walking_traces_a_figure_eight() -> void:
	_still_hands()
	var reach := Vector2.ZERO
	_hands.set_motion(FORWARD, true)
	for i in 180:
		_hands.advance(DT)
		reach.x = maxf(reach.x, absf(_hands.position.x - REST.x))
		reach.y = maxf(reach.y, absf(_hands.position.y - REST.y))
	assert_almost_eq(reach.x, _hands.bob_amount, 0.002, "full horizontal swing")
	assert_almost_eq(reach.y, _hands.bob_amount * 0.5, 0.002, "half as much vertically")


func test_bob_fades_in_with_speed_and_out_when_stopping() -> void:
	_still_hands()
	assert_eq(_hands.bob_weight(), 0.0)
	_walk(9.0, 60)
	assert_almost_eq(_hands.bob_weight(), 1.0, 0.02, "full bob at walk speed")
	_hands.set_motion(Vector3.ZERO, true)
	_advance(120)
	assert_almost_eq(_hands.bob_weight(), 0.0, 0.005)
	assert_almost_eq(_hands.position, REST, Vector3.ONE * 0.0005, "settles at rest")


func test_bob_scales_with_speed() -> void:
	_still_hands()
	_walk(2.0, 60)
	assert_almost_eq(_hands.bob_weight(), 2.0 / _hands.bob_full_speed, 0.02, "a walk is a smaller bob")


func test_no_bob_in_the_air() -> void:
	_still_hands()
	_hands.set_motion(FORWARD, false)
	_advance(120)
	assert_almost_eq(_hands.position, REST, Vector3.ONE * 0.0001)
	assert_eq(_hands.bob_weight(), 0.0)


func test_idle_drift_breathes_while_standing_and_stops_while_walking() -> void:
	var reach := 0.0
	for i in 240:
		_hands.advance(DT)
		reach = maxf(reach, absf(_hands.position.y - REST.y))
	assert_gt(reach, _hands.idle_amount * 0.5, "the hands breathe when nothing else moves them")
	assert_true(reach <= _hands.idle_amount + 0.0001, "but only barely")
	_walk(9.0, 120)
	assert_lt(_hands.idle_drift().length(), 0.0005, "drowned out by the walk bob")


func test_strafing_leans_and_rolls_the_hands() -> void:
	_still_hands()
	_hands.set_motion(Vector3(6, 0, 0), true)
	_advance(60)
	assert_lt(_hands.lean(), 0.0, "strafing right, the hands trail left")
	assert_almost_eq(_hands.lean(), -6.0 * _hands.lean_per_speed, 0.001)
	assert_gt(_hands.rotation.z, 0.0, "and roll with it")
	_hands.set_motion(Vector3(-6, 0, 0), true)
	_advance(60)
	assert_gt(_hands.lean(), 0.0, "mirrored when strafing the other way")
	assert_lt(_hands.rotation.z, 0.0)


func test_lean_is_capped() -> void:
	_still_hands()
	_hands.set_motion(Vector3(100, 0, 0), true)
	_advance(120)
	assert_almost_eq(_hands.lean(), -_hands.lean_max, 0.0005)


func test_every_effect_sums_from_the_rest_transform() -> void:
	_hands.apply_look_delta(Vector2(40, 20))
	_hands.kick(1.0)
	_hands.set_motion(Vector3(4, 0, -6), true)
	_advance(20)
	assert_almost_eq(_hands.position, REST + _hands.offset(), Vector3.ONE * 0.0001)
	assert_almost_eq(_hands.rotation, _hands.tilt(), Vector3.ONE * 0.0001)
	assert_ne(_hands.offset(), Vector3.ZERO)


func test_speed_ignores_the_vertical_component() -> void:
	_hands.set_motion(Vector3(3, 99.0, 4), true)
	assert_almost_eq(_hands.speed(), 5.0, 0.0001)


func test_muzzle_lookup() -> void:
	assert_null(_hands.muzzle())
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	_hands.add_child(muzzle)
	assert_same(_hands.muzzle(), muzzle)
