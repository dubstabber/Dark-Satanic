extends GameTest

const BaseEnemy := preload("res://src/enemies/base_enemy.tscn")

var _world: Node3D
var _target: Node3D


func before_each() -> void:
	super.before_each()
	_world = make_world()
	_target = Node3D.new()
	_target.name = "Target"
	_target.position = Vector3(10, 0, 0)
	_world.add_child(_target)


func _stats() -> EnemyStats:
	var stats := EnemyStats.new()
	stats.max_health = 3.0
	stats.move_speed = 5.0
	stats.acceleration = 500.0
	stats.scale = 1.5
	stats.gem_count = 3
	stats.contact_damage = 2.0
	stats.spawn_duration = 0.4
	stats.min_height = 0.45
	return stats


func _spawn(with_seek: bool = true, physics: bool = false) -> Enemy:
	var enemy: Enemy = BaseEnemy.instantiate()
	enemy.stats = _stats()
	enemy.target = _target
	enemy.rng_seed = 3
	if with_seek:
		enemy.get_node("Behaviors").add_child(SeekBehavior.new())
	_world.add_child(enemy)
	enemy.set_physics_process(physics)
	watch_signals(enemy)
	return enemy


func test_applies_stats_and_wires_components() -> void:
	var enemy := _spawn()
	assert_eq(enemy.health.max_health, 3.0)
	assert_eq(enemy.health.health, 3.0)
	assert_eq(enemy.scale, Vector3.ONE * 1.5)
	assert_eq(enemy.contact_hitbox.damage, 2.0)
	assert_eq(enemy.contact_hitbox.cause, &"enemy")
	assert_eq(enemy.contact_hitbox.collision_layer, PhysicsLayers.ENEMY_HITBOX)
	assert_eq(enemy.contact_hitbox.collision_mask, PhysicsLayers.PLAYER_HURTBOX)
	assert_eq(enemy.hurtbox.collision_layer, PhysicsLayers.ENEMY_HURTBOX)
	assert_same(enemy.hurtbox.health, enemy.health)
	assert_eq(enemy.gem_drop.count, 3)
	assert_eq(enemy.death_handler.free_delay, 0.25)
	assert_not_null(enemy.mover)
	assert_not_null(enemy.visual)
	assert_not_null(enemy.visual.material(), "material duplicated per instance")
	var other := _spawn()
	assert_ne(enemy.visual.material(), other.visual.material())


func test_context_reflects_state() -> void:
	var enemy := _spawn()
	enemy.advance(0.1)
	var ctx := enemy.context()
	assert_same(ctx.body, enemy)
	assert_same(ctx.target, _target)
	assert_same(ctx.stats, enemy.stats)
	assert_almost_eq(ctx.elapsed, 0.1, 0.0001)
	assert_eq(ctx.spawn_position, Vector3.ZERO)
	assert_eq(ctx.target_position(), Vector3(10, 0, 0))
	assert_not_null(ctx.arena_info, "default ArenaInfo without an arena")
	assert_eq(ctx.arena_info.target_position, Vector3(10, 0, 0))


func test_arena_info_comes_from_arena() -> void:
	var arena := Node.new()
	var script := GDScript.new()
	script.source_code = "extends Node\nfunc info() -> ArenaInfo:\n\treturn ArenaInfo.new(Vector3(1, 0, 1), 5.0, 2.0)\n"
	script.reload()
	arena.set_script(script)
	_world.add_child(arena)
	var enemy: Enemy = BaseEnemy.instantiate()
	enemy.stats = _stats()
	enemy.target = _target
	enemy.arena = arena
	_world.add_child(enemy)
	enemy.set_physics_process(false)
	var ctx := enemy.context()
	assert_eq(ctx.arena_info.radius, 5.0)
	assert_eq(ctx.arena_info.floor_y, 2.0)
	enemy.advance(1.0)
	assert_almost_eq(enemy.global_position.y, 2.45, 0.001, "floor_y + min_height from the arena")


func test_falls_back_to_player_group() -> void:
	var player := Node3D.new()
	player.add_to_group("player")
	_world.add_child(player)
	var enemy: Enemy = BaseEnemy.instantiate()
	enemy.stats = _stats()
	_world.add_child(enemy)
	enemy.set_physics_process(false)
	assert_same(enemy.target, player)


func test_moves_toward_target() -> void:
	var enemy := _spawn()
	for i in 20:
		enemy.advance(1.0 / 60.0)
	assert_true(enemy.is_holding(), "the first spawn_duration is spent materialising")
	assert_almost_eq(enemy.global_position.x, 0.0, 0.001, "held where it arrived")
	for i in 60:
		enemy.advance(1.0 / 60.0)
	assert_false(enemy.is_holding())
	var distance := enemy.global_position.distance_to(_target.global_position)
	assert_true(distance < 10.0 - 4.0, "closed in at ~5 m/s (distance %.2f)" % distance)
	assert_almost_eq(enemy.global_position.y, 0.45, 0.001, "held at min_height")
	assert_almost_eq((-enemy.global_transform.basis.z).normalized().dot(Vector3.RIGHT), 1.0, 0.01, "faces its motion")


func test_physics_process_delegates_to_advance() -> void:
	var enemy := _spawn(true, true)
	await wait_physics_frames(5)
	assert_true(enemy.elapsed > 0.0)
	await wait_physics_frames(35)  # past the spawn hold
	assert_true(enemy.global_position.x > 0.0)


func test_hold_during_spawn_can_be_switched_off_for_a_moving_spawn_animation() -> void:
	var enemy: Enemy = BaseEnemy.instantiate()
	var stats := _stats()
	stats.hold_during_spawn = false
	enemy.stats = stats
	enemy.target = _target
	enemy.get_node("Behaviors").add_child(SeekBehavior.new())
	_world.add_child(enemy)
	enemy.set_physics_process(false)
	assert_false(enemy.is_holding())
	for i in 10:
		enemy.advance(1.0 / 60.0)
	assert_gt(enemy.global_position.x, 0.0, "a nest's rise out of the floor is its spawn animation")


func test_an_enemy_without_stats_never_holds() -> void:
	var enemy: Enemy = BaseEnemy.instantiate()
	enemy.target = _target
	_world.add_child(enemy)
	enemy.set_physics_process(false)
	assert_false(enemy.is_holding())


func test_contact_hitbox_inactive_during_spawn() -> void:
	var enemy := _spawn(false)
	assert_false(enemy.contact_hitbox.active)
	assert_false(enemy.is_spawned())
	enemy.advance(0.3)
	assert_false(enemy.contact_hitbox.active)
	enemy.advance(0.2)
	assert_true(enemy.contact_hitbox.active)
	assert_true(enemy.is_spawned())


func test_instant_spawn_when_duration_zero() -> void:
	var enemy: Enemy = BaseEnemy.instantiate()
	enemy.stats = _stats()
	enemy.stats.spawn_duration = 0.0
	enemy.target = _target
	_world.add_child(enemy)
	enemy.set_physics_process(false)
	assert_true(enemy.contact_hitbox.active)
	assert_true(enemy.is_spawned())


func test_damage_flashes_and_death_emits_and_drops_gems() -> void:
	var enemy := _spawn(false)
	var hit := HitInfo.new(1.0, Vector3.ZERO, Vector3.FORWARD, Vector3.UP, null, &"dagger")
	enemy.hurtbox.receive_hit(hit)
	assert_eq(enemy.health.health, 2.0)
	assert_eq(enemy.last_hit.cause, &"dagger")
	assert_eq(enemy.last_hit.damage, 1.0)
	assert_true(enemy.visual.is_animating(), "hit flash running")
	assert_signal_not_emitted(enemy, "died")
	enemy.hurtbox.receive_hit(HitInfo.new(5.0))
	assert_signal_emitted(enemy, "died")
	var params: Array = get_signal_parameters(enemy, "died")
	assert_same(params[0], enemy)
	assert_true(params[1] is HitInfo)
	assert_false(enemy.contact_hitbox.active)
	await wait_process_frames(2)
	var gems: Array[GemPickup] = []
	for child in _world.get_children():
		if child is GemPickup:
			gems.append(child)
	assert_eq(gems.size(), 3, "gems dropped as siblings")
	for gem in gems:
		assert_eq(gem.state, GemPickup.State.SCATTER)
		assert_true(gem.velocity.length() > 0.0, "scattered")


func test_dead_enemy_stops_moving_and_is_freed_after_delay() -> void:
	var enemy := _spawn()
	enemy.health.kill()
	var before := enemy.global_position
	enemy.advance(0.5)
	assert_eq(enemy.global_position, before)
	enemy.death_handler.advance(0.3)
	assert_true(enemy.is_queued_for_deletion(), "freed after DeathHandler.free_delay (0.25 s of advance)")
	await wait_process_frames(2)
	assert_false(is_instance_valid(enemy))


func test_no_stats_is_safe() -> void:
	var enemy: Enemy = BaseEnemy.instantiate()
	enemy.target = _target
	_world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.advance(0.1)
	assert_eq(enemy.scale, Vector3.ONE)
	assert_true(enemy.contact_hitbox.active)


func test_aim_position_prefers_an_exposed_weak_point() -> void:
	var enemy := _spawn(false)
	enemy.position = Vector3(1, 2, 3)
	assert_eq(enemy.aim_position(), Vector3(1, 2, 3), "no weak point: the root")
	var weak: WeakPointComponent = preload("res://src/components/weak_point_component.tscn").instantiate()
	weak.position = Vector3(0, 1.5, 0)
	enemy.add_child(weak)
	assert_eq(enemy.aim_position(), Vector3(1, 4.25, 3), "exposed weak point wins (1.5 m scaled by stats.scale 1.5)")
	weak.exposed = false
	assert_eq(enemy.aim_position(), Vector3(1, 2, 3), "hidden weak points are skipped")


func test_armour_hit_flashes_without_damage() -> void:
	var enemy := _spawn(false)
	enemy.hurtbox.damage_multiplier = 0.0
	enemy.hurtbox.receive_hit(HitInfo.new(1.0))
	assert_eq(enemy.health.health, 3.0, "armour absorbs the hit")
	assert_true(enemy.visual.is_animating(), "but the hit is still readable")
	assert_null(enemy.last_hit, "never reached health.damaged")


func test_gem_drop_inherits_the_arena() -> void:
	var arena := Node.new()
	_world.add_child(arena)
	var enemy: Enemy = BaseEnemy.instantiate()
	enemy.stats = _stats()
	enemy.target = _target
	enemy.arena = arena
	_world.add_child(enemy)
	enemy.set_physics_process(false)
	assert_same(enemy.gem_drop.arena, arena)


func test_contact_hitbox_waits_while_the_mover_is_rising() -> void:
	var enemy := _spawn(false)
	var hover := HoverDriftBehavior.new()
	hover.rise_duration = 1.0
	enemy.get_node("Behaviors").add_child(hover)
	enemy.advance(0.5)
	assert_true(enemy.is_spawned(), "spawn_duration 0.4 elapsed")
	assert_true(enemy.mover.is_rising())
	assert_false(enemy.contact_hitbox.active, "still coming through the floor")
	for i in 40:
		enemy.advance(0.05)
	assert_false(enemy.mover.is_rising())
	assert_true(enemy.contact_hitbox.active)


func test_the_hit_flash_does_not_retrigger_while_it_is_still_playing() -> void:
	var enemy := _spawn()
	var visual := enemy.visual
	visual.flash()
	assert_true(visual.is_flashing())
	var lit: float = visual.material().emission_energy_multiplier
	# A tier-IV stream lands ~40 hits a second; without the guard this pinned the mesh white.
	for i in 20:
		visual.flash()
	assert_almost_eq(visual.material().emission_energy_multiplier, lit, 0.0001, "still the same flash")
	await wait_seconds(visual.flash_duration + 0.05)
	assert_false(visual.is_flashing(), "and it finishes")
	visual.flash()
	assert_true(visual.is_flashing(), "then a new hit can flash again")


func test_the_death_burst_is_sized_by_what_died() -> void:
	var enemy := _spawn()
	assert_almost_eq(enemy.death_handler.vfx_scale, Enemy.death_burst_scale(enemy.stats), 0.0001)
	var weeper: EnemyStats = load("res://src/enemies/resources/stats/weeper.tres")
	var mourner: EnemyStats = load("res://src/enemies/resources/stats/mourner.tres")
	var boss: EnemyStats = load("res://src/enemies/resources/stats/tenebrae.tres")
	assert_lt(Enemy.death_burst_scale(weeper), Enemy.death_burst_scale(mourner), "1 HP pops smaller than 12")
	assert_lt(Enemy.death_burst_scale(mourner), Enemy.death_burst_scale(boss))
	assert_between(Enemy.death_burst_scale(boss), 1.0, 3.0, "but never fills the arena")
	assert_eq(Enemy.death_burst_scale(null), 1.0)
