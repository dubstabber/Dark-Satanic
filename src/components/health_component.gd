class_name HealthComponent
extends Node
## Hit points for anything. Emits `died` exactly once.

signal health_changed(current: float, maximum: float)
signal damaged(hit: HitInfo)
signal died(last_hit: HitInfo)

@export var max_health: float = 1.0:
	set(value):
		max_health = maxf(value, 0.0)
		if not _touched:
			health = max_health
@export var invulnerable: bool = false

var health: float = 1.0
var _touched: bool = false
var _dead: bool = false


func is_dead() -> bool:
	return _dead


func take_damage(hit: HitInfo) -> void:
	if _dead or invulnerable or hit == null or hit.damage <= 0.0:
		return
	_touched = true
	health = maxf(health - hit.damage, 0.0)
	damaged.emit(hit)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die(hit)


## Unconditional death (kill zones, debug) — ignores `invulnerable`.
func kill(cause: StringName = &"kill", source: Node = null) -> void:
	if _dead:
		return
	_touched = true
	health = 0.0
	var hit := HitInfo.new(INF, Vector3.ZERO, Vector3.ZERO, Vector3.UP, source, cause)
	health_changed.emit(health, max_health)
	_die(hit)


func heal(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	health = minf(health + amount, max_health)
	health_changed.emit(health, max_health)


func reset_health() -> void:
	_touched = false
	_dead = false
	health = max_health
	health_changed.emit(health, max_health)


func _die(hit: HitInfo) -> void:
	_dead = true
	died.emit(hit)
