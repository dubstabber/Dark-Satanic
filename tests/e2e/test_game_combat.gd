extends GameTest

var _main: Node
var _flow: GameFlow


func before_each() -> void:
	super.before_each()
	_main = load("res://src/core/main.tscn").instantiate()
	_main.leaderboard_path = temp_user_path("e2e_leaderboard")
	_flow = _main.get_node("GameFlow")
	_flow.config = E2EHelpers.mourner_config()
	add_child_autofree(_main)
	await wait_process_frames(1)
	watch_signals(EventBus)


func after_each() -> void:
	Input.action_release("fire_primary")
	super.after_each()


func test_daggers_kill_enemy_and_gem_is_collected() -> void:
	_flow.start_run()
	await wait_physics_frames(15)
	var enemy := E2EHelpers.first_enemy(_flow.game)
	assert_not_null(enemy, "a mourner spawned")
	enemy.target = null
	await wait_physics_frames(30)
	var enemy_position: Vector3 = enemy.global_position
	var player: Player = _flow.game.player
	player.health.invulnerable = true  # death-burst weepers may reach us; we test kills + gems here
	player.look.look_at_point(enemy.global_position)
	Input.action_press("fire_primary")
	await wait_physics_frames(150)
	Input.action_release("fire_primary")
	assert_signal_emitted(EventBus, "enemy_died")
	assert_true(RunManager.current.kills >= 1, "mourner (and maybe a death-burst weeper) killed")
	assert_true(RunManager.is_running(), "run still going")
	# Stand inside the gem's magnet radius but clear of the death-burst weepers.
	player.global_position = enemy_position + Vector3(0, 0, -3)
	await wait_physics_frames(90)
	assert_true(RunManager.current.gems >= 1, "mourner gem magnetised and collected")
	assert_signal_emitted(EventBus, "gem_collected")
