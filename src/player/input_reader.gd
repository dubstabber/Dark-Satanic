class_name InputReader
extends Node
## Samples the Input singleton once per physics tick into a PlayerInputFrame.
## "Pressed" edges are tracked here per tick because Input.is_action_just_pressed is
## unreliable inside _physics_process. Mouse motion is accumulated elsewhere
## (LookController) and handed in by the player.

var _jump_was_down: bool = false
var _secondary_was_down: bool = false


## `yaw_basis` is the player body's basis (forward = -Z); `look_delta` is the mouse
## motion gathered since the previous tick.
func read(yaw_basis: Basis, look_delta: Vector2 = Vector2.ZERO) -> PlayerInputFrame:
	var frame := PlayerInputFrame.new()
	var axis := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	frame.wish_dir = wish_from_axis(yaw_basis, axis)
	var jump_down := Input.is_action_pressed(&"jump")
	frame.jump_held = jump_down
	frame.jump_pressed = jump_down and not _jump_was_down
	_jump_was_down = jump_down
	frame.primary_held = Input.is_action_pressed(&"fire_primary")
	var secondary_down := Input.is_action_pressed(&"fire_secondary")
	frame.secondary_pressed = secondary_down and not _secondary_was_down
	_secondary_was_down = secondary_down
	frame.look_delta = look_delta
	return frame


## Forgets edge state (e.g. when the game regains focus) so nothing fires spuriously.
func reset() -> void:
	_jump_was_down = false
	_secondary_was_down = false


## Maps a 2D input axis (x = right, y = back) onto the horizontal plane of `yaw_basis`.
static func wish_from_axis(yaw_basis: Basis, axis: Vector2) -> Vector3:
	var forward := MovementSolver.flatten(-yaw_basis.z)
	var right := MovementSolver.flatten(yaw_basis.x)
	var wish := right * axis.x - forward * axis.y
	wish.y = 0.0
	return wish.limit_length(1.0)
