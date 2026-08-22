class_name LeaderboardStore
extends RefCounted
## Reads and writes the leaderboard ConfigFile under user://. Never uses ResourceLoader/Saver.

var path: String


func _init(p_path: String = "user://leaderboard.cfg") -> void:
	path = p_path


## Empty data when the file is missing or corrupt (a warning is pushed for corrupt files).
func load() -> LeaderboardData:
	if not FileAccess.file_exists(path):
		return LeaderboardData.new()
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK:
		push_warning("LeaderboardStore: could not parse %s (error %d); starting empty" % [path, error])
		return LeaderboardData.new()
	return LeaderboardSerializer.from_config(config)


func save(data: LeaderboardData) -> Error:
	if data == null:
		return ERR_INVALID_PARAMETER
	var directory := ProjectSettings.globalize_path(path).get_base_dir()
	var made := DirAccess.make_dir_recursive_absolute(directory)
	if made != OK and made != ERR_ALREADY_EXISTS:
		return made
	return LeaderboardSerializer.to_config(data).save(path)
