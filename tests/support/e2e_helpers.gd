class_name E2EHelpers
## Builders for end-to-end tests: tiny wave tables and lookups on a live Game.


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
		if child is Node3D and not child.is_queued_for_deletion():
			return child
	return null
