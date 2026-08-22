class_name MovementController
extends Node
## Drives a CharacterBody3D with MovementSolver each physics tick and reports
## jump / landing edges. Owns no timing of its own; the player calls step().

signal jumped
## Emitted on touching the floor; `fall_speed` is the downward speed (positive) before impact.
signal landed(fall_speed: float)

## Body to move; the parent is used when unset.
@export var body: CharacterBody3D
@export var stats: PlayerMovementStats

var was_on_floor: bool = false


func _ready() -> void:
	if body == null:
		body = get_parent() as CharacterBody3D
	if stats == null:
		stats = PlayerMovementStats.new()
	if body != null:
		was_on_floor = body.is_on_floor()


## Applies one tick of input, moves the body and emits jump / land edges.
func step(frame: PlayerInputFrame, delta: float) -> void:
	if body == null or frame == null:
		return
	var on_floor := body.is_on_floor()
	var jumping := MovementSolver.wants_jump(on_floor, frame.jump_pressed, frame.jump_held, stats)
	body.velocity = MovementSolver.step(
		body.velocity, frame.wish_dir, on_floor, frame.jump_pressed, frame.jump_held, stats, delta
	)
	var fall_speed := maxf(-body.velocity.y, 0.0)
	body.move_and_slide()
	var now_on_floor := body.is_on_floor()
	if jumping:
		jumped.emit()
	elif now_on_floor and not was_on_floor:
		landed.emit(fall_speed)
	was_on_floor = now_on_floor


func horizontal_speed() -> float:
	return MovementSolver.horizontal_speed(body.velocity) if body != null else 0.0


func is_on_floor() -> bool:
	return body != null and body.is_on_floor()
