extends GameTest

const Weeper := preload("res://src/enemies/archetypes/weeper.tscn")
const Mourner := preload("res://src/enemies/archetypes/mourner.tscn")
const Lament := preload("res://src/enemies/archetypes/lament.tscn")
const Vesper := preload("res://src/enemies/archetypes/vesper.tscn")
const Glutton := preload("res://src/enemies/archetypes/glutton.tscn")


class GemStubWithValue:
	extends Node3D
	var value: int = 1
	var consumed: bool = false

	func consume() -> void:
		consumed = true
		queue_free()


var _world: Node3D
var _target: Node3D


func before_each() -> void:
	super.before_each()
	_world = make_world()
	_target = Node3D.new()
	_target.position = Vector3(8, 0, 0)
	_world.add_child(_target)


func _spawn(scene: PackedScene, position: Vector3 = Vector3.ZERO) -> Enemy:
	var enemy: Enemy = scene.instantiate()
	enemy.target = _target
	enemy.rng_seed = 5
	enemy.position = position
	_world.add_child(enemy)
	watch_signals(enemy)
	return enemy


func _count(type: Variant) -> int:
	var n := 0
	for child in _world.get_children():
		if is_instance_of(child, type) and not child.is_queued_for_deletion():
			n += 1
	return n


func test_every_archetype_instantiates_and_runs() -> void:
	for scene: PackedScene in [Weeper, Mourner, Lament, Vesper, Glutton]:
		var enemy := _spawn(scene, Vector3(5, 0, 5))
		assert_not_null(enemy.stats, scene.resource_path)
		assert_same(enemy.target, _target)
		assert_eq(enemy.health.max_health, enemy.stats.max_health)
		assert_true(enemy.get_node("Behaviors").get_child_count() > 0, "%s has behaviours" % scene.resource_path)
		assert_eq(enemy.gem_drop.gem_scene.resource_path, "res://src/pickups/gem_pickup.tscn")
	await wait_physics_frames(3)
	for enemy in _world.get_children():
		if enemy is Enemy:
			assert_true(enemy.elapsed > 0.0)
			assert_true(enemy.global_position.is_finite())


func test_weeper_stats_and_behaviors() -> void:
	var weeper := _spawn(Weeper)
	assert_eq(weeper.health.max_health, 1.0)
	assert_eq(weeper.gem_drop.count, 0)
	var behaviors := weeper.get_node("Behaviors")
	assert_true(behaviors.get_node("Seek") is SeekBehavior)
	assert_true(behaviors.get_node("Separation") is SeparationBehavior)
	assert_true(behaviors.get_node("Bob") is BobBehavior)
	assert_almost_eq((weeper.hurtbox.get_child(0) as CollisionShape3D).shape.radius, 0.45, 0.001)
	weeper.set_physics_process(false)
	for i in 30:
		weeper.advance(1.0 / 60.0)
	assert_true(weeper.global_position.x > 1.0, "chases the target")


func test_lament_body_is_armoured_but_weak_point_kills() -> void:
	var lament := _spawn(Lament)
	lament.set_physics_process(false)
	var weak_point: WeakPointComponent = lament.get_node("WeakPoint")
	assert_same(weak_point.health, lament.health)
	assert_eq(lament.hurtbox.damage_multiplier, 0.0)
	lament.hurtbox.receive_hit(HitInfo.new(5.0))
	assert_eq(lament.health.health, 10.0, "body hits do nothing")
	weak_point.receive_hit(HitInfo.new(4.0))
	assert_eq(lament.health.health, 6.0)
	weak_point.receive_hit(HitInfo.new(6.0))
	assert_signal_emitted(lament, "died")
	assert_eq(lament.gem_drop.count, 10)
	await wait_process_frames(2)
	assert_eq(_count(GemPickup), 10)


func test_lament_rises_and_hovers() -> void:
	var lament := _spawn(Lament, Vector3(10, 0, 0))
	lament.set_physics_process(false)
	var spawner: SpawnerComponent = lament.get_node("Spawner")
	spawner.enabled = false
	lament.advance(1.0 / 60.0)
	assert_true(lament.global_position.y < 0.0, "starts below the floor")
	for i in 150:
		lament.advance(1.0 / 60.0)
	assert_almost_eq(lament.global_position.y, 3.5, 0.1)
	assert_almost_eq(Vector2(lament.global_position.x, lament.global_position.z).length(), 10.0, 0.3)


func test_lament_spawner_emits_weepers_after_initial_delay() -> void:
	var lament := _spawn(Lament)
	var spawner: SpawnerComponent = lament.get_node("Spawner")
	assert_true(spawner.autonomous)
	assert_eq(spawner.interval, 8.0)
	assert_eq(spawner.max_alive, 12)
	assert_eq(spawner.max_emissions, 12)
	spawner.autonomous = false
	assert_eq(spawner.advance(2.9), 0)
	assert_eq(spawner.advance(0.2), 3)
	await wait_process_frames(2)
	assert_eq(_count(Enemy), 4, "3 weepers next to the lament")
	for child in _world.get_children():
		if child is Enemy and child != lament:
			assert_same(child.target, _target, "weepers inherit the target")
			assert_eq(child.stats.display_name, "Weeper")
	spawner.can_spawn = func() -> bool: return false
	assert_eq(spawner.advance(8.0), 0, "director veto respected")


func test_mourner_bursts_weepers_on_death() -> void:
	var mourner := _spawn(Mourner)
	assert_eq(mourner.health.max_health, 12.0)
	assert_eq(mourner.gem_drop.count, 1)
	var spawner: SpawnerComponent = mourner.get_node("Spawner")
	assert_false(spawner.enabled)
	assert_eq(spawner.death_burst, 2)
	mourner.health.kill()
	await wait_process_frames(2)
	assert_eq(_count(Enemy), 3, "mourner + 2 weepers")
	assert_eq(_count(GemPickup), 1)


func test_vesper_orbit_dive_phases() -> void:
	var vesper := _spawn(Vesper, Vector3(12, 4, 0))
	vesper.set_physics_process(false)
	var orbit: OrbitDiveBehavior = vesper.get_node("Behaviors/OrbitDive")
	watch_signals(orbit)
	assert_eq(vesper.health.max_health, 6.0)
	assert_eq(vesper.gem_drop.count, 2)
	for i in 60 * 7:
		vesper.advance(1.0 / 60.0)
	assert_signal_emitted_with_parameters(orbit, "phase_changed", [&"DIVE"], 0)
	assert_true(vesper.global_position.is_finite())


func test_glutton_eats_gems_and_grows() -> void:
	var glutton := _spawn(Glutton)
	glutton.set_physics_process(false)
	var eater: GemEaterComponent = glutton.get_node("GemEater")
	assert_eq(eater.collision_layer, PhysicsLayers.PICKUP)
	assert_true(eater.monitorable)
	assert_false(eater.monitoring)
	assert_same(eater.health, glutton.health)
	assert_same(eater.gem_drop, glutton.gem_drop)
	assert_true(glutton.get_node("Behaviors/GemSeek") is GemSeekBehavior)
	glutton.health.take_damage(HitInfo.new(2.0))
	var gem := GemStubWithValue.new()
	_world.add_child(gem)
	watch_signals(eater)
	eater.collect(gem)
	assert_eq(eater.eaten, 1)
	assert_eq(glutton.health.max_health, 13.0)
	assert_eq(glutton.health.health, 11.0, "healed 1")
	assert_almost_eq(glutton.scale.x, 1.03, 0.0001)
	assert_eq(glutton.gem_drop.count, 3, "base 2 + eaten")
	assert_true(gem.consumed)
	assert_signal_emitted_with_parameters(eater, "gem_eaten", [1])
	var second := GemStubWithValue.new()
	_world.add_child(second)
	eater.collect(second)
	assert_eq(glutton.gem_drop.count, 4)
	await wait_process_frames(1)


func test_glutton_magnetises_and_eats_real_gem() -> void:
	var glutton := _spawn(Glutton, Vector3(0, 0.8, 0))
	var gem: GemPickup = preload("res://src/pickups/gem_pickup.tscn").instantiate()
	gem.position = Vector3(2.5, 0.35, 0)
	_world.add_child(gem)
	gem.state = GemPickup.State.REST
	await wait_physics_frames(30)
	assert_eq((glutton.get_node("GemEater") as GemEaterComponent).eaten, 1)
	assert_false(is_instance_valid(gem) and not gem.is_queued_for_deletion())
