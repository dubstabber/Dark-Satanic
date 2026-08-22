extends GameTest


func _health(maximum: float) -> HealthComponent:
	var health := HealthComponent.new()
	health.max_health = maximum
	autofree(health)
	watch_signals(health)
	return health


func test_max_health_initialises_health() -> void:
	var health := _health(5.0)
	assert_eq(health.health, 5.0)
	assert_false(health.is_dead())


func test_damage_reduces_and_emits() -> void:
	var health := _health(5.0)
	var hit := HitInfo.new(2.0)
	health.take_damage(hit)
	assert_eq(health.health, 3.0)
	assert_signal_emitted_with_parameters(health, "damaged", [hit])
	assert_signal_emitted_with_parameters(health, "health_changed", [3.0, 5.0])
	assert_signal_not_emitted(health, "died")


func test_dies_exactly_once_and_clamps() -> void:
	var health := _health(3.0)
	health.take_damage(HitInfo.new(10.0))
	assert_eq(health.health, 0.0)
	assert_true(health.is_dead())
	health.take_damage(HitInfo.new(1.0))
	assert_signal_emit_count(health, "died", 1)
	assert_signal_emit_count(health, "damaged", 1, "damage after death ignored")


func test_invulnerable_blocks_damage_but_not_kill() -> void:
	var health := _health(1.0)
	health.invulnerable = true
	health.take_damage(HitInfo.new(5.0))
	assert_eq(health.health, 1.0)
	health.kill(&"void")
	assert_true(health.is_dead())
	var last_hit: HitInfo = get_signal_parameters(health, "died")[0]
	assert_eq(last_hit.cause, &"void")


func test_zero_or_null_damage_ignored() -> void:
	var health := _health(2.0)
	health.take_damage(HitInfo.new(0.0))
	health.take_damage(HitInfo.new(-1.0))
	health.take_damage(null)
	assert_eq(health.health, 2.0)
	assert_signal_not_emitted(health, "damaged")


func test_heal_and_reset() -> void:
	var health := _health(4.0)
	health.take_damage(HitInfo.new(3.0))
	health.heal(10.0)
	assert_eq(health.health, 4.0, "heal clamps to max")
	health.take_damage(HitInfo.new(4.0))
	assert_true(health.is_dead())
	health.reset_health()
	assert_false(health.is_dead())
	assert_eq(health.health, 4.0)


func test_changing_max_after_damage_keeps_damage() -> void:
	var health := _health(4.0)
	health.take_damage(HitInfo.new(1.0))
	health.max_health = 10.0
	assert_eq(health.health, 3.0)
