class_name Player
extends CharacterBody3D
## First-person player: reads one PlayerInputFrame per physics tick and hands it to
## the movement, look, weapon and camera children. Dies once, re-emitting the cause.

signal died(cause: StringName)

## Source of input frames; the first InputReader child is used when unset.
## Tests inject a FakeInputReader here.
@export var input_reader: InputReader

@onready var health: HealthComponent = $HealthComponent
@onready var movement: MovementController = $MovementController
@onready var look: LookController = $LookController
@onready var weapon_holder: WeaponHolder = $WeaponHolder
@onready var pickup_collector: PickupCollector = $PickupCollector
@onready var camera_rig: CameraRig = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var hands: HandViewModel = $CameraRig/Camera3D/HandViewModel

var last_frame: PlayerInputFrame = PlayerInputFrame.new()
var _dead: bool = false


func _ready() -> void:
	if input_reader == null:
		input_reader = _find_input_reader()
	health.died.connect(_on_health_died)
	movement.landed.connect(camera_rig.on_landed)
	weapon_holder.kicked.connect(camera_rig.kick)
	weapon_holder.kicked.connect(hands.kick)
	if movement.stats != null:
		camera_rig.position.y = movement.stats.camera_height


func setup(mouse_sensitivity: float) -> void:
	look.sensitivity = mouse_sensitivity


func _physics_process(delta: float) -> void:
	advance(delta)


## One tick: read input, look, move, fire, animate camera.
func advance(delta: float) -> void:
	if input_reader == null:
		return
	var frame := input_reader.read(global_basis, look.take_pending())
	if frame == null:
		return
	last_frame = frame
	look.apply_look(frame.look_delta)
	hands.apply_look_delta(frame.look_delta)
	movement.step(frame, delta)
	weapon_holder.update(frame, delta)
	camera_rig.horizontal_speed = movement.horizontal_speed()
	camera_rig.on_floor = movement.is_on_floor()
	camera_rig.advance(delta)
	hands.advance(delta)


func is_dead() -> bool:
	return _dead


func _on_health_died(last_hit: HitInfo) -> void:
	if _dead:
		return
	_dead = true
	var cause: StringName = last_hit.cause if last_hit != null else &"unknown"
	died.emit(cause)


func _find_input_reader() -> InputReader:
	for child in get_children():
		if child is InputReader:
			return child
	return null
