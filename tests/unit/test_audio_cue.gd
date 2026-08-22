extends GameTest


func _cue(count: int) -> AudioCue:
	var cue := AudioCue.new()
	for i in count:
		var stream := AudioStreamWAV.new()
		stream.resource_name = "s%d" % i
		cue.streams.append(stream)
	return cue


func test_empty_cue_is_not_playable() -> void:
	var cue := AudioCue.new()
	var rng := RandomNumberGenerator.new()
	assert_false(cue.is_playable())
	assert_null(cue.pick_stream(rng))


func test_pick_stream_only_returns_members() -> void:
	var cue := _cue(3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 30:
		assert_true(cue.streams.has(cue.pick_stream(rng)))


func test_pitch_stays_in_range_even_when_swapped() -> void:
	var cue := _cue(1)
	cue.pitch_min = 1.2
	cue.pitch_max = 0.8
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 30:
		assert_between(cue.pick_pitch(rng), 0.8, 1.2)
