class_name RunState
extends RefCounted
## Mutable state of a single survival run: elapsed time, gems, kills and the
## current dagger upgrade tier. Pure logic, no nodes, so it is trivially testable.

signal time_changed(elapsed: float)
signal gems_changed(total: int)
signal kills_changed(total: int)
signal tier_changed(tier: DaggerUpgradeTier, index: int)
signal ended(result: RunResult)

var elapsed: float = 0.0
var gems: int = 0
var kills: int = 0
var tier_index: int = 0
var ladder: UpgradeLadder
var is_running: bool = false
var death_cause: StringName = &""


func _init(p_ladder: UpgradeLadder = null) -> void:
	ladder = p_ladder if p_ladder != null else UpgradeLadder.new()


func start() -> void:
	is_running = true
	tier_index = ladder.tier_index_for_gems(gems)
	tier_changed.emit(current_tier(), tier_index)


func tick(delta: float) -> void:
	if not is_running or delta <= 0.0:
		return
	elapsed += delta
	time_changed.emit(elapsed)


func add_gems(amount: int) -> void:
	if amount <= 0 or not is_running:
		return
	gems += amount
	gems_changed.emit(gems)
	_update_tier()


func add_kill() -> void:
	if not is_running:
		return
	kills += 1
	kills_changed.emit(kills)


func current_tier() -> DaggerUpgradeTier:
	return ladder.tier(tier_index)


func gems_to_next_tier() -> int:
	return ladder.gems_to_next_tier(gems)


func end(cause: StringName) -> RunResult:
	if not is_running:
		return null
	is_running = false
	death_cause = cause
	var result := RunResult.new(elapsed, gems, kills, tier_index, cause)
	ended.emit(result)
	return result


func _update_tier() -> void:
	var new_index := ladder.tier_index_for_gems(gems)
	if new_index == tier_index:
		return
	tier_index = new_index
	tier_changed.emit(current_tier(), tier_index)
