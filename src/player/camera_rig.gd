class_name CameraRig
extends Node3D
## Procedural camera motion: walk bob, landing dip and weapon kick. This node is the
## pitch pivot (LookController rotates it); the effects are applied to the child camera
## so they never fight the look rotation.

## Camera to offset; the first Camera3D child is used when unset.
@export var camera: Camera3D

@export_group("Bob")
## Vertical bob amplitude (metres) at full walk speed.
@export_range(0.0, 0.5, 0.005) var bob_amplitude: float = 0.035
## Bob cycles per metre travelled: 3.6 Hz at the 9 m/s walk. Twice `HandViewModel`'s, which
## is what keeps this bounce and the weapon's vertical lobe on the same sine.
@export_range(0.0, 5.0, 0.05) var bob_frequency: float = 0.4
## Horizontal speed that counts as "full" bob.
@export_range(0.1, 50.0, 0.1) var bob_full_speed: float = 9.0
## How fast bob fades in / out (1/s).
@export_range(0.1, 50.0, 0.1) var bob_blend_rate: float = 10.0

@export_group("Land dip")
## Metres of dip per m/s of fall speed.
@export_range(0.0, 0.2, 0.001) var dip_per_fall_speed: float = 0.012
@export_range(0.0, 1.0, 0.01) var dip_max: float = 0.25
## Spring return speed of the dip (1/s).
@export_range(0.1, 50.0, 0.1) var dip_recovery: float = 9.0

@export_group("Shake")
## Metres of positional shake at full trauma.
@export_range(0.0, 1.0, 0.005) var shake_amount: float = 0.09
## Radians of roll at full trauma.
@export_range(0.0, 0.5, 0.001) var shake_roll: float = 0.045
## Shakes per second.
@export_range(1.0, 60.0, 0.5) var shake_frequency: float = 22.0
## Trauma lost per second; the shake fades on trauma squared, so it dies off sharply.
@export_range(0.1, 10.0, 0.05) var trauma_decay: float = 2.2
@export var shake_rng_seed: int = 0

@export_group("Kick")
## Pitch recoil (radians) per unit of kick strength.
@export_range(0.0, 0.5, 0.001) var kick_pitch: float = 0.012
@export_range(0.0, 1.0, 0.001) var kick_max: float = 0.12
@export_range(0.1, 50.0, 0.1) var kick_recovery: float = 12.0

## Set by the owner each tick before advance().
var horizontal_speed: float = 0.0
var on_floor: bool = true

var _distance: float = 0.0
var _bob_weight: float = 0.0
var _dip: float = 0.0
var _kick: float = 0.0
var _rest_position: Vector3 = Vector3.ZERO
var _trauma: float = 0.0
var _shake_time: float = 0.0
var _shake_rng := RandomNumberGenerator.new()
var _shake_seed: Vector3 = Vector3.ZERO


func _ready() -> void:
	if camera == null:
		for child in get_children():
			if child is Camera3D:
				camera = child
				break
	if camera != null:
		_rest_position = camera.position
	if shake_rng_seed != 0:
		_shake_rng.seed = shake_rng_seed
	# Three decorrelated phase offsets, so the axes never shake in lockstep.
	_shake_seed = Vector3(
		_shake_rng.randf_range(0.0, 100.0),
		_shake_rng.randf_range(0.0, 100.0),
		_shake_rng.randf_range(0.0, 100.0)
	)


func advance(delta: float) -> void:
	var bobbing := on_floor and horizontal_speed > 0.05
	var target_weight := clampf(horizontal_speed / bob_full_speed, 0.0, 1.0) if bobbing else 0.0
	_bob_weight = lerpf(_bob_weight, target_weight, clampf(bob_blend_rate * delta, 0.0, 1.0))
	if bobbing:
		_distance += horizontal_speed * delta
	_dip = lerpf(_dip, 0.0, clampf(dip_recovery * delta, 0.0, 1.0))
	_kick = lerpf(_kick, 0.0, clampf(kick_recovery * delta, 0.0, 1.0))
	_trauma = maxf(_trauma - trauma_decay * delta, 0.0)
	_shake_time += delta
	if camera == null:
		return
	var bob := sin(_distance * bob_frequency * TAU) * bob_amplitude * _bob_weight
	var shake := shake_offset()
	camera.position = _rest_position + Vector3(shake.x, bob - _dip + shake.y, 0.0)
	camera.rotation.x = _kick
	camera.rotation.z = shake.z


## Hook for MovementController.landed.
func on_landed(fall_speed: float) -> void:
	_dip = minf(_dip + maxf(fall_speed, 0.0) * dip_per_fall_speed, dip_max)


## Recoil upward by `strength` (1.0 = one stream dagger).
func kick(strength: float) -> void:
	_kick = minf(_kick + maxf(strength, 0.0) * kick_pitch, kick_max)


## Adds screen shake. `amount` is trauma in 0..1; it accumulates and is capped at 1,
## and the visible shake goes as trauma squared so small knocks stay subtle and a boss
## landing on you does not.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + maxf(amount, 0.0), 0.0, 1.0)


func trauma() -> float:
	return _trauma


## Current shake as (x metres, y metres, z radians). Deterministic in time, so two
## cameras with the same seed shake identically and tests can predict it.
func shake_offset() -> Vector3:
	if _trauma <= 0.0:
		return Vector3.ZERO
	var strength := _trauma * _trauma
	var phase := _shake_time * shake_frequency
	return Vector3(
		sin((phase + _shake_seed.x) * TAU) * shake_amount * strength,
		sin((phase + _shake_seed.y) * TAU * 1.31) * shake_amount * strength,
		sin((phase + _shake_seed.z) * TAU * 0.77) * shake_roll * strength
	)


func bob_offset() -> float:
	return camera.position.y - _rest_position.y + _dip if camera != null else 0.0


func dip() -> float:
	return _dip


func kick_angle() -> float:
	return _kick
