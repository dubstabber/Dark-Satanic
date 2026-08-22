class_name DaggerWeapon
extends Node3D
## The player's dagger: a stream on primary and a shotgun on secondary, both
## launching pooled DaggerProjectiles from the muzzle along the aim direction.

signal fired(count: int, mode: StringName)

const DEFAULT_LADDER := preload("res://src/weapons/resources/default_ladder.tres")

## Ladder whose first tier is applied at _ready when nothing was applied yet.
@export var ladder: UpgradeLadder = DEFAULT_LADDER
@export var stream_cue: AudioCue
@export var shotgun_cue: AudioCue

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


## Returns the number of projectiles launched this tick.
func update_fire(primary_held: bool, secondary_pressed: bool, delta: float) -> int:
	_discover()
	var origin := muzzle_position()
	var direction := aim_direction()
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


func aim_direction() -> Vector3:
	var basis := _aim_source.global_basis if _aim_source != null else global_basis
	return -basis.z.normalized()


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
