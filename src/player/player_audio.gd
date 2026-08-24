class_name PlayerAudio
extends Node
## The player's own movement foley: a grunt on take-off, a thud on a hard landing.
## Every cue is an export and every play is guarded, so an unconfigured player is
## silent rather than broken.
##
## These are the player's *own* sounds, so they play non-positionally — the listener
## is inside the head that made them.

signal played(cue: AudioCue)

## Movement whose jump / land edges are followed; the first sibling is used when unset.
@export var movement: MovementController
@export var jump_cue: AudioCue
@export var land_cue: AudioCue
## Landings gentler than this (stepping off a kerb, walking down the arena lip) are
## silent; only a real drop thuds.
@export_range(0.0, 30.0, 0.1) var land_min_fall_speed: float = 3.0


func _ready() -> void:
	if movement == null:
		movement = _find_sibling_movement()
	if movement == null:
		return
	movement.jumped.connect(on_jumped)
	movement.landed.connect(on_landed)


func on_jumped() -> void:
	_play(jump_cue)


func on_landed(fall_speed: float) -> void:
	if fall_speed < land_min_fall_speed:
		return
	_play(land_cue)


func _play(cue: AudioCue) -> void:
	if cue == null:
		return
	AudioManager.play(cue)
	played.emit(cue)


func _find_sibling_movement() -> MovementController:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is MovementController:
			return child
	return null
