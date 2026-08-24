extends GameTest
## The boss clock: announced, on the interval, never dropped because the arena is busy,
## and never two at once.

const SpawnStub := preload("res://tests/fixtures/spawn_stub.tscn")
const RiftScene := preload("res://src/vfx/particles/spawn_rift.tscn")


class FakeArena:
	extends Node3D

	func info() -> ArenaInfo:
		return ArenaInfo.new(global_position, 20.0, 0.0)


var _world: Node3D
var _container: Node3D
var _vfx: Node3D
var _director: SpawnDirector
var _boss_director: BossDirector


func before_each() -> void:
	super.before_each()
	_world = make_world()
	_container = Node3D.new()
	_container.name = "Enemies"
	_world.add_child(_container)
	_vfx = Node3D.new()
	_vfx.name = "Vfx"
	_world.add_child(_vfx)
	var arena := FakeArena.new()
	_world.add_child(arena)
	_director = SpawnDirector.new()
	_director.enemy_container = _container
	_director.vfx_root = _vfx
	_director.arena = arena
	_director.rng_seed = 5
	_director.telegraph_scene = RiftScene
	_director.wave_table = _capped_table(2)
	_world.add_child(_director)
	_director.start()
	_boss_director = BossDirector.new()
	_boss_director.director = _director
	_boss_director.event = _boss_event()
	_boss_director.first_at = 10.0
	_boss_director.interval = 20.0
	_boss_director.telegraph_lead = 3.0
	_world.add_child(_boss_director)
	_boss_director.start()
	watch_signals(_boss_director)


## A table whose only job is to set a low max_alive, so the cap is easy to saturate.
func _capped_table(cap: int) -> WaveTable:
	var table := WaveTable.new()
	table.events = []
	table.loop_from_time = -1.0
	table.max_alive = cap
	return table


func _boss_event() -> SpawnEvent:
	var pattern := PointPattern.new()
	pattern.point = Vector3(0, 12, 0)
	var event := SpawnEvent.new()
	event.enemy_scene = SpawnStub
	event.count = 1
	event.pattern = pattern
	event.label = "boss"
	return event


func _advance(seconds: float, step: float = 1.0 / 60.0) -> void:
	for i in int(round(seconds / step)):
		_boss_director.advance(step)


func _bosses() -> int:
	return _container.get_child_count()


func _rifts() -> int:
	var count := 0
	for child in _vfx.get_children():
		if child is OneShotVfx:
			count += 1
	return count


func test_nothing_arrives_before_the_first_window() -> void:
	_advance(6.0)
	assert_eq(_bosses(), 0)
	assert_signal_not_emitted(_boss_director, "boss_telegraphed")


func test_the_arrival_is_announced_before_it_lands() -> void:
	_advance(7.1)  # first_at 10 - telegraph_lead 3
	assert_signal_emitted(_boss_director, "boss_telegraphed")
	assert_eq(_rifts(), 1, "a warning went up")
	assert_eq(_bosses(), 0, "but nothing is here yet")
	_advance(3.0)
	assert_signal_emitted(_boss_director, "boss_spawned")
	assert_eq(_bosses(), 1)
	assert_eq(_boss_director.spawned, 1)


func test_it_lands_where_the_warning_stood() -> void:
	_advance(10.1)
	var boss := _container.get_child(0) as Node3D
	var announced: Vector3 = get_signal_parameters(_boss_director, "boss_telegraphed")[0]
	assert_almost_eq(boss.global_position, announced, Vector3.ONE * 0.001)


func test_it_comes_back_on_the_interval() -> void:
	_advance(10.1)
	assert_eq(_boss_director.spawned, 1)
	_container.get_child(0).free()
	_advance(20.0)
	assert_eq(_boss_director.spawned, 2)
	_container.get_child(0).free()
	_advance(20.0)
	assert_eq(_boss_director.spawned, 3)


func test_a_full_arena_never_swallows_the_boss() -> void:
	# Saturate max_alive with ordinary enemies first.
	var filler := _boss_event()
	filler.ignores_cap = false
	filler.count = 2
	_director.spawn_now(filler)
	assert_eq(_director.alive_count(), 2, "at the cap")
	assert_true(_director.alive_count() >= _director.max_alive())
	_advance(10.1)
	assert_eq(_boss_director.spawned, 1, "the boss arrives anyway")
	assert_true(_boss_director.event.ignores_cap, "which is what the flag is for")


func test_only_one_boss_stands_at_a_time() -> void:
	_advance(10.1)
	assert_eq(_boss_director.spawned, 1)
	assert_true(_boss_director.is_boss_alive())
	_advance(20.0)
	assert_eq(_boss_director.spawned, 1, "the window was skipped, the first is still up")
	_container.get_child(0).free()
	await wait_process_frames(1)
	assert_false(_boss_director.is_boss_alive())
	_advance(20.0)
	assert_eq(_boss_director.spawned, 2)


func test_only_one_alive_can_be_switched_off() -> void:
	_boss_director.only_one_alive = false
	_advance(10.1)
	_advance(20.0)
	assert_eq(_boss_director.spawned, 2, "two on the arena at once")
	assert_eq(_bosses(), 2)


func test_a_dead_boss_is_reported_and_forgotten() -> void:
	_advance(10.1)
	var boss := _container.get_child(0) as Node3D
	# The stub has no health; it just carries the `died` signal the director listens on.
	boss.died.emit(boss, HitInfo.new(1.0))
	await wait_process_frames(1)
	assert_signal_emitted(_boss_director, "boss_ended")
	assert_false(_boss_director.is_boss_alive())


func test_time_to_boss_counts_down() -> void:
	assert_almost_eq(_boss_director.time_to_boss(), 10.0, 0.001)
	_advance(4.0)
	assert_almost_eq(_boss_director.time_to_boss(), 6.0, 0.05)


func test_disabled_and_unconfigured_directors_are_inert() -> void:
	_boss_director.enabled = false
	_advance(60.0)
	assert_eq(_boss_director.spawned, 0)
	assert_eq(_boss_director.time_to_boss(), -1.0)
	_boss_director.enabled = true
	_boss_director.event = null
	_advance(60.0)
	assert_eq(_boss_director.spawned, 0)


func test_start_resets_the_clock() -> void:
	_advance(10.1)
	assert_eq(_boss_director.spawned, 1)
	_boss_director.start()
	assert_eq(_boss_director.spawned, 0)
	assert_eq(_boss_director.elapsed, 0.0)
	assert_false(_boss_director.is_boss_alive())
	_advance(6.0)
	assert_eq(_boss_director.spawned, 0, "counting from zero again")
