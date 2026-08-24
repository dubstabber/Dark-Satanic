extends GameTest
## The Cantor's ranged attack: the wind-up that makes it fair, the lead that punishes
## standing still, and the range window that keeps it from sniping across the arena.

const ShardScene := preload("res://src/enemies/projectiles/psalm_shard.tscn")
const DT := 1.0 / 60.0

var _world: Node3D
var _muzzle: Node3D
var _target: Node3D
var _projectiles: Node3D
var _attack: RangedAttackComponent


func before_each() -> void:
	super.before_each()
	_world = make_world()
	_muzzle = Node3D.new()
	_muzzle.name = "Muzzle"
	_world.add_child(_muzzle)
	_target = Node3D.new()
	_target.name = "Target"
	_target.position = Vector3(0, 0, -14)
	_world.add_child(_target)
	_projectiles = Node3D.new()
	_projectiles.name = "Projectiles"
	_world.add_child(_projectiles)
	_attack = RangedAttackComponent.new()
	_attack.projectile_scene = ShardScene
	_attack.muzzle = _muzzle
	_attack.target = _target
	_attack.projectile_root = _projectiles
	_attack.rng_seed = 7
	_world.add_child(_attack)
	watch_signals(_attack)


func after_each() -> void:
	for child in _projectiles.get_children():
		child.set("autonomous", false)
	super.after_each()


func _advance(seconds: float) -> void:
	for i in int(round(seconds / DT)):
		_attack.advance(DT)


func _shards() -> Array[Node]:
	var found: Array[Node] = []
	for child in _projectiles.get_children():
		if child is PsalmShard:
			found.append(child)
	return found


func test_nothing_happens_before_the_initial_delay() -> void:
	_advance(_attack.initial_delay - _attack.windup - 0.1)
	assert_signal_not_emitted(_attack, "windup_started")
	assert_eq(_shards().size(), 0)


func test_the_windup_starts_before_the_shot_and_the_shot_follows_it() -> void:
	_advance(_attack.initial_delay - _attack.windup + 0.05)
	assert_signal_emitted(_attack, "windup_started")
	assert_true(_attack.is_winding_up())
	assert_eq(_shards().size(), 0, "announced, not fired")
	_advance(_attack.windup)
	assert_signal_emitted(_attack, "fired")
	assert_false(_attack.is_winding_up())
	assert_eq(_shards().size(), 1)
	assert_eq(_attack.shots, 1)


func test_it_keeps_firing_on_its_interval() -> void:
	_advance(_attack.initial_delay + 0.05)
	assert_eq(_attack.shots, 1)
	_advance(_attack.interval)
	assert_eq(_attack.shots, 2)
	_advance(_attack.interval)
	assert_eq(_attack.shots, 3)


func test_shards_are_parented_to_the_projectile_root_never_the_enemy() -> void:
	_advance(_attack.initial_delay + 0.05)
	var shard := _shards()[0]
	assert_same(shard.get_parent(), _projectiles)
	assert_false(
		SpawnDirector.is_enemy(shard),
		"a shard must never read as an enemy: it would be counted alive and reported as an arrival"
	)
	assert_not_null(shard.health, "but it is killable")


func test_the_shot_flies_at_the_target() -> void:
	_advance(_attack.initial_delay + 0.05)
	var shard: PsalmShard = _shards()[0]
	assert_almost_eq(shard.global_position, _muzzle.global_position, Vector3.ONE * 0.01)
	assert_lt(shard.velocity.z, 0.0, "toward the target on -Z")
	assert_almost_eq(shard.velocity.length(), shard.speed, 0.01)
	assert_same(shard.target, _target)


func test_a_moving_target_is_led() -> void:
	# Walk the target sideways so aim_point() runs ahead of it.
	for i in 30:
		_target.position += Vector3(0.2, 0, 0)
		_attack.advance(DT)
	assert_gt(_attack.aim_point().x, _target.global_position.x, "aimed where it is going")


func test_a_standing_target_is_aimed_at_directly() -> void:
	_advance(0.5)
	assert_almost_eq(_attack.aim_point(), _target.global_position, Vector3.ONE * 0.01)


func test_point_blank_is_out_of_range() -> void:
	_target.position = Vector3(0, 0, -2)
	assert_false(_attack.in_range(), "closer than min_range")
	_advance(_attack.initial_delay + 1.0)
	assert_eq(_shards().size(), 0, "it rams you instead")
	assert_signal_not_emitted(_attack, "fired")


func test_across_the_arena_is_out_of_range() -> void:
	_target.position = Vector3(0, 0, -80)
	assert_false(_attack.in_range())
	_advance(_attack.initial_delay + 1.0)
	assert_eq(_shards().size(), 0)


func test_walking_out_of_range_during_the_windup_cancels_the_shot() -> void:
	_advance(_attack.initial_delay - _attack.windup + 0.05)
	assert_true(_attack.is_winding_up())
	_target.position = Vector3(0, 0, -2)
	_advance(_attack.windup)
	assert_signal_not_emitted(_attack, "fired")
	assert_eq(_shards().size(), 0)


func test_a_volley_spreads_around_the_aim() -> void:
	_attack.shards_per_shot = 3
	_advance(_attack.initial_delay + 0.05)
	var shards := _shards()
	assert_eq(shards.size(), 3)
	var directions: Array[Vector3] = []
	for shard: PsalmShard in shards:
		directions.append(shard.velocity.normalized())
	assert_almost_ne(directions[0], directions[1], Vector3.ONE * 0.0001, "spread, not stacked")


func test_disabled_is_inert() -> void:
	_attack.enabled = false
	_advance(20.0)
	assert_eq(_shards().size(), 0)
	assert_eq(_attack.time_to_shot(), -1.0)


func test_a_missing_target_never_fires() -> void:
	_attack.target = null
	_advance(20.0)
	assert_false(_attack.in_range())
	assert_eq(_shards().size(), 0)


func test_the_component_inherits_its_target_from_the_enemy_it_hangs_off() -> void:
	var enemy: Enemy = load("res://src/enemies/base_enemy.tscn").instantiate()
	enemy.target = _target
	var attack := RangedAttackComponent.new()
	enemy.add_child(attack)
	_world.add_child(enemy)
	enemy.set_physics_process(false)
	assert_same(attack.target, _target, "read off the parent when nothing injected it")
