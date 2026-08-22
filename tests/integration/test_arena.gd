extends GameTest

const ArenaScene := preload("res://src/arena/arena.tscn")

var _world: Node3D
var _arena: Arena


func before_each() -> void:
	super.before_each()
	_world = make_world()
	_arena = ArenaScene.instantiate()
	_world.add_child(_arena)
	watch_signals(_arena)


func _cylinder() -> CylinderMesh:
	return _arena.floor_mesh.mesh as CylinderMesh


func _shape() -> CylinderShape3D:
	return _arena.floor_shape.shape as CylinderShape3D


func _torus() -> TorusMesh:
	return _arena.edge_ring.mesh as TorusMesh


func test_scene_layout() -> void:
	assert_eq(_arena.radius, 30.0)
	assert_eq(_arena.floor_y(), 0.0)
	assert_eq(_arena.floor_body.collision_layer, PhysicsLayers.WORLD)
	assert_almost_eq(_arena.floor_mesh.position.y, -1.0, 0.001)
	assert_eq(_cylinder().height, 2.0)
	assert_eq(_cylinder().radial_segments, 64)
	var material := _cylinder().material as ShaderMaterial
	assert_not_null(material, "floor uses the void_floor shader")
	assert_true(material.get_shader_parameter(&"noise_tex") is NoiseTexture2D)
	assert_almost_eq(float(material.get_shader_parameter(&"radius")), 30.0, 0.001)
	assert_almost_eq(_arena.edge_ring.position.y, 0.05, 0.001)
	var kill_zone: KillZone = _arena.get_node("KillZone")
	assert_eq(kill_zone.collision_layer, PhysicsLayers.KILL_ZONE)
	assert_eq(kill_zone.collision_mask, PhysicsLayers.PLAYER | PhysicsLayers.ENEMY)
	assert_true(kill_zone.monitoring)
	assert_almost_eq(kill_zone.position.y, -12.0, 0.001)
	assert_true(_arena.get_node("ArenaShrinker") is ArenaShrinker)


func test_radius_setter_updates_everything() -> void:
	_arena.radius = 20.0
	assert_eq(_cylinder().top_radius, 20.0)
	assert_eq(_cylinder().bottom_radius, 20.0)
	assert_eq(_shape().radius, 20.0)
	assert_eq(_torus().outer_radius, 20.0)
	assert_almost_eq(_torus().inner_radius, 19.6, 0.001)
	assert_signal_emitted_with_parameters(_arena, "radius_changed", [20.0])
	_arena.radius = -5.0
	assert_eq(_arena.radius, 0.0, "clamped at zero")


func test_shape_only_rebuilt_for_large_changes() -> void:
	_arena.radius = 20.0
	_arena.radius = 19.95
	assert_almost_eq(_shape().radius, 20.0, 0.001, "tiny change skips the shape")
	assert_almost_eq(_cylinder().top_radius, 19.95, 0.001, "mesh always follows")
	_arena.radius = 19.8
	assert_almost_eq(_shape().radius, 19.8, 0.001)


func test_info() -> void:
	_arena.position = Vector3(4, 0, -2)
	var target := Node3D.new()
	target.position = Vector3(1, 2, 3)
	_world.add_child(target)
	var info := _arena.info()
	assert_eq(info.center, Vector3(4, 0, -2))
	assert_eq(info.radius, 30.0)
	assert_eq(info.floor_y, 0.0)
	assert_eq(info.target_position, Vector3.ZERO, "no target")
	_arena.target = target
	assert_eq(_arena.info().target_position, Vector3(1, 2, 3))
	_arena.radius = 12.0
	assert_eq(_arena.info().radius, 12.0)


func test_start_radius_applied_on_ready() -> void:
	var arena: Arena = ArenaScene.instantiate()
	arena.start_radius = 15.0
	_world.add_child(arena)
	assert_eq(arena.radius, 15.0)
	assert_eq((arena.floor_shape.shape as CylinderShape3D).radius, 15.0)


func test_shrinker_drives_radius() -> void:
	var shrinker: ArenaShrinker = _arena.get_node("ArenaShrinker")
	assert_same(shrinker.arena, _arena, "parent fallback")
	shrinker.advance(0.0)
	assert_eq(_arena.radius, 30.0)
	shrinker.advance(240.0)
	assert_almost_eq(_arena.radius, 21.0, 0.001)
	shrinker.advance(1000.0)
	assert_almost_eq(_arena.radius, 12.0, 0.001)
	assert_signal_emit_count(_arena, "radius_changed", 2, "only the two real changes (advance(0) is a no-op)")


func _body_with_health(layer: int) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	body.add_child(shape)
	body.add_child(HealthComponent.new())
	return body


func _area_with_health(layer: int) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = layer
	area.collision_mask = 0
	area.monitoring = false
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	area.add_child(shape)
	area.add_child(HealthComponent.new())
	return area


func test_kill_zone_kills_body_and_area() -> void:
	var kill_zone: KillZone = _arena.get_node("KillZone")
	watch_signals(kill_zone)
	var body := _body_with_health(PhysicsLayers.PLAYER)
	body.position = Vector3(3, -12, 0)
	_world.add_child(body)
	var area := _area_with_health(PhysicsLayers.ENEMY)
	area.position = Vector3(-3, -12, 1)
	_world.add_child(area)
	await wait_physics_frames(3)
	assert_true(KillZone.find_health(body).is_dead(), "body killed")
	assert_true(KillZone.find_health(area).is_dead(), "area killed")
	assert_signal_emit_count(kill_zone, "killed", 2)


func test_kill_zone_cause_is_void() -> void:
	var body := _body_with_health(PhysicsLayers.PLAYER)
	var health := KillZone.find_health(body)
	var causes: Array[StringName] = []
	health.died.connect(func(hit: HitInfo) -> void: causes.append(hit.cause))
	body.position = Vector3(0, -12, 0)
	_world.add_child(body)
	await wait_physics_frames(3)
	assert_eq(causes, [&"void"])


func test_kill_zone_ignores_nodes_above_and_without_health() -> void:
	var kill_zone: KillZone = _arena.get_node("KillZone")
	watch_signals(kill_zone)
	var safe := _body_with_health(PhysicsLayers.PLAYER)
	safe.position = Vector3(0, 1, 0)
	_world.add_child(safe)
	var no_health := CharacterBody3D.new()
	no_health.collision_layer = PhysicsLayers.ENEMY
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	no_health.add_child(shape)
	no_health.position = Vector3(0, -12, 0)
	_world.add_child(no_health)
	var wrong_layer := _body_with_health(PhysicsLayers.PICKUP)
	wrong_layer.position = Vector3(2, -12, 0)
	_world.add_child(wrong_layer)
	await wait_physics_frames(3)
	assert_false(KillZone.find_health(safe).is_dead())
	assert_false(KillZone.find_health(wrong_layer).is_dead())
	assert_signal_not_emitted(kill_zone, "killed")
	assert_false(kill_zone.try_kill(no_health))
	assert_false(kill_zone.try_kill(null))


func test_void_environment_resource() -> void:
	var env: Environment = load("res://src/arena/void_environment.tres")
	assert_not_null(env)
	assert_eq(env.background_mode, Environment.BG_COLOR)
	assert_eq(env.background_color, Color.BLACK)
	assert_eq(env.ambient_light_source, Environment.AMBIENT_SOURCE_COLOR)
	assert_almost_eq(env.ambient_light_color.r, 0.1, 0.001)
	assert_eq(env.tonemap_mode, Environment.TONE_MAPPER_LINEAR)
	assert_true(env.fog_enabled)
	assert_eq(env.fog_mode, Environment.FOG_MODE_DEPTH)
	assert_eq(env.fog_depth_begin, 10.0)
	assert_eq(env.fog_depth_end, 42.0)
	assert_eq(env.fog_light_color, Color.BLACK)
	assert_false(env.glow_enabled)
	assert_false(env.ssao_enabled)
	assert_false(env.ssil_enabled)
	assert_false(env.sdfgi_enabled)
	assert_false(env.ssr_enabled)
