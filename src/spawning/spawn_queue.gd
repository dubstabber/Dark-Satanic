class_name SpawnQueue
extends RefCounted
## Individual spawns waiting for their due time (handles SpawnEvent.stagger).


class Entry:
	var event: SpawnEvent
	var position: Vector3
	var due: float

	func _init(p_event: SpawnEvent, p_position: Vector3, p_due: float) -> void:
		event = p_event
		position = p_position
		due = p_due


var _entries: Array[Entry] = []


func size() -> int:
	return _entries.size()


func is_empty() -> bool:
	return _entries.is_empty()


func clear() -> void:
	_entries.clear()


## Queues one individual per position; position i is due at due_time + i * event.stagger.
func push(event: SpawnEvent, due_time: float, positions: Array[Vector3]) -> void:
	if event == null:
		return
	for i in positions.size():
		_entries.append(Entry.new(event, positions[i], due_time + float(i) * event.stagger))


## Removes and returns every entry due at `now` as {event, position}, ordered by due time.
func pop_due(now: float) -> Array[Dictionary]:
	var due: Array[Entry] = []
	var remaining: Array[Entry] = []
	for entry in _entries:
		if entry.due <= now:
			due.append(entry)
		else:
			remaining.append(entry)
	_entries = remaining
	due.sort_custom(func(a: Entry, b: Entry) -> bool: return a.due < b.due)
	var result: Array[Dictionary] = []
	for entry in due:
		result.append({"event": entry.event, "position": entry.position})
	return result
