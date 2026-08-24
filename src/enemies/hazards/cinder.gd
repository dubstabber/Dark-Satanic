class_name CinderHazard
extends Node3D
## A patch of ground a Thurible has censed: it arms visibly, flares once, then fades.
##
## Three timed states rather than tweens, because the timing *is* the gameplay and has to
## be inspectable: ARM is the fair-play window in which the sigil grows and nothing can
## hurt you, FLARE is the brief moment the hitbox is live, FADE is cosmetic. Time is
## driven through advance(delta).

signal armed
signal flared
signal finished(cinder: CinderHazard)

enum State { ARM, FLARE, FADE }

## Seconds of warning before it burns. Long enough to walk out of.
@export_range(0.1, 10.0, 0.05) var arm_time: float = 2.5
## Seconds the hitbox is live.
@export_range(0.05, 5.0, 0.05) var active_time: float = 0.6
@export_range(0.05, 5.0, 0.05) var fade_time: float = 0.8
## Radius of the burn, matched by the sigil decal.
@export_range(0.5, 10.0, 0.1) var radius: float = 2.2
## Advance on the engine clock; tests switch this off and call advance() themselves.
@export var autonomous: bool = true
@export var arm_cue: AudioCue
@export var flare_cue: AudioCue

var state: State = State.ARM
var elapsed: float = 0.0

@onready var hitbox: HitboxComponent = get_node_or_null("Hitbox") as HitboxComponent
@onready var sigil: Node3D = get_node_or_null("Sigil") as Node3D
@onready var flare: GPUParticles3D = get_node_or_null("Flare") as GPUParticles3D


func _ready() -> void:
	if hitbox != null:
		hitbox.active = false
		_size_hitbox()
	if flare != null:
		flare.emitting = false
	_apply_visual()
	AudioManager.play(arm_cue, global_position)
	armed.emit()


func _physics_process(delta: float) -> void:
	if autonomous:
		advance(delta)


## Fraction of the current state that has elapsed, 0..1.
func progress() -> float:
	var span := _state_duration()
	return clampf(elapsed / span, 0.0, 1.0) if span > 0.0 else 1.0


func is_dangerous() -> bool:
	return state == State.FLARE


func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	elapsed += delta
	while elapsed >= _state_duration():
		elapsed -= _state_duration()
		if not _next_state():
			return
	_apply_visual()


## Advances one state; returns false once the cinder has freed itself.
func _next_state() -> bool:
	match state:
		State.ARM:
			state = State.FLARE
			if hitbox != null:
				hitbox.active = true
			if flare != null:
				flare.emitting = true
			AudioManager.play(flare_cue, global_position)
			flared.emit()
		State.FLARE:
			state = State.FADE
			if hitbox != null:
				hitbox.active = false
		State.FADE:
			finished.emit(self)
			queue_free()
			return false
	return true


func _state_duration() -> float:
	match state:
		State.ARM:
			return arm_time
		State.FLARE:
			return active_time
		_:
			return fade_time


## The sigil grows through the warning, sits at full size while it burns, and shrinks away.
func _apply_visual() -> void:
	if sigil == null:
		return
	var factor := 1.0
	match state:
		State.ARM:
			factor = lerpf(0.35, 1.0, progress())
		State.FLARE:
			factor = 1.0
		State.FADE:
			factor = lerpf(1.0, 0.05, progress())
	sigil.scale = Vector3(radius * 2.0 * factor, 1.0, radius * 2.0 * factor)


func _size_hitbox() -> void:
	var shape := hitbox.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape == null or shape.shape == null:
		return
	var cylinder := shape.shape as CylinderShape3D
	if cylinder != null:
		# Duplicated: the shape resource is shared by every cinder in the scene.
		cylinder = cylinder.duplicate() as CylinderShape3D
		cylinder.radius = radius
		shape.shape = cylinder
