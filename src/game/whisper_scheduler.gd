class_name WhisperScheduler
extends Node
## Plays a half-heard whisper cue at random intervals; Game drives it via advance(delta).

signal whispered

@export var cue: AudioCue
@export var interval_min: float = 20.0
@export var interval_max: float = 45.0
@export var rng_seed: int = 0

var _rng := RandomNumberGenerator.new()
var _elapsed := 0.0
var _next_at := 0.0


func _ready() -> void:
	if rng_seed != 0:
		_rng.seed = rng_seed
	_schedule()


func advance(delta: float) -> void:
	_elapsed += delta
	if _elapsed < _next_at:
		return
	AudioManager.play(cue)
	whispered.emit()
	_schedule()


func _schedule() -> void:
	_elapsed = 0.0
	_next_at = _rng.randf_range(interval_min, interval_max)
