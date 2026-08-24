extends GameTest
## The Tenebrae's office: seven candles put out one by one as it is worn down, and a
## fight that escalates in bands of snuffed candles.

const BossScene := preload("res://src/enemies/bosses/tenebrae.tscn")

var _world: Node3D
var _boss: Enemy
var _phases: BossPhaseController


func before_each() -> void:
	super.before_each()
	_world = make_world()
	_boss = BossScene.instantiate()
	_boss.target = Node3D.new()
	_world.add_child(_boss.target)
	_world.add_child(_boss)
	_boss.set_physics_process(false)
	_phases = _boss.get_node("Phases")
	for child in _boss.find_children("*", "SpawnerComponent", true, false):
		child.set("autonomous", false)
	watch_signals(_phases)


func _candles() -> Array[WeakPointComponent]:
	var found: Array[WeakPointComponent] = []
	for child in _boss.get_children():
		if child is WeakPointComponent:
			found.append(child)
	return found


func _wear_down_to(fraction: float) -> void:
	var health := _boss.health
	var target := health.max_health * fraction
	health.take_damage(HitInfo.new(health.health - target))


func test_the_boss_is_armoured_and_only_the_candles_can_be_hurt() -> void:
	assert_eq(_boss.hurtbox.damage_multiplier, 0.0, "shooting the body does nothing")
	var candles := _candles()
	assert_eq(candles.size(), 7, "seven candles, as the office asks")
	for candle in candles:
		assert_true(candle.exposed)
		assert_gt(candle.effective_multiplier(HitInfo.new(1.0)), 1.0, "crits")


func test_a_candle_goes_out_for_each_seventh_of_health() -> void:
	var candles := _candles()
	assert_eq(_phases.snuffed, 0)
	_wear_down_to(6.0 / 7.0 - 0.01)
	assert_eq(_phases.snuffed, 1)
	assert_false(candles[0].exposed, "the first candle is out")
	assert_true(candles[1].exposed)
	assert_signal_emitted(_phases, "candle_snuffed")
	assert_eq(_phases.remaining(), 6)
	_wear_down_to(4.0 / 7.0 - 0.01)
	assert_eq(_phases.snuffed, 3, "big hits snuff every candle they pass")
	assert_false(candles[2].exposed)
	assert_true(candles[3].exposed)


func test_a_snuffed_candle_stops_taking_hits() -> void:
	_wear_down_to(6.0 / 7.0 - 0.01)
	var dead := _candles()[0]
	assert_eq(dead.effective_multiplier(HitInfo.new(1.0)), 0.0)
	var before := _boss.health.health
	dead.receive_hit(HitInfo.new(5.0))
	assert_almost_eq(_boss.health.health, before, 0.001, "a dark candle is just more armour")


func test_its_flame_is_hidden_with_it() -> void:
	var flame: Node3D = _boss.get_node("Visual/Flame0")
	assert_true(flame.visible)
	_wear_down_to(6.0 / 7.0 - 0.01)
	assert_false(flame.visible, "the arena gets one notch darker")


func test_the_fight_escalates_in_bands_of_candles() -> void:
	var hover: HoverDriftBehavior = _boss.get_node("Behaviors/Hover")
	var charge: EnemyBehavior = _boss.get_node("Behaviors/Charge")
	assert_eq(_phases.phase, 0)
	assert_true(hover.enabled)
	assert_false(charge.enabled)
	assert_almost_eq(hover.hover_height, 13.0, 0.001, "out of reach of the floor fight")

	_wear_down_to(5.0 / 7.0 - 0.01)  # two candles out
	assert_eq(_phases.phase, 1)
	assert_almost_eq(hover.hover_height, 6.0, 0.001, "down into the swarm's plane")
	assert_gt(hover.drift_speed, 2.5)
	assert_signal_emitted(_phases, "phase_changed")

	_wear_down_to(2.0 / 7.0 - 0.01)  # five candles out
	assert_eq(_phases.phase, 2)
	assert_false(hover.enabled, "it stops circling")
	assert_true(charge.enabled, "and comes at you")


func test_the_body_only_kills_once_it_has_come_down() -> void:
	var hitbox: HitboxComponent = _boss.get_node("ContactHitbox")
	assert_false(hitbox.active, "unreachable at 13 m, so it must not also be lethal")
	_wear_down_to(5.0 / 7.0 - 0.01)
	assert_true(hitbox.active)


func test_the_escorts_change_and_then_stop() -> void:
	var escorts: SpawnerComponent = _boss.get_node("Escorts")
	assert_true(escorts.enabled)
	var opening: PackedScene = escorts.scene
	_wear_down_to(5.0 / 7.0 - 0.01)
	assert_true(escorts.enabled)
	assert_ne(escorts.scene, opening, "phase II sends something worse")
	assert_gt(escorts.interval, 5.0)
	_wear_down_to(2.0 / 7.0 - 0.01)
	assert_false(escorts.enabled, "the last phase is the boss alone")


func test_the_last_candle_dies_with_the_boss() -> void:
	watch_signals(_boss)
	_boss.health.kill(&"dagger")
	assert_eq(_phases.snuffed, 7, "every candle out")
	assert_eq(_phases.remaining(), 0)
	assert_signal_emitted(_boss, "died")


func test_it_pays_out_like_a_boss() -> void:
	assert_eq(_boss.stats.display_name, "Tenebrae")
	assert_eq(_boss.gem_drop.count, 60, "far beyond any archetype")
	assert_gt(_boss.health.max_health, 80.0)


func test_thresholds_are_evenly_spaced_across_the_bar() -> void:
	assert_almost_eq(_phases.threshold_for(0), 6.0 / 7.0, 0.0001)
	assert_almost_eq(_phases.threshold_for(6), 0.0, 0.0001)
	for i in 6:
		assert_gt(_phases.threshold_for(i), _phases.threshold_for(i + 1))


func test_a_controller_with_no_candles_is_inert_rather_than_dividing_by_zero() -> void:
	var bare := BossPhaseController.new()
	bare.candles = []
	add_child_autofree(bare)
	assert_eq(bare.candle_count(), 0)
	assert_eq(bare.threshold_for(0), 0.0)
	assert_eq(bare.remaining(), 0)
