extends GameTest

var _world: Node3D


func before_each() -> void:
	super.before_each()
	_world = make_world()


func _enemy(free_delay: float = 0.0) -> Dictionary:
	var body := Area3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	body.add_child(shape)
	var health := HealthComponent.new()
	body.add_child(health)
	var handler := DeathHandlerComponent.new()
	handler.free_delay = free_delay
	body.add_child(handler)
	_world.add_child(body)
	watch_signals(handler)
	return {"body": body, "health": health, "handler": handler, "shape": shape}


func test_death_frees_immediately_by_default() -> void:
	var enemy := _enemy()
	enemy.health.kill()
	assert_signal_emitted(enemy.handler, "handled")
	assert_true(enemy.body.is_queued_for_deletion())


func test_death_disables_collisions_while_lingering() -> void:
	var enemy := _enemy(1.0)
	enemy.health.kill()
	await wait_process_frames(2)
	assert_true(is_instance_valid(enemy.body))
	assert_true(enemy.shape.disabled)
	assert_false(enemy.body.monitoring)
	assert_false(enemy.body.monitorable)


func test_delayed_free_counts_down_through_advance() -> void:
	var enemy := _enemy(0.2)
	enemy.handler.set_physics_process(false)
	enemy.health.kill()
	assert_true(enemy.handler.is_pending_free())
	await wait_process_frames(2)
	assert_true(is_instance_valid(enemy.body))
	assert_false(enemy.body.is_queued_for_deletion())
	enemy.handler.advance(0.1)
	assert_false(enemy.body.is_queued_for_deletion(), "0.1 < 0.2")
	enemy.handler.advance(0.1)
	assert_true(enemy.body.is_queued_for_deletion(), "freed once the delay elapsed")
	assert_false(enemy.handler.is_pending_free())
	await wait_process_frames(1)


func test_delayed_free_is_driven_by_physics_not_the_engine_clock() -> void:
	var enemy := _enemy(0.05)
	enemy.health.kill()
	await wait_process_frames(2)
	assert_true(is_instance_valid(enemy.body))
	await wait_physics_frames(5)
	assert_true(not is_instance_valid(enemy.body) or enemy.body.is_queued_for_deletion(), "5 ticks at 60 fps > 0.05 s")
	await wait_process_frames(1)


func test_advance_before_death_or_with_zero_delta_is_a_no_op() -> void:
	var enemy := _enemy(0.2)
	enemy.handler.advance(10.0)
	assert_true(is_instance_valid(enemy.body))
	assert_false(enemy.body.is_queued_for_deletion())
	enemy.health.kill()
	enemy.handler.advance(0.0)
	assert_false(enemy.body.is_queued_for_deletion())
	await wait_process_frames(1)


func test_death_vfx_spawned_next_to_body() -> void:
	var enemy := _enemy()
	var vfx_scene := PackedScene.new()
	var vfx_root: Node3D = autofree(Node3D.new())
	vfx_root.name = "DeathBurst"
	vfx_scene.pack(vfx_root)
	enemy.handler.death_vfx = vfx_scene
	enemy.body.position = Vector3(1, 2, 3)
	enemy.health.kill()
	await wait_process_frames(2)
	var vfx := _world.get_node_or_null("DeathBurst")
	assert_not_null(vfx)
	assert_eq(vfx.position, Vector3(1, 2, 3))
