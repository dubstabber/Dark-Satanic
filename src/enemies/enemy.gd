class_name Enemy
extends Node3D
## Root of every enemy scene. Applies EnemyStats to its components, builds the EnemyContext
## behaviours steer from, and relays health events to the visual, cues and `died`.

signal died(enemy: Enemy, last_hit: HitInfo)

@export var stats: EnemyStats
## The player; when null the first node in group "player" is used at _ready.
@export var target: Node3D
## Anything with `func info() -> ArenaInfo`; optional.
@export var arena: Node
@export var rng_seed: int = 0

var rng := RandomNumberGenerator.new()
var elapsed: float = 0.0
var spawn_position: Vector3 = Vector3.ZERO
var last_hit: HitInfo

@onready var health: HealthComponent = _child_of_type(HealthComponent) as HealthComponent
@onready var hurtbox: HurtboxComponent = get_node_or_null("Hurtbox") as HurtboxComponent
@onready var contact_hitbox: HitboxComponent = get_node_or_null("ContactHitbox") as HitboxComponent
@onready var mover: EnemyMover = _child_of_type(EnemyMover) as EnemyMover
@onready var behaviors_root: Node = get_node_or_null("Behaviors")
@onready var visual: EnemyVisual = _child_of_type(EnemyVisual) as EnemyVisual
@onready var gem_drop: GemDropComponent = _child_of_type(GemDropComponent) as GemDropComponent
@onready var death_handler: DeathHandlerComponent = _child_of_type(DeathHandlerComponent) as DeathHandlerComponent

var _ctx := EnemyContext.new()
var _spawned: bool = false


func _ready() -> void:
	if rng_seed != 0:
		rng.seed = rng_seed
	if target == null:
		target = get_tree().get_first_node_in_group("player") as Node3D
	spawn_position = global_position
	_apply_stats()
	_ctx.body = self
	_ctx.rng = rng
	_ctx.spawn_position = spawn_position
	if health != null:
		health.damaged.connect(_on_damaged)
		health.died.connect(_on_died)
	if contact_hitbox != null:
		contact_hitbox.active = _spawn_duration() <= 0.0
	if visual != null:
		visual.spawn_in(_spawn_duration())
	if stats != null and stats.spawn_cue != null:
		AudioManager.play(stats.spawn_cue, global_position)
	_spawned = _spawn_duration() <= 0.0


func _physics_process(delta: float) -> void:
	advance(delta)


func context() -> EnemyContext:
	_ctx.body = self
	_ctx.stats = stats
	_ctx.target = target
	_ctx.elapsed = elapsed
	_ctx.spawn_position = spawn_position
	_ctx.arena_info = _arena_info()
	return _ctx


func advance(delta: float) -> void:
	if health != null and health.is_dead():
		return
	elapsed += delta
	var ctx := context()
	if not _spawned and elapsed >= _spawn_duration():
		_spawned = true
		if contact_hitbox != null:
			contact_hitbox.active = true
	if mover != null:
		mover.advance(ctx, delta)


func is_spawned() -> bool:
	return _spawned


func _apply_stats() -> void:
	if stats == null:
		return
	if health != null:
		health.max_health = stats.max_health
		health.reset_health()
	scale = Vector3.ONE * stats.scale
	if contact_hitbox != null:
		contact_hitbox.damage = stats.contact_damage
	if gem_drop != null:
		gem_drop.count = stats.gem_count
	if death_handler != null and death_handler.death_cue == null:
		death_handler.death_cue = stats.death_cue


func _spawn_duration() -> float:
	return stats.spawn_duration if stats != null else 0.0


func _arena_info() -> ArenaInfo:
	if arena != null and is_instance_valid(arena) and arena.has_method("info"):
		var info: Variant = arena.call("info")
		if info is ArenaInfo:
			return info
	var fallback := ArenaInfo.new()
	fallback.target_position = target.global_position if target != null and is_instance_valid(target) and target.is_inside_tree() else Vector3.ZERO
	return fallback


func _on_damaged(hit: HitInfo) -> void:
	last_hit = hit
	if visual != null:
		visual.flash()
	if stats != null and stats.hurt_cue != null:
		AudioManager.play(stats.hurt_cue, global_position)


func _on_died(hit: HitInfo) -> void:
	last_hit = hit
	if contact_hitbox != null:
		contact_hitbox.active = false
	if visual != null:
		visual.death()
	died.emit(self, hit)


func _child_of_type(type: Variant) -> Node:
	for child in get_children():
		if is_instance_of(child, type):
			return child
	return null
