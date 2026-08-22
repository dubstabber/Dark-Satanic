extends Node
## Player-facing settings persisted to a ConfigFile. Consumers receive values via
## `changed` rather than polling this autoload every frame.

signal changed

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "settings"
const DEFAULT_SENSITIVITY := 0.0022

var mouse_sensitivity: float = DEFAULT_SENSITIVITY
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var path: String = DEFAULT_PATH


func _ready() -> void:
	load_from(DEFAULT_PATH)


func load_from(p_path: String) -> void:
	path = p_path
	_apply_defaults()
	var config := ConfigFile.new()
	if config.load(path) == OK:
		mouse_sensitivity = float(config.get_value(SECTION, "mouse_sensitivity", mouse_sensitivity))
		master_volume = float(config.get_value(SECTION, "master_volume", master_volume))
		music_volume = float(config.get_value(SECTION, "music_volume", music_volume))
		sfx_volume = float(config.get_value(SECTION, "sfx_volume", sfx_volume))
	changed.emit()


func save() -> Error:
	var config := ConfigFile.new()
	config.set_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
	config.set_value(SECTION, "master_volume", master_volume)
	config.set_value(SECTION, "music_volume", music_volume)
	config.set_value(SECTION, "sfx_volume", sfx_volume)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	return config.save(path)


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.0001, 0.05)
	changed.emit()


func set_volume(bus: StringName, linear: float) -> void:
	var value := clampf(linear, 0.0, 1.0)
	match bus:
		&"Master":
			master_volume = value
		&"Music":
			music_volume = value
		&"SFX", &"UI":
			sfx_volume = value
	changed.emit()


## Restores defaults and points back at the default file without touching disk.
func reset() -> void:
	path = DEFAULT_PATH
	_apply_defaults()
	changed.emit()


func _apply_defaults() -> void:
	mouse_sensitivity = DEFAULT_SENSITIVITY
	master_volume = 1.0
	music_volume = 0.8
	sfx_volume = 1.0
