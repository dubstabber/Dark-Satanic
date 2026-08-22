extends GameTest


func _cue() -> AudioCue:
	var cue := AudioCue.new()
	var stream := AudioStreamGenerator.new()
	stream.buffer_length = 0.1
	cue.streams.append(stream)
	return cue


func test_null_or_empty_cue_is_a_noop() -> void:
	assert_null(AudioManager.play(null))
	assert_null(AudioManager.play(AudioCue.new()))
	assert_eq(AudioManager.playing_count(), 0)


func test_positional_and_flat_playback() -> void:
	var flat := AudioManager.play(_cue())
	assert_is(flat, AudioStreamPlayer)
	assert_true(flat.playing)
	var positional := AudioManager.play(_cue(), Vector3(1, 2, 3))
	assert_is(positional, AudioStreamPlayer3D)
	assert_eq(positional.global_position, Vector3(1, 2, 3))
	assert_eq(AudioManager.playing_count(), 2)
	AudioManager.reset()
	assert_eq(AudioManager.playing_count(), 0)


func test_pool_never_grows_past_its_size() -> void:
	for i in AudioManager.POOL_3D_SIZE * 2:
		AudioManager.play(_cue(), Vector3(i, 0, 0))
	assert_true(AudioManager.playing_count() <= AudioManager.POOL_3D_SIZE + AudioManager.POOL_2D_SIZE)
	assert_eq(AudioManager.get_child_count(), AudioManager.POOL_3D_SIZE + AudioManager.POOL_2D_SIZE + 1)


func test_unknown_bus_falls_back_to_master() -> void:
	var cue := _cue()
	cue.bus = &"DoesNotExist"
	var player := AudioManager.play(cue)
	assert_eq(player.bus, &"Master")


func test_music() -> void:
	var stream := AudioStreamGenerator.new()
	AudioManager.play_music(stream)
	assert_true(AudioManager.is_music_playing())
	AudioManager.stop_music()
	assert_false(AudioManager.is_music_playing())
