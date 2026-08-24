extends GameTest
## The Thurible's ground fire: a warning you can walk out of, one brief burn, then gone.

const CinderScene := preload("res://src/enemies/hazards/cinder.tscn")
const ThuribleScene := preload("res://src/enemies/archetypes/thurible.tscn")
const DT := 1.0 / 60.0

var _world: Node3D
var _cinder: CinderHazard


func before_each() -> void:
	super.before_each()
	_world = make_world()
	_cinder = CinderScene.instantiate()
	_cinder.autonomous = false
	# Watched before it enters the tree: `armed` fires from _ready().
	watch_signals(_cinder)
	_world.add_child(_cinder)


func _advance(seconds: float) -> void:
	for i in int(round(seconds / DT)):
		_cinder.advance(DT)


func test_it_arms_before_it_burns() -> void:
	assert_eq(_cinder.state, CinderHazard.State.ARM)
	assert_false(_cinder.is_dangerous())
	assert_false(_cinder.hitbox.active, "nothing can be hurt during the warning")
	assert_signal_emitted(_cinder, "armed")
	_advance(_cinder.arm_time - 0.1)
	assert_eq(_cinder.state, CinderHazard.State.ARM, "still just a mark on the floor")
	assert_false(_cinder.hitbox.active)


func test_the_warning_grows_so_it_reads_as_a_countdown() -> void:
	var small: float = _cinder.sigil.scale.x
	_advance(_cinder.arm_time * 0.8)
	assert_gt(_cinder.sigil.scale.x, small, "the sigil swells as the burn approaches")
	assert_almost_eq(_cinder.progress(), 0.8, 0.05)


func test_it_burns_briefly_then_stops() -> void:
	_advance(_cinder.arm_time + 0.05)
	assert_eq(_cinder.state, CinderHazard.State.FLARE)
	assert_true(_cinder.is_dangerous())
	assert_true(_cinder.hitbox.active)
	assert_signal_emitted(_cinder, "flared")
	assert_true(_cinder.flare.emitting)
	_advance(_cinder.active_time)
	assert_eq(_cinder.state, CinderHazard.State.FADE)
	assert_false(_cinder.hitbox.active, "the window has closed")
	assert_false(_cinder.is_dangerous())


func test_it_cleans_itself_up() -> void:
	_advance(_cinder.arm_time + _cinder.active_time + _cinder.fade_time + 0.1)
	assert_signal_emitted(_cinder, "finished")
	assert_true(_cinder.is_queued_for_deletion())


func test_one_huge_step_still_walks_every_state() -> void:
	_advance(30.0)
	assert_signal_emitted(_cinder, "flared", "a lag spike must not skip the dangerous window")
	assert_signal_emitted(_cinder, "finished")


func test_its_burn_matches_its_radius() -> void:
	var shape := _cinder.hitbox.get_node("CollisionShape3D") as CollisionShape3D
	assert_almost_eq((shape.shape as CylinderShape3D).radius, _cinder.radius, 0.001)


func test_two_cinders_do_not_share_one_resized_shape() -> void:
	var other: CinderHazard = CinderScene.instantiate()
	other.autonomous = false
	other.radius = 5.0
	_world.add_child(other)
	var mine := (_cinder.hitbox.get_node("CollisionShape3D") as CollisionShape3D).shape as CylinderShape3D
	var theirs := (other.hitbox.get_node("CollisionShape3D") as CollisionShape3D).shape as CylinderShape3D
	assert_not_same(mine, theirs, "the scene's shape resource is shared; it must be duplicated")
	assert_almost_eq(theirs.radius, 5.0, 0.001)
	assert_almost_eq(mine.radius, _cinder.radius, 0.001)


func test_it_only_hits_the_player_layer() -> void:
	assert_eq(_cinder.hitbox.collision_layer, PhysicsLayers.ENEMY_HITBOX)
	assert_eq(_cinder.hitbox.collision_mask, PhysicsLayers.PLAYER_HURTBOX)
	assert_eq(_cinder.hitbox.cause, &"cinder")


func test_a_cinder_is_never_mistaken_for_an_enemy() -> void:
	assert_false(SpawnDirector.is_enemy(_cinder), "it has no `died` signal and must not read as an arrival")


func test_the_thurible_carries_a_censer_pointed_at_the_player() -> void:
	var thurible: Enemy = ThuribleScene.instantiate()
	var player := Node3D.new()
	player.position = Vector3(3, 0, 0)
	_world.add_child(player)
	thurible.target = player
	_world.add_child(thurible)
	thurible.set_physics_process(false)
	var censer: CenserComponent = thurible.get_node("Censer")
	censer.autonomous = false
	assert_same(censer.target, player, "inherited from the enemy it hangs off")
	assert_eq(censer.hazard_scene, CinderScene)
	assert_eq(thurible.stats.display_name, "Thurible")
	assert_lt(thurible.stats.move_speed, 3.0, "the slowest thing in the game: it zones, it does not chase")
