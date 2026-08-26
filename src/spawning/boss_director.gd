class_name BossDirector
extends Node
## Puts a boss on the arena on a fixed interval, telegraphed like any other arrival.
##
## Deliberately not a WaveTable entry. An ordinary SpawnEvent is dropped when the arena is
## at max_alive, which in a busy run is exactly when a boss is most due; and the endless
## loop block would re-fire it every block rather than on a schedule a designer picked.
## Time is driven through advance(delta); nothing here uses the engine clock.

signal boss_spawned(boss: Node3D)
signal boss_ended(boss: Node3D)
## The arrival was announced; the boss follows `telegraph_lead` seconds later.
signal boss_telegraphed(position: Vector3)

## The director that actually spawns it (and raises the warning effect).
@export var director: SpawnDirector
## What to spawn, and where. Give it a pattern; `ignores_cap` is forced on so a full
## arena can never swallow the boss.
@export var event: SpawnEvent
@export_range(0.0, 3600.0, 1.0) var first_at: float = 180.0
@export_range(10.0, 3600.0, 1.0) var interval: float = 180.0
## Seconds of warning before the boss lands.
@export_range(0.0, 20.0, 0.1) var telegraph_lead: float = 3.0
## Skip the window entirely while a boss is still standing.
@export var only_one_alive: bool = true
@export var enabled: bool = true
## Advance on the engine clock instead of waiting for external advance() calls.
@export var autonomous: bool = false

var elapsed: float = 0.0
## How many bosses have been put on the arena this run.
var spawned: int = 0
var current: Node3D

var _next_at: float = 0.0
var _telegraphed: bool = false
var _telegraph_position: Vector3 = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if autonomous:
		advance(delta)


## Resets the clock; call alongside SpawnDirector.start().
func start() -> void:
	elapsed = 0.0
	spawned = 0
	current = null
	_next_at = first_at
	_telegraphed = false


func is_boss_alive() -> bool:
	return current != null and is_instance_valid(current) and not current.is_queued_for_deletion()


## Seconds until the next boss is due (negative when disabled or unscheduled).
func time_to_boss() -> float:
	return _next_at - elapsed if enabled else -1.0


func advance(delta: float) -> void:
	if not enabled or delta <= 0.0 or director == null or event == null:
		return
	elapsed += delta
	if not _telegraphed and elapsed >= _next_at - telegraph_lead:
		_announce()
	if elapsed < _next_at:
		return
	_next_at += interval
	_telegraphed = false
	if only_one_alive and is_boss_alive():
		return
	_summon()


func _announce() -> void:
	_telegraphed = true
	# Sampled even when the window is skipped, so a boss that dies between the warning
	# and the spawn still lands somewhere fresh rather than on a stale mark.
	_telegraph_position = _pick_position()
	if only_one_alive and is_boss_alive():
		return
	# The boss event is a SpawnEvent like any other, so its own `announce_cue` is its herald;
	# past the guard above, a window skipped because the last boss still stands stays silent.
	director.telegraph_at(_telegraph_position, event)
	boss_telegraphed.emit(_telegraph_position)


func _summon() -> void:
	event.ignores_cap = true
	var boss := director.spawn_at(event, _telegraph_position)
	if boss == null:
		return
	current = boss
	spawned += 1
	if current.has_signal("died"):
		current.died.connect(_on_boss_died)
	boss_spawned.emit(current)


## Where the warning goes. The same pattern the spawn will use, so the sigil and the boss
## agree; a pattern that randomises will not, hence a single sample kept for both.
func _pick_position() -> Vector3:
	if event.pattern == null or director == null:
		return Vector3.ZERO
	var positions := event.pattern.positions(1, director.arena_info(), director.rng)
	return positions[0] if not positions.is_empty() else Vector3.ZERO


func _on_boss_died(boss: Node3D, _last_hit: HitInfo) -> void:
	boss_ended.emit(boss)
	if boss == current:
		current = null
