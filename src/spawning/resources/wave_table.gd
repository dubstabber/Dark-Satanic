class_name WaveTable
extends Resource
## Authored spawn schedule plus the rules for looping it endlessly.
##
## Endless mode: once the last authored event has fired, the events with
## `time >= loop_from_time` are replayed as block k = 1, 2, ... Each block
## starts when the previous one ends, is `loop_interval_multiplier^k` as long
## (never shorter than `min_interval_fraction` of the authored block) and
## multiplies counts by `loop_count_multiplier^k` (ceil, capped at
## `max_count_multiplier`). Both caps keep the series divergent in time and
## bounded in count, so the loop can run for hours without freezing.

@export var events: Array[SpawnEvent] = []
## Events at or after this time are repeated forever once the table is exhausted (-1 disables).
@export_range(-1.0, 3600.0, 1.0) var loop_from_time: float = 240.0
@export_range(1.0, 4.0, 0.01) var loop_count_multiplier: float = 1.25
@export_range(0.1, 1.0, 0.01) var loop_interval_multiplier: float = 0.9
## Loop blocks never get shorter than this fraction of the authored block length.
@export_range(0.1, 1.0, 0.01) var min_interval_fraction: float = 0.5
## Counts are never multiplied by more than this, however many blocks have passed.
@export_range(1.0, 64.0, 0.1) var max_count_multiplier: float = 4.0
## Shortest authored loop block (used when the looped events span less time).
@export_range(1.0, 600.0, 1.0) var min_loop_block: float = 30.0
@export_range(1, 1024) var max_alive: int = 120


## Copy of `events` sorted by time (stable, nulls dropped).
func expanded() -> Array[SpawnEvent]:
	var result: Array[SpawnEvent] = []
	for event in events:
		if event != null:
			result.append(event)
	_stable_sort(result)
	return result


## Time of the last authored event (0 when empty).
func last_time() -> float:
	var last := 0.0
	for event in events:
		if event != null:
			last = maxf(last, event.time)
	return last


func loops() -> bool:
	return loop_from_time >= 0.0 and not _loop_source().is_empty()


## Length of the authored loop block (last event time - loop_from_time, at least min_loop_block).
func loop_block_duration() -> float:
	return maxf(last_time() - loop_from_time, min_loop_block)


## Time scale of loop block k: loop_interval_multiplier^k, floored at min_interval_fraction.
func loop_time_scale(k: int) -> float:
	return maxf(pow(loop_interval_multiplier, k), min_interval_fraction)


## Count scale of loop block k: loop_count_multiplier^k, capped at max_count_multiplier.
func loop_count_scale(k: int) -> float:
	return minf(pow(loop_count_multiplier, k), max_count_multiplier)


## Start time of loop block k (k = 1 starts right after the last authored event).
func loop_block_start(k: int) -> float:
	var start := last_time()
	for i in range(1, k):
		start += loop_block_duration() * loop_time_scale(i)
	return start


## The looped events for repeat k (>= 1), re-timed and scaled.
func loop_events(k: int) -> Array[SpawnEvent]:
	var result: Array[SpawnEvent] = []
	if not loops() or k < 1:
		return result
	var start := loop_block_start(k)
	var time_scale := loop_time_scale(k)
	var count_scale := loop_count_scale(k)
	for event in _loop_source():
		var new_time := start + (event.time - loop_from_time) * time_scale
		var new_count := int(ceil(float(event.count) * count_scale))
		result.append(event.retimed(new_time, maxi(new_count, 1)))
	return result


## Human-readable problems; empty when the table is usable.
func validate() -> Array[String]:
	var problems: Array[String] = []
	for i in events.size():
		var event := events[i]
		var tag := "event %d" % i
		if event == null:
			problems.append("%s: null" % tag)
			continue
		if event.label != "":
			tag += " (%s)" % event.label
		if event.time < 0.0:
			problems.append("%s: negative time" % tag)
		if event.enemy_scene == null:
			problems.append("%s: null enemy_scene" % tag)
		if event.count <= 0:
			problems.append("%s: count <= 0" % tag)
		if event.pattern == null:
			problems.append("%s: null pattern" % tag)
	return problems


func _loop_source() -> Array[SpawnEvent]:
	var result: Array[SpawnEvent] = []
	for event in expanded():
		if event.time >= loop_from_time:
			result.append(event)
	return result


static func _stable_sort(list: Array[SpawnEvent]) -> void:
	for i in range(1, list.size()):
		var item := list[i]
		var j := i - 1
		while j >= 0 and list[j].time > item.time:
			list[j + 1] = list[j]
			j -= 1
		list[j + 1] = item
