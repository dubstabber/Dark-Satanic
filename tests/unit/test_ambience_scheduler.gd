extends GameTest
## AmbienceScheduler fires on a seeded random interval, picks from its cue list and places
## the sound around its origin. Two of these run in game.tscn: the whispers (flat, radius 0)
## and the dread stingers (out in the dark, radius 15).

var _scheduler: AmbienceScheduler


func before_each() -> void:
	_scheduler = AmbienceScheduler.new()
	_scheduler.rng_seed = 11
	_scheduler.interval_min = 2.0
	_scheduler.interval_max = 4.0
	add_child_autofree(_scheduler)


func test_first_sound_lands_inside_the_interval_window() -> void:
	watch_signals(_scheduler)
	for i in 39:  # 3.9 s: past interval_max is impossible, before interval_min is a bug
		_scheduler.advance(0.1)
		if get_signal_emit_count(_scheduler, "played") > 0:
			break
	assert_signal_emit_count(_scheduler, "played", 1)


func test_nothing_sounds_before_the_minimum_interval() -> void:
	watch_signals(_scheduler)
	for i in 19:
		_scheduler.advance(0.1)
	assert_signal_emit_count(_scheduler, "played", 0)


func test_reschedules_after_each_sound() -> void:
	watch_signals(_scheduler)
	for i in 100:
		_scheduler.advance(0.1)
	var first: int = get_signal_emit_count(_scheduler, "played")
	assert_gt(first, 0, "sounds at least once in 10 s")
	for i in 100:
		_scheduler.advance(0.1)
	assert_gt(get_signal_emit_count(_scheduler, "played"), first, "keeps going")


func test_an_empty_cue_list_does_not_error() -> void:
	_scheduler.cues = []
	for i in 50:
		_scheduler.advance(0.1)
	assert_null(_scheduler.pick_cue(), "nothing to pick")
	pass_test("advance with no cues is a safe no-op play")


func test_it_picks_across_the_whole_cue_list() -> void:
	var a := AudioCue.new()
	var b := AudioCue.new()
	var c := AudioCue.new()
	_scheduler.cues = [a, b, c]
	var seen := {}
	for i in 60:
		seen[_scheduler.pick_cue()] = true
	assert_eq(seen.size(), 3, "every cue comes up over sixty draws")


func test_a_flat_scheduler_sounds_at_the_origin_with_no_direction() -> void:
	_scheduler.radius = 0.0
	var origin := Node3D.new()
	origin.position = Vector3(4, 1, -2)
	add_child_autofree(origin)
	_scheduler.origin = origin
	assert_eq(_scheduler.next_position(), Vector3(4, 1, -2), "in your head, not out in the room")


func test_a_placed_scheduler_scatters_around_its_origin() -> void:
	_scheduler.radius = 15.0
	_scheduler.height_spread = 2.5
	var origin := Node3D.new()
	origin.position = Vector3(4, 1, -2)
	add_child_autofree(origin)
	_scheduler.origin = origin
	var bearings: Array[float] = []
	for i in 12:
		var at := _scheduler.next_position()
		var offset := at - origin.global_position
		assert_almost_eq(Vector2(offset.x, offset.z).length(), 15.0, 0.001, "on the circle")
		assert_lt(absf(offset.y), 2.5 + 0.001, "inside the height band")
		bearings.append(atan2(offset.z, offset.x))
	assert_gt(bearings.max() - bearings.min(), 1.0, "comes from all around, not one bearing")


func test_a_scheduler_without_an_origin_is_still_safe() -> void:
	_scheduler.radius = 10.0
	assert_almost_eq(_scheduler.next_position().length(), 10.0, 2.6, "falls back to the arena origin")
	for i in 50:
		_scheduler.advance(0.1)
	pass_test("no origin, no crash")
