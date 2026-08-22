class_name PlayerInputFrame
extends RefCounted
## Everything the player read from input during one physics tick.

## World-space movement wish (y = 0), length 0..1.
var wish_dir: Vector3 = Vector3.ZERO
## Jump went down this tick.
var jump_pressed: bool = false
## Jump is down (auto bunny hop).
var jump_held: bool = false
var primary_held: bool = false
## Secondary fire went down this tick.
var secondary_pressed: bool = false
## Mouse motion accumulated since the previous tick, in pixels.
var look_delta: Vector2 = Vector2.ZERO


static func idle() -> PlayerInputFrame:
	return PlayerInputFrame.new()


func is_idle() -> bool:
	return (
		wish_dir.is_zero_approx()
		and not jump_pressed
		and not jump_held
		and not primary_held
		and not secondary_pressed
		and look_delta.is_zero_approx()
	)


func copy() -> PlayerInputFrame:
	var frame := PlayerInputFrame.new()
	frame.wish_dir = wish_dir
	frame.jump_pressed = jump_pressed
	frame.jump_held = jump_held
	frame.primary_held = primary_held
	frame.secondary_pressed = secondary_pressed
	frame.look_delta = look_delta
	return frame
