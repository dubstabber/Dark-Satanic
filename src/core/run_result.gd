class_name RunResult
extends RefCounted
## Immutable snapshot taken when a run ends.

var time_survived: float
var gems: int
var kills: int
var tier_index: int
var death_cause: StringName
var unix_time: int


func _init(
	p_time: float,
	p_gems: int,
	p_kills: int,
	p_tier_index: int,
	p_cause: StringName,
	p_unix_time: int = int(Time.get_unix_time_from_system())
) -> void:
	time_survived = p_time
	gems = p_gems
	kills = p_kills
	tier_index = p_tier_index
	death_cause = p_cause
	unix_time = p_unix_time
