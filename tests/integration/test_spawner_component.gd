extends GameTest

const SpawnStub := preload("res://tests/fixtures/spawn_stub.tscn")

var _world: Node3D
var _anchor: Node3D
var _spawner: SpawnerComponent


func before_each() -> void:
	super.before_each()
	_world = make_world()
	_anchor = SpawnStub.instantiate()
	_anchor.position = Vector3(3, 2, 0)
	_spawner = SpawnerComponent.new()
	_spawner.scene = SpawnStub
	_spawner.interval = 1.0
	_spawner.burst = 2
	_spawner.initial_delay = 0.5
	_spawner.max_alive = 0
	_spawner.rng_seed = 5
	_anchor.add_child(_spawner)
	_world.add_child(_anchor)
	watch_signals(_spawner)


func _spawned() -> Array:
	return _world.get_children().filter(func(n: Node) -> bool: return n != _anchor)


func test_initial_delay_then_interval() -> void:
	assert_eq(_spawner.advance(0.4), 0)
	assert_eq(_spawner.advance(0.2), 2, "first burst after the initial delay")
	assert_eq(_spawner.advance(0.8), 0, "elapsed 1.4 < 1.5")
	assert_eq(_spawner.advance(0.2), 2, "elapsed 1.6 >= 1.5")
	assert_eq(_spawner.emissions, 2)
	await wait_process_frames(2)
	assert_eq(_spawned().size(), 4)
	assert_signal_emit_count(_spawner, "spawned", 4)


func test_large_time_jump_emits_every_due_burst() -> void:
	assert_eq(_spawner.advance(3.6), 8, "0.5, 1.5, 2.5, 3.5 are all due")
	await wait_process_frames(1)


func test_children_inherit_target_and_sit_on_radius() -> void:
	var target := Node3D.new()
	_world.add_child(target)
	_anchor.target = target
	_spawner.spawn_radius = 2.0
	var nodes := _spawner.spawn_burst(1)
	await wait_process_frames(2)
	assert_same(nodes[0].target, target)
	assert_almost_eq(nodes[0].global_position.distance_to(_anchor.global_position), 2.0, 0.001)


func test_max_alive_caps_until_children_die() -> void:
	_spawner.max_alive = 3
	assert_eq(_spawner.spawn_burst(5).size(), 3)
	await wait_process_frames(2)
	assert_eq(_spawner.alive_count(), 3)
	assert_eq(_spawner.spawn_burst(1).size(), 0)
	_spawned()[0].queue_free()
	await wait_process_frames(2)
	assert_eq(_spawner.alive_count(), 2)
	assert_eq(_spawner.spawn_burst(1).size(), 1)
	await wait_process_frames(1)


func test_max_emissions_and_enabled() -> void:
	_spawner.max_emissions = 1
	assert_eq(_spawner.advance(10.0), 2)
	assert_eq(_spawner.advance(10.0), 0)
	_spawner.max_emissions = 0
	_spawner.enabled = false
	assert_eq(_spawner.advance(10.0), 0)
	await wait_process_frames(1)


func test_director_veto() -> void:
	_spawner.can_spawn = func() -> bool: return false
	assert_eq(_spawner.advance(2.0), 0)
	_spawner.can_spawn = Callable()
	assert_eq(_spawner.spawn_burst(1).size(), 1)
	await wait_process_frames(1)


func test_death_burst() -> void:
	var body := Node3D.new()
	var health := HealthComponent.new()
	body.add_child(health)
	var spawner := SpawnerComponent.new()
	spawner.scene = SpawnStub
	spawner.death_burst = 3
	spawner.enabled = false
	body.add_child(spawner)
	_world.add_child(body)
	health.kill()
	await wait_process_frames(2)
	assert_eq(spawner.alive_count(), 3)
