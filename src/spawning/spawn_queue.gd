class_name SpawnQueue
extends RefCounted
## Individual spawns waiting for their due time (handles SpawnEvent.stagger), each
## with an earlier moment at which its arrival should be telegraphed.
##
## An entry is popped twice: once by pop_telegraph_due() to raise the warning effect,
## then by pop_due() to actually spawn. With a zero lead the two coincide.


class Entry:
	var event: SpawnEvent
	var position: Vector3
	## When the enemy arrives.
	var due: float
	## When its warning effect should appear; never later than `due`.
	var telegraph_due: float
	var telegraphed: bool = false

	func _init(p_event: SpawnEvent, p_position: Vector3, p_due: float, p_telegraph_due: float) -> void:
		event = p_event
		position = p_position
		due = p_due
		telegraph_due = minf(p_telegraph_due, p_due)


var _entries: Array[Entry] = []


func size() -> int:
	return _entries.size()


func is_empty() -> bool:
	return _entries.is_empty()


func clear() -> void:
	_entries.clear()


## Queues one individual per position; position i is due at due_time + i * event.stagger.
## `telegraph_lead` pulls the warning that many seconds *earlier* rather than delaying the
## spawn, so adding a telegraph never shifts an authored wave table's difficulty curve.
func push(
	event: SpawnEvent, due_time: float, positions: Array[Vector3], telegraph_lead: float = 0.0
) -> void:
	if event == null:
		return
	var lead := maxf(telegraph_lead, 0.0)
	for i in positions.size():
		var at := due_time + float(i) * event.stagger
		_entries.append(Entry.new(event, positions[i], at, at - lead))


## Every entry whose telegraph moment has arrived, as {event, position}, ordered by that
## moment. Each entry is only ever returned once — the flag lives on the entry, so the
## enemy itself still waits in the queue for pop_due().
func pop_telegraph_due(now: float) -> Array[Dictionary]:
	var due: Array[Entry] = []
	for entry in _entries:
		if not entry.telegraphed and entry.telegraph_due <= now:
			entry.telegraphed = true
			due.append(entry)
	due.sort_custom(func(a: Entry, b: Entry) -> bool: return a.telegraph_due < b.telegraph_due)
	return _as_dictionaries(due)


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
	return _as_dictionaries(due)


## Entries still waiting for their telegraph (nothing has been shown for them yet).
func untelegraphed_count() -> int:
	var count := 0
	for entry in _entries:
		if not entry.telegraphed:
			count += 1
	return count


static func _as_dictionaries(entries: Array[Entry]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in entries:
		result.append({"event": entry.event, "position": entry.position})
	return result
