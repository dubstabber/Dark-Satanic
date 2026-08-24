extends GameTest
## CameraRig only; the hands that hang off its camera have their own suite
## in test_hand_view_model.gd.

const DT := 1.0 / 60.0

var _rig: CameraRig
var _camera: Camera3D


func before_each() -> void:
	super.before_each()
	var world := make_world()
	_rig = CameraRig.new()
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 0.1, 0)
	_rig.add_child(_camera)
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
