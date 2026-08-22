class_name LeaderboardData
extends Resource
## Ordered top list of LeaderboardEntry (longest time_survived first), capped at max_entries.

@export var entries: Array[LeaderboardEntry] = []
@export_range(1, 100) var max_entries: int = 10


## Inserts the entry at its sorted position (ties go below existing equal times) and trims the
## list. Returns the 0-based rank, or -1 when the entry does not make the cut.
func insert(entry: LeaderboardEntry) -> int:
	if entry == null or not qualifies(entry.time_survived):
		return -1
	var rank := entries.size()
	for i in entries.size():
		if entry.time_survived > entries[i].time_survived:
			rank = i
			break
	entries.insert(rank, entry)
	while entries.size() > max_entries:
		entries.pop_back()
	return rank


## True when a run of this length would land on the board.
func qualifies(time: float) -> bool:
	if entries.size() < max_entries:
		return true
	return time > entries[entries.size() - 1].time_survived


func best() -> LeaderboardEntry:
	return null if entries.is_empty() else entries[0]


func size() -> int:
	return entries.size()
