class_name LeaderboardEntry
extends Resource
## One leaderboard row: who survived how long and what they achieved.

const DEFAULT_NAME := "ANON"

@export var player_name: String = DEFAULT_NAME
@export var time_survived: float = 0.0
@export var gems: int = 0
@export var tier_index: int = 0
@export var kills: int = 0
@export var unix_time: int = 0


static func make(
	p_name: String, p_time: float, p_gems: int = 0, p_tier: int = 0, p_kills: int = 0, p_unix: int = 0
) -> LeaderboardEntry:
	var entry := LeaderboardEntry.new()
	entry.player_name = p_name
	entry.time_survived = p_time
	entry.gems = p_gems
	entry.tier_index = p_tier
	entry.kills = p_kills
	entry.unix_time = p_unix
	return entry


## An unnamed entry carrying everything a finished run recorded.
static func from_result(result: RunResult) -> LeaderboardEntry:
	return make(DEFAULT_NAME, result.time_survived, result.gems, result.tier_index, result.kills, result.unix_time)
