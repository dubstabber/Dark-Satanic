class_name ArenaShrinker
extends Node
## Shrinks the arena from its start radius to `end_radius` between
## `start_time` and `end_time` (run seconds), following `curve` (linear when null).
## Driven through advance(run_time); radius_at() is pure.

## Arena to drive; when null the parent is used.
@export var arena: Arena
@export_range(0.0, 3600.0, 1.0) var start_time: float = 60.0
@export_range(0.0, 3600.0, 1.0) var end_time: float = 420.0
@export_range(0.0, 200.0, 0.5) var end_radius: float = 12.0
## Maps progress 0..1 (x) to shrink amount 0..1 (y); linear when null.
@export var curve: Curve


func _ready() -> void:
	if arena == null:
		arena = get_parent() as Arena


## Radius for a run time, from `start_radius` (arena's, or the given one) to end_radius.
func radius_at(run_time: float, start_radius: float = -1.0) -> float:
	var from: float = start_radius
	if from < 0.0:
		from = arena.start_radius if arena != null else 30.0
	return lerpf(from, end_radius, shrink_fraction(run_time))


## 0 before start_time, 1 at/after end_time, curve-shaped in between.
func shrink_fraction(run_time: float) -> float:
	if end_time <= start_time:
		return 1.0 if run_time >= end_time else 0.0
	var progress := clampf((run_time - start_time) / (end_time - start_time), 0.0, 1.0)
	if curve == null:
		return progress
	return clampf(curve.sample(progress), 0.0, 1.0)


func advance(run_time: float) -> void:
	if arena == null:
		return
	var wanted := radius_at(run_time)
	if not is_equal_approx(arena.radius, wanted):
		arena.radius = wanted
