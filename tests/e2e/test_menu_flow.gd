extends GameTest

var _main: Node
var _flow: GameFlow


func before_each() -> void:
	super.before_each()
	_main = E2EHelpers.boot(self, E2EHelpers.tiny_config(), temp_user_path("e2e_leaderboard"))
	_flow = _main.get_node("GameFlow")
	await wait_process_frames(1)
	watch_signals(_flow)


func after_each() -> void:
	E2EHelpers.release_input()
	super.after_each()


func _ui() -> CanvasLayer:
	return _main.get_node("UiLayer")


func test_menu_play_signal_starts_run() -> void:
	var menu: MainMenu = _ui().get_node("MainMenu")
	menu.play_requested.emit()
	assert_eq(_flow.state, GameFlow.State.PLAYING)
	assert_signal_emitted_with_parameters(_flow, "state_changed", [GameFlow.State.MENU, GameFlow.State.PLAYING])
	await wait_process_frames(2)
	assert_null(_ui().get_node_or_null("MainMenu"), "menu freed once playing")


func test_pause_and_resume() -> void:
	_flow.start_run()
	_flow.pause()
	assert_eq(_flow.state, GameFlow.State.PAUSED)
	assert_true(get_tree().paused)
	assert_not_null(_ui().get_node_or_null("PauseMenu"))
	_flow.resume()
	assert_eq(_flow.state, GameFlow.State.PLAYING)
	assert_false(get_tree().paused)
	_flow.pause()
	_flow.show_menu()
	assert_eq(_flow.state, GameFlow.State.MENU)
	assert_false(get_tree().paused)


func test_pause_action_toggles_through_the_viewport() -> void:
	_flow.start_run()
	assert_eq(_flow.process_mode, Node.PROCESS_MODE_ALWAYS)
	E2EHelpers.press_action(self, &"pause")
	await wait_process_frames(1)
	assert_eq(_flow.state, GameFlow.State.PAUSED)
	assert_true(get_tree().paused)
	assert_true(_flow.can_process(), "flow keeps processing while the tree is paused")
	E2EHelpers.press_action(self, &"pause")
	await wait_process_frames(1)
	assert_eq(_flow.state, GameFlow.State.PLAYING, "ESC resumes a paused game")
	assert_false(get_tree().paused)


func test_pause_freezes_gameplay() -> void:
	_flow.start_run()
	await wait_physics_frames(6)
	var elapsed: float = RunManager.current.elapsed
	var spawned := _flow.game.enemy_container.get_child_count()
	_flow.pause()
	await wait_physics_frames(60)
	assert_false(_flow.game.can_process(), "game subtree is paused")
	assert_almost_eq(RunManager.current.elapsed, elapsed, 0.0001, "run clock frozen")
	assert_eq(_flow.game.enemy_container.get_child_count(), spawned, "no spawns while paused")
	assert_eq(_flow.game.spawn_director.elapsed(), elapsed, "director clock frozen")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	_flow.resume()
	await wait_physics_frames(6)
	assert_almost_eq(RunManager.current.elapsed, elapsed + 6.0 / 60.0, 0.03, "clock resumes")


func test_show_menu_mid_run_aborts_the_run() -> void:
	_flow.start_run()
	await wait_physics_frames(3)
	_flow.show_menu()
	assert_false(RunManager.is_running(), "quitting to the menu ends the run")
	assert_not_null(RunManager.last_result)
	assert_eq(RunManager.last_result.death_cause, &"aborted")
	watch_signals(EventBus)
	_flow.start_run()
	assert_signal_not_emitted(EventBus, "run_ended", "no stale abort fires while the new game boots")
	assert_true(RunManager.is_running())


func test_settings_panel_round_trip_saves_to_the_temp_file() -> void:
	_flow.open_settings()
	var panel := _ui().get_node_or_null("SettingsPanel")
	assert_not_null(panel)
	panel.sensitivity_changed.emit(0.004)
	assert_almost_eq(SettingsManager.mouse_sensitivity, 0.004, 0.00001)
	panel.closed.emit()
	await wait_process_frames(2)
	assert_null(_ui().get_node_or_null("SettingsPanel"))
	assert_ne(SettingsManager.path, SettingsManager.DEFAULT_PATH, "tests never touch the real settings file")
	assert_true(FileAccess.file_exists(ProjectSettings.globalize_path(SettingsManager.path)), "closing saves")
	SettingsManager.load_from(SettingsManager.path)
	assert_almost_eq(SettingsManager.mouse_sensitivity, 0.004, 0.00001)


func test_menu_buttons_play_the_ui_cue() -> void:
	assert_not_null(_flow.ui_cue, "main.tscn assigns ui_click")
	var menu: MainMenu = _ui().get_node("MainMenu")
	menu.leaderboard_button.pressed.emit()
	assert_eq(AudioManager.playing_count(), 1, "one click cue playing")
	_flow.open_settings()
	var panel: SettingsPanel = _ui().get_node("SettingsPanel")
	panel.close_button.pressed.emit()
	assert_eq(AudioManager.playing_count(), 2, "settings close button clicks too")


func test_menu_and_game_music_come_from_cues() -> void:
	var music: AudioStreamPlayer = AudioManager.get_node("Music")
	assert_true(AudioManager.is_music_playing(), "menu hum plays in the menu")
	assert_same(music.stream, _flow.menu_music.streams[0])
	assert_almost_eq(music.volume_db, _flow.menu_music.volume_db, 0.001)
	assert_eq(music.bus, &"Music")
	_flow.start_run()
	assert_same(music.stream, _flow.game_music.streams[0])
	assert_almost_eq(music.volume_db, _flow.game_music.volume_db, 0.001)
