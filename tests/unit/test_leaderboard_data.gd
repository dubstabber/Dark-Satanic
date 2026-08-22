extends GameTest


func _entry(time: float, name: String = "ANON") -> LeaderboardEntry:
	return LeaderboardEntry.make(name, time, 3, 1, 7, 1000)


func _times(data: LeaderboardData) -> Array[float]:
	var result: Array[float] = []
	for entry in data.entries:
		result.append(entry.time_survived)
	return result


func test_empty_board() -> void:
	var data := LeaderboardData.new()
	assert_eq(data.size(), 0)
	assert_null(data.best())
	assert_true(data.qualifies(0.0))
	assert_eq(data.max_entries, 10)


func test_insert_keeps_descending_order_and_returns_rank() -> void:
	var data := LeaderboardData.new()
	assert_eq(data.insert(_entry(10.0)), 0)
	assert_eq(data.insert(_entry(30.0)), 0)
	assert_eq(data.insert(_entry(20.0)), 1)
	assert_eq(data.insert(_entry(5.0)), 3)
	assert_eq(_times(data), [30.0, 20.0, 10.0, 5.0])


func test_ties_rank_below_existing_equal_times() -> void:
	var data := LeaderboardData.new()
	data.insert(_entry(10.0, "FIRST"))
	assert_eq(data.insert(_entry(10.0, "SECOND")), 1)
	assert_eq(data.entries[0].player_name, "FIRST")
	assert_eq(data.entries[1].player_name, "SECOND")


func test_cap_at_max_entries_trims_the_worst() -> void:
	var data := LeaderboardData.new()
	for i in 10:
		data.insert(_entry(float(i + 1) * 10.0))
	assert_eq(data.size(), 10)
	assert_eq(data.insert(_entry(55.0)), 5, "beats the 50.0 entry")
	assert_eq(data.size(), 10)
	assert_false(_times(data).has(10.0), "the worst entry fell off")
	assert_eq(data.insert(_entry(1.0)), -1)
	assert_eq(data.size(), 10)


func test_qualifies_on_full_board_requires_beating_the_last() -> void:
	var data := LeaderboardData.new()
	data.max_entries = 3
	for t in [30.0, 20.0, 10.0]:
		data.insert(_entry(t))
	assert_false(data.qualifies(10.0), "equal to the last does not qualify")
	assert_true(data.qualifies(10.01))
	assert_false(data.qualifies(0.0))
	assert_eq(data.insert(_entry(10.0)), -1)


func test_smaller_max_entries_respected() -> void:
	var data := LeaderboardData.new()
	data.max_entries = 2
	data.insert(_entry(1.0))
	data.insert(_entry(2.0))
	assert_eq(data.insert(_entry(3.0)), 0)
	assert_eq(_times(data), [3.0, 2.0])


func test_best_is_the_first_entry() -> void:
	var data := LeaderboardData.new()
	data.insert(_entry(4.0, "LOW"))
	data.insert(_entry(9.0, "HIGH"))
	assert_eq(data.best().player_name, "HIGH")


func test_insert_null_is_rejected() -> void:
	var data := LeaderboardData.new()
	assert_eq(data.insert(null), -1)
	assert_eq(data.size(), 0)


func test_entry_make_copies_every_field() -> void:
	var entry := LeaderboardEntry.make("ZED", 12.5, 4, 2, 9, 777)
	assert_eq(entry.player_name, "ZED")
	assert_almost_eq(entry.time_survived, 12.5, 0.0001)
	assert_eq(entry.gems, 4)
	assert_eq(entry.tier_index, 2)
	assert_eq(entry.kills, 9)
	assert_eq(entry.unix_time, 777)


func test_entry_from_result_is_unnamed_and_complete() -> void:
	var result := RunResult.new(42.5, 7, 9, 2, &"void")
	var entry := LeaderboardEntry.from_result(result)
	assert_eq(entry.player_name, LeaderboardEntry.DEFAULT_NAME)
	assert_eq(LeaderboardEntry.DEFAULT_NAME, "ANON")
	assert_almost_eq(entry.time_survived, 42.5, 0.0001)
	assert_eq(entry.gems, 7)
	assert_eq(entry.kills, 9)
	assert_eq(entry.tier_index, 2)
	assert_eq(entry.unix_time, result.unix_time)
	assert_eq(DeathScreen.DEFAULT_NAME, LeaderboardEntry.DEFAULT_NAME)
