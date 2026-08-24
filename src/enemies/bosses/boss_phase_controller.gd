class_name BossPhaseController
extends Node
## Turns one health bar into a Tenebrae office: the candles go out one by one as the
## boss is worn down, and the fight escalates in bands of snuffed candles.
##
## Everything a phase changes is a per-instance export on a node in the boss's own scene.
## Nothing here writes to the shared EnemyStats `.tres` — that Resource is shared by every
## instance of the archetype, so a phase change would leak into the next boss.

signal candle_snuffed(index: int, remaining: int)
signal phase_changed(phase: int)

## Health to watch; the first HealthComponent sibling is used when unset.
@export var health: HealthComponent
## Weak points, brightest-first. Each is snuffed (exposed = false) as health falls.
@export var candles: Array[NodePath] = []
## Meshes hidden alongside their candle, same order.
@export var flames: Array[NodePath] = []
## Played at the candle's position as it goes out.
@export var snuff_cue: AudioCue

@export_group("Phases")
## How many candles must be out before the fight moves to phase 1, then phase 2, ...
## Left empty the boss stays in phase 0 and only loses candles.
@export var phase_thresholds: Array[int] = [2, 5]
## Hover behaviour retuned per phase; index 0 is the opening phase.
@export var hover: HoverDriftBehavior
@export var hover_heights: Array[float] = []
@export var hover_speeds: Array[float] = []
## Enabled in the last phase, so the boss stops circling and comes at the player.
@export var charge: EnemyBehavior
## Escorts; retuned per phase and switched off in the last one.
@export var spawner: SpawnerComponent
@export var spawner_intervals: Array[float] = []
@export var spawner_scenes: Array[PackedScene] = []
## Enabled once the boss drops to head height, so it can also kill by touch.
@export var contact_hitbox: HitboxComponent
## The phase index at which the body itself becomes dangerous (-1 = never).
@export var contact_from_phase: int = 1

var phase: int = 0
var snuffed: int = 0


func _ready() -> void:
	if health == null:
		health = _sibling_health()
	if health != null:
		health.health_changed.connect(_on_health_changed)
	if contact_hitbox != null and contact_from_phase > 0:
		contact_hitbox.active = false
	_apply_phase(0)


func candle_count() -> int:
	return candles.size()


## Candles still alight.
func remaining() -> int:
	return maxi(candle_count() - snuffed, 0)


## Fraction of health at which candle `index` (0-based) goes out. Seven candles means the
## first goes at 6/7 health and the last at 0 — i.e. the last one dies with the boss.
func threshold_for(index: int) -> float:
	if candle_count() <= 0:
		return 0.0
	return 1.0 - float(index + 1) / float(candle_count())


func _on_health_changed(current: float, maximum: float) -> void:
	if maximum <= 0.0:
		return
	var fraction := current / maximum
	while snuffed < candle_count() and fraction <= threshold_for(snuffed) + 0.0001:
		_snuff(snuffed)
		snuffed += 1
	_update_phase()


func _snuff(index: int) -> void:
	var candle := _node(candles, index) as WeakPointComponent
	if candle != null:
		candle.exposed = false
		AudioManager.play(snuff_cue, candle.global_position)
	var flame := _node(flames, index) as Node3D
	if flame != null:
		flame.visible = false
	candle_snuffed.emit(index, remaining())


func _update_phase() -> void:
	var next := 0
	for threshold in phase_thresholds:
		if snuffed >= threshold:
			next += 1
	if next != phase:
		_apply_phase(next)


func _apply_phase(index: int) -> void:
	phase = index
	var last := phase_thresholds.size()
	if hover != null:
		hover.enabled = index < last
		if index < hover_heights.size():
			hover.hover_height = hover_heights[index]
		if index < hover_speeds.size():
			hover.drift_speed = hover_speeds[index]
	if charge != null:
		charge.enabled = index >= last
	if spawner != null:
		spawner.enabled = index < last
		if index < spawner_intervals.size():
			spawner.interval = spawner_intervals[index]
		if index < spawner_scenes.size() and spawner_scenes[index] != null:
			spawner.scene = spawner_scenes[index]
	if contact_hitbox != null and contact_from_phase >= 0:
		contact_hitbox.active = index >= contact_from_phase
	phase_changed.emit(index)


func _node(paths: Array[NodePath], index: int) -> Node:
	if index < 0 or index >= paths.size():
		return null
	return get_node_or_null(paths[index])


func _sibling_health() -> HealthComponent:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is HealthComponent:
			return child
	return null
