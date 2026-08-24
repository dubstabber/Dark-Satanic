class_name DaggerWeapon
extends Node3D
## The player's dagger: a stream on primary and a shotgun on secondary, both
## launching pooled DaggerProjectiles from the muzzle along the aim direction.

signal fired(count: int, mode: StringName)

const DEFAULT_LADDER := preload("res://src/weapons/resources/default_ladder.tres")
## What the crosshair ray may converge on: level geometry and enemies.
const AIM_MASK := PhysicsLayers.WORLD | PhysicsLayers.ENEMY_HURTBOX

## Ladder whose first tier is applied at _ready when nothing was applied yet.
@export var ladder: UpgradeLadder = DEFAULT_LADDER
@export var stream_cue: AudioCue
@export var shotgun_cue: AudioCue

@export_group("Aim")
## Daggers leave the muzzle aimed at whatever the crosshair is on, so an offset
## muzzle still shoots through the reticle. This is how far the aim reaches when
## the crosshair ray finds nothing.
@export_range(1.0, 200.0, 0.5) var convergence_distance: float = 45.0
## Aim never converges nearer than this; a wall against the face would otherwise
## swing every shot sideways by the whole muzzle offset.
@export_range(0.1, 20.0, 0.1) var min_convergence_distance: float = 1.5

## Callable() -> Array[Node3D] of homing candidates; forwarded to the spawner.
var target_provider: Callable = Callable():
	set(value):
		target_provider = value
		_discover()
		if _spawner != null:
			_spawner.target_provider = value
var tier: DaggerUpgradeTier

var _aim_source: Node3D
var _muzzle: Node3D
var _spawner: ProjectileSpawner
var _stream: StreamFire
var _shotgun: ShotgunFire


func _ready() -> void:
	_discover()
	if _spawner != null:
		_spawner.source = self
	if tier == null and ladder != null:
		apply_tier(ladder.tier(0))


func setup(aim_source: Node3D, muzzle: Node3D, projectile_root: Node) -> void:
	_aim_source = aim_source
	_muzzle = muzzle
	_discover()
	if _spawner != null:
		_spawner.source = self
		var pool := _spawner.ensure_pool()
		if projectile_root != null and pool != null:
			pool.container = projectile_root


func apply_tier(p_tier: DaggerUpgradeTier) -> void:
	if p_tier == null:
		return
	tier = p_tier
	_discover()
	if _stream != null:
		_stream.configure(p_tier)
	if _shotgun != null:
		_shotgun.configure(p_tier)
	if _spawner != null and _spawner.ensure_pool() != null:
		_spawner.pool.ensure_size(peak_live_projectiles(p_tier))


## Upper bound on daggers in flight at once for a tier: a full lifetime of stream
## shots plus every shotgun volley that can still be alive.
static func peak_live_projectiles(p_tier: DaggerUpgradeTier) -> int:
	if p_tier == null:
		return 0
	var stream := ceili(p_tier.stream_rate * p_tier.stream_daggers_per_shot * p_tier.projectile_lifetime)
	var volleys := ceili(p_tier.projectile_lifetime / maxf(p_tier.shotgun_cooldown, 0.001))
	return stream + p_tier.shotgun_pellets * volleys


## Returns the number of projectiles launched this tick.
func update_fire(primary_held: bool, secondary_pressed: bool, delta: float) -> int:
	_discover()
	var origin := muzzle_position()
	# The convergence ray only matters on a tick that can launch something; idle
	# ticks still need an origin/direction for the modes' bookkeeping.
	var direction := aim_direction() if primary_held or secondary_pressed else forward()
	var total := 0
	if _stream != null:
		var count := _stream.update(primary_held, false, origin, direction, delta)
		if count > 0:
			_report(count, &"stream", stream_cue if stream_cue != null else _stream.cue, origin)
			total += count
	if _shotgun != null:
		var count := _shotgun.update(secondary_pressed, secondary_pressed, origin, direction, delta)
		if count > 0:
			_report(count, &"shotgun", shotgun_cue if shotgun_cue != null else _shotgun.cue, origin)
			total += count
	return total


func muzzle_position() -> Vector3:
	if _muzzle != null:
		return _muzzle.global_position
	if _aim_source != null:
		return _aim_source.global_position
	return global_position


## Where the crosshair points, straight out of the aim source.
func forward() -> Vector3:
	var basis := _aim_source.global_basis if _aim_source != null else global_basis
	return -basis.z.normalized()


## Direction a dagger leaves the muzzle on: from the muzzle to the point the
## crosshair is on, so an offset muzzle still puts its shots under the reticle.
func aim_direction() -> Vector3:
	var straight := forward()
	if _aim_source == null or _muzzle == null:
		return straight
	var origin := _aim_source.global_position
	var point := AimSolver.convergence_point(
		origin,
		straight,
		crosshair_distance(origin, straight),
		convergence_distance,
		min_convergence_distance
	)
	return AimSolver.direction(muzzle_position(), point, straight)


## Distance from `origin` to the first thing under the crosshair, or -1 when the
## ray reaches `convergence_distance` without hitting anything.
func crosshair_distance(origin: Vector3, direction: Vector3) -> float:
	if not is_inside_tree():
		return -1.0
	var world := get_world_3d()
	if world == null:
		return -1.0
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + direction * convergence_distance, AIM_MASK
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result := world.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return -1.0
	return origin.distance_to(result["position"])


func spawner() -> ProjectileSpawner:
	_discover()
	return _spawner


func stream_mode() -> StreamFire:
	_discover()
	return _stream


func shotgun_mode() -> ShotgunFire:
	_discover()
	return _shotgun


func _report(count: int, mode: StringName, cue: AudioCue, origin: Vector3) -> void:
	fired.emit(count, mode)
	if cue != null:
		AudioManager.play(cue, origin)


func _discover() -> void:
	for child in get_children():
		if child is ProjectileSpawner and _spawner == null:
			_spawner = child
		elif child is StreamFire and _stream == null:
			_stream = child
		elif child is ShotgunFire and _shotgun == null:
			_shotgun = child
	if _spawner != null:
		_spawner.target_provider = target_provider
		for mode in [_stream, _shotgun]:
			if mode != null and mode.spawner == null:
				mode.spawner = _spawner
