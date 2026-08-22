# Architecture contract

This file is the agreement between the game's modules. Each folder under `src/` can be built and tested on its
own; only `src/game/game.gd` (the composition root) and `src/core/game_flow.gd` know how they fit together.
Read `CLAUDE.md` for the coding rules. When code and this file disagree, fix one of them in the same commit.

## Existing foundation (do not redesign)

- `src/core/physics_layers.gd` — `PhysicsLayers.WORLD|PLAYER|PLAYER_HURTBOX|ENEMY|ENEMY_HURTBOX|ENEMY_HITBOX|PICKUP|KILL_ZONE`
  (bits 1..128). Names are declared in `project.godot`. `ENEMY` is reserved for enemy bodies; today's enemies
  are bodiless Node3Ds whose `Hurtbox` area is what other systems see.
- `src/core/run_state.gd` — `RunState` (elapsed, gems, kills, tier_index, ladder; `tick`, `add_gems`, `add_kill`,
  `end(cause)`; signals `time_changed`, `gems_changed`, `kills_changed`, `tier_changed(tier, index)`, `ended(result)`).
- `src/core/run_result.gd` — `RunResult` (time_survived, gems, kills, tier_index, death_cause, unix_time).
- `src/core/audio_cue.gd` — `AudioCue` resource; play with `AudioManager.play(cue, position)` (null cue = no-op),
  loop as music with `AudioManager.play_music_cue(cue)` (null/empty cue stops the music).
- `src/core/autoload/*` — `EventBus` (signals only; Game emits them all, GameFlow listens to `tier_changed`,
  the rest are extension points), `RunManager` (owns the current `RunState` so `is_running()` / `last_result`
  outlive the Game; GameFlow aborts the run when the player quits to the menu), `SettingsManager`
  (mouse_sensitivity, volumes with `DEFAULT_*` constants, `changed`, `path`), `AudioManager`. Only `src/core`
  and `src/game` may reference `EventBus`/`RunManager`/`SettingsManager`.
- `src/components/*` — `HealthComponent`, `HurtboxComponent`, `WeakPointComponent`, `HitboxComponent`,
  `GemDropComponent` (`spawn_root` = where gems are parented, optional `arena` for platform clamping),
  `SpawnerComponent` (`can_spawn` veto; children placed on the floor / seeking vertically so they can reach
  the player), `DeathHandlerComponent`, `HitInfo`. See their docstrings.
- `src/weapons/resources/*` — `DaggerUpgradeTier`, `UpgradeLadder`, `default_ladder.tres` (tiers I–IV).
- `src/arena/arena_info.gd` — `ArenaInfo` (center, radius, floor_y, target_position, `clamp_to_platform`).
- `src/ui/common/time_format.gd` — `TimeFormat.seconds()`, `TimeFormat.roman()`.
- `tests/support/game_test.gd` — `GameTest` base (`make_world()`, `temp_user_path()`, autoload reset,
  SettingsManager redirected to a temp file, mouse mode / pause restored); `tests/support/e2e_helpers.gd` —
  `E2EHelpers.boot(test, config, leaderboard_path)`, `press_action(test, action)`, `release_input()`, tiny
  configs; fixtures in `tests/fixtures` (`spawn_stub.tscn` exposes `target`, `arena`, `rng_seed`, `died`).

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
  player's parent; `game.tscn` points it at `Game/ProjectileContainer` through `node_paths`, and assigning it
  after `_ready` re-runs `setup`). `func set_tier(tier)` is what `Game` calls. Recoil: `weapon.fired` →
  `signal kicked(strength)` → `CameraRig.kick` / `HandViewModel.kick` (wired in `Player._ready`).
- Player hurtbox: child `Hurtbox` (HurtboxComponent, layer PLAYER_HURTBOX) feeding `HealthComponent`
  (max_health 1). `died` re-emits the last `HitInfo.cause` (`&"enemy"`, `&"void"`).

### Weapons (`src/weapons`)
- `dagger_weapon.tscn` root `DaggerWeapon` (Node3D): `setup(aim_source: Node3D, muzzle: Node3D,
  projectile_root: Node)`, `update_fire(primary_held, secondary_pressed, delta)`, `apply_tier(tier)`,
  `signal fired(count: int, mode: StringName)`, `var target_provider: Callable` (returns `Array[Node3D]` of
  homing candidates; `Game` injects `Game.enemies`), `@export var stream_cue/shotgun_cue: AudioCue`.
- Children are `FireMode` nodes (`StreamFire`, `ShotgunFire`) driving a `ProjectileSpawner` + `ProjectilePool`.
- `DaggerProjectile` (Node3D, no physics body): swept `intersect_ray(prev, next)` each tick with
  `collide_with_areas = true`, mask `PhysicsLayers.ENEMY_HURTBOX | PhysicsLayers.WORLD`; on hitting a
  `HurtboxComponent` calls `receive_hit(HitInfo)` with `cause = &"dagger"`, `source = the weapon`. Returns to
  the pool on hit or lifetime expiry. Exposes `launch(origin, direction, params: ProjectileParams, source)`.
  Homing steers at `target.aim_position()` when the target has that method (exposed weak point), else at
  its `global_position`.

### Enemies (`src/enemies`)
- `base_enemy.tscn` root `Enemy` (Node3D) script `enemy.gd`: `@export var stats: EnemyStats`,
  `@export var target: Node3D` (player; when null falls back to group `"player"` at `_ready`),
  `@export var arena: Node` (anything with `func info() -> ArenaInfo`; optional), `@export var rng_seed`
  (the SpawnDirector seeds it from its own rng), `signal died(enemy: Enemy, last_hit: HitInfo)`,
  `func context() -> EnemyContext`, `func aim_position() -> Vector3` (first exposed WeakPoint, else root).
  Children: `HealthComponent`, `Hurtbox` (HurtboxComponent, layer ENEMY_HURTBOX), `ContactHitbox`
  (HitboxComponent, layer ENEMY_HITBOX, mask PLAYER_HURTBOX, `cause = &"enemy"`; inactive while spawning or
  rising through the floor), `Mover` (EnemyMover), `Behaviors` (Node holding `EnemyBehavior` children),
  `Visual`, `GemDrop`, `DeathHandler`.
  Archetype scenes inherit `base_enemy.tscn`: `weeper.tscn`, `mourner.tscn`, `lament.tscn`, `vesper.tscn`,
  `glutton.tscn`. Anything instantiating an enemy may set `target`, `arena` and `rng_seed` before `add_child`.
  The `died` signal is the enemy marker: `SpawnDirector.is_enemy(node)` / `Game.enemies()` count only nodes
  that have it, so gems or VFX that land in the container are never treated as enemies.
- Enemies are kinematic: `EnemyMover.advance(delta)` integrates `global_position`; `_physics_process`
  delegates. Enemies must never leave the platform (`ArenaInfo.clamp_to_platform`) or go below `floor_y + min_height`.
  Enemies spawned by other enemies (lament nests, mourner bursts) are placed on the floor / seek vertically so
  they can reach a grounded player.
- Gem drops use `GemDropComponent` with `gem_scene = res://src/pickups/gem_pickup.tscn`; the director injects
  `spawn_root = Game/GemContainer` before the enemy enters the tree.

### Pickups (`src/pickups`)
- `gem_pickup.tscn` root `GemPickup` (Area3D, `monitoring = true`, `monitorable = false`, mask PICKUP):
  `@export var stats: GemStats`, `var value: int` (from stats), `func scatter(rng: RandomNumberGenerator)`,
  `func consume()` (plays cue, frees), `func advance(delta)`; child `MagnetArea` (Area3D, mask PICKUP, bigger
  sphere) that acquires a target when a collector overlaps it. On `area_entered` of the root, if
  `area.has_method("collect")`: `area.collect(self)`. Gems stay on the platform (clamped on landing, dropped
  into the void when the shrink leaves them behind) when an `arena` is handed in.

### Spawning (`src/spawning`)
- Resources: `SpawnEvent` (time, enemy_scene, count, pattern: SpawnPattern, stagger, label),
  `WaveTable` (events, loop_from_time, loop_count_multiplier, loop_interval_multiplier, min_interval_fraction,
  max_count_multiplier, min_loop_block, max_alive; `expanded() -> Array[SpawnEvent]` sorted,
  `loop_events(k)`, `loop_block_start(k)`, `validate()`), `SpawnPattern` (@abstract, `positions(count, arena:
  ArenaInfo, rng) -> Array[Vector3]`) with `RingPattern`, `RandomEdgePattern`, `OppositePlayerPattern`,
  `PointPattern`. Loop block k is `loop_interval_multiplier^k` as long, floored at `min_interval_fraction`,
  and `loop_count_multiplier^k` as dense, capped at `max_count_multiplier`, so block starts grow without bound
  and counts stay finite.
- `SpawnDirector` (Node): `@export var wave_table: WaveTable`, `@export var enemy_container: Node3D`,
  `@export var drop_root: Node` (injected as `spawn_root` on spawned GemDropComponents), `@export var arena:
  Node` (has `info() -> ArenaInfo`), `@export var target: Node3D`, `@export var rng_seed`,
  `@export var difficulty_scale: float = 1.0`, `func start()` (push_warnings `wave_table.validate()`),
  `func advance(delta)` (appends at most one loop block per call, once it is due; schedules at most
  `max_alive - alive - pending` individuals per event), `func spawn_now(event: SpawnEvent) -> Array[Node3D]`,
  `func alive_count() -> int`, `static func is_enemy(node) -> bool`, `signal enemy_spawned(enemy: Node3D,
  event: SpawnEvent)`. Sets `target`/`arena`/`rng_seed` on spawned nodes when they declare those properties.
  Never uses groups or autoloads.
- Authored tables: `src/spawning/waves/milestone1.tres` (5-minute Devil Daggers-style escalation referencing
  `res://src/enemies/archetypes/*.tscn`, loop 1.15× count / 0.95× interval), `src/spawning/waves/test_tiny.tres`
  (references `res://tests/fixtures/spawn_stub.tscn`: 3 at t=0.5 ring, 1 at t=1.5 point).

### Arena (`src/arena`)
- `arena.tscn` root `Arena` (Node3D): `@export var start_radius: float = 30.0`, `var radius: float` (setter
  updates floor mesh/shape/edge ring/shader param), `signal radius_changed(radius)`, `func info() -> ArenaInfo`
  (target_position from `@export var target: Node3D` when set), `func floor_y() -> float` (0.0).
  Children: `Floor` (MeshInstance3D), `FloorBody` (StaticBody3D, layer WORLD), `EdgeRing`,
  `ArenaShrinker` (Node: `advance(run_time)` using a `Curve`; `radius_at(run_time)` pure; start/end time and
  end radius are authored on the node, not in GameConfig), `KillZone` (Area3D, layer KILL_ZONE, at y ≈ -12;
  finds a `HealthComponent` under the entered node — or its parent for an enemy `Hurtbox` area — and calls
  `kill(&"void")`; the mask is PLAYER | ENEMY_HURTBOX, so enemies that fall off the shrinking platform die too —
  the ENEMY body layer is unused).
- `void_environment.tres` (Environment): black background, black depth fog 10→42, ambient 0.1.

### UI (`src/ui`) and persistence (`src/persistence`)
- Screens are `Control` scenes emitting intent signals only; `GameFlow` decides what happens and connects the
  `pressed` signal of every `Button` in a screen it shows to the `ui_cue` click:
  `MainMenu`: `play_requested`, `settings_requested`, `quit_requested`; `show_leaderboard(data: LeaderboardData)`.
  `DeathScreen`: `retry_requested`, `menu_requested`, `name_submitted(name: String)`;
  `show_result(result: RunResult, data: LeaderboardData, rank: int)` (rank -1 = unranked hides the name box).
  `PauseMenu`: `resume_requested`, `menu_requested` (`process_mode = PROCESS_MODE_ALWAYS`).
  `SettingsPanel`: never touches the autoload — it receives values via `func bind(sensitivity: float, master:
  float, music: float, sfx: float)` and emits `sensitivity_changed(value)`, `volume_changed(bus: StringName,
  value: float)`, `closed`.
  `HUD`: `func bind(run_state: RunState)`; shows timer (`TimeFormat.seconds`), gems, tier (`TimeFormat.roman`),
  kills, `Crosshair` (theme font sizes; only the big timer/tier labels override them).
- `LeaderboardEntry` (Resource: name, time_survived, gems, tier_index, kills, unix_time; `DEFAULT_NAME`,
  `make(...)`, `from_result(result)`), `LeaderboardData` (Resource: entries, max_entries 10; `insert(entry) ->
  int` rank or -1, `qualifies(time)`), `LeaderboardSerializer` (static: `to_config(data) -> ConfigFile`,
  `from_config(cfg) -> LeaderboardData`), `LeaderboardStore` (RefCounted: `_init(path :=
  "user://leaderboard.cfg")`, `load() -> LeaderboardData`, `save(data) -> Error`).

### VFX (`src/vfx`)
- `post_process.tscn` root `PostProcess` (CanvasLayer, layer 100) → `ColorRect` with `sad_satan_post.gdshader`.
  `PostProcessController`: `func apply(profile: PostFxProfile, duration: float = 0.0)`,
  `func pulse(strength: float, duration: float)`, `func set_virtual_scale(scale: float)`,
  `get_parameter(name)`; profiles in `src/vfx/post_process/profiles/{menu,gameplay,death}.tres`.
- `src/vfx/particles/*` + `OneShotVfx` are wired: `death_burst.tscn` is the `DeathHandler.death_vfx` of
  `base_enemy.tscn`, `hit_spark.tscn` the default `DaggerProjectile.hit_vfx`, `gem_sparkle.tscn` the
  `GemStats.collect_vfx`. `MeshFactory` / `MaterialFactory` (static, cached builders) are a tested toolkit for
  future procedural meshes (the archetype scenes still use primitive meshes).

### Audio (`assets/audio`)
- `tools/gen_audio.sh` generates `assets/audio/sfx/*.ogg` (LFS). `assets/audio/cues/*.tres` are `AudioCue`
  resources named by use: `dagger_tick`, `shotgun_thump`, `hit`, `skull_screech`, `spawner_groan`, `gem_chime`,
  `tier_up`, `death_stinger`, `ui_click` (GameFlow's `ui_cue`), plus the music loops `amb_drone` (game) and
  `menu_hum` (menu), both on the Music bus and played through `AudioManager.play_music_cue`.
  `assets/audio/default_bus_layout.tres`: Master → VHS → Music / SFX / UI.

### Game (`src/game`) and flow (`src/core/game_flow.gd`, `src/core/main.tscn`)
- `GameConfig` (Resource): `wave_table`, `ladder`, `shrink_curve`, `difficulty_scale`, `rng_seed` (seeds the
  SpawnDirector and, through it, every spawned enemy; dagger spread and gem scatter stay unseeded).
  Player, arena and gem scenes are baked into `game.tscn` / `base_enemy.tscn`; post-process profiles, music
  cues and the fade/pulse tunables live on `GameFlow` exports in `main.tscn`.
- `game.tscn`: `Arena`, `Player` (editable; `WeaponHolder.projectile_root → ProjectileContainer`),
  `EnemyContainer`, `GemContainer`, `ProjectileContainer`, `SpawnDirector` (container/drop_root/arena/target
  wired by `node_paths`), `PlayerLight`, `HudLayer/HUD`.
- `Game` wires everything: connects `player.pickup_collector.gem_collected → run_state.add_gems`,
  `run_state.tier_changed → player.weapon_holder.set_tier` + `EventBus.tier_changed`,
  `enemy_container.child_entered_tree` → enemy `died` → `run_state.add_kill` + `EventBus.enemy_died`,
  `player.died → run_state.end(cause)` → `run_ended`; `enemies()` is the homing target provider; drives
  `run_state.tick`, `spawn_director.advance`, `arena_shrinker.advance` from `_physics_process`.
  `setup(run_state)` before `add_child` injects a state (tests); otherwise `RunManager.begin(ladder)`.
- `Main` (`main.gd`): `leaderboard_path`, `autostart` (from `--autostart`); `GameFlow`
  (`process_mode = ALWAYS` so ESC resumes a paused tree): MENU → PLAYING ⇄ PAUSED → DEAD; `show_menu()`
  aborts a live run via `RunManager.finish(&"aborted")`; `_on_run_ended` builds `LeaderboardEntry.from_result`,
  saves, shows `DeathScreen`, plays `death_cue`, stops music; tier-ups play `tier_up_cue` and pulse only while
  PLAYING.

## Signal chain
```
InputReader → PlayerInputFrame → MovementController / WeaponHolder → DaggerWeapon → FireMode → ProjectileSpawner
DaggerProjectile → HurtboxComponent.receive_hit → HealthComponent.died → GemDrop (→ GemContainer) / DeathHandler / Enemy.died
GemPickup overlaps PickupCollector → collect(gem) → gem_collected(value) → Game → RunState.add_gems → tier_changed
ContactHitbox overlaps player Hurtbox → player HealthComponent.died → Player.died(cause) → Game → RunState.end
KillZone → HealthComponent.kill(&"void") (same path) → Game.run_ended → GameFlow DEAD
```
