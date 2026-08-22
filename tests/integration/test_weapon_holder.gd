extends GameTest


## Records every call a WeaponHolder makes on its weapon.
class WeaponStub:
	extends Node
	var setup_calls: Array = []
	var fire_calls: Array = []
	var tiers: Array = []

	func setup(aim_source: Node3D, muzzle: Node3D, projectile_root: Node) -> void:
		setup_calls.append([aim_source, muzzle, projectile_root])

	func update_fire(primary_held: bool, secondary_pressed: bool, delta: float) -> void:
		fire_calls.append([primary_held, secondary_pressed, delta])

	func apply_tier(tier: DaggerUpgradeTier) -> void:
		tiers.append(tier)


## A weapon with no optional methods at all.
class BareWeapon:
	extends Node


var _world: Node3D
var _player_root: Node3D
var _aim: Node3D
var _muzzle: Node3D
var _root: Node


func before_each() -> void:
	super.before_each()
	_world = make_world()
	_player_root = Node3D.new()
	_player_root.name = "PlayerStandIn"
	_aim = Node3D.new()
	_muzzle = Node3D.new()
	_player_root.add_child(_aim)
	_player_root.add_child(_muzzle)
	_root = Node.new()
	_root.name = "Projectiles"
	_world.add_child(_root)
	_world.add_child(_player_root)


func _holder(weapon: Node, projectile_root: Node = null) -> WeaponHolder:
	var holder := WeaponHolder.new()
	holder.aim_source = _aim
	holder.muzzle = _muzzle
	holder.projectile_root = projectile_root
	if weapon != null:
		holder.add_child(weapon)
	holder.weapon = weapon
	_player_root.add_child(holder)
	return holder


func test_setup_is_called_in_ready_with_injected_refs() -> void:
	var weapon := WeaponStub.new()
	_holder(weapon, _root)
	assert_eq(weapon.setup_calls.size(), 1)
	assert_same(weapon.setup_calls[0][0], _aim)
	assert_same(weapon.setup_calls[0][1], _muzzle)
	assert_same(weapon.setup_calls[0][2], _root)


func test_projectile_root_defaults_to_the_players_parent() -> void:
	var weapon := WeaponStub.new()
	var holder := _holder(weapon)
	assert_same(holder.projectile_root, _world)
	assert_same(weapon.setup_calls[0][2], _world)


func test_update_forwards_fire_input() -> void:
	var weapon := WeaponStub.new()
	var holder := _holder(weapon, _root)
	holder.update(FakeInputReader.frame(Vector3.ZERO, false, false, true, true), 0.016)
	holder.update(FakeInputReader.frame(), 0.02)
	assert_eq(weapon.fire_calls.size(), 2)
	assert_eq(weapon.fire_calls[0], [true, true, 0.016])
	assert_eq(weapon.fire_calls[1], [false, false, 0.02])


func test_set_tier_forwards_and_remembers() -> void:
	var weapon := WeaponStub.new()
	var holder := _holder(weapon, _root)
	var tier: DaggerUpgradeTier = load("res://src/weapons/resources/tiers/tier_2.tres")
	holder.set_tier(tier)
	assert_eq(weapon.tiers.size(), 1)
	assert_same(weapon.tiers[0], tier)
	assert_same(holder.tier(), tier)


func test_weapon_assigned_later_gets_setup_and_pending_tier() -> void:
	var holder := _holder(null, _root)
	var tier: DaggerUpgradeTier = load("res://src/weapons/resources/tiers/tier_3.tres")
	holder.set_tier(tier)
	holder.update(FakeInputReader.frame(), 0.016)
	var weapon := WeaponStub.new()
	holder.add_child(weapon)
	holder.weapon = weapon
	assert_eq(weapon.setup_calls.size(), 1)
	assert_same(weapon.setup_calls[0][0], _aim)
	assert_eq(weapon.tiers, [tier])


func test_no_weapon_is_a_no_op() -> void:
	var holder := _holder(null, _root)
	holder.update(FakeInputReader.frame(Vector3.ZERO, false, false, true, true), 0.016)
	holder.set_tier(load("res://src/weapons/resources/tiers/tier_1.tres"))
	assert_null(holder.weapon)
	pass_test("no errors with a missing weapon")


func test_weapon_without_optional_methods_is_tolerated() -> void:
	var weapon := BareWeapon.new()
	var holder := _holder(weapon, _root)
	holder.update(FakeInputReader.frame(Vector3.ZERO, false, false, true, true), 0.016)
	holder.set_tier(load("res://src/weapons/resources/tiers/tier_1.tres"))
	pass_test("duck typing guards every call")


func test_update_with_null_frame_is_ignored() -> void:
	var weapon := WeaponStub.new()
	var holder := _holder(weapon, _root)
	holder.update(null, 0.016)
	assert_eq(weapon.fire_calls.size(), 0)
