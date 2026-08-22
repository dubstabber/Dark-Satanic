extends GameTest


class ConstBehavior:
	extends EnemyBehavior
	var velocity: Vector3 = Vector3.ZERO
	var exclusive: bool = false
	var floor_free: bool = false
	var calls: int = 0

	func steer(_ctx: EnemyContext, _delta: float) -> Vector3:
		calls += 1
		return velocity

	func is_exclusive() -> bool:
		return exclusive

	func ignores_floor() -> bool:
		return floor_free


var _world: Node3D
var _body: Node3D
var _behaviors: Node
var _mover: EnemyMover
var _ctx: EnemyContext


func before_each() -> void:
	super.before_each()
	_world = make_world()
	_body = Node3D.new()
	_mover = EnemyMover.new()
	_mover.name = "Mover"
	_behaviors = Node.new()
	_behaviors.name = "Behaviors"
	_body.add_child(_mover)
	_body.add_child(_behaviors)
	_world.add_child(_body)
	_ctx = EnemyContext.new()
	_ctx.body = _body
	_ctx.stats = EnemyStats.new()
	_ctx.stats.move_speed = 10.0
	_ctx.stats.acceleration = 1000.0
	_ctx.stats.min_height = 0.5
	_ctx.arena_info = ArenaInfo.new(Vector3.ZERO, 10.0, 0.0)


func _add(velocity: Vector3, weight: float = 1.0) -> ConstBehavior:
	var behavior := ConstBehavior.new()
	behavior.velocity = velocity
	behavior.weight = weight
	_behaviors.add_child(behavior)
	return behavior


func test_discovers_body_and_behaviors_root() -> void:
	assert_same(_mover.body, _body)
	assert_same(_mover.behaviors_root, _behaviors)


func test_weighted_blend_and_integration() -> void:
	_add(Vector3(2, 0, 0), 1.0)
	_add(Vector3(0, 0, 4), 0.5)
	_mover.advance(_ctx, 0.5)
	assert_almost_eq(_mover.desired_velocity.distance_to(Vector3(2, 0, 2)), 0.0, 0.001)
	assert_almost_eq(_body.global_position.distance_to(Vector3(1, 0.5, 1)), 0.0, 0.001, "moved, lifted to min height")


func test_disabled_behaviors_are_skipped() -> void:
	var off := _add(Vector3(5, 0, 0))
	off.enabled = false
	_mover.advance(_ctx, 0.1)
	assert_eq(off.calls, 0)
	assert_eq(_mover.velocity, Vector3.ZERO)


func test_exclusive_behavior_overrides_the_rest() -> void:
	var normal := _add(Vector3(5, 0, 0))
	var boss := _add(Vector3(0, 0, 3))
	boss.exclusive = true
	_mover.advance(_ctx, 0.1)
	assert_almost_eq(_mover.desired_velocity.distance_to(Vector3(0, 0, 3)), 0.0, 0.001)
	assert_eq(normal.calls, 0, "others are not even asked")
	boss.exclusive = false
	_mover.advance(_ctx, 0.1)
	assert_almost_eq(_mover.desired_velocity.distance_to(Vector3(5, 0, 3)), 0.0, 0.001)


func test_speed_clamp_and_acceleration() -> void:
	_add(Vector3(100, 0, 0))
	_ctx.stats.acceleration = 20.0
	_mover.advance(_ctx, 0.1)
	assert_almost_eq(_mover.velocity.length(), 2.0, 0.001, "accelerates by acceleration * delta")
	for i in 10:
		_mover.advance(_ctx, 0.1)
	assert_almost_eq(_mover.velocity.length(), 10.0, 0.001, "capped at move_speed")


func test_platform_clamp() -> void:
	_add(Vector3(10, 0, 0))
	_body.position = Vector3(9, 1, 0)
	_mover.advance(_ctx, 1.0)
	assert_almost_eq(_body.global_position.x, 9.5, 0.001, "radius 10 - margin 0.5")
	_mover.platform_margin = 2.0
	_mover.advance(_ctx, 1.0)
	assert_almost_eq(_body.global_position.x, 8.0, 0.001)


func test_min_height_and_floor_free() -> void:
	var down := _add(Vector3(0, -10, 0))
	_body.position = Vector3(0, 2, 0)
	_ctx.arena_info.floor_y = 1.0
	_mover.advance(_ctx, 1.0)
	assert_almost_eq(_body.global_position.y, 1.5, 0.001, "floor_y + min_height")
	down.exclusive = true
	down.floor_free = true
	_mover.advance(_ctx, 1.0)
	assert_true(_body.global_position.y < 0.0, "an exclusive floor-ignoring behaviour may sink")


func test_faces_horizontal_velocity() -> void:
	_add(Vector3(0, 0, -10))
	_mover.advance(_ctx, 0.1)
	var forward := -_body.global_transform.basis.z
	assert_almost_eq(forward.dot(Vector3.FORWARD), 1.0, 0.001)
	_behaviors.get_child(0).velocity = Vector3(10, 0, 0)
	_mover.advance(_ctx, 0.5)
	forward = -_body.global_transform.basis.z
	assert_almost_eq(forward.dot(Vector3.RIGHT), 1.0, 0.001)
	assert_almost_eq(_body.global_transform.basis.y.dot(Vector3.UP), 1.0, 0.001, "stays upright")


func test_no_facing_change_when_still_or_disabled() -> void:
	_add(Vector3(0, 0, 0))
	var basis := _body.global_transform.basis
	_mover.advance(_ctx, 0.1)
	assert_true(_body.global_transform.basis.is_equal_approx(basis))
	_mover.face_velocity = false
	_behaviors.get_child(0).velocity = Vector3(10, 0, 0)
	_mover.advance(_ctx, 0.1)
	assert_true(_body.global_transform.basis.is_equal_approx(basis))


func test_zero_delta_or_missing_body_is_safe() -> void:
	_add(Vector3(10, 0, 0))
	_mover.advance(_ctx, 0.0)
	assert_eq(_body.global_position, Vector3.ZERO)
	_mover.body = null
	_mover.advance(_ctx, 0.1)
	assert_eq(_body.global_position, Vector3.ZERO)
