class_name PsalmShard
extends Node3D
## A slow homing note sung at the player by a Cantor. Killable: one dagger pops it,
## which is the whole point — it is a threat you are meant to shoot down, not dodge
## forever. Time is driven through advance(delta).

signal expired(shard: PsalmShard)

@export var speed: float = 9.0
## Degrees per second it may turn toward the target; low enough that strafing beats it.
@export_range(0.0, 720.0, 1.0) var homing_turn_rate_deg: float = 60.0
@export_range(0.1, 30.0, 0.1) var lifetime: float = 6.0
## Advance on the engine clock; tests switch this off and call advance() themselves.
@export var autonomous: bool = true
## What it flies at; set by whoever launched it.
@export var target: Node3D

var velocity: Vector3 = Vector3.ZERO
var age: float = 0.0

@onready var health: HealthComponent = _child_of_type(HealthComponent) as HealthComponent


func _ready() -> void:
	if health != null:
		health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if autonomous:
		advance(delta)


## Points the shard at `direction` and starts its flight.
func launch(origin: Vector3, direction: Vector3, p_target: Node3D = null) -> void:
	global_position = origin
	target = p_target
	age = 0.0
	var dir := direction.normalized() if direction.length_squared() > 0.0 else Vector3.FORWARD
	velocity = dir * speed
	_face(dir)


func advance(delta: float) -> void:
	if delta <= 0.0 or (health != null and health.is_dead()):
		return
	age += delta
	_steer(delta)
	global_position += velocity * delta
	if velocity.length_squared() > 0.0:
		_face(velocity.normalized())
	if age >= lifetime:
		expired.emit(self)
		queue_free()


func _steer(delta: float) -> void:
	if target == null or not is_instance_valid(target) or velocity.length_squared() == 0.0:
		return
	var desired := (target.global_position - global_position)
	if desired.length_squared() < 0.000001:
		return
	desired = desired.normalized()
	var forward := velocity.normalized()
	var angle := forward.angle_to(desired)
	if angle <= 0.0001:
		return
	var axis := forward.cross(desired)
	if axis.length_squared() <= 0.000001:
		return
	var step := minf(angle, deg_to_rad(homing_turn_rate_deg) * delta)
	velocity = forward.rotated(axis.normalized(), step) * speed


func _face(forward: Vector3) -> void:
	var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.999 else Vector3.RIGHT
	global_basis = Basis.looking_at(forward, up)


func _on_died(_hit: HitInfo) -> void:
	velocity = Vector3.ZERO


func _child_of_type(type: Variant) -> Node:
	for child in get_children():
		if is_instance_of(child, type):
			return child
	return null
