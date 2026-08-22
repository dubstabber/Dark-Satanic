class_name AudioCue
extends Resource
## A designer-authored sound: one or more interchangeable streams with volume,
## pitch randomisation and the bus to play on.

@export var streams: Array[AudioStream] = []
@export_range(-60.0, 12.0, 0.1) var volume_db: float = 0.0
@export_range(0.1, 4.0, 0.01) var pitch_min: float = 0.9
@export_range(0.1, 4.0, 0.01) var pitch_max: float = 1.1
@export var bus: StringName = &"SFX"
## Distance after which a positional cue is inaudible (AudioStreamPlayer3D.max_distance).
@export_range(1.0, 200.0, 1.0) var max_distance: float = 40.0


func is_playable() -> bool:
	return not streams.is_empty()


func pick_stream(rng: RandomNumberGenerator) -> AudioStream:
	if streams.is_empty():
		return null
	return streams[rng.randi_range(0, streams.size() - 1)]


func pick_pitch(rng: RandomNumberGenerator) -> float:
	var low := minf(pitch_min, pitch_max)
	var high := maxf(pitch_min, pitch_max)
	return rng.randf_range(low, high)
