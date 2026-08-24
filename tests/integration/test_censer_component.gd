extends GameTest
## The Thurible's censer: where it drops burning ground, how often, and the limits that
## stop it paving the arena.

const CinderScene := preload("res://src/enemies/hazards/cinder.tscn")
const DT := 1.0 / 60.0


class FakeArena:
	extends Node3D

	var radius := 12.0

	func info() -> ArenaInfo:
		return ArenaInfo.new(global_position, radius, 0.0)


var _world: Node3D
var _hazards: Node3D
var _target: Node3D
var _censer: CenserComponent
var _arena: FakeArena


func before_each() -> void:
	super.before_each()
	_world = make_world()
	_hazards = Node3D.new()
	_hazards.name = "Hazards"
	_world.add_child(_hazards)
	_target = Node3D.new()
	_target.position = Vector3(2, 0, 1)
	_world.add_child(_target)
	_arena = FakeArena.new()
	_world.add_child(_arena)
	_censer = CenserComponent.new()
	_censer.hazard_scene = CinderScene
	_censer.hazard_root = _hazards
	_censer.target = _target
	_censer.arena = _arena
	_censer.rng_seed = 9
	_world.add_child(_censer)
	watch_signals(_censer)


func after_each() -> void:
	for child in _hazards.get_children():
		child.set("autonomous", false)
	super.after_each()


func _advance(seconds: float) -> void:
	for i in int(round(seconds / DT)):
		_censer.advance(DT)


func _cinders() -> Array[Node]:
	var found: Array[Node] = []
	for child in _hazards.get_children():
		if child is CinderHazard:
			found.append(child)
	return found


func test_nothing_drops_before_the_initial_delay() -> void:
	_advance(_censer.initial_delay - 0.1)
	assert_eq(_cinders().size(), 0)
	assert_signal_not_emitted(_censer, "dropped")


func test_it_drops_a_burst_on_its_interval() -> void:
	_advance(_censer.initial_delay + 0.05)
	assert_eq(_cinders().size(), _censer.burst)
	assert_signal_emitted(_censer, "dropped")
	assert_eq(_censer.drops, 1)
	_advance(_censer.interval)
	assert_eq(_censer.drops, 2)
	assert_eq(_cinders().size(), _censer.burst * 2)


func test_drops_land_around_the_player_not_around_itself() -> void:
	_advance(_censer.initial_delay + 0.05)
	for cinder: Node3D in _cinders():
		var offset := cinder.global_position - _target.global_position
		offset.y = 0.0
		assert_true(
			offset.length() <= _censer.drop_radius + 0.001,
			"dropped %.2f m from the player, radius is %.2f" % [offset.length(), _censer.drop_radius]
		)


func test_drops_sit_on_the_floor() -> void:
	_advance(_censer.initial_delay + 0.05)
	for cinder: Node3D in _cinders():
		assert_almost_eq(cinder.global_position.y, _censer.floor_offset, 0.001)


func test_drops_are_kept_on_the_platform() -> void:
	_target.position = Vector3(11.5, 0, 0)  # right on the rim of a 12 m arena
	for i in 40:
		var point := _censer.drop_point(_target.global_position, _arena.info())
		var flat := Vector2(point.x, point.z).length()
		assert_true(
			flat <= _arena.radius - _censer.platform_margin + 0.001,
			"dropped %.2f m out on a %.1f m platform" % [flat, _arena.radius]
		)


func test_it_stops_once_its_cinders_pile_up() -> void:
	_censer.max_alive = 3
	_advance(_censer.initial_delay + _censer.interval * 6.0)
	assert_eq(_cinders().size(), 3, "never paves the arena")


func test_a_burnt_out_cinder_frees_the_slot() -> void:
	_censer.max_alive = 2
	_advance(_censer.initial_delay + 0.05)
	assert_eq(_cinders().size(), 2)
	_cinders()[0].free()
	assert_eq(_censer.alive_count(), 1, "the dead one is forgotten")
	_advance(_censer.interval)
	assert_eq(_cinders().size(), 2)


func test_disabled_and_unconfigured_censers_are_inert() -> void:
	_censer.enabled = false
	_advance(60.0)
	assert_eq(_cinders().size(), 0)
	_censer.enabled = true
	_censer.hazard_scene = null
	_advance(60.0)
	assert_eq(_cinders().size(), 0)


func test_without_a_target_it_censes_around_itself() -> void:
	_censer.target = null
	_censer.anchor = _arena
	_arena.position = Vector3(-4, 0, 2)
	_advance(_censer.initial_delay + 0.05)
	assert_eq(_cinders().size(), _censer.burst)
	for cinder: Node3D in _cinders():
		var offset := cinder.global_position - _arena.global_position
		offset.y = 0.0
		assert_true(offset.length() <= _censer.drop_radius + 0.001)


func test_placement_is_reproducible_from_the_seed() -> void:
	_advance(_censer.initial_delay + 0.05)
	var first: Array[Vector3] = []
	for cinder: Node3D in _cinders():
		first.append(cinder.global_position)
	for child in _hazards.get_children():
		child.free()
	var other := CenserComponent.new()
	other.hazard_scene = CinderScene
	other.hazard_root = _hazards
	other.target = _target
	other.arena = _arena
	other.rng_seed = 9
	_world.add_child(other)
	for i in int(round((other.initial_delay + 0.05) / DT)):
		other.advance(DT)
	var second: Array[Vector3] = []
	for cinder: Node3D in _cinders():
		second.append(cinder.global_position)
	assert_eq(first.size(), second.size())
	for i in first.size():
		assert_almost_eq(second[i], first[i], Vector3.ONE * 0.0001, "same seed, same drops")
