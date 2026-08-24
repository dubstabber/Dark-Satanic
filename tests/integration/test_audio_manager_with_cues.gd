extends GameTest
## AudioManager driving the real authored cues while the project bus layout is active.

const LAYOUT_PATH := "res://assets/audio/default_bus_layout.tres"
const CUE_DIR := "res://assets/audio/cues"

var _previous_layout: AudioBusLayout


func before_each() -> void:
	super.before_each()
	_previous_layout = AudioServer.generate_bus_layout()
	AudioServer.set_bus_layout(load(LAYOUT_PATH))


func after_each() -> void:
	AudioManager.reset()
	AudioServer.set_bus_layout(_previous_layout)
	super.after_each()


func _cue(cue_name: String) -> AudioCue:
	return load("%s/%s.tres" % [CUE_DIR, cue_name]) as AudioCue


func test_positional_sfx_cue_plays_on_sfx_bus() -> void:
	var player := AudioManager.play(_cue("dagger_tick"), Vector3.ZERO) as AudioStreamPlayer3D
	assert_not_null(player)
	assert_true(player.playing)
	assert_eq(player.bus, &"SFX")
	assert_eq(player.global_position, Vector3.ZERO)
	assert_is(player.stream, AudioStreamWAV, "the generated fire takes are uncompressed")
	assert_true(player.stream in _cue("dagger_tick").streams, "one of the cue's takes")
	assert_almost_eq(player.volume_db, -15.0, 0.001)
	assert_between(player.pitch_scale, 0.92, 1.12)
	assert_almost_eq(player.max_distance, 30.0, 0.001)


func test_ui_cue_without_position_uses_2d_player_on_ui_bus() -> void:
	var player := AudioManager.play(_cue("ui_click")) as AudioStreamPlayer
	assert_not_null(player)
	assert_true(player.playing)
	assert_eq(player.bus, &"UI")


func test_every_sfx_cue_plays_at_its_position() -> void:
	var names: Array[String] = [
		"dagger_tick", "shotgun_thump", "hit", "skull_screech", "spawner_groan",
		"gem_chime", "tier_up", "death_stinger", "ui_click",
	]
	var i := 0
	for cue_name in names:
		var cue := _cue(cue_name)
		var player := AudioManager.play(cue, Vector3(i, 0, 0)) as AudioStreamPlayer3D
		assert_not_null(player, cue_name)
		assert_true(player.playing, cue_name)
		assert_eq(player.bus, cue.bus, cue_name)
		i += 1
	assert_eq(AudioManager.playing_count(), names.size())


func test_drone_plays_as_music() -> void:
	var drone := _cue("amb_drone")
	AudioManager.play_music(drone.streams[0], drone.volume_db)
	assert_true(AudioManager.is_music_playing())
	var music := AudioManager.get_node("Music") as AudioStreamPlayer
	assert_true((music.stream as AudioStreamOggVorbis).loop)
	assert_almost_eq(music.volume_db, -6.0, 0.001)
	AudioManager.play_music(_cue("menu_hum").streams[0])
	assert_true(AudioManager.is_music_playing())
	assert_same(music.stream, _cue("menu_hum").streams[0])


func test_sounds_keep_playing_across_physics_frames() -> void:
	AudioManager.play(_cue("spawner_groan"), Vector3.ZERO)
	await wait_physics_frames(3)
	assert_eq(AudioManager.playing_count(), 1)
	AudioManager.reset()
	assert_eq(AudioManager.playing_count(), 0)
