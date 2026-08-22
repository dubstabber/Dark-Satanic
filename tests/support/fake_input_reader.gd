class_name FakeInputReader
extends InputReader
## Scripted input for player tests: a queue of frames consumed one per read();
## once empty the last frame repeats (an idle frame when nothing was ever queued).

var frames: Array[PlayerInputFrame] = []
var last: PlayerInputFrame = PlayerInputFrame.new()
var reads: int = 0
var last_yaw_basis: Basis = Basis.IDENTITY
var last_look_delta: Vector2 = Vector2.ZERO


func read(yaw_basis: Basis, look_delta: Vector2 = Vector2.ZERO) -> PlayerInputFrame:
	reads += 1
	last_yaw_basis = yaw_basis
	last_look_delta = look_delta
	if not frames.is_empty():
		last = frames.pop_front()
	# Edges are one-tick events: a repeated frame must not re-press them.
	var frame := last.copy()
	if frames.is_empty():
		last = last.copy()
		last.jump_pressed = false
		last.secondary_pressed = false
		last.look_delta = Vector2.ZERO
	return frame


func push(frame: PlayerInputFrame) -> void:
	frames.append(frame)


func push_repeated(frame: PlayerInputFrame, count: int) -> void:
	for i in count:
		frames.append(frame.copy())


func clear() -> void:
	frames.clear()
	last = PlayerInputFrame.new()


## Convenience builder.
static func frame(
	wish_dir: Vector3 = Vector3.ZERO,
	jump_held: bool = false,
	jump_pressed: bool = false,
	primary_held: bool = false,
	secondary_pressed: bool = false,
	look_delta: Vector2 = Vector2.ZERO
) -> PlayerInputFrame:
	var f := PlayerInputFrame.new()
	f.wish_dir = wish_dir
	f.jump_held = jump_held
	f.jump_pressed = jump_pressed
	f.primary_held = primary_held
	f.secondary_pressed = secondary_pressed
	f.look_delta = look_delta
	return f
