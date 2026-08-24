class_name RangedAttackComponent
extends Node
## Fires a projectile at the target on a cycle, with a visible wind-up first.
##
## The wind-up is not decoration: an unannounced ranged attack in an arena this dark is
## unfair, so `windup_started` fires `windup` seconds before the shot and drives whatever
## tell the archetype wears. Time is driven through advance(delta).

signal windup_started
signal fired(shards: Array[Node3D])

@export var projectile_scene: PackedScene
## Position the shot leaves from; the parent is used when unset.
@export var muzzle: Node3D
## What to shoot at; inherited from the enemy by SpawnDirector/SpawnerComponent wiring.
@export var target: Node3D
## Node the projectiles are parented to. Never the enemy container: Game announces every
## child entering that one as a spawned enemy, and a shard is not an arrival.
@export var projectile_root: Node

@export_group("Timing")
@export_range(0.1, 30.0, 0.1) var interval: float = 3.2
@export_range(0.0, 30.0, 0.1) var initial_delay: float = 2.0
## Seconds between the tell and the shot.
@export_range(0.0, 5.0, 0.05) var windup: float = 0.9
@export var enabled: bool = true
## Run on the engine clock instead of waiting for advance() calls.
@export var autonomous: bool = false

@export_group("Aim")
## Only fires when the target is at least this far away; point blank it just rams you.
@export_range(0.0, 100.0, 0.5) var min_range: float = 6.0
@export_range(1.0, 200.0, 1.0) var max_range: float = 45.0
## Seconds of target movement to lead by, so standing still is punished.
@export_range(0.0, 2.0, 0.01) var lead_time: float = 0.35
@export_range(1, 8) var shards_per_shot: int = 1
## Cone half-angle for a multi-shard volley.
@export_range(0.0, 45.0, 0.5) var spread_deg: float = 7.0
@export var fire_cue: AudioCue
@export var rng_seed: int = 0

var rng := RandomNumberGenerator.new()
var shots: int = 0

var _elapsed: float = 0.0
var _next_shot: float = 0.0
var _winding: bool = false
var _target_position: Vector3 = Vector3.ZERO
var _target_velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	if rng_seed != 0:
		rng.seed = rng_seed
	if muzzle == null:
		muzzle = get_parent() as Node3D
	if target == null:
		target = _inherited_target()
	_next_shot = initial_delay


func _physics_process(delta: float) -> void:
	if autonomous:
		advance(delta)


func is_winding_up() -> bool:
	return _winding


## Seconds until the next shot leaves (negative when disabled).
func time_to_shot() -> float:
	return _next_shot - _elapsed if enabled else -1.0


func advance(delta: float) -> void:
	if not enabled or delta <= 0.0:
		return
	_elapsed += delta
	_track_target(delta)
	if not _winding and _elapsed >= _next_shot - windup and in_range():
		_winding = true
		windup_started.emit()
	if _elapsed < _next_shot:
		return
	_next_shot = _elapsed + interval
	if _winding and in_range():
		_shoot()
	_winding = false


func in_range() -> bool:
	if target == null or not is_instance_valid(target) or muzzle == null:
		return false
	var distance := muzzle.global_position.distance_to(target.global_position)
	return distance >= min_range and distance <= max_range


## Where the shot is aimed: the target's position plus `lead_time` of its own motion.
func aim_point() -> Vector3:
	return _target_position + _target_velocity * lead_time


func _track_target(delta: float) -> void:
	if target == null or not is_instance_valid(target) or delta <= 0.0:
		return
	var now := target.global_position
	_target_velocity = (now - _target_position) / delta if _elapsed > delta else Vector3.ZERO
	_target_position = now


func _shoot() -> void:
	var root := projectile_root if projectile_root != null else get_parent().get_parent()
	if projectile_scene == null or root == null or muzzle == null:
		return
	var origin := muzzle.global_position
	var forward := (aim_point() - origin)
	if forward.length_squared() < 0.000001:
		return
	forward = forward.normalized()
	var launched: Array[Node3D] = []
	for i in shards_per_shot:
		var shard := projectile_scene.instantiate() as Node3D
		if shard == null:
			continue
		root.add_child(shard)
		var direction := ProjectileSpawner.cone_direction(forward, spread_deg, rng)
		if shard.has_method("launch"):
			shard.call("launch", origin, direction, target)
		else:
			shard.global_position = origin
		launched.append(shard)
	if launched.is_empty():
		return
	shots += 1
	AudioManager.play(fire_cue, origin)
	fired.emit(launched)


## Falls back to the owning enemy's target, so a Cantor released by a nest (which only
## copies properties onto the root) still knows what to sing at.
func _inherited_target() -> Node3D:
	var parent := get_parent()
	if parent != null and "target" in parent:
		return parent.get("target") as Node3D
	return null
