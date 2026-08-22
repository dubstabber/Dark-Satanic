extends GameTest
## Proves the GUT pipeline itself works before any game code exists.


func test_truth() -> void:
	assert_true(true, "GUT runs")


func test_godot_version_is_4_7() -> void:
	var version := Engine.get_version_info()
	assert_eq(version.major, 4)
	assert_eq(version.minor, 7)


func test_world_helper_is_in_tree() -> void:
	var world := make_world()
	assert_true(world.is_inside_tree())


func test_temp_user_path_is_unique() -> void:
	assert_ne(temp_user_path("a"), temp_user_path("a"))
