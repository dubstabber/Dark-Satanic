class_name Game
extends Node3D
## Composition root of one run: wires player, weapon, enemies, gems, spawning,
## arena and HUD together and drives them from one physics clock.

signal run_ended(result: RunResult)

@export var config: GameConfig
@export var player_light_height: float = 2.5

@onready var arena: Arena = $Arena
@onready var arena_shrinker: ArenaShrinker = $Arena/ArenaShrinker
@onready var player: Player = $Player
@onready var enemy_container: Node3D = $EnemyContainer
@onready var gem_container: Node3D = $GemContainer
@onready var projectile_container: Node3D = $ProjectileContainer
@onready var vfx_container: Node3D = $VfxContainer
@onready var spawn_director: SpawnDirector = $SpawnDirector
@onready var boss_director: BossDirector = $BossDirector
@onready var hud: HUD = $HudLayer/HUD
@onready var player_light: OmniLight3D = $PlayerLight
@onready var whisper_scheduler: AmbienceScheduler = $WhisperScheduler
@onready var dread_scheduler: AmbienceScheduler = $DreadScheduler

## Screen shake from an enemy dying right next to you (0 disables).
@export_range(0.0, 1.0, 0.005) var death_shake: float = 0.1
## Distance at which a death stops shaking the camera at all.
@export_range(1.0, 80.0, 0.5) var death_shake_range: float = 14.0

var run_state: RunState
var _injected_state: RunState


## Optional: hand in a RunState before add_child (tests); otherwise RunManager.begin() is used.
func setup(state: RunState) -> void:
	_injected_state = state


func _ready() -> void:
	run_state = _injected_state if _injected_state != null else RunManager.begin(config.ladder)
	_wire_player()
	_wire_spawning()
	_wire_arena()
	hud.bind(run_state)
	run_state.tier_changed.connect(_on_tier_changed)
	run_state.gems_changed.connect(func(total: int) -> void: EventBus.gem_collected.emit(total))
	player.weapon_holder.set_tier(run_state.current_tier())
	spawn_director.start()
	boss_director.start()


func _physics_process(delta: float) -> void:
	if run_state == null or not run_state.is_running:
		return
	run_state.tick(delta)
	spawn_director.advance(delta)
	boss_director.advance(delta)
	whisper_scheduler.advance(delta)
	dread_scheduler.advance(delta)
	arena_shrinker.advance(run_state.elapsed)
	player_light.global_position = player.global_position + Vector3.UP * player_light_height


## Live enemies (nodes with a `died` signal); the homing-dagger target provider.
func enemies() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child in enemy_container.get_children():
		if SpawnDirector.is_enemy(child):
			result.append(child)
	return result


func _wire_player() -> void:
	player.setup(SettingsManager.mouse_sensitivity)
	player.weapon_holder.projectile_root = projectile_container
	var weapon := player.weapon_holder.weapon
	if weapon != null and "target_provider" in weapon:
		weapon.target_provider = enemies
	player.pickup_collector.gem_collected.connect(run_state.add_gems)
	player.died.connect(_on_player_died)


func _wire_spawning() -> void:
	spawn_director.wave_table = config.wave_table
	spawn_director.enemy_container = enemy_container
	spawn_director.drop_root = gem_container
	spawn_director.arena = arena
	spawn_director.target = player
	spawn_director.difficulty_scale = config.difficulty_scale
	spawn_director.rng_seed = config.rng_seed
	enemy_container.child_entered_tree.connect(_on_enemy_entered)


func _wire_arena() -> void:
	arena.target = player
	if config.shrink_curve != null:
		arena_shrinker.curve = config.shrink_curve


func _on_enemy_entered(node: Node) -> void:
	if node.has_signal("died"):
		node.died.connect(_on_enemy_died)
	_route_death_vfx(node)
	EventBus.enemy_spawned.emit(node)


## Death effects go to VfxContainer wherever the enemy came from — the director or a
## nest's SpawnerComponent. Left in EnemyContainer they would be counted as enemies.
func _route_death_vfx(node: Node) -> void:
	for child in node.get_children():
		if child is DeathHandlerComponent:
			(child as DeathHandlerComponent).vfx_root = vfx_container


func _on_enemy_died(enemy: Node3D, _last_hit: HitInfo) -> void:
	run_state.add_kill()
	_shake_for_death(enemy)
	EventBus.enemy_died.emit(enemy, enemy.global_position)


## A kill you are standing next to should be felt. Weighted by the enemy's health so a
## swarm of 1 HP skulls stays a rumble and the boss going out is an event, and by distance
## so a nest dying across the arena is not.
func _shake_for_death(enemy: Node3D) -> void:
	if death_shake <= 0.0 or player == null or not is_instance_valid(enemy):
		return
	var distance := player.global_position.distance_to(enemy.global_position)
	var falloff := clampf(1.0 - distance / death_shake_range, 0.0, 1.0)
	if falloff <= 0.0:
		return
	var health: Variant = enemy.get("stats")
	var weight := clampf((health as EnemyStats).max_health / 12.0, 0.15, 4.0) if health is EnemyStats else 1.0
	player.camera_rig.add_trauma(death_shake * falloff * weight)


func _on_tier_changed(tier: DaggerUpgradeTier, index: int) -> void:
	player.weapon_holder.set_tier(tier)
	EventBus.tier_changed.emit(tier, index)


func _on_player_died(cause: StringName) -> void:
	var result := run_state.end(cause)
	if result == null:
		return
	EventBus.player_died.emit(cause)
	run_ended.emit(result)
