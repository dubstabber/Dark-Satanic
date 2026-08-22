# Architecture contract

This file is the agreement between the game's modules. Each folder under `src/` can be built and tested on its
own; only `src/game/game.gd` (the composition root) and `src/core/game_flow.gd` know how they fit together.
Read `CLAUDE.md` for the coding rules.

## Existing foundation (do not redesign)

- `src/core/physics_layers.gd` — `PhysicsLayers.WORLD|PLAYER|PLAYER_HURTBOX|ENEMY|ENEMY_HURTBOX|ENEMY_HITBOX|PICKUP|KILL_ZONE`
  (bits 1..128). Names are declared in `project.godot`.
- `src/core/run_state.gd` — `RunState` (elapsed, gems, kills, tier_index, ladder; `tick`, `add_gems`, `add_kill`,
  `end(cause)`; signals `time_changed`, `gems_changed`, `kills_changed`, `tier_changed(tier, index)`, `ended(result)`).
- `src/core/run_result.gd` — `RunResult` (time_survived, gems, kills, tier_index, death_cause, unix_time).
- `src/core/audio_cue.gd` — `AudioCue` resource; play with `AudioManager.play(cue, position)` (null cue = no-op).
- `src/core/autoload/*` — `EventBus` (signals only), `RunManager`, `SettingsManager` (mouse_sensitivity,
  volumes, `changed`), `AudioManager`. Only `src/core` and `src/game` may reference `EventBus`/`RunManager`/
  `SettingsManager`.
- `src/components/*` — `HealthComponent`, `HurtboxComponent`, `WeakPointComponent`, `HitboxComponent`,
  `GemDropComponent`, `SpawnerComponent`, `DeathHandlerComponent`, `HitInfo`. See their docstrings.
- `src/weapons/resources/*` — `DaggerUpgradeTier`, `UpgradeLadder`, `default_ladder.tres` (tiers I–IV).
- `src/arena/arena_info.gd` — `ArenaInfo` (center, radius, floor_y, target_position, `clamp_to_platform`).
- `src/ui/common/time_format.gd` — `TimeFormat.seconds()`, `TimeFormat.roman()`.
- `tests/support/game_test.gd` — `GameTest` base (`make_world()`, `temp_user_path()`), fixtures in `tests/fixtures`.

## Module contracts

### Player (`src/player`)
- `player.tscn` root `Player` (CharacterBody3D, layer PLAYER, mask WORLD). Script `player.gd` exposes
  `signal died(cause: StringName)`, `@onready var health: HealthComponent`, `movement: MovementController`,
  `look: LookController`, `weapon_holder: WeaponHolder`, `pickup_collector: PickupCollector`, `camera: Camera3D`.
  `func setup(mouse_sensitivity: float) -> void`. Input comes from a child `InputReader` producing a
  `PlayerInputFrame` per physics tick; tests swap in `tests/support/fake_input_reader.gd`.
- `PickupCollector` (Area3D, layer PICKUP, `monitorable = true`, `monitoring = false`):
  `signal gem_collected(value: int)`; `func collect(gem: Node) -> void` reads `gem.value` (int), emits, then
  calls `gem.consume()` if present. This is the only contract between player and pickups.
- `WeaponHolder` (Node): `@export var weapon: Node` (a `DaggerWeapon` in production). In `_ready` it calls
  `weapon.setup(aim_source, muzzle, projectile_root)` when the weapon has that method, forwards input via
  `weapon.update_fire(primary_held: bool, secondary_pressed: bool, delta: float)` and tiers via
  `weapon.apply_tier(tier: DaggerUpgradeTier)`. `projectile_root` is an exported Node (defaults to the
  player's parent). `func set_tier(tier)` is what `Game` calls.
- Player hurtbox: child `Hurtbox` (HurtboxComponent, layer PLAYER_HURTBOX) feeding `HealthComponent`
  (max_health 1). `died` re-emits the last `HitInfo.cause` (`&"enemy"`, `&"void"`).

### Weapons (`src/weapons`)
- `dagger_weapon.tscn` root `DaggerWeapon` (Node3D): `setup(aim_source: Node3D, muzzle: Node3D,
  projectile_root: Node)`, `update_fire(primary_held, secondary_pressed, delta)`, `apply_tier(tier)`,
  `signal fired(count: int, mode: StringName)`, `var target_provider: Callable` (returns `Array[Node3D]` of
  homing candidates; `Game` injects it), `@export var stream_cue/shotgun_cue: AudioCue`.
- Children are `FireMode` nodes (`StreamFire`, `ShotgunFire`) driving a `ProjectileSpawner` + `ProjectilePool`.
- `DaggerProjectile` (Node3D, no physics body): swept `intersect_ray(prev, next)` each tick with
  `collide_with_areas = true`, mask `PhysicsLayers.ENEMY_HURTBOX | PhysicsLayers.WORLD`; on hitting a
  `HurtboxComponent` calls `receive_hit(HitInfo)` with `cause = &"dagger"`, `source = the weapon`. Returns to
  the pool on hit or lifetime expiry. Exposes `launch(origin, direction, params: ProjectileParams)`.

### Enemies (`src/enemies`)
- `base_enemy.tscn` root `Enemy` (Node3D) script `enemy.gd`: `@export var stats: EnemyStats`,
  `@export var target: Node3D` (player; when null falls back to group `"player"` at `_ready`),
  `@export var arena: Node` (anything with `func info() -> ArenaInfo`; optional),
  `signal died(enemy: Enemy, last_hit: HitInfo)`, `func context() -> EnemyContext`.
  Children: `HealthComponent`, `Hurtbox` (HurtboxComponent, layer ENEMY_HURTBOX), `ContactHitbox`
  (HitboxComponent, layer ENEMY_HITBOX, mask PLAYER_HURTBOX, `cause = &"enemy"`), `Mover` (EnemyMover),
  `Behaviors` (Node holding `EnemyBehavior` children), `Visual`, `GemDrop`, `DeathHandler`.
  Archetype scenes inherit `base_enemy.tscn`: `weeper.tscn`, `mourner.tscn`, `lament.tscn`, `vesper.tscn`,
  `glutton.tscn`. Anything instantiating an enemy may set `target` and `arena` before `add_child`.
- Enemies are kinematic: `EnemyMover.advance(delta)` integrates `global_position`; `_physics_process`
  delegates. Enemies must never leave the platform (`ArenaInfo.clamp_to_platform`) or go below `floor_y + min_height`.
- Gem drops use `GemDropComponent` with `gem_scene = res://src/pickups/gem_pickup.tscn`.

### Pickups (`src/pickups`)
- `gem_pickup.tscn` root `GemPickup` (Area3D, `monitoring = true`, `monitorable = false`, mask PICKUP):
  `@export var stats: GemStats`, `var value: int` (from stats), `func scatter(rng: RandomNumberGenerator)`,
  `func consume()` (plays cue, frees), `func advance(delta)`; child `MagnetArea` (Area3D, mask PICKUP, bigger
  sphere) that acquires a target when a collector overlaps it. On `area_entered` of the root, if
  `area.has_method("collect")`: `area.collect(self)`.

### Spawning (`src/spawning`)
- Resources: `SpawnEvent` (time, enemy_scene, count, pattern: SpawnPattern, stagger, label),
  `WaveTable` (events, loop_from_time, loop_count_multiplier, loop_interval_multiplier, max_alive;
  `expanded() -> Array[SpawnEvent]` sorted), `SpawnPattern` (@abstract, `positions(count, arena: ArenaInfo,
  rng) -> Array[Vector3]`) with `RingPattern`, `RandomEdgePattern`, `OppositePlayerPattern`, `PointPattern`.
- `SpawnDirector` (Node): `@export var wave_table: WaveTable`, `@export var enemy_container: Node3D`,
  `@export var arena: Node` (has `info() -> ArenaInfo`), `@export var target: Node3D`, `@export var rng_seed`,
  `@export var difficulty_scale: float = 1.0`, `func start()`, `func advance(delta)`,
  `func spawn_now(event: SpawnEvent) -> Array[Node3D]`, `func alive_count() -> int`,
  `signal enemy_spawned(enemy: Node3D, event: SpawnEvent)`. Sets `target`/`arena` on spawned nodes when they
  declare those properties. Never uses groups or autoloads.
- Authored tables: `src/spawning/waves/milestone1.tres` (5-minute Devil Daggers-style escalation referencing
  `res://src/enemies/archetypes/*.tscn`), `src/spawning/waves/test_tiny.tres` (references
  `res://tests/fixtures/spawn_stub.tscn`: 3 at t=0.5 ring, 1 at t=1.5 point).

### Arena (`src/arena`)
- `arena.tscn` root `Arena` (Node3D): `@export var start_radius: float = 30.0`, `var radius: float` (setter
  updates floor mesh/shape/edge ring/shader param), `signal radius_changed(radius)`, `func info() -> ArenaInfo`
  (target_position from `@export var target: Node3D` when set), `func floor_y() -> float` (0.0).
  Children: `Floor` (MeshInstance3D), `FloorBody` (StaticBody3D, layer WORLD), `EdgeRing`,
  `ArenaShrinker` (Node: `advance(run_time)` using a `Curve`; `radius_at(run_time)` pure), `KillZone`
  (Area3D, layer KILL_ZONE, mask PLAYER|ENEMY at y ≈ -12; on `body_entered`/`area_entered` finds a
  `HealthComponent` child of the node and calls `kill(&"void")`).
- `void_environment.tres` (Environment): black background, black depth fog 10→42, ambient 0.1.

### UI (`src/ui`) and persistence (`src/persistence`)
- Screens are `Control` scenes emitting intent signals only; `GameFlow` decides what happens:
  `MainMenu`: `play_requested`, `settings_requested`, `quit_requested`; `show_leaderboard(data: LeaderboardData)`.
  `DeathScreen`: `retry_requested`, `menu_requested`, `name_submitted(name: String)`;
  `show_result(result: RunResult, data: LeaderboardData, rank: int)` (rank -1 = unranked).
  `PauseMenu`: `resume_requested`, `menu_requested` (`process_mode = PROCESS_MODE_ALWAYS`).
  `SettingsPanel`: `closed`; edits `SettingsManager` directly (ui may read/write SettingsManager? No — it
  receives values via `func bind(sensitivity: float, master: float, music: float, sfx: float)` and emits
  `sensitivity_changed(value)`, `volume_changed(bus: StringName, value: float)`).
  `HUD`: `func bind(run_state: RunState)`; shows timer (`TimeFormat.seconds`), gems, tier (`TimeFormat.roman`),
  kills, crosshair.
- `LeaderboardEntry` (Resource: name, time_survived, gems, tier_index, kills, unix_time),
  `LeaderboardData` (Resource: entries, max_entries 10; `insert(entry) -> int` rank or -1, `qualifies(time)`),
  `LeaderboardSerializer` (static: `to_config(data) -> ConfigFile`, `from_config(cfg) -> LeaderboardData`),
  `LeaderboardStore` (RefCounted: `_init(path := "user://leaderboard.cfg")`, `load() -> LeaderboardData`,
  `save(data) -> Error`).

### VFX (`src/vfx`)
- `post_process.tscn` root `PostProcess` (CanvasLayer, layer 100) → `ColorRect` with `sad_satan_post.gdshader`.
  `PostProcessController`: `func apply(profile: PostFxProfile, duration: float = 0.0)`,
  `func pulse(strength: float, duration: float)`, `func set_virtual_scale(scale: float)`; profiles in
  `src/vfx/post_process/profiles/{menu,gameplay,death}.tres`.
- `MeshFactory` / `MaterialFactory` static, cached builders; particles as scenes + `OneShotVfx`.

### Audio (`assets/audio`)
- `tools/gen_audio.sh` generates `assets/audio/sfx/*.ogg` (LFS). `assets/audio/cues/*.tres` are `AudioCue`
  resources named by use: `dagger_tick`, `shotgun_thump`, `hit`, `skull_screech`, `spawner_groan`, `gem_chime`,
  `tier_up`, `death_stinger`, `ui_click`, plus loops `amb_drone`, `menu_hum`.
  `assets/audio/default_bus_layout.tres`: Master → VHS → Music / SFX / UI.

### Game (`src/game`) and flow (`src/core/game_flow.gd`, `src/core/main.tscn`)
- `GameConfig` (Resource): wave_table, ladder, player_scene, arena_scene, gem_scene, shrink curve, post profiles.
- `Game` wires everything: connects `player.pickup_collector.gem_collected → run_state.add_gems`,
  `run_state.tier_changed → player.weapon_holder.set_tier`, `enemy_container.child_entered_tree` → enemy
  `died` → `run_state.add_kill` + `EventBus.enemy_died`, `player.died → run_state.end(cause)`;
  drives `run_state.tick`, `spawn_director.advance`, `arena_shrinker.advance` from `_physics_process`.

## Signal chain
```
InputReader → PlayerInputFrame → MovementController / WeaponHolder → DaggerWeapon → FireMode → ProjectileSpawner
DaggerProjectile → HurtboxComponent.receive_hit → HealthComponent.died → GemDrop / DeathHandler / Enemy.died
GemPickup overlaps PickupCollector → collect(gem) → gem_collected(value) → Game → RunState.add_gems → tier_changed
ContactHitbox overlaps player Hurtbox → player HealthComponent.died → Player.died(cause) → Game → RunState.end
KillZone → HealthComponent.kill(&"void") (same path)
```
