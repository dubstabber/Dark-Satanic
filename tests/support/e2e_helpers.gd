class_name E2EHelpers
## Builders for end-to-end tests: booting main.tscn, tiny wave tables and lookups on a live Game.
##
## Determinism: `rng_seed` seeds the SpawnDirector (schedule and positions) and, through it,
## every spawned enemy's `rng_seed`. The player's dagger spread and the gem scatter stay
## unseeded, so only the spawn side of an e2e run is reproducible.


## Instantiates main.tscn with the given config and leaderboard path under `test` (autofreed).
## Await one process frame afterwards so Main._ready can show the menu.
static func boot(test: GutTest, config: GameConfig, leaderboard_path: String) -> Node:
	var main: Node = load("res://src/core/main.tscn").instantiate()
	main.leaderboard_path = leaderboard_path
	main.get_node("GameFlow").config = config
	test.add_child_autofree(main)
	return main


## Releases the held actions an e2e test may have pressed (GameTest restores mouse/pause).
static func release_input() -> void:
	Input.action_release("fire_primary")
	Input.action_release("fire_secondary")


static func tiny_config() -> GameConfig:
	var config := GameConfig.new()
	config.wave_table = load("res://src/spawning/waves/test_tiny.tres")
	config.ladder = load("res://src/weapons/resources/default_ladder.tres")
	config.rng_seed = 1
	return config


## One enemy of the given scene at a fixed point shortly after the run starts.
static func single_enemy_config(scene_path: String, point: Vector3, time: float = 0.1) -> GameConfig:
	var pattern := PointPattern.new()
	pattern.point = point
	var event := SpawnEvent.new()
	event.time = time
	event.enemy_scene = load(scene_path)
	event.count = 1
	event.pattern = pattern
	event.label = "e2e"
	var table := WaveTable.new()
	table.events.append(event)
	table.loop_from_time = -1.0
	var config := GameConfig.new()
	config.wave_table = table
	config.ladder = load("res://src/weapons/resources/default_ladder.tres")
	config.rng_seed = 1
	return config


static func weeper_config() -> GameConfig:
	return single_enemy_config("res://src/enemies/archetypes/weeper.tscn", Vector3(0, 1, 6))


static func mourner_config() -> GameConfig:
	return single_enemy_config("res://src/enemies/archetypes/mourner.tscn", Vector3(0, 1.2, 10))


static func first_enemy(game: Game) -> Node3D:
	for child in game.enemy_container.get_children():
		if SpawnDirector.is_enemy(child):
			return child
	return null


## Pushes a pressed InputEventAction through the viewport (exercises the engine's
## can_process gate, unlike calling _unhandled_input directly).
static func press_action(test: GutTest, action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	test.get_viewport().push_input(press)
