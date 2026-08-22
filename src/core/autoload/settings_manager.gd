extends Node
## Player-facing settings persisted to a ConfigFile. Consumers receive values via
## `changed` rather than polling this autoload every frame.

signal changed

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "settings"
const DEFAULT_SENSITIVITY := 0.0022
const DEFAULT_MASTER_VOLUME := 1.0
const DEFAULT_MUSIC_VOLUME := 0.8
const DEFAULT_SFX_VOLUME := 1.0
const DEFAULT_FULLSCREEN := false

var mouse_sensitivity: float = DEFAULT_SENSITIVITY
var master_volume: float = DEFAULT_MASTER_VOLUME
var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
var fullscreen: bool = DEFAULT_FULLSCREEN
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
		fullscreen = bool(config.get_value(SECTION, "fullscreen", fullscreen))
	changed.emit()


func save() -> Error:
	var config := ConfigFile.new()
	config.set_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
	config.set_value(SECTION, "master_volume", master_volume)
	config.set_value(SECTION, "music_volume", music_volume)
	config.set_value(SECTION, "sfx_volume", sfx_volume)
	config.set_value(SECTION, "fullscreen", fullscreen)
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


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	changed.emit()


func toggle_fullscreen() -> void:
	set_fullscreen(not fullscreen)


## Restores defaults and points back at the default file without touching disk.
func reset() -> void:
	path = DEFAULT_PATH
	_apply_defaults()
	changed.emit()


func _apply_defaults() -> void:
	mouse_sensitivity = DEFAULT_SENSITIVITY
	master_volume = DEFAULT_MASTER_VOLUME
	music_volume = DEFAULT_MUSIC_VOLUME
	sfx_volume = DEFAULT_SFX_VOLUME
	fullscreen = DEFAULT_FULLSCREEN
