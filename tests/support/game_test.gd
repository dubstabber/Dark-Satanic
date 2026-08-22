class_name GameTest
extends GutTest
## Shared base for every test in the project.
##
## Resets autoload state before each test (and points SettingsManager at a throwaway
## file so nothing can clobber the developer's real settings), offers a throwaway
## world node and temporary user:// paths that are cleaned up automatically, and
## restores the mouse mode / tree pause that a flow test may have changed.

const TEMP_DIR := "user://tests"

var _temp_paths: Array[String] = []
var _temp_dirs: Array[String] = []


func before_each() -> void:
	_reset_autoloads()
	SettingsManager.load_from(temp_user_path("settings"))


func after_each() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for path in _temp_paths:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
	_temp_paths.clear()
	for dir in _temp_dirs:
		_remove_dir_recursive(ProjectSettings.globalize_path(dir))
	_temp_dirs.clear()
	_reset_autoloads()


## A Node3D added to the tree and freed with the test; parent everything under it.
func make_world() -> Node3D:
	var world := Node3D.new()
	world.name = "World"
	add_child_autofree(world)
	return world


## Unique user:// path for a test file; deleted in after_each. A stem with directories
## ("nested/deeper/file") registers its top directory for recursive removal.
func temp_user_path(stem: String, extension: String = "cfg") -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_DIR))
	var path := "%s/%s_%d.%s" % [TEMP_DIR, stem, randi(), extension]
	_temp_paths.append(path)
	if "/" in stem:
		var top := "%s/%s" % [TEMP_DIR, stem.get_slice("/", 0)]
		if top not in _temp_dirs:
			_temp_dirs.append(top)
	return path


func _reset_autoloads() -> void:
	for autoload_name in ["RunManager", "AudioManager", "SettingsManager"]:
		var root := get_tree().root
		if root.has_node(autoload_name):
			var node := root.get_node(autoload_name)
			if node.has_method("reset"):
				node.call("reset")


static func _remove_dir_recursive(absolute: String) -> void:
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var dir := DirAccess.open(absolute)
	if dir == null:
		return
	for name in dir.get_directories():
		_remove_dir_recursive(absolute.path_join(name))
	for name in dir.get_files():
		DirAccess.remove_absolute(absolute.path_join(name))
	DirAccess.remove_absolute(absolute)
