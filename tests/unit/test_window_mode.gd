extends GameTest


func test_mode_mapping() -> void:
	assert_eq(WindowMode.mode_for(true), DisplayServer.WINDOW_MODE_FULLSCREEN)
	assert_eq(WindowMode.mode_for(false), DisplayServer.WINDOW_MODE_WINDOWED)


func test_headless_is_reported_unsupported_and_never_fullscreen() -> void:
	if DisplayServer.get_name() != WindowMode.HEADLESS:
		pending("only meaningful under --headless")
		return
	assert_false(WindowMode.is_supported())
	assert_false(WindowMode.is_fullscreen())


func test_apply_is_safe_without_a_window() -> void:
	WindowMode.apply(true)
	WindowMode.apply(false)
	assert_engine_error_count(0)
	pass_test("no engine errors while applying window modes")
