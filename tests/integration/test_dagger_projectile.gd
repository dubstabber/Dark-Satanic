extends GameTest

const ProjectileScene := preload("res://src/weapons/projectiles/dagger_projectile.tscn")
const DT := 1.0 / 60.0

var _world: Node3D
var _projectile: DaggerProjectile
var _source: Node


func before_each() -> void:
	super.before_each()
	_world = make_world()
	_source = Node.new()
	_source.name = "Weapon"
	_world.add_child(_source)
	_projectile = ProjectileScene.instantiate()
	_projectile.autonomous = false
	_world.add_child(_projectile)
	watch_signals(_projectile)


func _params(speed: float = 60.0, damage: float = 1.0, lifetime: float = 1.0) -> ProjectileParams:
	var params := ProjectileParams.new()
	params.speed = speed
	params.damage = damage
	params.lifetime = lifetime
	return params


func _tick(times: int) -> void:
	for i in times:
		_projectile.advance(DT)


func test_launch_activates_and_positions() -> void:
	assert_false(_projectile.active)
	assert_false(_projectile.visible)
	var params := _params()
	params.scale = 1.5
	params.emission_energy = 3.0
	_projectile.launch(Vector3(1, 2, 3), Vector3.FORWARD, params, _source)
	assert_true(_projectile.active)
	assert_true(_projectile.visible)
	assert_eq(_projectile.global_position, Vector3(1, 2, 3))
	assert_almost_eq(_projectile.velocity, Vector3(0, 0, -60), Vector3.ONE * 0.001)
	assert_almost_eq(_projectile.scale, Vector3.ONE * 1.5, Vector3.ONE * 0.001)
	var mesh: MeshInstance3D = _projectile.get_node("Mesh")
	var material := mesh.get_surface_override_material(0) as StandardMaterial3D
	assert_almost_eq(material.emission_energy_multiplier, 3.0, 0.001)


func test_material_is_per_instance() -> void:
	var other: DaggerProjectile = ProjectileScene.instantiate()
	_world.add_child(other)
	var a := (_projectile.get_node("Mesh") as MeshInstance3D).get_surface_override_material(0)
	var b := (other.get_node("Mesh") as MeshInstance3D).get_surface_override_material(0)
	assert_ne(a, b, "each projectile owns its material so emission differs per tier")


func test_hits_hurtbox_damages_and_releases() -> void:
	var target := WeaponTargets.hurtbox_target(_world, Vector3(0, 0, -3), 3.0)
	await wait_physics_frames(3)
	_projectile.launch(Vector3.ZERO, Vector3.FORWARD, _params(60.0, 2.0), _source)
	_tick(5)
	assert_eq(target.health.health, 1.0, "damage applied once")
	assert_signal_emitted(_projectile, "hit")
	assert_signal_emit_count(_projectile, "hit", 1)
	assert_signal_emitted(_projectile, "released")
	assert_signal_not_emitted(_projectile, "hit_world")
	assert_false(_projectile.active)
	assert_false(_projectile.visible)
	var hit_info: HitInfo = get_signal_parameters(_projectile, "hit")[1]
	assert_same(get_signal_parameters(_projectile, "hit")[0], target.hurtbox)
	assert_eq(hit_info.damage, 2.0)
	assert_eq(hit_info.cause, &"dagger")
	assert_same(hit_info.source, _source)
	assert_almost_eq(hit_info.direction, Vector3.FORWARD, Vector3.ONE * 0.001)
	assert_almost_eq(hit_info.position.z, -2.5, 0.05, "stops on the sphere surface")


func test_ignores_hurtbox_on_other_layer() -> void:
	var target := WeaponTargets.hurtbox_target(_world, Vector3(0, 0, -3), 1.0)
	target.hurtbox.collision_layer = PhysicsLayers.PLAYER_HURTBOX
	await wait_physics_frames(3)
	_projectile.launch(Vector3.ZERO, Vector3.FORWARD, _params(), _source)
	_tick(10)
	assert_false(target.health.is_dead())
	assert_signal_not_emitted(_projectile, "hit")
	assert_true(_projectile.active)


func test_miss_flies_straight_and_expires() -> void:
	_projectile.launch(Vector3.ZERO, Vector3(1, 0, 0), _params(30.0, 1.0, 0.5), _source)
	_tick(29)
	assert_true(_projectile.active)
	assert_almost_eq(_projectile.global_position, Vector3(29.0 * 30.0 * DT, 0, 0), Vector3.ONE * 0.01)
	assert_almost_eq(_projectile.age, 29.0 * DT, 0.0001)
	_tick(1)
	assert_false(_projectile.active, "lifetime 0.5 s reached on the 30th tick")
	assert_signal_emitted(_projectile, "released")
	assert_signal_not_emitted(_projectile, "hit")
	assert_signal_not_emitted(_projectile, "hit_world")


func test_release_emits_once() -> void:
	_projectile.launch(Vector3.ZERO, Vector3.FORWARD, _params(), _source)
	_projectile.release()
	_projectile.release()
	assert_signal_emit_count(_projectile, "released", 1)
	_projectile.advance(DT)
	assert_eq(_projectile.global_position, Vector3.ZERO, "inactive projectiles do not move")


func test_hits_world_body() -> void:
	WeaponTargets.floor_body(_world, 0.0)
	await wait_physics_frames(3)
	_projectile.launch(Vector3(0, 2, 0), Vector3.DOWN, _params(60.0), _source)
	_tick(5)
	assert_signal_emitted(_projectile, "hit_world")
	assert_signal_not_emitted(_projectile, "hit")
	assert_signal_emitted(_projectile, "released")
	var normal: Vector3 = get_signal_parameters(_projectile, "hit_world")[1]
	assert_almost_eq(normal, Vector3.UP, Vector3.ONE * 0.01)
	assert_almost_eq(_projectile.global_position.y, 0.0, 0.02)


func test_orientation_follows_velocity() -> void:
	_projectile.launch(Vector3.ZERO, Vector3(1, 0, 1), _params(), _source)
	assert_almost_eq(-_projectile.global_basis.z.normalized(), Vector3(1, 0, 1).normalized(), Vector3.ONE * 0.001)
	_projectile.velocity = Vector3(0, 0, 60)
	_tick(1)
	assert_almost_eq(-_projectile.global_basis.z.normalized(), Vector3.BACK, Vector3.ONE * 0.001)


func test_vertical_velocity_orients_without_nan() -> void:
	_projectile.launch(Vector3.ZERO, Vector3.UP, _params(), _source)
	assert_true(_projectile.global_basis.z.is_finite())
	assert_almost_eq(-_projectile.global_basis.z.normalized(), Vector3.UP, Vector3.ONE * 0.001)


func _homing_params(range_: float = 20.0, turn_rate: float = 360.0) -> ProjectileParams:
	var params := _params(60.0, 1.0, 2.0)
	params.homing = true
	params.homing_turn_rate_deg = turn_rate
	params.homing_acquire_range = range_
	return params


func _node_at(position: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = position
	_world.add_child(node)
	return node


func test_homing_turns_toward_target() -> void:
	var target := _node_at(Vector3(4, 0, -6))
	_projectile.target_provider = func() -> Array[Node3D]: return [target]
	_projectile.launch(Vector3.ZERO, Vector3.FORWARD, _homing_params(), _source)
	var before := _projectile.velocity.normalized().dot(Vector3(4, 0, -6).normalized())
	_tick(1)
	var after := _projectile.velocity.normalized().dot((target.global_position - _projectile.global_position).normalized())
	assert_gt(after, before, "velocity rotated toward the target")
	assert_almost_eq(_projectile.velocity.length(), 60.0, 0.01, "speed preserved")
	var turned := rad_to_deg(Vector3.FORWARD.angle_to(_projectile.velocity))
	assert_almost_eq(turned, 360.0 * DT, 0.05, "turn limited by homing_turn_rate_deg * delta")


func test_homing_without_provider_or_disabled_flies_straight() -> void:
	_node_at(Vector3(4, 0, -6))
	_projectile.launch(Vector3.ZERO, Vector3.FORWARD, _homing_params(), _source)
	_tick(3)
	assert_almost_eq(_projectile.velocity, Vector3(0, 0, -60), Vector3.ONE * 0.001, "no provider")
	var target := _node_at(Vector3(4, 0, -6))
	_projectile.target_provider = func() -> Array[Node3D]: return [target]
	_projectile.launch(Vector3.ZERO, Vector3.FORWARD, _params(), _source)
	_tick(3)
	assert_almost_eq(_projectile.velocity, Vector3(0, 0, -60), Vector3.ONE * 0.001, "homing off")


func test_homing_ignores_targets_behind_and_out_of_range() -> void:
	var behind := _node_at(Vector3(0, 0, 5))
	var far := _node_at(Vector3(3, 0, -30))
	_projectile.target_provider = func() -> Array[Node3D]: return [behind, far]
	_projectile.launch(Vector3.ZERO, Vector3.FORWARD, _homing_params(10.0), _source)
	_tick(3)
	assert_almost_eq(_projectile.velocity, Vector3(0, 0, -60), Vector3.ONE * 0.001)


func test_homing_picks_nearest_candidate() -> void:
	var near := _node_at(Vector3(2, 0, -4))
	var farther := _node_at(Vector3(-5, 0, -8))
	_projectile.target_provider = func() -> Array[Node3D]: return [farther, near]
	_projectile.launch(Vector3.ZERO, Vector3.FORWARD, _homing_params(), _source)
	_tick(1)
	assert_gt(_projectile.velocity.x, 0.0, "turned toward +x (the nearer target)")


func test_hit_vfx_spawned_under_parent_at_hit_point() -> void:
	WeaponTargets.hurtbox_target(_world, Vector3(0, 0, -3), 1.0)
	await wait_physics_frames(3)
	var vfx_scene := PackedScene.new()
	var template := Node3D.new()
	template.name = "Vfx"
	vfx_scene.pack(template)
	template.free()
	_projectile.hit_vfx = vfx_scene
	_projectile.launch(Vector3.ZERO, Vector3.FORWARD, _params(), _source)
	_tick(5)
	await wait_process_frames(2)
	var vfx := _world.get_node_or_null("Vfx") as Node3D
	assert_not_null(vfx)
	if vfx != null:
		assert_almost_eq(vfx.global_position.z, -2.5, 0.05)
