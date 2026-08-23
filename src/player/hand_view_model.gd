class_name HandViewModel
extends Node3D
## First-person hand: the view-model mesh that sways with the mouse and kicks
## back when firing. The `Muzzle` Marker3D child is where daggers leave from.
## The mesh and material live in player.tscn so a designer can swap them.

## Metres of sway per pixel of look delta.
@export_range(0.0, 0.01, 0.0001) var sway_per_pixel: float = 0.0006
@export_range(0.0, 0.2, 0.001) var sway_max: float = 0.04
## Spring return speed of the sway (1/s).
@export_range(0.1, 50.0, 0.1) var sway_recovery: float = 10.0

@export_group("Kick")
## Metres pushed back (+Z, towards the camera) per unit of kick strength.
@export_range(0.0, 0.5, 0.001) var kick_distance: float = 0.03
@export_range(0.0, 1.0, 0.001) var kick_max: float = 0.15
@export_range(0.01, 2.0, 0.01) var kick_return_time: float = 0.12

var _rest_position: Vector3 = Vector3.ZERO
var _sway: Vector2 = Vector2.ZERO
var _kick: float = 0.0
var _kick_tween: Tween


func _ready() -> void:
	_rest_position = position


func muzzle() -> Node3D:
	return get_node_or_null("Muzzle") as Node3D


## Feed the tick's mouse motion; the hands lag opposite to it.
func apply_look_delta(delta: Vector2) -> void:
	_sway = (_sway - delta * sway_per_pixel).limit_length(sway_max)


func advance(delta: float) -> void:
	_sway = _sway.lerp(Vector2.ZERO, clampf(sway_recovery * delta, 0.0, 1.0))
	position = _rest_position + Vector3(_sway.x, _sway.y, _kick)


## Pushes the hands back; they tween home over `kick_return_time`.
func kick(strength: float) -> void:
	_kick = minf(_kick + maxf(strength, 0.0) * kick_distance, kick_max)
	if _kick_tween != null and _kick_tween.is_valid():
		_kick_tween.kill()
	if not is_inside_tree():
		return
	_kick_tween = create_tween()
	_kick_tween.tween_property(self, "_kick", 0.0, kick_return_time).set_ease(Tween.EASE_OUT)


func kick_offset() -> float:
	return _kick


func sway() -> Vector2:
	return _sway
