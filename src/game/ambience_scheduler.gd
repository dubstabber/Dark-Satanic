class_name AmbienceScheduler
extends Node
## Plays one of `cues` at a random interval, from somewhere around `origin`. Game drives it
## through advance(delta), which is what keeps it quiet in menus, under a pause and once the
## player is dead.
##
## Two of these run. The whispers are flat and in your head; the dread stingers - screams,
## laughter, tape static, a dragged chain - land out in the dark at `radius` metres, so they
## have a direction and you turn to look at nothing. Neither has any side effect, and that is the
## point: `SpawnEvent.announce_cue` heralds an arrival in the same register, so hearing a
## scream is never proof that anything is actually coming.

## Emitted where the sound was placed, for tests and for anything that wants to react.
signal played(position: Vector3)

## Drawn from at random each time; entries may repeat and a null entry is a silent no-op.
@export var cues: Array[AudioCue] = []
@export_range(0.5, 300.0, 0.5) var interval_min: float = 20.0
@export_range(0.5, 300.0, 0.5) var interval_max: float = 45.0
## Metres out from `origin` the sound is placed. 0 plays it flat - no direction, no distance
## falloff - straight into the player's head, which is where the whispers belong.
@export_range(0.0, 100.0, 0.5) var radius: float = 0.0
## Half the height band the sound is scattered through, relative to `origin`.
@export_range(0.0, 20.0, 0.1) var height_spread: float = 1.5
## What the sound happens around, normally the player; when null it happens around the origin.
@export var origin: Node3D
@export var rng_seed: int = 0

var _rng := RandomNumberGenerator.new()
var _elapsed: float = 0.0
var _next_at: float = 0.0


func _ready() -> void:
	if rng_seed != 0:
		_rng.seed = rng_seed
	_schedule()


func advance(delta: float) -> void:
	_elapsed += delta
	if _elapsed < _next_at:
		return
	var at := next_position()
	if radius <= 0.0:
		AudioManager.play(pick_cue())
	else:
		AudioManager.play(pick_cue(), at)
	played.emit(at)
	_schedule()


## The next cue to play, or null when there is nothing to play (a safe no-op downstream).
func pick_cue() -> AudioCue:
	if cues.is_empty():
		return null
	return cues[_rng.randi_range(0, cues.size() - 1)]


## Somewhere on the circle of `radius` around the origin, at a random height inside the band.
func next_position() -> Vector3:
	var center := Vector3.ZERO
	if origin != null and is_instance_valid(origin) and origin.is_inside_tree():
		center = origin.global_position
	if radius <= 0.0:
		return center
	var angle := _rng.randf_range(0.0, TAU)
	return center + Vector3(cos(angle) * radius, _rng.randf_range(-height_spread, height_spread), sin(angle) * radius)


func seconds_until_next() -> float:
	return maxf(_next_at - _elapsed, 0.0)


func _schedule() -> void:
	_elapsed = 0.0
	_next_at = _rng.randf_range(minf(interval_min, interval_max), maxf(interval_min, interval_max))
