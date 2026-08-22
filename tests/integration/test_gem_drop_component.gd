extends GameTest

const GemStub := preload("res://tests/fixtures/gem_stub.tscn")

var _world: Node3D


func before_each() -> void:
	super.before_each()
	_world = make_world()


func _enemy(count: int) -> Dictionary:
	var body := Node3D.new()
	body.position = Vector3(4, 1, -2)
	var health := HealthComponent.new()
	body.add_child(health)
	var drop := GemDropComponent.new()
	drop.gem_scene = GemStub
	drop.count = count
	drop.rng_seed = 11
	body.add_child(drop)
	_world.add_child(body)
	watch_signals(drop)
	return {"body": body, "health": health, "drop": drop}


func test_death_drops_gems_as_siblings() -> void:
	var enemy := _enemy(3)
	enemy.health.kill()
	await wait_process_frames(2)
	var gems: Array = _world.get_children().filter(func(n: Node) -> bool: return n.has_method("scatter"))
	assert_eq(gems.size(), 3)
	assert_signal_emitted(enemy.drop, "gems_dropped")
	for gem in gems:
		assert_true(gem.scattered, "scatter() called on each gem")
		assert_almost_eq(gem.global_position.distance_to(Vector3(4, 1, -2)), 0.0, 0.5 * 1.5)


func test_drop_into_explicit_root_with_transform() -> void:
	var enemy := _enemy(1)
	var root := Node3D.new()
	root.position = Vector3(100, 0, 0)
	_world.add_child(root)
	enemy.drop.spawn_root = root
	enemy.drop.scatter_radius = 0.0
	var gems: Array = enemy.drop.drop()
	await wait_process_frames(2)
	assert_eq(gems.size(), 1)
	assert_same(gems[0].get_parent(), root)
	assert_almost_eq(gems[0].global_position.distance_to(Vector3(4, 1, -2)), 0.0, 0.001)


func test_nothing_without_scene_or_count() -> void:
	var enemy := _enemy(0)
	assert_eq(enemy.drop.drop().size(), 0)
	enemy.drop.count = 2
	enemy.drop.gem_scene = null
	assert_eq(enemy.drop.drop().size(), 0)
	assert_signal_not_emitted(enemy.drop, "gems_dropped")
