extends GameTest
## WhisperScheduler emits on a seeded random interval and tolerates a null cue.

var _scheduler: WhisperScheduler


func before_each() -> void:
	_scheduler = WhisperScheduler.new()
	_scheduler.rng_seed = 11
	_scheduler.interval_min = 2.0
	_scheduler.interval_max = 4.0
	add_child_autofree(_scheduler)


func test_first_whisper_lands_inside_the_interval_window() -> void:
	watch_signals(_scheduler)
	for i in 39:  # 3.9 s < interval_min is impossible to miss but never past max
		_scheduler.advance(0.1)
		if get_signal_emit_count(_scheduler, "whispered") > 0:
			break
	assert_signal_emit_count(_scheduler, "whispered", 1)


func test_no_whisper_before_the_minimum_interval() -> void:
	watch_signals(_scheduler)
	for i in 19:
		_scheduler.advance(0.1)
	assert_signal_emit_count(_scheduler, "whispered", 0)


func test_reschedules_after_each_whisper() -> void:
	watch_signals(_scheduler)
	for i in 100:
		_scheduler.advance(0.1)
	var first: int = get_signal_emit_count(_scheduler, "whispered")
	assert_gt(first, 0, "whispers at least once in 10 s")
	for i in 100:
		_scheduler.advance(0.1)
	assert_gt(get_signal_emit_count(_scheduler, "whispered"), first, "keeps whispering")


func test_null_cue_does_not_error() -> void:
	_scheduler.cue = null
	for i in 50:
		_scheduler.advance(0.1)
	pass_test("advance with a null cue is a safe no-op play")
