class_name GameTest
extends GutTest
## Shared base for every test in the project.
##
## Resets autoload state before each test, offers a throwaway world node and
## temporary user:// paths that are cleaned up automatically.

var _temp_paths: Array[String] = []


func before_each() -> void:
	_reset_autoloads()


func after_each() -> void:
	for path in _temp_paths:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
	_temp_paths.clear()
	_reset_autoloads()


## A Node3D added to the tree and freed with the test; parent everything under it.
func make_world() -> Node3D:
	var world := Node3D.new()
	world.name = "World"
	add_child_autofree(world)
	return world


## Unique user:// path for a test file; deleted in after_each.
func temp_user_path(stem: String, extension: String = "cfg") -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var path := "user://tests/%s_%d.%s" % [stem, randi(), extension]
	_temp_paths.append(path)
	return path


func _reset_autoloads() -> void:
	for autoload_name in ["RunManager", "AudioManager", "SettingsManager"]:
		var root := get_tree().root
		if root.has_node(autoload_name):
			var node := root.get_node(autoload_name)
			if node.has_method("reset"):
				node.call("reset")
