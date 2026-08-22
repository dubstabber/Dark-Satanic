class_name LeaderboardSerializer
## Converts LeaderboardData to/from a ConfigFile (sections entry_0..n). Tolerant of missing keys
## and garbage values so a hand-edited or half-written file never crashes the game.

const SECTION_PREFIX := "entry_"


static func to_config(data: LeaderboardData) -> ConfigFile:
	var config := ConfigFile.new()
	for i in data.entries.size():
		var entry := data.entries[i]
		var section := SECTION_PREFIX + str(i)
		config.set_value(section, "name", entry.player_name)
		config.set_value(section, "time", entry.time_survived)
		config.set_value(section, "gems", entry.gems)
		config.set_value(section, "tier", entry.tier_index)
		config.set_value(section, "kills", entry.kills)
		config.set_value(section, "unix_time", entry.unix_time)
	return config


static func from_config(config: ConfigFile) -> LeaderboardData:
	var data := LeaderboardData.new()
	if config == null:
		return data
	for section in config.get_sections():
		if not section.begins_with(SECTION_PREFIX):
			continue
		data.insert(_read_entry(config, section))
	return data


static func _read_entry(config: ConfigFile, section: String) -> LeaderboardEntry:
	return LeaderboardEntry.make(
		_as_string(config.get_value(section, "name", LeaderboardEntry.DEFAULT_NAME)),
		_as_float(config.get_value(section, "time", 0.0)),
		_as_int(config.get_value(section, "gems", 0)),
		_as_int(config.get_value(section, "tier", 0)),
		_as_int(config.get_value(section, "kills", 0)),
		_as_int(config.get_value(section, "unix_time", 0))
	)


static func _as_string(value: Variant) -> String:
	if value is String or value is StringName:
		var text := str(value).strip_edges()
		return text if not text.is_empty() else LeaderboardEntry.DEFAULT_NAME
	return LeaderboardEntry.DEFAULT_NAME


static func _as_float(value: Variant) -> float:
	if value is float or value is int:
		var number := float(value)
		return number if is_finite(number) and number >= 0.0 else 0.0
	if value is String and str(value).is_valid_float():
		return maxf(float(value), 0.0)
	return 0.0


static func _as_int(value: Variant) -> int:
	if value is int:
		return maxi(value, 0)
	if value is float and is_finite(value):
		return maxi(int(value), 0)
	if value is String and str(value).is_valid_int():
		return maxi(int(value), 0)
	return 0
