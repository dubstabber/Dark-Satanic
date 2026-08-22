extends GameTest


func test_begin_creates_running_state_and_broadcasts() -> void:
	watch_signals(RunManager)
	watch_signals(EventBus)
	var state := RunManager.begin(UpgradeLadder.new())
	assert_not_null(state)
	assert_true(RunManager.is_running())
	assert_same(RunManager.current, state)
	assert_signal_emitted_with_parameters(RunManager, "run_started", [state])
	assert_signal_emitted_with_parameters(EventBus, "run_started", [state])


func test_finish_stores_result_and_broadcasts() -> void:
	watch_signals(RunManager)
	watch_signals(EventBus)
	var state := RunManager.begin(UpgradeLadder.new())
	state.tick(3.0)
	var result := RunManager.finish(&"void")
	assert_false(RunManager.is_running())
	assert_same(RunManager.last_result, result)
	assert_eq(result.death_cause, &"void")
	assert_signal_emitted_with_parameters(RunManager, "run_ended", [result])
	assert_signal_emitted_with_parameters(EventBus, "run_ended", [result])
	assert_same(RunManager.finish(&"twice"), result, "finishing again is a no-op")


func test_state_ending_itself_is_observed() -> void:
	watch_signals(RunManager)
	var state := RunManager.begin(UpgradeLadder.new())
	state.end(&"enemy")
	assert_signal_emitted(RunManager, "run_ended")
	assert_false(RunManager.is_running())


func test_begin_while_running_aborts_previous() -> void:
	var first := RunManager.begin(UpgradeLadder.new())
	var second := RunManager.begin(UpgradeLadder.new())
	assert_false(first.is_running)
	assert_true(second.is_running)
	assert_eq(first.death_cause, &"aborted")


func test_reset_clears_everything() -> void:
	RunManager.begin(UpgradeLadder.new())
	RunManager.reset()
	assert_null(RunManager.current)
	assert_null(RunManager.last_result)
	assert_false(RunManager.is_running())
