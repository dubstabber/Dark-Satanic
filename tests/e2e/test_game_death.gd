extends GameTest

var _main: Node
var _flow: GameFlow
var _path: String


func before_each() -> void:
	super.before_each()
	_path = temp_user_path("e2e_leaderboard")
	_main = load("res://src/core/main.tscn").instantiate()
	_main.leaderboard_path = _path
	_flow = _main.get_node("GameFlow")
	_flow.config = E2EHelpers.weeper_config()
	add_child_autofree(_main)
	await wait_process_frames(1)
	watch_signals(EventBus)


func test_contact_death_shows_screen_and_saves_score() -> void:
	_flow.start_run()
	await wait_physics_frames(30)
	var enemy := E2EHelpers.first_enemy(_flow.game)
	assert_not_null(enemy, "a weeper spawned")
	await wait_physics_frames(30)
	_flow.game.player.global_position = enemy.global_position
	await wait_physics_frames(4)
	assert_eq(_flow.state, GameFlow.State.DEAD)
	assert_signal_emitted_with_parameters(EventBus, "player_died", [&"enemy"])
	assert_false(RunManager.is_running())
	var screen: DeathScreen = _main.get_node("UiLayer").get_node_or_null("DeathScreen")
	assert_not_null(screen)
	assert_eq(_flow.game.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_true(FileAccess.file_exists(ProjectSettings.globalize_path(_path)), "score saved on death")
	screen.name_submitted.emit("DUBSTABBER")
	var data := LeaderboardStore.new(_path).load()
	assert_eq(data.entries.size(), 1)
	assert_eq(data.entries[0].player_name, "DUBSTABBER")
	assert_true(data.entries[0].time_survived > 0.5)


func test_void_death_and_retry() -> void:
	_flow.start_run()
	await wait_physics_frames(5)
	_flow.game.player.global_position = Vector3(0, -12, 0)
	await wait_physics_frames(6)
	assert_eq(_flow.state, GameFlow.State.DEAD)
	assert_signal_emitted_with_parameters(EventBus, "player_died", [&"void"])
	var old_game := _flow.game
	var retry := InputEventAction.new()
	retry.action = "retry"
	retry.pressed = true
	_flow._unhandled_input(retry)
	assert_eq(_flow.state, GameFlow.State.PLAYING)
	assert_ne(_flow.game, old_game)
	assert_true(RunManager.is_running())
	assert_almost_eq(RunManager.current.elapsed, 0.0, 0.05)
