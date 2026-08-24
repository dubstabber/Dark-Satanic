extends GameTest
## Screen shake: trauma accumulates, decays, and never survives a run.

const DT := 1.0 / 60.0

var _rig: CameraRig
var _camera: Camera3D


func before_each() -> void:
	super.before_each()
	var world := make_world()
	_rig = CameraRig.new()
	_rig.shake_rng_seed = 3
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 0.1, 0)
	_rig.add_child(_camera)
	world.add_child(_rig)


func _advance(ticks: int) -> void:
	for i in ticks:
		_rig.advance(DT)


func _peak_offset(ticks: int) -> float:
	var peak := 0.0
	for i in ticks:
		_rig.advance(DT)
		peak = maxf(peak, absf(_camera.position.x) + absf(_camera.rotation.z))
	return peak


func test_a_still_camera_does_not_shake() -> void:
	assert_eq(_rig.trauma(), 0.0)
	assert_eq(_rig.shake_offset(), Vector3.ZERO)
	_advance(60)
	assert_almost_eq(_camera.position, Vector3(0, 0.1, 0), Vector3.ONE * 0.0001)
	assert_eq(_camera.rotation.z, 0.0)


func test_trauma_shakes_the_camera_on_all_three_axes() -> void:
	_rig.add_trauma(1.0)
	var moved := Vector3.ZERO
	for i in 20:
		_rig.advance(DT)
		moved.x = maxf(moved.x, absf(_camera.position.x))
		moved.y = maxf(moved.y, absf(_camera.position.y - 0.1))
		moved.z = maxf(moved.z, absf(_camera.rotation.z))
	assert_gt(moved.x, 0.0, "shifts sideways")
	assert_gt(moved.y, 0.0, "and vertically")
	assert_gt(moved.z, 0.0, "and rolls")


func test_trauma_decays_back_to_a_still_camera() -> void:
	_rig.add_trauma(1.0)
	assert_almost_eq(_rig.trauma(), 1.0, 0.0001)
	_advance(int(1.0 / _rig.trauma_decay / DT) + 10)
	assert_eq(_rig.trauma(), 0.0)
	_advance(2)
	assert_almost_eq(_camera.position, Vector3(0, 0.1, 0), Vector3.ONE * 0.0001)
	assert_almost_eq(_camera.rotation.z, 0.0, 0.0001)


func test_trauma_accumulates_and_is_capped() -> void:
	_rig.add_trauma(0.3)
	_rig.add_trauma(0.3)
	assert_almost_eq(_rig.trauma(), 0.6, 0.0001)
	for i in 20:
		_rig.add_trauma(0.5)
	assert_almost_eq(_rig.trauma(), 1.0, 0.0001, "a swarm dying cannot shake past full")


func test_negative_trauma_is_ignored() -> void:
	_rig.add_trauma(0.5)
	_rig.add_trauma(-10.0)
	assert_almost_eq(_rig.trauma(), 0.5, 0.0001)


func test_a_big_knock_shakes_much_harder_than_a_small_one() -> void:
	_rig.add_trauma(0.25)
	var small := _peak_offset(20)
	_rig.add_trauma(1.0)  # tops out at 1.0
	var big := _peak_offset(20)
	assert_gt(big, small * 3.0, "shake goes as trauma squared, so small knocks stay subtle")


func test_shake_rides_on_top_of_bob_and_dip_instead_of_replacing_them() -> void:
	_rig.on_landed(10.0)
	var dipped := _camera.position.y
	_rig.add_trauma(1.0)
	_rig.advance(DT)
	assert_ne(_camera.position.y, dipped, "both are in the same offset")
	assert_gt(_rig.dip(), 0.0, "the dip is still there")
