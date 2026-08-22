extends GameTest


func _sample() -> LeaderboardData:
	var data := LeaderboardData.new()
	data.insert(LeaderboardEntry.make("ABE", 12.5, 3, 1, 4, 100))
	data.insert(LeaderboardEntry.make("BEA", 99.25, 20, 3, 40, 200))
	data.insert(LeaderboardEntry.make("CID", 0.5, 0, 0, 0, 300))
	return data


func test_to_config_writes_sections_in_rank_order() -> void:
	var config := LeaderboardSerializer.to_config(_sample())
	assert_eq(config.get_sections(), PackedStringArray(["entry_0", "entry_1", "entry_2"]))
	assert_eq(config.get_value("entry_0", "name"), "BEA")
	assert_almost_eq(float(config.get_value("entry_0", "time")), 99.25, 0.0001)
	assert_eq(config.get_value("entry_0", "gems"), 20)
	assert_eq(config.get_value("entry_0", "tier"), 3)
	assert_eq(config.get_value("entry_0", "kills"), 40)
	assert_eq(config.get_value("entry_0", "unix_time"), 200)


func test_round_trip_preserves_entries() -> void:
	var config := LeaderboardSerializer.to_config(_sample())
	var text := config.encode_to_text()
	var reread := ConfigFile.new()
	assert_eq(reread.parse(text), OK)
	var data := LeaderboardSerializer.from_config(reread)
	assert_eq(data.size(), 3)
	assert_eq(data.entries[0].player_name, "BEA")
	assert_eq(data.entries[1].player_name, "ABE")
	assert_eq(data.entries[2].player_name, "CID")
	assert_almost_eq(data.entries[1].time_survived, 12.5, 0.0001)
	assert_eq(data.entries[1].gems, 3)
	assert_eq(data.entries[1].tier_index, 1)
	assert_eq(data.entries[1].kills, 4)
	assert_eq(data.entries[1].unix_time, 100)


func test_from_config_sorts_unordered_sections() -> void:
	var config := ConfigFile.new()
	config.set_value("entry_0", "name", "LOW")
	config.set_value("entry_0", "time", 1.0)
	config.set_value("entry_1", "name", "HIGH")
	config.set_value("entry_1", "time", 50.0)
	var data := LeaderboardSerializer.from_config(config)
	assert_eq(data.entries[0].player_name, "HIGH")


func test_missing_keys_fall_back_to_defaults() -> void:
	var config := ConfigFile.new()
	config.set_value("entry_0", "time", 7.0)
	var data := LeaderboardSerializer.from_config(config)
	assert_eq(data.size(), 1)
	assert_eq(data.entries[0].player_name, "ANON")
	assert_eq(data.entries[0].gems, 0)
	assert_eq(data.entries[0].tier_index, 0)
	assert_eq(data.entries[0].kills, 0)
	assert_eq(data.entries[0].unix_time, 0)


func test_garbage_values_are_sanitised() -> void:
	var config := ConfigFile.new()
	config.set_value("entry_0", "name", 42)
	config.set_value("entry_0", "time", "not a number")
	config.set_value("entry_0", "gems", Vector2(1, 2))
	config.set_value("entry_0", "tier", -3)
	config.set_value("entry_0", "kills", "12")
	config.set_value("entry_0", "unix_time", 3.9)
	config.set_value("entry_1", "name", "   ")
	config.set_value("entry_1", "time", -5.0)
	config.set_value("entry_2", "time", INF)
	config.set_value("junk", "time", 999.0)
	var data := LeaderboardSerializer.from_config(config)
	assert_eq(data.size(), 3, "the junk section is ignored")
	for entry in data.entries:
		assert_eq(entry.player_name, "ANON")
		assert_almost_eq(entry.time_survived, 0.0, 0.0001)
	assert_eq(data.entries[0].gems, 0)
	assert_eq(data.entries[0].tier_index, 0)
	assert_eq(data.entries[0].kills, 12, "numeric strings are accepted")
	assert_eq(data.entries[0].unix_time, 3)


func test_more_sections_than_max_entries_are_trimmed() -> void:
	var config := ConfigFile.new()
	for i in 15:
		config.set_value("entry_%d" % i, "time", float(i))
	var data := LeaderboardSerializer.from_config(config)
	assert_eq(data.size(), 10)
	assert_almost_eq(data.best().time_survived, 14.0, 0.0001)


func test_null_and_empty_config_give_empty_data() -> void:
	assert_eq(LeaderboardSerializer.from_config(null).size(), 0)
	assert_eq(LeaderboardSerializer.from_config(ConfigFile.new()).size(), 0)
	assert_eq(LeaderboardSerializer.to_config(LeaderboardData.new()).get_sections().size(), 0)
