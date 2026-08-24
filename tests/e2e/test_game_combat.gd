extends GameTest

var _main: Node
var _flow: GameFlow


func before_each() -> void:
	super.before_each()
	_main = E2EHelpers.boot(self, E2EHelpers.mourner_config(), temp_user_path("e2e_leaderboard"))
	_flow = _main.get_node("GameFlow")
	await wait_process_frames(1)
	watch_signals(EventBus)


func after_each() -> void:
	E2EHelpers.release_input()
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
	var gems_dropped: Array[int] = [0]
	_flow.game.gem_container.child_entered_tree.connect(func(_gem: Node) -> void: gems_dropped[0] += 1)
	Input.action_press("fire_primary")
	await wait_physics_frames(150)
	Input.action_release("fire_primary")
	assert_signal_emitted(EventBus, "enemy_died")
	assert_true(RunManager.current.kills >= 1, "mourner (and maybe a death-burst weeper) killed")
	assert_true(RunManager.is_running(), "run still going")
	assert_true(gems_dropped[0] >= 1, "gems drop into GemContainer (and may already be collected)")
	for child in _flow.game.enemy_container.get_children():
		assert_true(child.has_signal("died"), "%s (%s, script %s): only enemies live in EnemyContainer" % [child.name, child.get_class(), child.get_script()])
	for candidate in _flow.game.enemies():
		assert_true(candidate.has_signal("died"), "homing targets are enemies only")
	assert_true(_flow.game.projectile_container.get_child_count() >= 1, "daggers parented to ProjectileContainer")
	# Stand inside the gem's magnet radius but clear of the death-burst weepers.
	player.global_position = enemy_position + Vector3(0, 0, -3)
	await wait_physics_frames(90)
	assert_true(RunManager.current.gems >= 1, "mourner gem magnetised and collected")
	assert_signal_emitted(EventBus, "gem_collected")
