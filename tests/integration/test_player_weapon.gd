extends GameTest
## Player + real DaggerWeapon: recoil reaches the camera rig and hands, and the
## camera sits at the movement stats' camera_height.

const WeaponScene := preload("res://src/weapons/dagger_weapon.tscn")
const DT := 1.0 / 60.0

var _world: Node3D
var _input: FakeInputReader
var _player: Player
var _weapon: DaggerWeapon


func before_each() -> void:
	super.before_each()
	_world = make_world()
	PlayerTestWorld.add_floor(_world)
	_input = FakeInputReader.new()
	_player = PlayerTestWorld.spawn_player(_world, _input)
	_weapon = WeaponScene.instantiate()
	_player.weapon_holder.add_child(_weapon)
	_player.weapon_holder.weapon = _weapon


func after_each() -> void:
	for child in _world.get_children():
		if child is DaggerProjectile:
			child.autonomous = false
	super.after_each()


func test_stream_shot_kicks_camera_and_hands() -> void:
	assert_eq(_player.camera_rig.kick_angle(), 0.0)
	assert_eq(_player.hands.kick_offset(), 0.0)
	_input.push(FakeInputReader.frame(Vector3.ZERO, false, false, true, false))
	_player.advance(DT)
	assert_gt(_player.camera_rig.kick_angle(), 0.0, "camera recoiled")
	assert_gt(_player.hands.kick_offset(), 0.0, "hands pushed back")
	# The rig's advance() runs after the kick in the same tick, so one step of recovery applies.
	var kick := _player.camera_rig.kick_pitch * _player.weapon_holder.stream_kick
	var expected := kick * (1.0 - _player.camera_rig.kick_recovery * DT)
	assert_almost_eq(_player.camera_rig.kick_angle(), expected, 0.0005)


func test_shotgun_kicks_harder_than_stream() -> void:
	_input.push(FakeInputReader.frame(Vector3.ZERO, false, false, true, false))
	_player.advance(DT)
	var stream_kick := _player.camera_rig.kick_angle()
	for i in 240:
		_player.camera_rig.advance(DT)
	assert_almost_eq(_player.camera_rig.kick_angle(), 0.0, 0.0001, "recoil settled")
	_input.push(FakeInputReader.frame(Vector3.ZERO, false, false, false, true))
	_player.advance(DT)
	assert_gt(_player.camera_rig.kick_angle(), stream_kick)


func test_idle_tick_has_no_kick() -> void:
	_player.advance(DT)
	assert_eq(_player.camera_rig.kick_angle(), 0.0)
	assert_eq(_player.hands.kick_offset(), 0.0)


func test_camera_rig_height_comes_from_movement_stats() -> void:
	assert_almost_eq(_player.camera_rig.position.y, _player.movement.stats.camera_height, 0.0001)
	var stats := PlayerMovementStats.new()
	stats.camera_height = 2.25
	var other: Player = PlayerTestWorld.PlayerScene.instantiate()
	(other.get_node("MovementController") as MovementController).stats = stats
	_world.add_child(other)
	assert_almost_eq(other.camera_rig.position.y, 2.25, 0.0001, "stat applied, not the scene's transform")
