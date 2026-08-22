extends GameTest

const DT := 1.0 / 60.0

var _rig: CameraRig
var _camera: Camera3D
var _hands: HandViewModel


func before_each() -> void:
	super.before_each()
	var world := make_world()
	_rig = CameraRig.new()
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 0.1, 0)
	_rig.add_child(_camera)
	_hands = HandViewModel.new()
	_hands.position = Vector3(0.2, -0.2, -0.4)
	_camera.add_child(_hands)
	world.add_child(_rig)


func test_camera_child_is_discovered() -> void:
	assert_same(_rig.camera, _camera)


func test_idle_rig_keeps_camera_at_rest() -> void:
	for i in 30:
		_rig.advance(DT)
	assert_almost_eq(_camera.position, Vector3(0, 0.1, 0), Vector3.ONE * 0.0001)
	assert_eq(_camera.rotation.x, 0.0)


func test_walking_bobs_and_stopping_settles() -> void:
	_rig.horizontal_speed = 9.0
	_rig.on_floor = true
	var max_offset := 0.0
	for i in 60:
		_rig.advance(DT)
		max_offset = maxf(max_offset, absf(_camera.position.y - 0.1))
	assert_gt(max_offset, _rig.bob_amplitude * 0.5)
	assert_true(max_offset <= _rig.bob_amplitude + 0.0001)
	_rig.horizontal_speed = 0.0
	for i in 120:
		_rig.advance(DT)
	assert_almost_eq(_camera.position.y, 0.1, 0.001)


func test_no_bob_in_the_air() -> void:
	_rig.horizontal_speed = 9.0
	_rig.on_floor = false
	for i in 60:
		_rig.advance(DT)
	assert_almost_eq(_camera.position.y, 0.1, 0.0001)


func test_landing_dips_then_recovers() -> void:
	_rig.on_landed(10.0)
	assert_almost_eq(_rig.dip(), 0.12, 0.0001)
	_rig.advance(DT)
	assert_lt(_camera.position.y, 0.1)
	for i in 180:
		_rig.advance(DT)
	assert_almost_eq(_camera.position.y, 0.1, 0.001)


func test_dip_is_capped() -> void:
	_rig.on_landed(1000.0)
	assert_eq(_rig.dip(), _rig.dip_max)
	_rig.on_landed(-5.0)
	assert_eq(_rig.dip(), _rig.dip_max, "negative fall speed adds nothing")


func test_kick_pitches_camera_up_and_recovers() -> void:
	_rig.kick(1.0)
	assert_almost_eq(_rig.kick_angle(), _rig.kick_pitch, 0.0001)
	_rig.advance(DT)
	assert_gt(_camera.rotation.x, 0.0)
	for i in 20:
		_rig.kick(1.0)
	assert_true(_rig.kick_angle() <= _rig.kick_max)
	for i in 180:
		_rig.advance(DT)
	assert_almost_eq(_camera.rotation.x, 0.0, 0.0005)


func test_hands_sway_opposite_to_look_and_return() -> void:
	_hands.apply_look_delta(Vector2(50, 0))
	assert_lt(_hands.sway().x, 0.0)
	_hands.advance(DT)
	assert_lt(_hands.position.x, 0.2)
	for i in 180:
		_hands.advance(DT)
	assert_almost_eq(_hands.position, Vector3(0.2, -0.2, -0.4), Vector3.ONE * 0.0005)


func test_hands_sway_is_capped() -> void:
	_hands.apply_look_delta(Vector2(100000, 100000))
	assert_almost_eq(_hands.sway().length(), _hands.sway_max, 0.0001)


func test_hands_kick_pushes_back_then_tweens_home() -> void:
	_hands.kick(1.0)
	assert_almost_eq(_hands.kick_offset(), _hands.kick_distance, 0.0001)
	_hands.advance(DT)
	assert_gt(_hands.position.z, -0.4)
	for i in 10:
		_hands.kick(1.0)
	assert_true(_hands.kick_offset() <= _hands.kick_max)
	await wait_seconds(_hands.kick_return_time + 0.1)
	_hands.advance(DT)
	assert_almost_eq(_hands.position.z, -0.4, 0.0005)


func test_muzzle_lookup() -> void:
	assert_null(_hands.muzzle())
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	_hands.add_child(muzzle)
	assert_same(_hands.muzzle(), muzzle)
