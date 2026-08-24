extends GameTest
## MovementController: the tick loop around MovementSolver, the impulse queue that
## shotgun jumping pushes through, and the jump graces it owns.

const DT := 1.0 / 60.0

var _world: Node3D
var _body: CharacterBody3D
var _controller: MovementController
var _stats: PlayerMovementStats


func before_each() -> void:
	super.before_each()
	_world = make_world()
	PlayerTestWorld.add_floor(_world)
	_body = CharacterBody3D.new()
	_body.name = "Body"
	_body.collision_layer = PhysicsLayers.PLAYER
	_body.collision_mask = PhysicsLayers.WORLD
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.7
	shape.shape = capsule
	shape.position = Vector3(0, 0.85, 0)
	_body.add_child(shape)
	_body.position = Vector3(0, 0.05, 0)
	_world.add_child(_body)
	# Duplicated so a test tweaking a stat cannot leak into the shared resource.
	_stats = (load("res://src/player/resources/default_movement.tres") as PlayerMovementStats).duplicate()
	_controller = MovementController.new()
	_controller.body = _body
	_controller.stats = _stats
	_body.add_child(_controller)
	watch_signals(_controller)


func _idle() -> PlayerInputFrame:
	return FakeInputReader.frame()


func _press() -> PlayerInputFrame:
	return FakeInputReader.frame(Vector3.ZERO, false, true)


func _tick(frame: PlayerInputFrame) -> void:
	_controller.step(frame, DT)


## Runs `count` ticks with a real physics frame between them so is_on_floor() settles.
func _settle(count: int = 10) -> void:
	for i in count:
		_tick(_idle())
		await wait_physics_frames(1)


func test_impulse_is_applied_on_the_next_step_and_then_cleared() -> void:
	await _settle()
	_controller.add_impulse(Vector3(0, 5, 0))
	assert_almost_eq(_controller.pending_impulse(), Vector3(0, 5, 0), Vector3.ONE * 0.0001)
	_tick(_idle())
	assert_eq(_controller.pending_impulse(), Vector3.ZERO, "consumed by the step")
	assert_gt(_body.velocity.y, 4.0)
	_tick(_idle())
	assert_lt(_body.velocity.y, 4.7, "and not re-applied")


func test_impulse_lands_after_friction_so_the_ground_cannot_eat_it() -> void:
	await _settle()
	_body.velocity = Vector3(9, 0, 0)
	_controller.add_impulse(Vector3(5, 0, 0))
	_tick(_idle())
	assert_gt(MovementSolver.horizontal_speed(_body.velocity), 13.0)


func test_impulses_queued_in_one_tick_add_up() -> void:
	await _settle()
	_controller.add_impulse(Vector3(0, 2, 0))
	_controller.add_impulse(Vector3(0, 3, 0))
	assert_almost_eq(_controller.pending_impulse(), Vector3(0, 5, 0), Vector3.ONE * 0.0001)


func test_impulse_caps_the_resulting_velocity() -> void:
	await _settle()
	_controller.add_impulse(Vector3(0, 40, 0), 0.0, 15.0)
	_tick(_idle())
	assert_almost_eq(_body.velocity.y, 15.0, 0.001)


func test_the_tighter_of_two_queued_caps_wins() -> void:
	await _settle()
	_controller.add_impulse(Vector3(0, 40, 0), 0.0, 20.0)
	_controller.add_impulse(Vector3(0, 1, 0), 0.0, 12.0)
	_tick(_idle())
	assert_almost_eq(_body.velocity.y, 12.0, 0.001)


func test_an_uncapped_impulse_is_not_capped_by_default() -> void:
	await _settle()
	_controller.add_impulse(Vector3(0, 40, 0))
	_tick(_idle())
	assert_gt(_body.velocity.y, 39.0)


func test_useless_impulses_are_ignored() -> void:
	_controller.add_impulse(Vector3.ZERO)
	assert_eq(_controller.pending_impulse(), Vector3.ZERO)
	_controller.add_impulse(Vector3(NAN, 0, 0))
	assert_eq(_controller.pending_impulse(), Vector3.ZERO, "NaN never reaches the body")
	_controller.add_impulse(Vector3(INF, 0, 0))
	assert_eq(_controller.pending_impulse(), Vector3.ZERO)


func test_a_jump_still_fires_just_after_the_floor_disappears() -> void:
	await _settle()
	assert_true(_controller.is_on_floor())
	assert_almost_eq(_controller.jump_assist.coyote_remaining, _stats.coyote_time, 0.0001)
	_body.global_position = Vector3(0, 20, 0)
	_tick(_idle())
	await wait_physics_frames(1)
	assert_false(_controller.is_on_floor())
	assert_gt(_controller.jump_assist.coyote_remaining, 0.0)
	_tick(_press())
	assert_signal_emitted(_controller, "jumped", "coyote jump")
	assert_gt(_body.velocity.y, 0.0)


func test_the_coyote_grace_expires() -> void:
	await _settle()
	_body.global_position = Vector3(0, 20, 0)
	for i in 12:
		_tick(_idle())
	assert_eq(_controller.jump_assist.coyote_remaining, 0.0)
	var before := _body.velocity.y
	_tick(_press())
	assert_signal_not_emitted(_controller, "jumped")
	assert_lt(_body.velocity.y, before, "still just falling")


func test_a_press_just_before_landing_fires_on_touchdown() -> void:
	_body.global_position = Vector3(0, 1.5, 0)
	await wait_physics_frames(1)
	var pressed := false
	for i in 120:
		# Press once the drop is close enough that touchdown lands inside the buffer.
		var press := not pressed and _body.global_position.y < 0.5
		pressed = pressed or press
		_tick(FakeInputReader.frame(Vector3.ZERO, false, press))
		if press:
			assert_signal_not_emitted(_controller, "jumped", "nothing to jump off yet")
		await wait_physics_frames(1)
		if get_signal_emit_count(_controller, "jumped") > 0:
			break
	assert_true(pressed, "the drop got low enough to press")
	assert_signal_emitted(_controller, "jumped", "buffered press fired on landing")
	assert_gt(_body.velocity.y, 0.0, "and it was a real jump")


func test_landing_reports_its_fall_speed_once() -> void:
	_body.global_position = Vector3(0, 4, 0)
	for i in 120:
		_tick(_idle())
		await wait_physics_frames(1)
		if get_signal_emit_count(_controller, "landed") > 0:
			break
	assert_signal_emit_count(_controller, "landed", 1)
	assert_gt(get_signal_parameters(_controller, "landed")[0], 3.0)


func test_step_without_a_body_or_frame_is_a_no_op() -> void:
	var bare := MovementController.new()
	bare.body = null
	bare.stats = _stats
	add_child_autofree(bare)
	bare.step(_idle(), DT)
	_controller.step(null, DT)
	pass_test("neither call crashed")
