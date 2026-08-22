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
