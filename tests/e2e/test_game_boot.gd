extends GameTest
## Boots the real main scene with a tiny wave table and checks the run loop runs.

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


func test_starts_in_menu_then_runs() -> void:
	assert_eq(_flow.state, GameFlow.State.MENU)
	assert_not_null(_main.get_node("UiLayer").get_node_or_null("MainMenu"))
	_flow.start_run()
	assert_eq(_flow.state, GameFlow.State.PLAYING)
	assert_not_null(_flow.game)
	assert_true(RunManager.is_running())
	await wait_physics_frames(120)
	assert_almost_eq(RunManager.current.elapsed, 2.0, 0.15, "clock advanced ~2 s in 120 ticks")
	assert_eq(_flow.game.enemy_container.get_child_count(), 4, "test_tiny spawns 3 + 1 stubs")
	assert_true(_flow.game.hud.visible)


func test_autostart_argument_is_honoured_by_flow_api() -> void:
	_flow.start_run()
	await wait_physics_frames(5)
	assert_eq(_flow.state, GameFlow.State.PLAYING)
	_flow.show_menu()
	assert_eq(_flow.state, GameFlow.State.MENU)
	assert_null(_flow.game)
