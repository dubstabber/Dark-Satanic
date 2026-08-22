extends GameTest


func _tier(gems: int, name: String = "") -> DaggerUpgradeTier:
	var tier := DaggerUpgradeTier.new()
	tier.gems_required = gems
	tier.display_name = name if name != "" else str(gems)
	return tier


func _ladder(thresholds: Array) -> UpgradeLadder:
	var ladder := UpgradeLadder.new()
	for gems in thresholds:
		ladder.tiers.append(_tier(gems))
	return ladder


func test_empty_ladder_is_tier_zero() -> void:
	var ladder := UpgradeLadder.new()
	assert_eq(ladder.tier_index_for_gems(0), 0)
	assert_eq(ladder.tier_index_for_gems(999), 0)
	assert_not_null(ladder.tier(0), "tier() returns a default tier on an empty ladder")
	assert_eq(ladder.gems_to_next_tier(0), -1)


var boundary_params = ParameterFactory.named_parameters(
	["gems", "expected"],
	[[0, 0], [9, 0], [10, 1], [11, 1], [69, 1], [70, 2], [219, 2], [220, 3], [10000, 3]]
)


func test_boundaries_are_inclusive(p = use_parameters(boundary_params)) -> void:
	var ladder := _ladder([0, 10, 70, 220])
	assert_eq(ladder.tier_index_for_gems(p.gems), p.expected, "gems=%d" % p.gems)


func test_is_monotonic() -> void:
	var ladder := _ladder([0, 10, 70, 220])
	var last := 0
	for gems in 300:
		var index := ladder.tier_index_for_gems(gems)
		assert_true(index >= last, "tier never decreases (gems=%d)" % gems)
		last = index


func test_unsorted_authoring_order_is_fine() -> void:
	var ladder := _ladder([70, 0, 220, 10])
	assert_eq(ladder.tier_index_for_gems(10), 1)
	assert_eq(ladder.tier(1).gems_required, 10)
	assert_eq(ladder.tier(3).gems_required, 220)


func test_gems_to_next_tier() -> void:
	var ladder := _ladder([0, 10, 70])
	assert_eq(ladder.gems_to_next_tier(0), 10)
	assert_eq(ladder.gems_to_next_tier(7), 3)
	assert_eq(ladder.gems_to_next_tier(10), 60)
	assert_eq(ladder.gems_to_next_tier(70), -1)


func test_default_ladder_resource_matches_design() -> void:
	var ladder: UpgradeLadder = load("res://src/weapons/resources/default_ladder.tres")
	assert_not_null(ladder)
	assert_eq(ladder.tier_count(), 4)
	assert_eq(ladder.tier(0).gems_required, 0)
	assert_eq(ladder.tier(1).gems_required, 10)
	assert_eq(ladder.tier(2).gems_required, 70)
	assert_eq(ladder.tier(3).gems_required, 220)
	assert_true(ladder.tier(3).homing, "top tier homes")
	assert_false(ladder.tier(0).homing)
	assert_eq(ladder.tier(0).display_name, "I")
