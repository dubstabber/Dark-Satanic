extends GameTest

const GemScene := preload("res://src/pickups/gem_pickup.tscn")
const DT := 1.0 / 60.0


class Collector:
	extends Area3D
	var collected: Array[Node] = []

	func _init() -> void:
		collision_layer = PhysicsLayers.PICKUP
		collision_mask = 0
		monitorable = true
		monitoring = false
		var shape := CollisionShape3D.new()
		shape.shape = SphereShape3D.new()
		(shape.shape as SphereShape3D).radius = 0.2
		add_child(shape)

	func collect(gem: Node) -> void:
		collected.append(gem)
		if gem.has_method("consume"):
			gem.call("consume")


var _world: Node3D


func before_each() -> void:
	super.before_each()
	_world = make_world()


func _gem(position: Vector3 = Vector3.ZERO, physics: bool = false) -> GemPickup:
	var gem: GemPickup = GemScene.instantiate()
	gem.position = position
	_world.add_child(gem)
	gem.set_physics_process(physics)
	return gem


func _collector(position: Vector3) -> Collector:
	var collector := Collector.new()
	collector.position = position
	_world.add_child(collector)
	return collector


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_scene_layout_and_value() -> void:
	var gem := _gem()
	assert_true(gem.monitoring)
	assert_false(gem.monitorable)
	assert_eq(gem.collision_layer, 0)
	assert_eq(gem.collision_mask, PhysicsLayers.PICKUP)
	assert_eq(gem.value, 1)
	assert_almost_eq((gem.get_node("CollisionShape3D") as CollisionShape3D).shape.radius, 0.45, 0.001)
	var magnet_shape: CollisionShape3D = gem.magnet_area.get_node("CollisionShape3D")
	assert_almost_eq(magnet_shape.shape.radius, 4.0, 0.001)
	assert_eq(gem.magnet_area.collision_mask, PhysicsLayers.PICKUP)
	assert_not_null(gem.mesh_instance.mesh, "octahedron built in _ready")
	assert_eq(gem.mesh_instance.mesh.get_faces().size(), 24, "8 triangles")


func test_value_and_magnet_radius_come_from_stats() -> void:
	var gem: GemPickup = GemScene.instantiate()
	var stats := GemStats.new()
	stats.value = 5
	stats.magnet_radius = 7.0
	gem.stats = stats
	_world.add_child(gem)
	assert_eq(gem.value, 5)
	var magnet_shape: CollisionShape3D = gem.magnet_area.get_node("CollisionShape3D")
	assert_almost_eq(magnet_shape.shape.radius, 7.0, 0.001)
	var other := _gem()
	assert_almost_eq((other.magnet_area.get_node("CollisionShape3D") as CollisionShape3D).shape.radius, 4.0, 0.001, "shape not shared")


func test_scatter_is_seeded_and_lands_at_rest_height() -> void:
	var gem := _gem(Vector3(0, 1, 0))
	gem.scatter(_rng(21))
	var launch := gem.velocity
	assert_eq(launch.y, 3.0)
	var horizontal := Vector2(launch.x, launch.z).length()
	assert_true(horizontal >= 2.0 and horizontal <= 5.0)
	var other := _gem(Vector3(0, 1, 0))
	other.scatter(_rng(21))
	assert_eq(other.velocity, launch, "same seed, same launch")
	var peak := 0.0
	for i in 240:
		gem.advance(DT)
		peak = maxf(peak, gem.global_position.y)
	assert_true(peak > 1.2, "went up first")
	assert_eq(gem.state, GemPickup.State.REST)
	assert_almost_eq(gem.global_position.y, 0.35, 0.0001)
	assert_eq(gem.velocity, Vector3.ZERO)
	assert_true(Vector2(gem.global_position.x, gem.global_position.z).length() > 0.5, "travelled sideways")


func test_floor_y_export_shifts_rest_height() -> void:
	var gem := _gem(Vector3(0, 3, 0))
	gem.floor_y = 2.0
	gem.scatter(_rng(1))
	for i in 240:
		gem.advance(DT)
	assert_almost_eq(gem.global_position.y, 2.35, 0.0001)


func test_rest_spins_mesh() -> void:
	var gem := _gem(Vector3(0, 0.35, 0))
	gem.state = GemPickup.State.REST
	var before := gem.mesh_instance.rotation.y
	gem.advance(0.5)
	assert_almost_eq(gem.mesh_instance.rotation.y - before, 1.0, 0.001)
	assert_eq(gem.global_position, Vector3(0, 0.35, 0), "resting gems do not move")


func test_magnet_only_after_collector_enters_magnet_area() -> void:
	var gem := _gem(Vector3(0, 0.35, 0))
	gem.state = GemPickup.State.REST
	var far := _collector(Vector3(6, 0.35, 0))
	await wait_physics_frames(3)
	assert_null(gem.magnet_target)
	gem.advance(0.5)
	assert_eq(gem.state, GemPickup.State.REST)
	assert_eq(gem.global_position, Vector3(0, 0.35, 0))
	far.position = Vector3(3, 0.35, 0)
	await wait_physics_frames(3)
	assert_same(gem.magnet_target, far)
	assert_eq(gem.state, GemPickup.State.MAGNET)
	gem.advance(0.1)
	assert_true(gem.velocity.x > 0.0, "accelerates toward the collector")
	assert_almost_eq(gem.velocity.length(), 3.0, 0.001, "magnet_accel * delta")
	gem.stats = gem.stats.duplicate()
	gem.stats.magnet_accel = 10000.0
	gem.advance(0.1)
	assert_almost_eq(gem.velocity.length(), 25.0, 0.001, "capped at magnet_max_speed")


func test_magnet_waits_for_scatter_to_land() -> void:
	var gem := _gem(Vector3(0, 1, 0))
	gem.scatter(_rng(3))
	_collector(Vector3(2, 0.35, 0))
	await wait_physics_frames(3)
	assert_not_null(gem.magnet_target)
	assert_eq(gem.state, GemPickup.State.SCATTER, "keeps flying until it lands")
	for i in 240:
		gem.advance(DT)
		if gem.state != GemPickup.State.SCATTER:
			break
	assert_eq(gem.state, GemPickup.State.MAGNET, "magnet takes over on landing")


func test_collect_called_on_root_overlap_and_consume_frees() -> void:
	var gem := _gem(Vector3(0, 0.35, 0), true)
	gem.state = GemPickup.State.REST
	var collector := _collector(Vector3(3, 0.35, 0))
	await wait_physics_frames(40)
	assert_eq(collector.collected.size(), 1)
	assert_false(is_instance_valid(gem), "consume() freed the gem")


func test_consume_is_idempotent_and_stops_advance() -> void:
	var gem := _gem(Vector3(0, 0.35, 0))
	gem.consume()
	gem.consume()
	gem.advance(1.0)
	assert_eq(gem.state, GemPickup.State.COLLECTED)
	assert_eq(gem.global_position, Vector3(0, 0.35, 0))
	await wait_process_frames(1)
	assert_false(is_instance_valid(gem))


func test_lost_magnet_target_returns_to_rest() -> void:
	var gem := _gem(Vector3(0, 0.35, 0))
	gem.state = GemPickup.State.REST
	var collector := _collector(Vector3(3, 0.35, 0))
	await wait_physics_frames(3)
	assert_eq(gem.state, GemPickup.State.MAGNET)
	collector.free()
	gem.advance(DT)
	assert_eq(gem.state, GemPickup.State.REST)
	assert_null(gem.magnet_target)


func test_lifetime_expires_resting_gem() -> void:
	var gem: GemPickup = GemScene.instantiate()
	var stats := GemStats.new()
	stats.lifetime = 1.0
	gem.stats = stats
	_world.add_child(gem)
	gem.set_physics_process(false)
	gem.state = GemPickup.State.REST
	gem.advance(0.9)
	assert_false(gem.is_queued_for_deletion())
	gem.advance(0.2)
	assert_true(gem.is_queued_for_deletion())
	await wait_process_frames(1)


func test_scatter_without_rng_still_launches() -> void:
	var gem := _gem(Vector3(0, 1, 0))
	gem.scatter(null)
	assert_eq(gem.velocity.y, 3.0)
	assert_eq(gem.state, GemPickup.State.SCATTER)


class ArenaStub:
	extends Node
	var radius: float = 3.0

	func info() -> ArenaInfo:
		return ArenaInfo.new(Vector3.ZERO, radius, 0.0)


func test_scatter_lands_clamped_to_the_platform() -> void:
	var arena := ArenaStub.new()
	_world.add_child(arena)
	var gem := _gem(Vector3(2.9, 3.5, 0))
	gem.arena = arena
	gem.scatter(_rng(21))
	for i in 240:
		gem.advance(DT)
	assert_eq(gem.state, GemPickup.State.REST)
	assert_almost_eq(gem.global_position.y, 0.35, 0.0001)
	var flat := Vector2(gem.global_position.x, gem.global_position.z).length()
	assert_almost_eq(flat, 2.5, 0.0001, "pulled back to radius - edge_margin")
	var free := _gem(Vector3(2.9, 3.5, 0))
	free.scatter(_rng(21))
	for i in 240:
		free.advance(DT)
	assert_true(Vector2(free.global_position.x, free.global_position.z).length() > 3.0, "without an arena it lands wherever the arc ends")


func test_resting_gem_falls_and_frees_when_the_platform_shrinks_away() -> void:
	var arena := ArenaStub.new()
	_world.add_child(arena)
	var gem := _gem(Vector3(2.5, 0.35, 0))
	gem.arena = arena
	gem.state = GemPickup.State.REST
	gem.advance(DT)
	assert_eq(gem.state, GemPickup.State.REST, "still on the platform")
	arena.radius = 2.0
	gem.advance(DT)
	assert_eq(gem.state, GemPickup.State.FALL)
	for i in 120:
		gem.advance(DT)
		if gem.is_queued_for_deletion():
			break
	assert_true(gem.is_queued_for_deletion(), "freed below floor_y - fall_depth")
	assert_true(gem.global_position.y <= -2.0)
	await wait_process_frames(1)


func test_consume_spawns_collect_vfx_next_to_the_gem() -> void:
	var gem := _gem(Vector3(1, 0.35, 2))
	assert_eq(gem.stats.collect_vfx.resource_path, "res://src/vfx/particles/gem_sparkle.tscn")
	gem.consume()
	await wait_process_frames(2)
	var sparkles: Array[Node] = []
	for child in _world.get_children():
		if child is OneShotVfx:
			sparkles.append(child)
	assert_eq(sparkles.size(), 1)
	assert_eq((sparkles[0] as Node3D).position, Vector3(1, 0.35, 2))


func test_mesh_dimensions_are_exported() -> void:
	var gem: GemPickup = GemScene.instantiate()
	gem.mesh_half_width = 0.6
	gem.mesh_half_height = 0.9
	_world.add_child(gem)
	gem.set_physics_process(false)
	var aabb := gem.mesh_instance.mesh.get_aabb()
	assert_almost_eq(aabb.size.x, 1.2, 0.001)
	assert_almost_eq(aabb.size.y, 1.8, 0.001)
