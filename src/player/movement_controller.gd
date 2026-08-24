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
## Coyote time and jump buffering; owned here so the solver stays stateless.
var jump_assist := JumpAssist.new()

var _impulse: Vector3 = Vector3.ZERO
var _impulse_clamp := Vector2.ZERO


func _ready() -> void:
	if body == null:
		body = get_parent() as CharacterBody3D
	if stats == null:
		stats = PlayerMovementStats.new()
	if body != null:
		was_on_floor = body.is_on_floor()


## Adds a one-off velocity change applied at the start of the next step(), after the
## solver has run so ground friction cannot eat it. `max_horizontal` / `max_up` cap the
## resulting velocity (0 = uncapped); the strictest cap queued this tick wins.
func add_impulse(impulse: Vector3, max_horizontal: float = 0.0, max_up: float = 0.0) -> void:
	if not impulse.is_finite() or impulse.is_zero_approx():
		return
	_impulse += impulse
	_impulse_clamp = Vector2(
		_tighter(_impulse_clamp.x, max_horizontal), _tighter(_impulse_clamp.y, max_up)
	)


func pending_impulse() -> Vector3:
	return _impulse


## Applies one tick of input, moves the body and emits jump / land edges.
func step(frame: PlayerInputFrame, delta: float) -> void:
	if body == null or frame == null:
		return
	var on_floor := body.is_on_floor()
	jump_assist.advance(on_floor, frame.jump_pressed, stats, delta)
	var jumping := jump_assist.wants_jump(on_floor, frame.jump_held, stats)
	if jumping:
		jump_assist.consume()
	body.velocity = MovementSolver.step_with_jump(
		body.velocity, frame.wish_dir, on_floor, jumping, stats, delta
	)
	_apply_impulse()
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


func _apply_impulse() -> void:
	if _impulse.is_zero_approx():
		return
	body.velocity = KnockbackSolver.clamp_velocity(
		body.velocity + _impulse, _impulse_clamp.x, _impulse_clamp.y
	)
	_impulse = Vector3.ZERO
	_impulse_clamp = Vector2.ZERO


## 0 means "no cap"; between two caps the smaller non-zero one wins.
static func _tighter(current: float, candidate: float) -> float:
	if candidate <= 0.0:
		return current
	return candidate if current <= 0.0 else minf(current, candidate)
