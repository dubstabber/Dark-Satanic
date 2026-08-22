extends GameTest


## Gem stand-in recording consume() calls.
class GemStub:
	extends Node3D
	var value: int = 3
	var consumed: int = 0

	func consume() -> void:
		consumed += 1


## Gem stand-in with a value but no consume().
class ValueOnlyGem:
	extends Node
	var value: int = 7


var _world: Node3D
var _collector: PickupCollector


func before_each() -> void:
	super.before_each()
	_world = make_world()
	_collector = PickupCollector.new()
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	_collector.add_child(shape)
	_world.add_child(_collector)
	watch_signals(_collector)


func test_layers_and_monitoring_match_contract() -> void:
	assert_eq(_collector.collision_layer, PhysicsLayers.PICKUP)
	assert_eq(_collector.collision_mask, 0)
	assert_true(_collector.monitorable)
	assert_false(_collector.monitoring)


func test_collect_emits_value_and_consumes() -> void:
	var gem := GemStub.new()
	_world.add_child(gem)
	_collector.collect(gem)
	assert_signal_emitted_with_parameters(_collector, "gem_collected", [3])
	assert_eq(gem.consumed, 1)
	assert_eq(_collector.collected_total, 3)


func test_collect_without_consume_still_emits() -> void:
	var gem := ValueOnlyGem.new()
	autofree(gem)
	_collector.collect(gem)
	assert_signal_emitted_with_parameters(_collector, "gem_collected", [7])


func test_collect_accumulates_total() -> void:
	var a := GemStub.new()
	var b := GemStub.new()
	b.value = 10
	_world.add_child(a)
	_world.add_child(b)
	_collector.collect(a)
	_collector.collect(b)
	assert_signal_emit_count(_collector, "gem_collected", 2)
	assert_eq(_collector.collected_total, 13)


func test_collect_null_or_valueless_node_is_safe() -> void:
	_collector.collect(null)
	assert_signal_not_emitted(_collector, "gem_collected")
	var plain := Node.new()
	autofree(plain)
	_collector.collect(plain)
	assert_signal_emitted_with_parameters(_collector, "gem_collected", [0])


func test_an_active_gem_area_finds_the_collector_by_overlap() -> void:
	# Mimics GemPickup: monitoring area on mask PICKUP calling collect(self) on overlap.
	var gem := GemStub.new()
	_world.add_child(gem)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = PhysicsLayers.PICKUP
	area.monitorable = false
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	area.add_child(shape)
	area.area_entered.connect(
		func(other: Area3D) -> void:
			if other.has_method("collect"):
				other.call("collect", gem)
	)
	area.position = Vector3(0.3, 0, 0)
	_world.add_child(area)
	await wait_physics_frames(3)
	assert_signal_emitted_with_parameters(_collector, "gem_collected", [3])
	assert_eq(gem.consumed, 1)
