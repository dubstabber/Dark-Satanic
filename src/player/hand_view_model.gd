class_name HandViewModel
extends Node3D
## First-person hand: the view-model that sways with the mouse, bobs with the walk
## cycle, leans out of a strafe and kicks back when firing. The `Muzzle` Marker3D
## child is where daggers leave from. The mesh and material live in player.tscn so
## a designer can swap them.
##
## Every effect is an offset from the rest transform recorded at _ready, summed once
## per advance() — nothing writes `position` or `rotation` directly, so effects never
## fight each other. The landing dip comes for free: this node hangs off the camera
## the CameraRig already dips.

## Body-space velocity (x = right, z = back), set by the owner each tick before advance().
var local_velocity: Vector3 = Vector3.ZERO
var on_floor: bool = true

@export_group("Sway")
## Metres of sway per pixel of look delta.
@export_range(0.0, 0.01, 0.0001) var sway_per_pixel: float = 0.0006
@export_range(0.0, 0.2, 0.001) var sway_max: float = 0.04
## Spring return speed of the sway (1/s).
@export_range(0.1, 50.0, 0.1) var sway_recovery: float = 10.0
## Radians the wrist rotates per metre of positional sway, so the hand turns into
## the drag instead of sliding flatly across the screen.
@export_range(0.0, 20.0, 0.1) var sway_tilt: float = 5.0

@export_group("Bob")
## Metres of horizontal bob at full walk speed; the vertical figure-eight is half this.
@export_range(0.0, 0.2, 0.001) var bob_amount: float = 0.024
## Bob cycles per metre travelled (one figure-eight per stride pair).
@export_range(0.0, 5.0, 0.05) var bob_frequency: float = 0.45
## Horizontal speed that counts as "full" bob.
@export_range(0.1, 50.0, 0.1) var bob_full_speed: float = 9.0
## How fast bob fades in / out (1/s).
@export_range(0.1, 50.0, 0.1) var bob_blend_rate: float = 8.0

@export_group("Idle sway")
## Metres of slow breathing drift while standing still; fades out as the bob fades in.
@export_range(0.0, 0.05, 0.0005) var idle_amount: float = 0.005
@export_range(0.0, 5.0, 0.01) var idle_frequency: float = 0.5

@export_group("Lean")
## Metres the hands trail sideways per m/s of strafing.
@export_range(0.0, 0.05, 0.0005) var lean_per_speed: float = 0.005
@export_range(0.0, 0.3, 0.001) var lean_max: float = 0.045
## Radians of roll per metre of lateral lean.
@export_range(0.0, 20.0, 0.05) var lean_roll: float = 3.0
## How fast the lean follows the strafe (1/s).
@export_range(0.1, 50.0, 0.1) var lean_rate: float = 8.0

@export_group("Kick")
## Metres pushed back (+Z, towards the camera) per unit of kick strength.
@export_range(0.0, 0.5, 0.001) var kick_distance: float = 0.03
@export_range(0.0, 1.0, 0.001) var kick_max: float = 0.15
@export_range(0.01, 2.0, 0.01) var kick_return_time: float = 0.12

var _rest_position: Vector3 = Vector3.ZERO
var _rest_rotation: Vector3 = Vector3.ZERO
var _sway: Vector2 = Vector2.ZERO
var _kick: float = 0.0
var _kick_tween: Tween
var _distance: float = 0.0
var _bob_weight: float = 0.0
var _idle_time: float = 0.0
var _lean: float = 0.0


func _ready() -> void:
	_rest_position = position
	_rest_rotation = rotation


func muzzle() -> Node3D:
	return get_node_or_null("Muzzle") as Node3D


## Feed the tick's mouse motion; the hands lag opposite to it.
func apply_look_delta(delta: Vector2) -> void:
	_sway = (_sway - delta * sway_per_pixel).limit_length(sway_max)


## Feed the tick's motion (body-space velocity and floor state) before advance().
func set_motion(p_local_velocity: Vector3, p_on_floor: bool) -> void:
	local_velocity = p_local_velocity
	on_floor = p_on_floor


func advance(delta: float) -> void:
	_sway = _sway.lerp(Vector2.ZERO, clampf(sway_recovery * delta, 0.0, 1.0))
	_advance_bob(delta)
	_advance_lean(delta)
	_idle_time += delta
	position = _rest_position + offset()
	rotation = _rest_rotation + tilt()


## Pushes the hands back; they tween home over `kick_return_time`.
func kick(strength: float) -> void:
	_kick = minf(_kick + maxf(strength, 0.0) * kick_distance, kick_max)
	if _kick_tween != null and _kick_tween.is_valid():
		_kick_tween.kill()
	if not is_inside_tree():
		return
	_kick_tween = create_tween()
	_kick_tween.tween_property(self, "_kick", 0.0, kick_return_time).set_ease(Tween.EASE_OUT)


## Total offset from the rest position: mouse sway, walk bob, idle drift, strafe
## lean and the firing kick.
func offset() -> Vector3:
	var wobble := bob() + idle_drift()
	return Vector3(_sway.x + wobble.x + _lean, _sway.y + wobble.y, _kick)


## Total rotation offset: the wrist turning into the mouse drag plus the strafe roll.
func tilt() -> Vector3:
	return Vector3(-_sway.y * sway_tilt, _sway.x * sway_tilt, -_lean * lean_roll)


## Lemniscate ("figure eight") traced once per stride pair, scaled by the bob weight.
func bob() -> Vector2:
	var phase := _distance * bob_frequency * TAU
	return Vector2(sin(phase), sin(phase * 2.0) * 0.5) * bob_amount * _bob_weight


## Slow breathing wander, only while the walk bob is not driving the hands.
func idle_drift() -> Vector2:
	var phase := _idle_time * idle_frequency * TAU
	return Vector2(sin(phase * 0.7), sin(phase)) * idle_amount * (1.0 - _bob_weight)


func speed() -> float:
	return Vector2(local_velocity.x, local_velocity.z).length()


func bob_weight() -> float:
	return _bob_weight


func lean() -> float:
	return _lean


func kick_offset() -> float:
	return _kick


func sway() -> Vector2:
	return _sway


func _advance_bob(delta: float) -> void:
	var walking := on_floor and speed() > 0.05
	var target: float = clampf(speed() / bob_full_speed, 0.0, 1.0) if walking else 0.0
	_bob_weight = lerpf(_bob_weight, target, clampf(bob_blend_rate * delta, 0.0, 1.0))
	if walking:
		_distance += speed() * delta


func _advance_lean(delta: float) -> void:
	var target := clampf(-local_velocity.x * lean_per_speed, -lean_max, lean_max)
	_lean = lerpf(_lean, target, clampf(lean_rate * delta, 0.0, 1.0))
