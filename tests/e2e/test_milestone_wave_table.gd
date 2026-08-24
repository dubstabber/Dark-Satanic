extends GameTest
## The authored wave table must be valid and run 30 s of spawning without errors.


func test_milestone1_is_valid_and_spawns() -> void:
	var table: WaveTable = load("res://src/spawning/waves/milestone1.tres")
	assert_not_null(table)
	assert_eq(table.validate(), [] as Array[String], "no authoring problems")
	assert_true(table.events.size() >= 19)
	var world := make_world()
	var arena: Arena = load("res://src/arena/arena.tscn").instantiate()
	world.add_child(arena)
	var target := Node3D.new()
	world.add_child(target)
	var container := Node3D.new()
	world.add_child(container)
	var director := SpawnDirector.new()
	director.wave_table = table
	director.enemy_container = container
	director.arena = arena
	director.target = target
	director.rng_seed = 3
	world.add_child(director)
	director.start()
	for i in 45 * 10:
		director.advance(0.1)
	await wait_physics_frames(3)
	assert_true(director.alive_count() >= 2, "first two laments are out by 20 s")
	for enemy in container.get_children():
		assert_true(enemy is Enemy, "%s is an Enemy" % enemy.name)
