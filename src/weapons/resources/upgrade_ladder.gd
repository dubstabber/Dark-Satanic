class_name UpgradeLadder
extends Resource
## Ordered list of DaggerUpgradeTier resources; answers "which tier for N gems".
## Tiers are sorted by gems_required on access so authoring order does not matter.

@export var tiers: Array[DaggerUpgradeTier] = []


func sorted_tiers() -> Array[DaggerUpgradeTier]:
	var copy: Array[DaggerUpgradeTier] = tiers.duplicate()
	copy.sort_custom(func(a: DaggerUpgradeTier, b: DaggerUpgradeTier) -> bool:
		return a.gems_required < b.gems_required)
	return copy


func tier_count() -> int:
	return tiers.size()


## Highest tier index whose gems_required <= gems (0 when the ladder is empty).
func tier_index_for_gems(gems: int) -> int:
	var index := 0
	var sorted := sorted_tiers()
	for i in sorted.size():
		if sorted[i].gems_required <= gems:
			index = i
	return index


func tier(index: int) -> DaggerUpgradeTier:
	var sorted := sorted_tiers()
	if sorted.is_empty():
		return DaggerUpgradeTier.new()
	return sorted[clampi(index, 0, sorted.size() - 1)]


## Gems still needed for the next tier, or -1 when already at the top.
func gems_to_next_tier(gems: int) -> int:
	var sorted := sorted_tiers()
	var next := tier_index_for_gems(gems) + 1
	if next >= sorted.size():
		return -1
	return sorted[next].gems_required - gems
