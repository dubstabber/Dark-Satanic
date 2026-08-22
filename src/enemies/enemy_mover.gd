class_name EnemyMover
extends Node
## Blends the EnemyBehavior children of `behaviors_root` into one desired velocity, eases the
## actual velocity toward it and integrates the body. Keeps the body on the platform and above
## the floor, and faces it along its horizontal motion.

## Node moved; when null the parent is used.
@export var body: Node3D
## Node whose EnemyBehavior children steer; when null the sibling named "Behaviors" is used.
@export var behaviors_root: Node
@export_range(0.0, 5.0, 0.05) var platform_margin: float = 0.5
@export var face_velocity: bool = true
## Grounded enemies left above `floor_y + min_height + ground_slack` sink at this speed (m/s).
@export_range(0.0, 100.0, 0.5) var fall_speed: float = 12.0
## Headroom a grounded enemy may bob up into before it is pulled back down.
@export_range(0.0, 5.0, 0.05) var ground_slack: float = 0.5

var velocity: Vector3 = Vector3.ZERO
var desired_velocity: Vector3 = Vector3.ZERO
var _floor_free: bool = false


func _ready() -> void:
	if body == null:
		body = get_parent() as Node3D
	if behaviors_root == null and get_parent() != null:
		behaviors_root = get_parent().get_node_or_null("Behaviors")


## True while an exclusive behaviour is letting the body sit below the floor (e.g. a rising nest).
func is_rising() -> bool:
	return _floor_free


func behaviors() -> Array[EnemyBehavior]:
	var result: Array[EnemyBehavior] = []
	if behaviors_root == null:
		return result
	for child in behaviors_root.get_children():
		if child is EnemyBehavior and child.enabled:
			result.append(child)
	return result


## Desired velocity for this tick: the first exclusive behaviour wins, otherwise a weighted sum.
func blend(ctx: EnemyContext, delta: float) -> Vector3:
	_floor_free = false
	var active := behaviors()
	for behavior in active:
		if behavior.is_exclusive():
			_floor_free = behavior.ignores_floor()
			return behavior.steer(ctx, delta)
	var sum := Vector3.ZERO
	for behavior in active:
		sum += behavior.steer(ctx, delta) * behavior.weight
	return sum


func advance(ctx: EnemyContext, delta: float) -> void:
	if body == null or delta <= 0.0:
		return
	var max_speed: float = ctx.stats.move_speed if ctx.stats != null else 5.0
	var acceleration: float = ctx.stats.acceleration if ctx.stats != null else 40.0
	var min_height: float = ctx.stats.min_height if ctx.stats != null else 0.0
	var grounded: bool = ctx.stats.grounded if ctx.stats != null else false
	desired_velocity = blend(ctx, delta).limit_length(max_speed)
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)
	var next := body.global_position + velocity * delta
	var info := ctx.arena_info
	if info != null:
		next = info.clamp_to_platform(next, platform_margin)
		if not _floor_free:
			next.y = maxf(next.y, info.floor_y + min_height)
			if grounded:
				next.y = _sink(next.y, info.floor_y + min_height + ground_slack, delta)
	body.global_position = next
	if face_velocity:
		_face(velocity)


## Pulls a height above `ceiling` down toward it at `fall_speed` (never below it).
func _sink(y: float, ceiling: float, delta: float) -> float:
	if y <= ceiling:
		return y
	return maxf(ceiling, y - fall_speed * delta)


func _face(motion: Vector3) -> void:
	var flat := Vector3(motion.x, 0.0, motion.z)
	if flat.length_squared() < 0.01:
		return
	var origin := body.global_position
	var look := origin + flat
	if origin.is_equal_approx(look) or not body.is_inside_tree():
		return
	body.look_at(look, Vector3.UP)
