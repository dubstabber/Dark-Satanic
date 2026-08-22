extends GameTest

const HurtboxScene := preload("res://src/components/hurtbox_component.tscn")
const HitboxScene := preload("res://src/components/hitbox_component.tscn")
const WeakPointScene := preload("res://src/components/weak_point_component.tscn")

var _world: Node3D


func before_each() -> void:
	super.before_each()
	_world = make_world()


## A body (Node3D) with a HealthComponent and a hurtbox on the player_hurtbox layer.
func _victim(max_health: float, hurtbox_scene: PackedScene = HurtboxScene) -> Dictionary:
	var body := Node3D.new()
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = max_health
	body.add_child(health)
	var hurtbox: HurtboxComponent = hurtbox_scene.instantiate()
	hurtbox.collision_layer = PhysicsLayers.PLAYER_HURTBOX
	body.add_child(hurtbox)
	_world.add_child(body)
	watch_signals(health)
	watch_signals(hurtbox)
	return {"body": body, "health": health, "hurtbox": hurtbox}


func _hitbox(position: Vector3, damage: float = 1.0) -> HitboxComponent:
	var hitbox: HitboxComponent = HitboxScene.instantiate()
	hitbox.damage = damage
	hitbox.position = position
	_world.add_child(hitbox)
	watch_signals(hitbox)
	return hitbox


func test_hurtbox_finds_sibling_health_and_forwards() -> void:
	var victim := _victim(3.0)
	var hurtbox: HurtboxComponent = victim.hurtbox
	assert_same(hurtbox.health, victim.health)
	hurtbox.receive_hit(HitInfo.new(2.0))
	assert_eq(victim.health.health, 1.0)
	assert_signal_emitted(hurtbox, "hit_received")


func test_armoured_hurtbox_reports_but_does_not_damage() -> void:
	var victim := _victim(3.0)
	victim.hurtbox.damage_multiplier = 0.0
	victim.hurtbox.receive_hit(HitInfo.new(2.0))
	assert_eq(victim.health.health, 3.0)
	assert_signal_emitted(victim.hurtbox, "hit_received")


func test_overlapping_hitbox_deals_contact_damage() -> void:
	var victim := _victim(1.0)
	var hitbox := _hitbox(Vector3(0.2, 0, 0))
	await wait_physics_frames(3)
	assert_true(victim.health.is_dead())
	assert_signal_emitted(hitbox, "hit_dealt")
	var last_hit: HitInfo = get_signal_parameters(victim.health, "died")[0]
	assert_eq(last_hit.cause, &"enemy")
	assert_same(last_hit.source, hitbox.get_parent())


func test_far_hitbox_does_nothing() -> void:
	var victim := _victim(1.0)
	_hitbox(Vector3(5, 0, 0))
	await wait_physics_frames(3)
	assert_false(victim.health.is_dead())


func test_inactive_hitbox_hits_once_activated() -> void:
	var victim := _victim(1.0)
	var hitbox := _hitbox(Vector3.ZERO)
	hitbox.active = false
	await wait_physics_frames(3)
	assert_false(victim.health.is_dead(), "inactive hitbox ignored the overlap")
	hitbox.active = true
	assert_true(victim.health.is_dead(), "activation re-checks current overlaps")


func test_one_shot_hitbox_deactivates() -> void:
	var victim := _victim(5.0)
	var hitbox := _hitbox(Vector3.ZERO, 1.0)
	hitbox.one_shot = true
	await wait_physics_frames(3)
	assert_eq(victim.health.health, 4.0)
	assert_false(hitbox.active)


func test_weak_point_crit_and_exposure() -> void:
	var victim := _victim(10.0, WeakPointScene)
	var weak_point: WeakPointComponent = victim.hurtbox
	weak_point.crit_multiplier = 3.0
	weak_point.receive_hit(HitInfo.new(1.0))
	assert_eq(victim.health.health, 7.0)
	assert_signal_emitted(weak_point, "weak_point_hit")
	weak_point.exposed = false
	weak_point.receive_hit(HitInfo.new(1.0))
	assert_eq(victim.health.health, 7.0, "hidden weak point takes nothing")
	assert_signal_emit_count(weak_point, "weak_point_hit", 1)
	assert_signal_emit_count(weak_point, "hit_received", 2)
