extends GameTest


func _event(stagger: float) -> SpawnEvent:
	var event := SpawnEvent.new()
	event.stagger = stagger
	return event


func _positions(n: int) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for i in n:
		result.append(Vector3(i, 0, 0))
	return result


func test_push_and_pop_without_stagger() -> void:
	var queue := SpawnQueue.new()
	var event := _event(0.0)
	queue.push(event, 1.0, _positions(3))
	assert_eq(queue.size(), 3)
	assert_eq(queue.pop_due(0.99).size(), 0)
	var due := queue.pop_due(1.0)
	assert_eq(due.size(), 3)
	assert_same(due[0]["event"], event)
	assert_eq(due[2]["position"], Vector3(2, 0, 0))
	assert_true(queue.is_empty())


func test_stagger_spreads_due_times() -> void:
	var queue := SpawnQueue.new()
	queue.push(_event(0.5), 1.0, _positions(3))
	assert_eq(queue.pop_due(1.0).size(), 1)
	assert_eq(queue.pop_due(1.4).size(), 0)
	assert_eq(queue.pop_due(1.5).size(), 1)
	assert_eq(queue.size(), 1)
	assert_eq(queue.pop_due(10.0).size(), 1)


func test_pop_due_orders_by_due_time_across_events() -> void:
	var queue := SpawnQueue.new()
	queue.push(_event(1.0), 2.0, _positions(2))
	queue.push(_event(0.0), 2.5, [Vector3(9, 9, 9)])
	var due := queue.pop_due(3.0)
	assert_eq(due.size(), 3)
	assert_eq(due[0]["position"], Vector3(0, 0, 0))
	assert_eq(due[1]["position"], Vector3(9, 9, 9))
	assert_eq(due[2]["position"], Vector3(1, 0, 0))


func test_null_event_and_clear() -> void:
	var queue := SpawnQueue.new()
	queue.push(null, 0.0, _positions(2))
	assert_true(queue.is_empty())
	queue.push(_event(0.0), 0.0, _positions(2))
	queue.clear()
	assert_eq(queue.size(), 0)
	assert_eq(queue.pop_due(100.0).size(), 0)


func test_telegraph_lead_pulls_the_warning_earlier_without_moving_the_spawn() -> void:
	var queue := SpawnQueue.new()
	queue.push(_event(0.0), 2.0, _positions(1), 0.5)
	assert_eq(queue.pop_telegraph_due(1.49).size(), 0)
	assert_eq(queue.pop_telegraph_due(1.5).size(), 1, "warned half a second early")
	assert_eq(queue.size(), 1, "the enemy is still queued")
	assert_eq(queue.pop_due(1.99).size(), 0)
	assert_eq(queue.pop_due(2.0).size(), 1, "and still arrives at the authored time")


func test_each_entry_is_only_telegraphed_once() -> void:
	var queue := SpawnQueue.new()
	queue.push(_event(0.0), 2.0, _positions(3), 0.5)
	assert_eq(queue.pop_telegraph_due(1.5).size(), 3)
	assert_eq(queue.pop_telegraph_due(1.6).size(), 0, "already warned")
	assert_eq(queue.pop_telegraph_due(9.0).size(), 0)
	assert_eq(queue.pop_due(9.0).size(), 3, "all three still spawn")


func test_telegraph_follows_the_stagger() -> void:
	var queue := SpawnQueue.new()
	queue.push(_event(0.5), 1.0, _positions(3), 0.25)
	assert_eq(queue.pop_telegraph_due(0.75).size(), 1)
	assert_eq(queue.pop_telegraph_due(1.24).size(), 0)
	assert_eq(queue.pop_telegraph_due(1.25).size(), 1, "the second of the stagger")
	assert_eq(queue.pop_telegraph_due(10.0).size(), 1)


func test_telegraphs_are_ordered_by_their_own_moment() -> void:
	var queue := SpawnQueue.new()
	queue.push(_event(1.0), 2.0, _positions(2), 0.5)
	queue.push(_event(0.0), 2.5, [Vector3(9, 9, 9)], 0.5)
	var warned := queue.pop_telegraph_due(3.0)
	assert_eq(warned.size(), 3)
	assert_eq(warned[0]["position"], Vector3(0, 0, 0))
	assert_eq(warned[1]["position"], Vector3(9, 9, 9))
	assert_eq(warned[2]["position"], Vector3(1, 0, 0))


func test_without_a_lead_the_warning_and_the_spawn_coincide() -> void:
	var queue := SpawnQueue.new()
	queue.push(_event(0.0), 1.0, _positions(2))
	assert_eq(queue.pop_telegraph_due(0.99).size(), 0)
	assert_eq(queue.pop_telegraph_due(1.0).size(), 2)
	assert_eq(queue.pop_due(1.0).size(), 2)


func test_a_negative_lead_is_ignored_rather_than_delaying_the_warning() -> void:
	var queue := SpawnQueue.new()
	queue.push(_event(0.0), 1.0, _positions(1), -5.0)
	assert_eq(queue.pop_telegraph_due(1.0).size(), 1)


func test_a_lead_longer_than_the_run_so_far_warns_immediately() -> void:
	var queue := SpawnQueue.new()
	queue.push(_event(0.0), 0.2, _positions(1), 5.0)
	assert_eq(queue.pop_telegraph_due(0.0).size(), 1, "as much warning as there was room for")
	assert_eq(queue.pop_due(0.19).size(), 0)
	assert_eq(queue.pop_due(0.2).size(), 1)


func test_untelegraphed_count_tracks_what_has_not_been_warned_yet() -> void:
	var queue := SpawnQueue.new()
	queue.push(_event(0.0), 2.0, _positions(3), 0.5)
	assert_eq(queue.untelegraphed_count(), 3)
	queue.pop_telegraph_due(1.5)
	assert_eq(queue.untelegraphed_count(), 0)
	assert_eq(queue.size(), 3, "still waiting to spawn")
