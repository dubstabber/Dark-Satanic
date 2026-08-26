extends GameTest
## Game (composition root) wiring with an injected RunState and a stub wave table.

const GameScene := preload("res://src/game/game.tscn")
const WeeperScene := preload("res://src/enemies/archetypes/weeper.tscn")
const MournerScene := preload("res://src/enemies/archetypes/mourner.tscn")


class FakeEnemy:
	extends Node3D
	signal died(enemy: Node3D, last_hit: HitInfo)


var _game: Game
var _state: RunState


func before_each() -> void:
	super.before_each()
	_state = RunState.new(load("res://src/weapons/resources/default_ladder.tres"))
	_state.start()
	_game = GameScene.instantiate()
	_game.config = E2EHelpers.tiny_config()
	_game.setup(_state)
	add_child_autofree(_game)
	watch_signals(EventBus)
	watch_signals(_game)


func test_scene_wiring() -> void:
	assert_same(_game.run_state, _state, "injected state used instead of RunManager")
	assert_false(RunManager.is_running(), "RunManager untouched when a state is injected")
	assert_same(_game.player.weapon_holder.projectile_root, _game.projectile_container)
	assert_same(_game.player.weapon_holder.weapon.target_provider.get_object(), _game)
	assert_eq(_game.player.weapon_holder.weapon.target_provider.get_method(), &"enemies")
	assert_same(_game.spawn_director.enemy_container, _game.enemy_container)
	assert_same(_game.spawn_director.drop_root, _game.gem_container)
	assert_same(_game.spawn_director.arena, _game.arena)
	assert_same(_game.spawn_director.target, _game.player)
	assert_same(_game.spawn_director.wave_table, _game.config.wave_table)
	assert_eq(_game.spawn_director.rng_seed, 1)
	assert_true(_game.spawn_director.telegraph_scene is PackedScene, "the scene ships a warning effect")
	assert_true(_game.spawn_director.telegraph_cue is AudioCue, "and its cue")
	assert_gt(_game.spawn_director.telegraph_lead(), 0.0, "so spawns really are announced early")
	assert_same(_game.spawn_director.vfx_root, _game.vfx_container)
	assert_same(_game.spawn_director.projectile_root, _game.projectile_container)
	assert_same(_game.boss_director.director, _game.spawn_director)
	assert_true(_game.boss_director.event is SpawnEvent, "the scene ships a boss to summon")
	assert_true(_game.boss_director.event.enemy_scene is PackedScene)
	assert_true(_game.boss_director.event.ignores_cap, "a full arena must not swallow it")
	assert_gt(_game.boss_director.first_at, 0.0)
	assert_gt(_game.boss_director.interval, 0.0)
	assert_not_same(_game.spawn_director.vfx_root, _game.enemy_container, "never the enemy container")
	assert_same(_game.arena.target, _game.player)
	assert_true(_game.hud.is_bound())
	assert_almost_eq(_game.player.look.sensitivity, SettingsManager.mouse_sensitivity, 0.00001)
	assert_same(_game.player.weapon_holder.tier(), _state.current_tier())


func test_physics_clock_drives_run_director_and_light() -> void:
	await wait_physics_frames(60)
	assert_almost_eq(_state.elapsed, 1.0, 0.05)
	assert_almost_eq(_game.spawn_director.elapsed(), _state.elapsed, 0.0001)
	assert_eq(_game.enemy_container.get_child_count(), 3, "ring of three at 0.5 s")
	assert_signal_emit_count(EventBus, "enemy_spawned", 3)
	assert_almost_eq(_game.player_light.global_position.y, _game.player.global_position.y + 2.5, 0.01)
	_state.end(&"test")
	await wait_physics_frames(60)
	assert_eq(_game.enemy_container.get_child_count(), 3, "clock stops once the run ended")


func test_gems_raise_tier_and_forward_to_weapon_and_bus() -> void:
	var needed := _state.gems_to_next_tier()
	_game.player.pickup_collector.gem_collected.emit(needed)
	assert_eq(_state.gems, needed)
	assert_eq(_state.tier_index, 1)
	assert_same(_game.player.weapon_holder.tier(), _state.ladder.tier(1))
	assert_signal_emitted_with_parameters(EventBus, "gem_collected", [needed])
	assert_signal_emitted_with_parameters(EventBus, "tier_changed", [_state.ladder.tier(1), 1])


func test_enemy_death_counts_a_kill() -> void:
	var enemy := FakeEnemy.new()
	enemy.position = Vector3(1, 2, 3)
	_game.enemy_container.add_child(enemy)
	enemy.died.emit(enemy, null)
	assert_eq(_state.kills, 1)
	assert_signal_emitted_with_parameters(EventBus, "enemy_died", [enemy, Vector3(1, 2, 3)])


func test_enemies_lists_only_live_nodes_with_died() -> void:
	var enemy := FakeEnemy.new()
	_game.enemy_container.add_child(enemy)
	var dying := FakeEnemy.new()
	_game.enemy_container.add_child(dying)
	dying.queue_free()
	var stray := Node3D.new()
	_game.enemy_container.add_child(stray)
	assert_eq(_game.enemies(), [enemy] as Array[Node3D])
	assert_eq(_game.spawn_director.alive_count(), 1)
	await wait_process_frames(1)


func test_player_death_ends_run_once() -> void:
	_state.tick(4.0)
	_game.player.died.emit(&"enemy")
	assert_false(_state.is_running)
	assert_signal_emitted_with_parameters(EventBus, "player_died", [&"enemy"])
	assert_signal_emit_count(_game, "run_ended", 1)
	var result: RunResult = get_signal_parameters(_game, "run_ended", 0)[0]
	assert_eq(result.death_cause, &"enemy")
	assert_almost_eq(result.time_survived, 4.0, 0.0001)
	_game.player.died.emit(&"void")
	assert_signal_emit_count(_game, "run_ended", 1, "second death ignored")


func test_real_enemy_drops_gems_into_gem_container() -> void:
	var event := SpawnEvent.new()
	event.enemy_scene = MournerScene
	event.pattern = PointPattern.new()
	event.pattern.point = Vector3(0, 1.2, 10)
	var spawned := _game.spawn_director.spawn_now(event)
	assert_eq(spawned.size(), 1)
	var enemy: Enemy = spawned[0]
	assert_same(enemy.gem_drop.spawn_root, _game.gem_container)
	assert_same(enemy.target, _game.player)
	assert_ne(enemy.rng_seed, 0, "director seeds the enemy")
	enemy.health.kill(&"dagger")
	await wait_process_frames(1)
	assert_eq(_state.kills, 1)
	assert_true(_game.gem_container.get_child_count() >= 1, "gem parented to GemContainer")
	for child in _game.enemy_container.get_children():
		assert_false(child is GemPickup, "%s: no gems in EnemyContainer" % child.name)
	await wait_seconds(0.3)


func test_uses_run_manager_when_no_state_injected() -> void:
	var game: Game = GameScene.instantiate()
	game.config = E2EHelpers.tiny_config()
	add_child_autofree(game)
	assert_true(RunManager.is_running())
	assert_same(game.run_state, RunManager.current)
	assert_same(game.run_state.ladder, game.config.ladder)


func test_directed_spawns_raise_a_warning_into_the_vfx_container() -> void:
	await wait_physics_frames(60)
	assert_gt(_game.vfx_container.get_child_count(), 0, "the ring at 0.5 s was announced first")
	for child in _game.vfx_container.get_children():
		assert_true(child is OneShotVfx, "%s is not a one-shot effect" % child.name)
	for child in _game.enemy_container.get_children():
		assert_true(SpawnDirector.is_enemy(child), "%s is not an enemy" % child.name)


func test_death_effects_are_routed_out_of_the_enemy_container() -> void:
	var enemy: Enemy = WeeperScene.instantiate()
	_game.enemy_container.add_child(enemy)
	await wait_physics_frames(1)
	assert_same(enemy.death_handler.vfx_root, _game.vfx_container)


func test_the_boss_clock_runs_with_the_run() -> void:
	assert_eq(_game.boss_director.elapsed, 0.0, "started with the run")
	await wait_physics_frames(30)
	assert_gt(_game.boss_director.elapsed, 0.0, "and is driven by the physics clock")
	assert_almost_eq(_game.boss_director.elapsed, _game.spawn_director.elapsed(), 0.001)


func test_a_big_death_flares_the_screen_and_a_skull_does_not() -> void:
	var flow := GameFlow.new()
	var post: PostProcessController = preload("res://src/vfx/post_process/post_process.tscn").instantiate()
	flow.post_process = post
	flow.state = GameFlow.State.PLAYING
	add_child_autofree(post)
	add_child_autofree(flow)
	var weeper: EnemyStats = load("res://src/enemies/resources/stats/weeper.tres")
	var mourner: EnemyStats = load("res://src/enemies/resources/stats/mourner.tres")
	var base := float(post.get_parameter(&"brightness"))
	flow._on_enemy_died(_enemy_with(weeper), Vector3.ZERO)
	assert_almost_eq(float(post.get_parameter(&"brightness")), base, 0.001, "a 1 HP skull is beneath notice")
	flow._on_enemy_died(_enemy_with(mourner), Vector3.ZERO)
	var flare := float(post.get_parameter(&"brightness")) - base
	assert_almost_eq(flare, (Enemy.death_burst_scale(mourner) - 1.0) * flow.kill_pulse_strength, 0.001)
	flow.state = GameFlow.State.DEAD
	post.pulse(0.0, 0.0)
	flow._on_enemy_died(_enemy_with(mourner), Vector3.ZERO)
	assert_almost_eq(float(post.get_parameter(&"brightness")), base, 0.001, "silent outside PLAYING")


func _enemy_with(stats: EnemyStats) -> Enemy:
	var enemy := Enemy.new()
	enemy.stats = stats
	return autofree(enemy)


func test_both_ambience_schedulers_are_wired_and_only_one_is_placed() -> void:
	var whispers: AmbienceScheduler = _game.whisper_scheduler
	var dread: AmbienceScheduler = _game.dread_scheduler
	assert_eq(whispers.radius, 0.0, "whispers are in your head, not out in the room")
	assert_eq(whispers.cues.size(), 1)
	assert_gt(dread.radius, 10.0, "the dread comes from somewhere out in the dark")
	assert_same(dread.origin, _game.player, "somewhere around you, wherever you are")
	assert_gt(dread.cues.size(), 4, "a library, so the same scream is not always the scream")
	assert_lt(dread.interval_max, whispers.interval_max, "and it is the more frequent of the two")
	for cue in dread.cues:
		assert_true(cue is AudioCue and cue.is_playable(), "every dread cue is playable")


func test_the_boss_arrival_has_its_own_herald() -> void:
	var event: SpawnEvent = _game.boss_director.event
	assert_not_null(event.announce_cue, "3 s of warning deserves its own sound")
	assert_true(event.announce_cue.is_playable())
	assert_gt(event.announce_cue.max_distance, 100.0, "audible wherever you are standing")


func test_the_wave_table_names_its_special_arrivals() -> void:
	var table: WaveTable = load("res://src/spawning/waves/milestone1.tres")
	var announced: Array[String] = []
	for event in table.events:
		if event.announce_cue != null:
			announced.append(event.label)
			assert_true(event.announce_cue.is_playable(), "%s herald is playable" % event.label)
	assert_gt(announced.size(), 3, "the rare arrivals are heralded: %s" % [announced])
	assert_lt(announced.size(), table.events.size() / 2, "but most arrivals are not, or it means nothing")
