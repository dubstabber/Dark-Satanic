extends GameTest
## SpawnDirector endless-loop behaviour: block scheduling, caps and bounded work per advance().

const SpawnStub := preload("res://tests/fixtures/spawn_stub.tscn")

var _world: Node3D
var _container: Node3D
var _director: SpawnDirector


func before_each() -> void:
	super.before_each()
	_world = make_world()
	_container = Node3D.new()
	_world.add_child(_container)
	_director = SpawnDirector.new()
	_director.enemy_container = _container
	_director.rng_seed = 11
	_world.add_child(_director)


func _event(time: float, count: int, stagger: float = 0.0) -> SpawnEvent:
	var event := SpawnEvent.new()
	event.time = time
	event.count = count
	event.stagger = stagger
	event.enemy_scene = SpawnStub
	event.pattern = RingPattern.new()
	return event


func test_endless_loop_scales_events() -> void:
	var table := WaveTable.new()
	table.loop_from_time = 10.0
	table.loop_count_multiplier = 2.0
	table.loop_interval_multiplier = 0.5
	table.min_interval_fraction = 0.1
	table.max_alive = 1000
	table.events = [_event(0.0, 1), _event(10.0, 2), _event(20.0, 1)]
	_director.wave_table = table
	_director.start()
	_director.advance(19.99)
	assert_eq(_director.alive_count(), 3, "authored: 1 + 2")
	# Block 1 starts at 20 (last time), lasts 30 * 0.5 = 15: events at 20 (count 4) and 25 (count 2).
	_director.advance(0.02)
	assert_eq(_director.alive_count(), 8, "authored event at 20 plus loop block 1 first event (count 4)")
	_director.advance(4.9)
	assert_eq(_director.alive_count(), 8)
	_director.advance(0.2)
	assert_eq(_director.alive_count(), 10, "second event of block 1 at t=25")
	# Block 2 starts at 35, lasts 7.5: events at 35 (count 8) and 37.5 (count 4).
	_director.advance(9.9)
	assert_eq(_director.alive_count(), 18)
	_director.advance(2.6)
	assert_eq(_director.alive_count(), 22)


func test_runaway_loop_table_advances_in_bounded_time() -> void:
	var table := WaveTable.new()
	table.loop_from_time = 10.0
	table.loop_count_multiplier = 1.25
	table.loop_interval_multiplier = 0.9
	table.max_alive = 20
	table.events = [_event(0.0, 2), _event(10.0, 3), _event(20.0, 4)]
	_director.wave_table = table
	_director.start()
	var started := Time.get_ticks_msec()
	for i in 900:
		_director.advance(1.0)
		assert_true(_director.pending_count() <= table.max_alive, "queue never holds more than max_alive")
	assert_true(Time.get_ticks_msec() - started < 5000, "15 minutes of endless loop in well under 5 s")
	assert_eq(_director.alive_count(), table.max_alive)
	assert_true(_director.dropped > 0)


func test_loop_extends_one_block_per_advance_and_only_when_due() -> void:
	var table := WaveTable.new()
	table.loop_from_time = 10.0
	table.loop_interval_multiplier = 0.5
	table.loop_count_multiplier = 1.0
	table.max_alive = 1000
	table.events = [_event(0.0, 1), _event(10.0, 1), _event(20.0, 1)]
	_director.wave_table = table
	_director.start()
	_director.advance(20.5)
	assert_eq(_director.alive_count(), 4, "authored 3 + block 1 first event at 20")
	_director.advance(200.0)
	var after_jump := _director.alive_count()
	assert_true(after_jump < 40, "one block per advance: a huge jump does not schedule every block at once")
	_director.advance(1.0)
	assert_true(_director.alive_count() > after_jump, "the next advance catches up another block")


func test_scheduling_caps_positions_to_room_under_max_alive() -> void:
	var table := WaveTable.new()
	table.loop_from_time = -1.0
	table.max_alive = 3
	table.events = [_event(0.0, 10, 1.0)]
	_director.wave_table = table
	_director.start()
	_director.advance(0.1)
	assert_eq(_director.alive_count(), 1)
	assert_eq(_director.pending_count(), 2, "only 3 individuals queued, not 10")
	assert_eq(_director.dropped, 7)
