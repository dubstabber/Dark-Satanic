extends GameTest

const HitboxScene := preload("res://src/components/hitbox_component.tscn")

var _world: Node3D
var _player: Player


func before_each() -> void:
	super.before_each()
	_world = make_world()
	PlayerTestWorld.add_floor(_world)
	_player = PlayerTestWorld.spawn_player(_world)
	watch_signals(_player)
	watch_signals(_player.health)


func _enemy_hitbox(offset: Vector3) -> HitboxComponent:
	var carrier := Node3D.new()
	carrier.name = "EnemyStandIn"
	var hitbox: HitboxComponent = HitboxScene.instantiate()
	carrier.add_child(hitbox)
	carrier.position = _player.position + Vector3(0, 0.85, 0) + offset
	_world.add_child(carrier)
	return hitbox


func test_enemy_contact_kills_and_emits_died_once_with_cause_enemy() -> void:
	_enemy_hitbox(Vector3(0.2, 0, 0))
	await wait_physics_frames(3)
	assert_true(_player.health.is_dead())
	assert_true(_player.is_dead())
	assert_signal_emitted_with_parameters(_player, "died", [&"enemy"])
	assert_signal_emit_count(_player, "died", 1)
	await wait_physics_frames(3)
	assert_signal_emit_count(_player, "died", 1, "still once after more overlap frames")


func test_second_hitbox_after_death_does_not_re_emit() -> void:
	_enemy_hitbox(Vector3(0.2, 0, 0))
	await wait_physics_frames(3)
	_enemy_hitbox(Vector3(-0.2, 0, 0))
	await wait_physics_frames(3)
	assert_signal_emit_count(_player, "died", 1)


func test_far_hitbox_does_not_kill() -> void:
	_enemy_hitbox(Vector3(4, 0, 0))
	await wait_physics_frames(3)
	assert_false(_player.health.is_dead())
	assert_signal_not_emitted(_player, "died")


func test_kill_void_reports_void() -> void:
	_player.health.kill(&"void")
	assert_signal_emitted_with_parameters(_player, "died", [&"void"])
	assert_signal_emit_count(_player, "died", 1)
	_player.health.kill(&"void")
	assert_signal_emit_count(_player, "died", 1)


func test_direct_hurtbox_hit_kills_with_its_cause() -> void:
	var hurtbox: HurtboxComponent = _player.get_node("Hurtbox")
	hurtbox.receive_hit(HitInfo.new(1.0, Vector3.ZERO, Vector3.ZERO, Vector3.UP, null, &"enemy"))
	assert_signal_emitted_with_parameters(_player, "died", [&"enemy"])


func test_hitbox_masking_player_hurtbox_ignores_player_body_layer() -> void:
	# A hitbox that only masks ENEMY_HURTBOX must not hurt the player.
	var hitbox := _enemy_hitbox(Vector3.ZERO)
	hitbox.collision_mask = PhysicsLayers.ENEMY_HURTBOX
	await wait_physics_frames(3)
	assert_false(_player.health.is_dead())
