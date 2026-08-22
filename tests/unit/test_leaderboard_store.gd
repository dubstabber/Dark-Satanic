extends GameTest


func _sample() -> LeaderboardData:
	var data := LeaderboardData.new()
	data.insert(LeaderboardEntry.make("ABE", 12.5, 3, 1, 4, 100))
	data.insert(LeaderboardEntry.make("BEA", 99.25, 20, 3, 40, 200))
	return data


func test_default_path() -> void:
	assert_eq(LeaderboardStore.new().path, "user://leaderboard.cfg")


func test_missing_file_loads_empty() -> void:
	var store := LeaderboardStore.new(temp_user_path("missing_leaderboard"))
	var data := store.load()
	assert_not_null(data)
	assert_eq(data.size(), 0)


func test_save_creates_directory_and_file() -> void:
	var path := temp_user_path("nested/deeper/leaderboard")
	var store := LeaderboardStore.new(path)
	assert_eq(store.save(_sample()), OK)
	assert_true(FileAccess.file_exists(path))


func test_save_then_load_round_trips() -> void:
	var store := LeaderboardStore.new(temp_user_path("leaderboard"))
	assert_eq(store.save(_sample()), OK)
	var data := store.load()
	assert_eq(data.size(), 2)
	assert_eq(data.entries[0].player_name, "BEA")
	assert_almost_eq(data.entries[0].time_survived, 99.25, 0.0001)
	assert_eq(data.entries[1].kills, 4)


func test_save_overwrites_previous_contents() -> void:
	var store := LeaderboardStore.new(temp_user_path("leaderboard_overwrite"))
	store.save(_sample())
	var smaller := LeaderboardData.new()
	smaller.insert(LeaderboardEntry.make("ONLY", 1.0))
	assert_eq(store.save(smaller), OK)
	var data := store.load()
	assert_eq(data.size(), 1)
	assert_eq(data.best().player_name, "ONLY")


func test_corrupt_file_loads_empty_and_warns() -> void:
	var path := temp_user_path("corrupt_leaderboard")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[entry_0\nname = \"BROKEN\n= = =\n")
	file.close()
	var store := LeaderboardStore.new(path)
	var data := store.load()
	assert_not_null(data)
	assert_eq(data.size(), 0)
	assert_engine_error("ConfigFile parse error")
	assert_push_warning("could not parse")


func test_save_null_returns_error() -> void:
	var store := LeaderboardStore.new(temp_user_path("null_leaderboard"))
	assert_eq(store.save(null), ERR_INVALID_PARAMETER)


func test_nested_temp_directories_are_removed_after_each() -> void:
	var path := temp_user_path("nested_probe/deeper/leaderboard")
	assert_eq(LeaderboardStore.new(path).save(_sample()), OK)
	var top := ProjectSettings.globalize_path(GameTest.TEMP_DIR.path_join("nested_probe"))
	assert_true(DirAccess.dir_exists_absolute(top))
	super.after_each()
	assert_false(DirAccess.dir_exists_absolute(top), "temp_user_path cleans its directories")
	super.before_each()
