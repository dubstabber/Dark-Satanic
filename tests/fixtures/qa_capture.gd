extends Node
## Dev-only visual QA harness: boots the real game, poses one of each enemy,
## and saves screenshots of what the player actually sees.
##
## Run on a real display (rendering must be on):
##   $GODOT_BIN --path . res://tests/fixtures/qa_capture.tscn -- --qa-out=/absolute/dir

var out_dir := "/tmp/qa"

@onready var _tree := get_tree()


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):
			out_dir = arg.trim_prefix("--qa-out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await _capture_all()
	_tree.quit()


func _capture_all() -> void:
	var main: Node = load("res://src/core/main.tscn").instantiate()
	add_child(main)
	await _frames(30)
	await _shot("menu")

	var flow: Node = main.get_node("GameFlow")
	flow.config = _posed_config()
	flow.start_run()
	await _frames(8)
	var player := _tree.get_first_node_in_group("player") as Node3D
	player.get_node("HealthComponent").invulnerable = true
	_freeze_enemies(main, "Lament")
	await _frames(17)
	await _shot("hand_idle")

	Input.action_press("fire_primary")
	await _frames(35)
	await _shot("hand_firing")
	Input.action_release("fire_primary")

	await _frames(105)  # lament finishes its rise around t = 2.6 s
	_freeze_enemies(main, "")

	_aim(player, Vector3(0, 0.2, -3.5), Vector3(0, 3.5, -9))
	await _frames(5)
	await _shot("lament_eye")

	_aim(player, Vector3(0, 0.2, -6.2), Vector3(0, 5.5, -9))
	await _frames(5)
	await _shot("lament_eye_close")

	await _enemy_shot(main, player, "Mourner", "mourner")
	await _enemy_shot(main, player, "Glutton", "glutton")
	await _enemy_shot(main, player, "Vesper", "vesper")

	_aim(player, Vector3(0, 0.2, 16), Vector3(0, 1.0, 20))
	Input.action_press("fire_primary")
	await _frames(40)
	await _shot("weepers_firing")
	Input.action_release("fire_primary")

	_aim(player, Vector3(0, 0.2, -24), Vector3(0, 0.3, -30))
	await _frames(5)
	await _shot("edge_ring")

	main.queue_free()
	await _frames(3)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])
	print("qa shot: ", shot_name)


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame


## Teleports the player and points the camera at `target`.
func _aim(player: Node3D, position: Vector3, target: Vector3) -> void:
	player.global_position = position
	var to_target := target - position
	player.rotation.y = atan2(-to_target.x, -to_target.z)
	var rig := player.get_node("CameraRig") as Node3D
	var flat := Vector2(to_target.x, to_target.z).length()
	rig.rotation.x = atan2(to_target.y - 1.6, flat)


## Frames the named enemy from 4 m toward the arena center and shoots it.
func _enemy_shot(main: Node, player: Node3D, display_name: String, shot_name: String) -> void:
	var target := _enemy_position(main, display_name)
	if target == Vector3.ZERO:
		print("qa skip (not found): ", shot_name)
		return
	var flat := Vector3(target.x, 0.0, target.z)
	var toward_center := -flat.normalized() if flat.length() > 0.5 else Vector3.FORWARD
	_aim(player, flat + toward_center * 4.0 + Vector3(0, 0.2, 0), target)
	await _frames(5)
	await _shot(shot_name)


func _enemy_position(main: Node, display_name: String) -> Vector3:
	for container in main.find_children("EnemyContainer", "", true, false):
		for child in container.get_children():
			var stats: Resource = child.get("stats")
			if stats != null and stats.get("display_name") == display_name:
				return (child as Node3D).global_position
	return Vector3.ZERO


func _freeze_enemies(main: Node, except_display_name: String) -> void:
	var containers := main.find_children("EnemyContainer", "", true, false)
	for container in containers:
		for child in container.get_children():
			var stats: Resource = child.get("stats")
			if stats != null and except_display_name != "" and stats.get("display_name") == except_display_name:
				continue
			child.set_physics_process(false)


## One of each archetype at a fixed point, all spawned right at run start.
func _posed_config() -> GameConfig:
	var table := WaveTable.new()
	var events: Array[SpawnEvent] = []
	events.append(_event("res://src/enemies/archetypes/lament.tscn", Vector3(0, 0, -9), 1))
	events.append(_event("res://src/enemies/archetypes/mourner.tscn", Vector3(-5, 0, -8), 1))
	events.append(_event("res://src/enemies/archetypes/glutton.tscn", Vector3(5, 0, -8), 1))
	events.append(_event("res://src/enemies/archetypes/vesper.tscn", Vector3(8, 3, 8), 1))
	events.append(_event("res://src/enemies/archetypes/weeper.tscn", Vector3(0, 1, 20), 5))
	table.events = events
	table.loop_from_time = -1.0
	var config := GameConfig.new()
	config.wave_table = table
	config.ladder = load("res://src/weapons/resources/default_ladder.tres")
	config.rng_seed = 1
	return config


func _event(scene_path: String, point: Vector3, count: int) -> SpawnEvent:
	var pattern := PointPattern.new()
	pattern.point = point
	var event := SpawnEvent.new()
	event.time = 0.05
	event.enemy_scene = load(scene_path)
	event.count = count
	event.pattern = pattern
	return event
