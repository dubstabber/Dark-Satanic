extends GameTest

var _ladder: UpgradeLadder


func before_each() -> void:
	super.before_each()
	_ladder = UpgradeLadder.new()
	for gems in [0, 10, 70]:
		var tier := DaggerUpgradeTier.new()
		tier.gems_required = gems
		_ladder.tiers.append(tier)


func _started() -> RunState:
	var state := RunState.new(_ladder)
	watch_signals(state)
	state.start()
	return state


func test_start_emits_initial_tier() -> void:
	var state := _started()
	assert_true(state.is_running)
	assert_signal_emitted_with_parameters(state, "tier_changed", [state.current_tier(), 0])


func test_tick_accumulates_only_while_running() -> void:
	var state := RunState.new(_ladder)
	state.tick(1.0)
	assert_eq(state.elapsed, 0.0, "not running yet")
	state.start()
	state.tick(0.5)
	state.tick(0.25)
	assert_almost_eq(state.elapsed, 0.75, 0.0001)
	state.tick(-1.0)
	assert_almost_eq(state.elapsed, 0.75, 0.0001, "negative delta ignored")


func test_gems_cross_tier_once() -> void:
	var state := _started()
	state.add_gems(4)
	state.add_gems(5)
	assert_eq(state.gems, 9)
	assert_eq(state.tier_index, 0)
	assert_signal_emit_count(state, "tier_changed", 1, "only the initial emission so far")
	state.add_gems(1)
	assert_eq(state.tier_index, 1)
	assert_signal_emit_count(state, "tier_changed", 2)
	state.add_gems(5)
	assert_signal_emit_count(state, "tier_changed", 2, "staying inside a tier does not re-emit")
	assert_signal_emit_count(state, "gems_changed", 4)


func test_big_jump_skips_tiers() -> void:
	var state := _started()
	state.add_gems(500)
	assert_eq(state.tier_index, 2)
	assert_eq(state.gems_to_next_tier(), -1)


func test_non_positive_gems_ignored() -> void:
	var state := _started()
	state.add_gems(0)
	state.add_gems(-3)
	assert_eq(state.gems, 0)
	assert_signal_not_emitted(state, "gems_changed")


func test_end_snapshots_result_and_stops() -> void:
	var state := _started()
	state.tick(12.5)
	state.add_gems(12)
	state.add_kill()
	var result := state.end(&"enemy")
	assert_false(state.is_running)
	assert_signal_emitted(state, "ended")
	assert_almost_eq(result.time_survived, 12.5, 0.0001)
	assert_eq(result.gems, 12)
	assert_eq(result.kills, 1)
	assert_eq(result.tier_index, 1)
	assert_eq(result.death_cause, &"enemy")
	assert_true(result.unix_time > 0)
	assert_null(state.end(&"again"), "ending twice returns null")
	state.tick(1.0)
	state.add_gems(1)
	assert_almost_eq(state.elapsed, 12.5, 0.0001, "frozen after death")
	assert_eq(state.gems, 12)
