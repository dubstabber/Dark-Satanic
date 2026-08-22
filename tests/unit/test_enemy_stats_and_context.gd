extends GameTest

const WeeperStats := preload("res://src/enemies/resources/stats/weeper.tres")
const MournerStats := preload("res://src/enemies/resources/stats/mourner.tres")
const LamentStats := preload("res://src/enemies/resources/stats/lament.tres")
const VesperStats := preload("res://src/enemies/resources/stats/vesper.tres")
const GluttonStats := preload("res://src/enemies/resources/stats/glutton.tres")
const GemDefault := preload("res://src/pickups/resources/gem_default.tres")


func test_enemy_stats_defaults() -> void:
	var stats := EnemyStats.new()
	assert_eq(stats.acceleration, 40.0)
	assert_eq(stats.turn_speed_deg, 540.0)
	assert_eq(stats.min_height, 0.45)
	assert_eq(stats.scale, 1.0)
	assert_eq(stats.contact_damage, 1.0)
	assert_eq(stats.spawn_duration, 0.4)
	assert_null(stats.hurt_cue)
	assert_null(stats.death_cue)
	assert_null(stats.spawn_cue)


func test_authored_stats_load() -> void:
	assert_eq(WeeperStats.max_health, 1.0)
	assert_eq(WeeperStats.move_speed, 7.0)
	assert_eq(WeeperStats.turn_speed_deg, 540.0)
	assert_eq(WeeperStats.gem_count, 0)
	assert_eq(MournerStats.max_health, 12.0)
	assert_eq(MournerStats.move_speed, 4.5)
	assert_eq(MournerStats.turn_speed_deg, 60.0)
	assert_eq(MournerStats.gem_count, 1)
	assert_eq(LamentStats.max_health, 10.0)
	assert_eq(LamentStats.gem_count, 10)
	assert_eq(LamentStats.min_height, 3.5)
	assert_eq(VesperStats.max_health, 6.0)
	assert_eq(VesperStats.gem_count, 2)
	assert_eq(GluttonStats.max_health, 12.0)
	assert_eq(GluttonStats.move_speed, 3.0)
	assert_eq(GluttonStats.gem_count, 2)
	for stats: EnemyStats in [WeeperStats, MournerStats, LamentStats, VesperStats, GluttonStats]:
		assert_true(stats.display_name.length() > 0)
		assert_true(stats.move_speed > 0.0)


func test_gem_stats_defaults_and_authored() -> void:
	var stats := GemStats.new()
	assert_eq(stats.value, 1)
	assert_eq(stats.rest_height, 0.35)
	assert_eq(stats.magnet_radius, 4.0)
	assert_eq(stats.lifetime, 0.0)
	assert_eq(GemDefault.value, 1)
	assert_eq(GemDefault.scatter_speed_min, 2.0)
	assert_eq(GemDefault.scatter_speed_max, 5.0)
	assert_eq(GemDefault.scatter_up, 3.0)
	assert_eq(GemDefault.scatter_gravity, 12.0)
	assert_eq(GemDefault.magnet_accel, 30.0)
	assert_eq(GemDefault.magnet_max_speed, 25.0)
	assert_null(GemDefault.collect_cue)


func test_context_target_position_is_safe_without_target() -> void:
	var ctx := EnemyContext.new()
	assert_eq(ctx.target_position(), Vector3.ZERO)
	assert_eq(ctx.to_target(), Vector3.ZERO)
	assert_eq(ctx.body_position(), Vector3.ZERO)
	ctx.arena_info = ArenaInfo.new(Vector3.ZERO, 30.0, 0.0, Vector3(1, 2, 3))
	assert_eq(ctx.target_position(), Vector3(1, 2, 3), "falls back to the arena's known target position")


func test_context_to_target_uses_body_and_target() -> void:
	var world := make_world()
	var body := Node3D.new()
	body.position = Vector3(1, 0, 0)
	var target := Node3D.new()
	target.position = Vector3(4, 0, 4)
	world.add_child(body)
	world.add_child(target)
	var ctx := EnemyContext.new()
	ctx.body = body
	ctx.target = target
	assert_eq(ctx.to_target(), Vector3(3, 0, 4))
	assert_eq(ctx.target_position(), Vector3(4, 0, 4))
	target.free()
	assert_eq(ctx.to_target(), Vector3(-1, 0, 0), "freed target falls back to zero")


func test_context_default_arena_info_and_helpers() -> void:
	var ctx := EnemyContext.new()
	assert_not_null(ctx.arena_info)
	assert_eq(ctx.floor_y(), 0.0)
	assert_eq(ctx.center(), Vector3.ZERO)
	ctx.arena_info = ArenaInfo.new(Vector3(5, 0, 5), 10.0, 1.0)
	assert_eq(ctx.floor_y(), 1.0)
	assert_eq(ctx.center(), Vector3(5, 0, 5))
	assert_not_null(ctx.rng)


func test_context_providers() -> void:
	var a: Node3D = autofree(Node3D.new())
	var b: Node3D = autofree(Node3D.new())
	var ctx := EnemyContext.new()
	ctx.body = a
	ctx.neighbors_provider = func() -> Array[Node3D]: return [a, b]
	var neighbors := ctx.neighbors()
	assert_eq(neighbors.size(), 1, "the body itself is never a neighbour")
	assert_same(neighbors[0], b)
	ctx.gems_provider = func() -> Array[Node3D]: return [b]
	assert_eq(ctx.gems().size(), 1)
	ctx.gems_provider = Callable()
	ctx.neighbors_provider = Callable()
	assert_eq(ctx.gems().size(), 0, "no parent: nothing found")
	assert_eq(ctx.neighbors().size(), 0)


func test_context_default_providers_scan_siblings() -> void:
	var world := make_world()
	var body := Enemy.new()
	var other := Enemy.new()
	var gem := Node3D.new()
	gem.set_script(preload("res://tests/fixtures/gem_stub.gd"))
	var consumable := GemPickup.new()
	world.add_child(body)
	world.add_child(other)
	world.add_child(gem)
	world.add_child(consumable)
	var ctx := EnemyContext.new()
	ctx.body = body
	var neighbors := ctx.neighbors()
	assert_eq(neighbors.size(), 1)
	assert_same(neighbors[0], other)
	var gems := ctx.gems()
	assert_eq(gems.size(), 1, "only nodes with consume() count as gems")
	assert_same(gems[0], consumable)


func test_turn_toward_limits_rotation() -> void:
	var heading := Vector3.RIGHT
	var turned := EnemyBehavior.turn_toward(heading, Vector3.FORWARD, 90.0, 0.5)
	assert_almost_eq(rad_to_deg(heading.angle_to(turned)), 45.0, 0.01)
	var full := EnemyBehavior.turn_toward(heading, Vector3.FORWARD, 900.0, 1.0)
	assert_almost_eq(full.distance_to(Vector3.FORWARD), 0.0, 0.001)
	assert_eq(EnemyBehavior.turn_toward(Vector3.ZERO, Vector3.FORWARD, 10.0, 0.01), Vector3.FORWARD, "no heading yet: snap")
	assert_eq(EnemyBehavior.turn_toward(heading, Vector3.ZERO, 10.0, 0.01), heading, "no desired: keep heading")
