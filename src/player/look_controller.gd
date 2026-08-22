class_name LookController
extends Node
## Mouse look: yaw on one node (the body), pitch on another (the camera rig).
## Raw mouse motion is gathered in _unhandled_input and handed out with take_pending()
## so the player can fold it into its PlayerInputFrame and apply it once per tick.

## Rotated around Y; the parent is used when unset.
@export var yaw_target: Node3D
## Rotated around X (clamped to stats.pitch_limit_deg).
@export var pitch_target: Node3D
## Source of `pitch_limit_deg`; a default resource is used when unset.
@export var stats: PlayerMovementStats

## Radians per pixel of mouse motion (set by Player.setup).
var sensitivity: float = 0.002

var _pending: Vector2 = Vector2.ZERO


func _ready() -> void:
	if yaw_target == null:
		yaw_target = get_parent() as Node3D
	if stats == null:
		stats = PlayerMovementStats.new()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_pending += (event as InputEventMouseMotion).screen_relative


## Mouse motion (pixels) gathered since the last call; clears the accumulator.
func take_pending() -> Vector2:
	var delta := _pending
	_pending = Vector2.ZERO
	return delta


## Rotates by a pixel delta scaled by `sensitivity` (x → yaw, y → pitch).
func apply_look(delta: Vector2) -> void:
	if yaw_target != null:
		yaw_target.rotation.y -= delta.x * sensitivity
	if pitch_target != null:
		pitch_target.rotation.x = clampf(
			pitch_target.rotation.x - delta.y * sensitivity, -pitch_limit(), pitch_limit()
		)


## Sets yaw and pitch so the pitch target's -Z axis points at `point`.
func look_at_point(point: Vector3) -> void:
	var origin := pitch_target.global_position if pitch_target != null else yaw_target.global_position
	var dir := point - origin
	if dir.length_squared() < MovementSolver.EPSILON:
		return
	var flat_length := Vector2(dir.x, dir.z).length()
	if yaw_target != null and flat_length > MovementSolver.EPSILON:
		yaw_target.rotation.y = atan2(-dir.x, -dir.z)
	if pitch_target != null:
		pitch_target.rotation.x = clampf(atan2(dir.y, flat_length), -pitch_limit(), pitch_limit())


func yaw() -> float:
	return yaw_target.rotation.y if yaw_target != null else 0.0


func pitch() -> float:
	return pitch_target.rotation.x if pitch_target != null else 0.0


func pitch_limit() -> float:
	return deg_to_rad(stats.pitch_limit_deg if stats != null else 89.0)
