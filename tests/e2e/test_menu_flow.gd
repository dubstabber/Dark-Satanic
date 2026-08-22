extends GameTest

var _main: Node
var _flow: GameFlow


func before_each() -> void:
	super.before_each()
	_main = load("res://src/core/main.tscn").instantiate()
	_main.leaderboard_path = temp_user_path("e2e_leaderboard")
	_flow = _main.get_node("GameFlow")
	_flow.config = E2EHelpers.tiny_config()
	add_child_autofree(_main)
	await wait_process_frames(1)
	watch_signals(_flow)


func after_each() -> void:
	get_tree().paused = false
	super.after_each()


func test_menu_play_signal_starts_run() -> void:
	var menu: MainMenu = _main.get_node("UiLayer").get_node("MainMenu")
	menu.play_requested.emit()
	assert_eq(_flow.state, GameFlow.State.PLAYING)
	assert_signal_emitted_with_parameters(_flow, "state_changed", [GameFlow.State.MENU, GameFlow.State.PLAYING])
	await wait_process_frames(2)
	assert_null(_main.get_node("UiLayer").get_node_or_null("MainMenu"), "menu freed once playing")


func test_pause_and_resume() -> void:
	_flow.start_run()
	_flow.pause()
	assert_eq(_flow.state, GameFlow.State.PAUSED)
	assert_true(get_tree().paused)
	assert_not_null(_main.get_node("UiLayer").get_node_or_null("PauseMenu"))
	_flow.resume()
	assert_eq(_flow.state, GameFlow.State.PLAYING)
	assert_false(get_tree().paused)
	_flow.pause()
	_flow.show_menu()
	assert_eq(_flow.state, GameFlow.State.MENU)
	assert_false(get_tree().paused)


func test_pause_action_toggles() -> void:
	_flow.start_run()
	var press := InputEventAction.new()
	press.action = "pause"
	press.pressed = true
	_flow._unhandled_input(press)
	assert_eq(_flow.state, GameFlow.State.PAUSED)
	_flow._unhandled_input(press)
	assert_eq(_flow.state, GameFlow.State.PLAYING)


func test_settings_panel_round_trip() -> void:
	_flow.open_settings()
	var panel := _main.get_node("UiLayer").get_node_or_null("SettingsPanel")
	assert_not_null(panel)
	panel.sensitivity_changed.emit(0.004)
	assert_almost_eq(SettingsManager.mouse_sensitivity, 0.004, 0.00001)
	panel.closed.emit()
	await wait_process_frames(2)
	assert_null(_main.get_node("UiLayer").get_node_or_null("SettingsPanel"))
