extends GameTest
## Boots the real main scene with a tiny wave table and checks the run loop runs.

var _main: Node
var _flow: GameFlow


func before_each() -> void:
	super.before_each()
	_main = E2EHelpers.boot(self, E2EHelpers.tiny_config(), temp_user_path("e2e_leaderboard"))
	_flow = _main.get_node("GameFlow")
	await wait_process_frames(1)


func after_each() -> void:
	E2EHelpers.release_input()
	super.after_each()


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
	var hud: HUD = _flow.game.hud
	assert_true(hud.visible)
	assert_eq(hud.timer_label.text, TimeFormat.seconds(RunManager.current.elapsed), "HUD timer follows the run clock")
	assert_eq(hud.gems_label.text, "GEMS 0")
	assert_eq(hud.kills_label.text, "KILLS 0")
	assert_eq(hud.tier_label.text, "I")
	RunManager.current.add_gems(RunManager.current.gems_to_next_tier())
	assert_eq(hud.tier_label.text, "II", "HUD tier follows the bound RunState")
	assert_eq(hud.gems_label.text, "GEMS %d" % RunManager.current.gems)


func test_endless_loop_runs_through_the_real_game() -> void:
	var config := E2EHelpers.tiny_config()
	var table: WaveTable = config.wave_table.duplicate(true)
	table.loop_from_time = 1.5
	config.wave_table = table
	_flow.config = config
	_flow.start_run()
	await wait_physics_frames(120)
	assert_eq(_flow.game.enemy_container.get_child_count(), 6,
		"4 authored + loop block 1 (point event x ceil(1.25)) at t = 1.5")
	assert_eq(_flow.game.spawn_director.alive_count(), 6)


func test_show_menu_after_run_clears_game() -> void:
	_flow.start_run()
	await wait_physics_frames(5)
	assert_eq(_flow.state, GameFlow.State.PLAYING)
	_flow.show_menu()
	assert_eq(_flow.state, GameFlow.State.MENU)
	assert_null(_flow.game)


func test_autostart_flag_skips_the_menu() -> void:
	var main: Node = load("res://src/core/main.tscn").instantiate()
	main.leaderboard_path = temp_user_path("e2e_leaderboard_autostart")
	main.autostart = true
	var flow: GameFlow = main.get_node("GameFlow")
	flow.config = E2EHelpers.tiny_config()
	add_child_autofree(main)
	await wait_process_frames(1)
	assert_eq(flow.state, GameFlow.State.PLAYING)
	assert_not_null(flow.game)
	assert_null(main.get_node("UiLayer").get_node_or_null("MainMenu"))
	assert_false(_main.autostart, "without the user argument the flag stays off")
