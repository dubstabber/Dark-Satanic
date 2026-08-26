class_name SpawnEvent
extends Resource
## One entry of a WaveTable: spawn `count` copies of `enemy_scene` at `time`.

@export_range(0.0, 3600.0, 0.1) var time: float = 0.0
@export var enemy_scene: PackedScene
@export_range(1, 512) var count: int = 1
@export var pattern: SpawnPattern
## Seconds between individual spawns of this event (0 = all at once).
@export_range(0.0, 10.0, 0.01) var stagger: float = 0.0
@export var label: String = ""
## Spawn even when the arena is already at max_alive. For the rare arrival that must not
## be silently dropped — a boss is most due exactly when the arena is fullest.
@export var ignores_cap: bool = false
## Played at the warning, in place of the director's generic telegraph cue, for an arrival
## worth naming: the first cantor, the swarm, the thing behind you. The ambience scheduler
## throws the same kind of noise around for no reason at all, so a herald is a hint and
## never a promise.
@export var announce_cue: AudioCue


## Copy with a different time and count (used for endless loop blocks).
func retimed(new_time: float, new_count: int) -> SpawnEvent:
	var copy := SpawnEvent.new()
	copy.time = new_time
	copy.enemy_scene = enemy_scene
	copy.count = new_count
	copy.pattern = pattern
	copy.stagger = stagger
	copy.label = label
	copy.ignores_cap = ignores_cap
	copy.announce_cue = announce_cue
	return copy
