extends GameTest

const SpawnStub := preload("res://tests/fixtures/spawn_stub.tscn")
const TinyTable := preload("res://src/spawning/waves/test_tiny.tres")


class FakeArena:
	extends Node3D
	var radius := 20.0

	func info() -> ArenaInfo:
		return ArenaInfo.new(global_position, radius, 0.0)


var _world: Node3D
var _container: Node3D
var _arena: FakeArena
var _target: Node3D
var _director: SpawnDirector


func before_each() -> void:
	super.before_each()
	_world = make_world()
	_container = Node3D.new()
	_container.name = "Enemies"
	_world.add_child(_container)
	_arena = FakeArena.new()
	_world.add_child(_arena)
	_target = Node3D.new()
	_target.position = Vector3(5, 1, 0)
	_world.add_child(_target)
	_director = SpawnDirector.new()
	_director.wave_table = TinyTable
	_director.enemy_container = _container
	_director.arena = _arena
	_director.target = _target
	_director.rng_seed = 11
	_world.add_child(_director)
	watch_signals(_director)
	_director.start()


func _event(time: float, count: int, stagger: float = 0.0, pattern: SpawnPattern = null) -> SpawnEvent:
	var event := SpawnEvent.new()
	event.time = time
	event.count = count
	event.stagger = stagger
	event.enemy_scene = SpawnStub
	event.pattern = pattern
	return event


func test_schedule_from_tiny_table() -> void:
	_director.advance(0.4)
	assert_eq(_director.alive_count(), 0)
	_director.advance(0.2)
	assert_eq(_director.alive_count(), 3, "ring of three at 0.5")
	_director.advance(1.5)
	assert_eq(_director.alive_count(), 4, "point at 1.5")
	_director.advance(100.0)
	assert_eq(_director.alive_count(), 4, "non-looping table is done")
	assert_signal_emit_count(_director, "enemy_spawned", 4)


func test_large_jump_fires_each_event_once() -> void:
	_director.advance(50.0)
	assert_eq(_director.alive_count(), 4)
	_director.advance(50.0)
	assert_eq(_director.alive_count(), 4)


func test_positions_match_the_ring_and_point() -> void:
	_director.advance(2.0)
	var children := _container.get_children()
	for i in 3:
		var p: Vector3 = children[i].global_position
		assert_almost_eq(Vector2(p.x, p.z).length(), 10.0, 0.001, "ring at half of radius 20")
		assert_almost_eq(p.y, 1.0, 0.001)
	assert_almost_eq(children[3].global_position, Vector3(0, 1, 5), Vector3.ONE * 0.001)


func test_positions_are_relative_to_arena_and_container() -> void:
	_arena.position = Vector3(100, 0, 0)
	_container.position = Vector3(-3, 0, 0)
	_director.advance(2.0)
	var p: Vector3 = _container.get_child(3).global_position
	assert_almost_eq(p, Vector3(100, 1, 5), Vector3.ONE * 0.001, "global position honours both offsets")


func test_target_and_arena_injected() -> void:
	_director.advance(1.0)
	for child in _container.get_children():
		assert_same(child.target, _target)
		assert_same(child.arena, _arena)


func test_enemy_spawned_signal_carries_event() -> void:
	_director.advance(0.6)
	var params: Array = get_signal_parameters(_director, "enemy_spawned", 0)
	assert_same(params[0], _container.get_child(0))
	assert_same(params[1], TinyTable.events[0])


func test_stagger_spreads_spawns() -> void:
	var table := WaveTable.new()
	table.loop_from_time = -1.0
	table.events = [_event(1.0, 3, 0.5)]
	_director.wave_table = table
	_director.start()
	_director.advance(1.0)
	assert_eq(_director.alive_count(), 1)
	assert_eq(_director.pending_count(), 2)
	_director.advance(0.4)
	assert_eq(_director.alive_count(), 1)
	_director.advance(0.1)
	assert_eq(_director.alive_count(), 2)
	_director.advance(0.5)
	assert_eq(_director.alive_count(), 3)
	assert_eq(_director.pending_count(), 0)


func test_null_pattern_falls_back_to_ring() -> void:
	var table := WaveTable.new()
	table.loop_from_time = -1.0
	table.events = [_event(0.0, 4)]
	_director.wave_table = table
	_director.start()
	_director.advance(0.1)
	assert_eq(_director.alive_count(), 4)
	for child in _container.get_children():
		var p: Vector3 = child.global_position
		assert_almost_eq(Vector2(p.x, p.z).length(), 18.0, 0.001, "default ring at 0.9 of 20")


func test_max_alive_drops_spawns() -> void:
	var table := WaveTable.new()
	table.loop_from_time = -1.0
	table.max_alive = 2
	table.events = [_event(0.0, 5), _event(1.0, 1)]
	_director.wave_table = table
	_director.start()
	_director.advance(0.1)
	assert_eq(_director.alive_count(), 2)
	assert_eq(_director.dropped, 3)
	_director.advance(1.0)
	assert_eq(_director.alive_count(), 2, "still full")
	assert_eq(_director.dropped, 4)
	_container.get_child(0).queue_free()
	assert_eq(_director.alive_count(), 1, "queued for deletion does not count")
	assert_eq(_director.spawn_now(_event(0.0, 1)).size(), 1)
	await wait_process_frames(1)


func test_spawn_now_bypasses_time_and_stagger() -> void:
	var nodes := _director.spawn_now(_event(500.0, 3, 1.0))
	assert_eq(nodes.size(), 3)
	assert_eq(_director.alive_count(), 3)
	assert_signal_emit_count(_director, "enemy_spawned", 3)
	assert_eq(_director.spawn_now(null).size(), 0)
	var no_scene := _event(0.0, 1)
	no_scene.enemy_scene = null
	assert_eq(_director.spawn_now(no_scene).size(), 0)


func test_difficulty_scale_multiplies_counts() -> void:
	_director.difficulty_scale = 1.5
	_director.advance(0.6)
	assert_eq(_director.alive_count(), 5, "ceil(3 * 1.5)")
	_director.advance(1.0)
	assert_eq(_director.alive_count(), 7, "ceil(1 * 1.5) = 2")


func test_start_resets() -> void:
	_director.advance(2.0)
	assert_eq(_director.alive_count(), 4)
	_director.start()
	assert_eq(_director.elapsed(), 0.0)
	_director.advance(0.6)
	assert_eq(_container.get_child_count(), 7, "events replay after start()")


func test_advance_before_start_or_zero_delta_is_ignored() -> void:
	var director := SpawnDirector.new()
	director.wave_table = TinyTable
	director.enemy_container = _container
	_world.add_child(director)
	director.advance(5.0)
	assert_eq(_container.get_child_count(), 0)
	director.start()
	director.advance(0.0)
	director.advance(-1.0)
	assert_eq(_container.get_child_count(), 0)


func test_reseeded_director_is_reproducible() -> void:
	_director.advance(2.0)
	var first: Array[Vector3] = []
	for child in _container.get_children():
		first.append(child.global_position)
	for child in _container.get_children():
		child.free()
	_director.start()
	_director.advance(2.0)
	var second: Array[Vector3] = []
	for child in _container.get_children():
		second.append(child.global_position)
	assert_eq(first, second)


func test_spawner_components_get_director_veto() -> void:
	var scene := PackedScene.new()
	var root := Node3D.new()
	root.set_script(load("res://tests/fixtures/spawn_stub.gd"))
	var inner := Node3D.new()
	inner.name = "Inner"
	root.add_child(inner)
	var spawner := SpawnerComponent.new()
	spawner.name = "Spawner"
	spawner.enabled = false
	inner.add_child(spawner)
	spawner.owner = root
	inner.owner = root
	assert_eq(scene.pack(root), OK)
	root.free()
	var table := WaveTable.new()
	table.loop_from_time = -1.0
	table.max_alive = 2
	_director.wave_table = table
	_director.start()
	var event := _event(0.0, 1)
	event.enemy_scene = scene
	var spawned := _director.spawn_now(event)
	assert_eq(spawned.size(), 1)
	var nested: SpawnerComponent = spawned[0].get_node("Inner/Spawner")
	assert_true(nested.can_spawn.is_valid())
	assert_true(nested.can_spawn.call(), "1 alive < 2")
	_director.spawn_now(_event(0.0, 1))
	assert_false(nested.can_spawn.call(), "2 alive >= 2")


func test_drop_root_injected_on_gem_droppers_before_enter_tree() -> void:
	var scene := PackedScene.new()
	var root := Node3D.new()
	var dropper := GemDropComponent.new()
	dropper.name = "GemDrop"
	root.add_child(dropper)
	dropper.owner = root
	assert_eq(scene.pack(root), OK)
	root.free()
	var gems := Node3D.new()
	_world.add_child(gems)
	_director.drop_root = gems
	var event := _event(0.0, 1)
	event.enemy_scene = scene
	var spawned := _director.spawn_now(event)
	assert_same(spawned[0].get_node("GemDrop").spawn_root, gems)
	_director.drop_root = null
	var plain := _director.spawn_now(event)
	assert_null(plain[0].get_node("GemDrop").spawn_root, "no drop_root leaves the component alone")


func test_alive_count_ignores_nodes_without_died_signal() -> void:
	_director.advance(2.0)
	assert_eq(_director.alive_count(), 4)
	_container.add_child(Node3D.new())
	_container.add_child(Node.new())
	assert_eq(_director.alive_count(), 4, "gems / vfx in the container are not enemies")
	assert_eq(_container.get_child_count(), 6)


func test_spawned_nodes_get_a_seed_from_the_director() -> void:
	_director.advance(2.0)
	var seeds: Array[int] = []
	for child in _container.get_children():
		assert_ne(child.rng_seed, 0)
		seeds.append(child.rng_seed)
	_clear_container()
	_director.start()
	_director.advance(2.0)
	var again: Array[int] = []
	for child in _container.get_children():
		again.append(child.rng_seed)
	assert_eq(seeds, again, "seeds are reproducible from rng_seed")


func test_start_warns_about_authoring_problems() -> void:
	var table := WaveTable.new()
	table.loop_from_time = -1.0
	table.events = [_event(0.0, 2)]
	_director.wave_table = table
	_director.start()
	assert_push_warning("null pattern")
	_director.advance(0.1)
	assert_push_warning("using a default ring")


func _clear_container() -> void:
	for child in _container.get_children():
		child.free()
