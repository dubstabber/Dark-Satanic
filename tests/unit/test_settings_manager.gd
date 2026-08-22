extends GameTest


func test_defaults_after_reset() -> void:
	SettingsManager.set_mouse_sensitivity(0.01)
	SettingsManager.reset()
	assert_almost_eq(SettingsManager.mouse_sensitivity, SettingsManager.DEFAULT_SENSITIVITY, 0.00001)
	assert_eq(SettingsManager.path, SettingsManager.DEFAULT_PATH)


func test_setters_clamp_and_emit() -> void:
	watch_signals(SettingsManager)
	SettingsManager.set_mouse_sensitivity(99.0)
	assert_almost_eq(SettingsManager.mouse_sensitivity, 0.05, 0.00001)
	SettingsManager.set_volume(&"Music", 1.7)
	assert_eq(SettingsManager.music_volume, 1.0)
	SettingsManager.set_volume(&"SFX", -1.0)
	assert_eq(SettingsManager.sfx_volume, 0.0)
	assert_signal_emit_count(SettingsManager, "changed", 3)


func test_save_and_load_round_trip() -> void:
	var path := temp_user_path("settings")
	SettingsManager.load_from(path)
	SettingsManager.set_mouse_sensitivity(0.004)
	SettingsManager.set_volume(&"Master", 0.25)
	assert_eq(SettingsManager.save(), OK)
	SettingsManager.reset()
	SettingsManager.load_from(path)
	assert_almost_eq(SettingsManager.mouse_sensitivity, 0.004, 0.00001)
	assert_almost_eq(SettingsManager.master_volume, 0.25, 0.00001)


func test_loading_missing_file_keeps_defaults() -> void:
	watch_signals(SettingsManager)
	SettingsManager.load_from("user://tests/does_not_exist_%d.cfg" % randi())
	assert_almost_eq(SettingsManager.mouse_sensitivity, SettingsManager.DEFAULT_SENSITIVITY, 0.00001)
	assert_signal_emitted(SettingsManager, "changed")


func test_volume_defaults_come_from_the_constants() -> void:
	SettingsManager.set_volume(&"Master", 0.1)
	SettingsManager.set_volume(&"Music", 0.2)
	SettingsManager.set_volume(&"SFX", 0.3)
	SettingsManager.reset()
	assert_eq(SettingsManager.master_volume, SettingsManager.DEFAULT_MASTER_VOLUME)
	assert_eq(SettingsManager.music_volume, SettingsManager.DEFAULT_MUSIC_VOLUME)
	assert_eq(SettingsManager.sfx_volume, SettingsManager.DEFAULT_SFX_VOLUME)


func test_game_test_points_settings_at_a_temp_file() -> void:
	assert_ne(SettingsManager.path, SettingsManager.DEFAULT_PATH)
	assert_true(SettingsManager.path.begins_with(GameTest.TEMP_DIR))


func test_fullscreen_defaults_off_and_toggles_with_signal() -> void:
	assert_false(SettingsManager.fullscreen)
	watch_signals(SettingsManager)
	SettingsManager.toggle_fullscreen()
	assert_true(SettingsManager.fullscreen)
	SettingsManager.set_fullscreen(false)
	assert_false(SettingsManager.fullscreen)
	assert_signal_emit_count(SettingsManager, "changed", 2)


func test_fullscreen_is_persisted() -> void:
	var path := temp_user_path("settings_fullscreen")
	SettingsManager.load_from(path)
	SettingsManager.set_fullscreen(true)
	assert_eq(SettingsManager.save(), OK)
	SettingsManager.reset()
	assert_false(SettingsManager.fullscreen)
	SettingsManager.load_from(path)
	assert_true(SettingsManager.fullscreen)
