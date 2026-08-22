extends GameTest

const SpawnStub := preload("res://tests/fixtures/spawn_stub.tscn")


func _event(time: float, count: int = 1, label: String = "") -> SpawnEvent:
	var event := SpawnEvent.new()
	event.time = time
	event.count = count
	event.label = label
	event.enemy_scene = SpawnStub
	event.pattern = RingPattern.new()
	return event


func _table(times: Array, loop_from: float = 240.0) -> WaveTable:
	var table := WaveTable.new()
	for t in times:
		table.events.append(_event(t))
	table.loop_from_time = loop_from
	return table


func test_expanded_sorted_and_stable() -> void:
	var table := WaveTable.new()
	table.events = [_event(5, 1, "a"), _event(1, 1, "b"), _event(5, 1, "c"), null, _event(0, 1, "d"), _event(1, 1, "e")]
	var labels: Array[String] = []
	for event in table.expanded():
		labels.append(event.label)
	assert_eq(labels, ["d", "b", "e", "a", "c"])
	assert_eq(table.events.size(), 6, "original untouched")
	assert_eq(WaveTable.new().expanded().size(), 0)


func test_validate_reports_problems() -> void:
	var table := WaveTable.new()
	var bad := _event(-1, 0, "bad")
	bad.enemy_scene = null
	bad.pattern = null
	table.events = [_event(1), bad, null]
	var problems := table.validate()
	assert_eq(problems.size(), 5)
	assert_string_contains(problems[0], "negative time")
	assert_string_contains(problems[0], "bad")
	assert_string_contains(problems[1], "null enemy_scene")
	assert_string_contains(problems[2], "count <= 0")
	assert_string_contains(problems[3], "null pattern")
	assert_string_contains(problems[4], "event 2: null")
	assert_eq(_table([1, 2]).validate().size(), 0)


func test_loop_events_scaling_k1_and_k2() -> void:
	var table := WaveTable.new()
	table.events = [_event(0, 5), _event(240, 3, "x"), _event(300, 10, "y")]
	table.loop_from_time = 240.0
	assert_eq(table.last_time(), 300.0)
	assert_eq(table.loop_block_duration(), 60.0)
	assert_true(table.loops())
	var k1 := table.loop_events(1)
	assert_eq(k1.size(), 2, "only events at or after loop_from_time")
	assert_almost_eq(k1[0].time, 300.0, 0.001)
	assert_almost_eq(k1[1].time, 300.0 + 60.0 * 0.9, 0.001)
	assert_eq(k1[0].count, 4, "ceil(3 * 1.25)")
	assert_eq(k1[1].count, 13, "ceil(10 * 1.25)")
	assert_eq(k1[0].label, "x")
	assert_same(k1[0].pattern, table.events[1].pattern)
	assert_same(k1[0].enemy_scene, SpawnStub)
	var k2 := table.loop_events(2)
	assert_almost_eq(k2[0].time, 300.0 + 54.0, 0.001, "block 2 starts after block 1")
	assert_almost_eq(k2[1].time, 354.0 + 60.0 * 0.81, 0.001)
	assert_eq(k2[0].count, 5, "ceil(3 * 1.5625)")
	assert_eq(k2[1].count, 16, "ceil(10 * 1.5625)")
	assert_eq(table.loop_events(0).size(), 0)


func test_loop_block_minimum_duration() -> void:
	var table := _table([0, 240, 250])
	assert_eq(table.loop_block_duration(), 30.0)
	var k2 := table.loop_events(2)
	assert_almost_eq(k2[0].time, 250.0 + 30.0 * 0.9, 0.001)


func test_loop_disabled_with_negative_loop_from_time() -> void:
	var table := _table([0, 10, 20], -1.0)
	assert_false(table.loops())
	assert_eq(table.loop_events(1).size(), 0)


func test_loop_empty_when_no_event_reaches_loop_from_time() -> void:
	var table := _table([0, 10], 240.0)
	assert_false(table.loops())
	assert_eq(table.loop_events(1).size(), 0)


func test_loop_counts_never_drop_below_one() -> void:
	var table := _table([0, 240])
	table.loop_count_multiplier = 1.0
	assert_eq(table.loop_events(3)[0].count, 1)


func test_defaults() -> void:
	var table := WaveTable.new()
	assert_eq(table.loop_from_time, 240.0)
	assert_eq(table.loop_count_multiplier, 1.25)
	assert_eq(table.loop_interval_multiplier, 0.9)
	assert_eq(table.max_alive, 120)
	var event := SpawnEvent.new()
	assert_eq(event.count, 1)
	assert_eq(event.stagger, 0.0)


func test_test_tiny_resource_loads() -> void:
	var table: WaveTable = load("res://src/spawning/waves/test_tiny.tres")
	assert_not_null(table)
	assert_eq(table.validate().size(), 0)
	assert_eq(table.events.size(), 2)
	assert_eq(table.loop_from_time, -1.0)
	assert_true(table.events[0].pattern is RingPattern)
	assert_true(table.events[1].pattern is PointPattern)
	assert_eq(table.events[1].pattern.point, Vector3(0, 1, 5))


func test_milestone1_table_when_archetypes_exist() -> void:
	for archetype in ["weeper", "mourner", "lament", "vesper", "glutton"]:
		if not ResourceLoader.exists("res://src/enemies/archetypes/%s.tscn" % archetype):
			pending("enemy archetype scenes are not present yet")
			return
	var table: WaveTable = load("res://src/spawning/waves/milestone1.tres")
	assert_not_null(table)
	assert_eq(table.validate().size(), 0)
	assert_eq(table.events.size(), 23)
	assert_eq(table.loop_from_time, 240.0)
	assert_eq(table.max_alive, 120)
	assert_eq(table.last_time(), 300.0)
	assert_true(table.loops())
	assert_eq(table.loop_events(1).size(), 7)
	var times: Array[float] = []
	for event in table.expanded():
		times.append(event.time)
		assert_ne(event.label, "")
	assert_eq(times[0], 3.0)
	assert_eq(times[times.size() - 1], 300.0)
