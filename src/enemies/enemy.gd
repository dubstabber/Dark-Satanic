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
	if hurtbox != null:
		hurtbox.hit_received.connect(_on_hurtbox_hit)
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
	# A corpse keeps ticking. EnemyVisual owns the death animation and is stepped here, on
	# the same clock as everything else, until DeathHandlerComponent frees the body.
	if health != null and health.is_dead():
		if visual != null:
			visual.advance(delta)
		return
	elapsed += delta
	var ctx := context()
	if not _spawned and elapsed >= _spawn_duration():
		_spawned = true
		if contact_hitbox != null:
			contact_hitbox.active = true
	if mover != null and not is_holding():
		mover.advance(ctx, delta)
		# A nest still rising through the floor must not kill from underneath.
		if contact_hitbox != null:
			contact_hitbox.active = _spawned and not mover.is_rising()


func is_spawned() -> bool:
	return _spawned


## How big a death should look. Square-rooted so the range from a 1 HP skull to an 84 HP
## boss reads as "small / normal / huge" instead of the burst vanishing or filling the arena.
static func death_burst_scale(p_stats: EnemyStats) -> float:
	if p_stats == null:
		return 1.0
	return clampf(sqrt(p_stats.max_health / 3.0), 0.6, 3.0)


## True while the enemy is still materialising and its stats say to stay put.
func is_holding() -> bool:
	return not _spawned and stats != null and stats.hold_during_spawn


## Where projectiles should aim: the first exposed WeakPointComponent child, else the root.
func aim_position() -> Vector3:
	for child in get_children():
		if child is WeakPointComponent and child.exposed and child is Node3D:
			return child.global_position
	return global_position


func _apply_stats() -> void:
	if gem_drop != null and gem_drop.arena == null:
		gem_drop.arena = arena
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
	if death_handler != null:
		death_handler.vfx_scale = death_burst_scale(stats)


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


## Armour hits (0-multiplier) never reach `health.damaged`; make them readable anyway.
func _on_hurtbox_hit(hit: HitInfo) -> void:
	if hurtbox.effective_multiplier(hit) > 0.0:
		return
	if visual != null:
		visual.flash()
	if stats != null and stats.armor_cue != null:
		AudioManager.play(stats.armor_cue, global_position)


func _on_died(hit: HitInfo) -> void:
	last_hit = hit
	if contact_hitbox != null:
		contact_hitbox.active = false
	if visual != null:
		visual.death(rng)
	died.emit(self, hit)


func _child_of_type(type: Variant) -> Node:
	for child in get_children():
		if is_instance_of(child, type):
			return child
	return null
