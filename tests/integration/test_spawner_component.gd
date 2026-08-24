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


func test_spawn_point_overrides_the_emission_origin() -> void:
	var crown := Marker3D.new()
	crown.position = Vector3(0, 2.1, 0)
	_anchor.add_child(crown)
	_spawner.spawn_point = crown
	_spawner.spawn_radius = 0.5
	var nodes := _spawner.spawn_burst(2)
	await wait_process_frames(2)
	for node in nodes:
		assert_almost_eq(node.global_position.y, crown.global_position.y, 0.001, "released at the crown height")
		var flat := node.global_position - crown.global_position
		flat.y = 0.0
		assert_almost_eq(flat.length(), 0.5, 0.001, "on the crown radius")


func test_burst_released_fires_once_per_non_empty_burst() -> void:
	assert_eq(_spawner.spawn_burst(3).size(), 3)
	assert_signal_emit_count(_spawner, "burst_released", 1)
	_spawner.scene = null
	_spawner.spawn_burst(2)
	assert_signal_emit_count(_spawner, "burst_released", 1, "empty bursts stay silent")
	await wait_process_frames(2)


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


func test_spawn_burst_without_emit_cue_stays_silent() -> void:
	_spawner.emit_cue = null
	assert_eq(_spawner.spawn_burst(1).size(), 1, "null cue: AudioManager.play no-ops, burst still spawns")
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


class ArenaStub:
	extends Node
	var floor_height: float = 2.0

	func info() -> ArenaInfo:
		return ArenaInfo.new(Vector3.ZERO, 30.0, floor_height)


func test_spawn_on_floor_places_children_at_floor_plus_min_height() -> void:
	_spawner.spawn_on_floor = true
	_anchor.position = Vector3(3, 7.5, 0)
	var nodes := _spawner.spawn_burst(1)
	await wait_process_frames(2)
	assert_almost_eq(nodes[0].global_position.y, 0.0, 0.001, "no arena: floor y = 0")
	var arena := ArenaStub.new()
	_world.add_child(arena)
	_anchor.arena = arena
	_spawner.scene = preload("res://src/enemies/base_enemy.tscn")
	nodes = _spawner.spawn_burst(1)
	var enemy := nodes[0] as Enemy
	enemy.stats = EnemyStats.new()
	enemy.stats.min_height = 0.7
	var target := Node3D.new()
	_world.add_child(target)
	enemy.target = target
	await wait_process_frames(2)
	enemy.set_physics_process(false)
	assert_same(enemy.arena, arena, "arena inherited")
	assert_almost_eq(Vector2(enemy.global_position.x - 3.0, enemy.global_position.z).length(), 1.5, 0.01, "still on the spawn ring")
	_spawner.spawn_on_floor = false
	_spawner.scene = SpawnStub
	nodes = _spawner.spawn_burst(1)
	await wait_process_frames(2)
	assert_almost_eq(nodes[0].global_position.y, 7.5, 0.001, "default keeps the anchor's height")


func test_spawn_on_floor_uses_floor_and_child_min_height() -> void:
	var arena := ArenaStub.new()
	_world.add_child(arena)
	_anchor.arena = arena
	_anchor.position = Vector3(0, 9.0, 0)
	_spawner.spawn_on_floor = true
	assert_almost_eq(_spawner._floor_y(_anchor), 2.0, 0.001)
	var enemy: Enemy = preload("res://src/enemies/base_enemy.tscn").instantiate()
	enemy.stats = EnemyStats.new()
	enemy.stats.min_height = 0.7
	assert_almost_eq(_spawner._min_height(enemy), 0.7, 0.001)
	assert_almost_eq(_spawner._min_height(_anchor), 0.0, 0.001, "no stats: sits on the floor")
	enemy.free()
	var nodes := _spawner.spawn_burst(1)
	await wait_process_frames(2)
	assert_almost_eq(nodes[0].global_position.y, 2.0, 0.001, "stub lands on the arena floor")
