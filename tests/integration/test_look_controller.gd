extends GameTest

var _world: Node3D
var _body: Node3D
var _head: Node3D
var _look: LookController


func before_each() -> void:
	super.before_each()
	_world = make_world()
	_body = Node3D.new()
	_body.name = "Body"
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 1.6, 0)
	_body.add_child(_head)
	_look = LookController.new()
	_look.yaw_target = _body
	_look.pitch_target = _head
	_look.sensitivity = 1.0
	_body.add_child(_look)
	_world.add_child(_body)


func test_apply_look_rotates_yaw_and_pitch() -> void:
	_look.apply_look(Vector2(0.5, 0.25))
	assert_almost_eq(_look.yaw(), -0.5, 0.0001, "mouse right turns clockwise (negative yaw)")
	assert_almost_eq(_look.pitch(), -0.25, 0.0001, "mouse down looks down")
	assert_almost_eq(_body.rotation.y, -0.5, 0.0001)
	assert_almost_eq(_head.rotation.x, -0.25, 0.0001)


func test_sensitivity_scales_delta() -> void:
	_look.sensitivity = 0.01
	_look.apply_look(Vector2(100, 0))
	assert_almost_eq(_look.yaw(), -1.0, 0.0001)


func test_pitch_clamps_to_limit_both_ways() -> void:
	var limit := deg_to_rad(89.0)
	_look.apply_look(Vector2(0, 10))
	assert_almost_eq(_look.pitch(), -limit, 0.0001)
	_look.apply_look(Vector2(0, -40))
	assert_almost_eq(_look.pitch(), limit, 0.0001)
	assert_eq(_look.yaw(), 0.0)


func test_pitch_limit_comes_from_stats() -> void:
	var stats := PlayerMovementStats.new()
	stats.pitch_limit_deg = 30.0
	_look.stats = stats
	_look.apply_look(Vector2(0, 10))
	assert_almost_eq(_look.pitch(), -deg_to_rad(30.0), 0.0001)


func test_yaw_is_unbounded() -> void:
	_look.apply_look(Vector2(-20, 0))
	assert_almost_eq(_look.yaw(), 20.0, 0.0001)


func test_mouse_motion_accumulates_until_taken() -> void:
	var motion := InputEventMouseMotion.new()
	motion.screen_relative = Vector2(3, -2)
	_look._unhandled_input(motion)
	_look._unhandled_input(motion)
	assert_eq(_look.yaw(), 0.0, "input alone does not rotate; the player applies it per tick")
	assert_eq(_look.take_pending(), Vector2(6, -4))
	assert_eq(_look.take_pending(), Vector2.ZERO, "cleared after take")


func test_mouse_motion_reaches_controller_through_the_tree() -> void:
	var motion := InputEventMouseMotion.new()
	motion.screen_relative = Vector2(5, 0)
	get_tree().root.push_input(motion)
	await wait_physics_frames(2)
	assert_eq(_look.take_pending(), Vector2(5, 0))


func test_look_at_point_faces_the_point() -> void:
	var target := Vector3(10, 5, -10)
	_look.look_at_point(target)
	await wait_physics_frames(1)
	var expected := (target - _head.global_position).normalized()
	var forward := -_head.global_basis.z
	assert_almost_eq(forward, expected, Vector3.ONE * 0.001)


func test_look_at_point_behind_and_below() -> void:
	var target := Vector3(-4, -3, 6)
	_look.look_at_point(target)
	await wait_physics_frames(1)
	var expected := (target - _head.global_position).normalized()
	assert_almost_eq(-_head.global_basis.z, expected, Vector3.ONE * 0.001)
	assert_lt(_look.pitch(), 0.0)


func test_look_at_point_straight_up_clamps_pitch_and_keeps_yaw() -> void:
	_look.apply_look(Vector2(1, 0))
	_look.look_at_point(_head.global_position + Vector3.UP * 3.0)
	assert_almost_eq(_look.pitch(), deg_to_rad(89.0), 0.0001)
	assert_almost_eq(_look.yaw(), -1.0, 0.0001)


func test_look_at_own_position_is_a_no_op() -> void:
	_look.apply_look(Vector2(1, 1))
	_look.look_at_point(_head.global_position)
	assert_almost_eq(_look.yaw(), -1.0, 0.0001)
	assert_almost_eq(_look.pitch(), -1.0, 0.0001)


func test_parent_is_the_default_yaw_target() -> void:
	var look := LookController.new()
	_head.add_child(look)
	assert_same(look.yaw_target, _head)
	assert_not_null(look.stats)
	look.apply_look(Vector2(0, 5))
	assert_eq(look.pitch(), 0.0, "no pitch target: pitch stays 0 without errors")
