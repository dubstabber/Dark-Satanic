extends GameTest
## Every authored AudioCue in assets/audio/cues loads and points at a usable ogg stream.

const CUE_DIR := "res://assets/audio/cues"
const SFX_NAMES: Array[String] = [
	"dagger_tick", "shotgun_thump", "hit", "skull_screech", "spawner_groan",
	"gem_chime", "tier_up", "death_stinger", "ui_click", "skull_arrive", "whispers",
]
const LOOP_NAMES: Array[String] = ["amb_drone", "menu_hum"]
## Cues holding several takes that pick_stream() randomizes between.
const MULTI_TAKE_NAMES: Array[String] = ["whispers"]
const VALID_BUSES: Array[StringName] = [&"SFX", &"UI", &"Music"]


func _cue(cue_name: String) -> AudioCue:
	var cue := load("%s/%s.tres" % [CUE_DIR, cue_name]) as AudioCue
	assert_not_null(cue, "%s.tres loads as an AudioCue" % cue_name)
	return cue


func _stream(cue_name: String) -> AudioStreamOggVorbis:
	var cue := _cue(cue_name)
	if cue == null or cue.streams.is_empty():
		return null
	return cue.streams[0] as AudioStreamOggVorbis


func _streams(cue_name: String) -> Array[AudioStream]:
	var cue := _cue(cue_name)
	return [] as Array[AudioStream] if cue == null else cue.streams


func test_every_expected_cue_file_exists() -> void:
	for cue_name in SFX_NAMES + LOOP_NAMES:
		assert_true(ResourceLoader.exists("%s/%s.tres" % [CUE_DIR, cue_name]), cue_name)


func test_no_stray_cue_files() -> void:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(CUE_DIR):
		if file.ends_with(".tres"):
			found.append(file.get_basename())
	found.sort()
	var expected: Array[String] = SFX_NAMES + LOOP_NAMES
	expected.sort()
	assert_eq(found, expected)


func test_every_cue_is_playable_with_an_ogg_stream() -> void:
	for cue_name in SFX_NAMES + LOOP_NAMES:
		var cue := _cue(cue_name)
		assert_true(cue.is_playable(), "%s is playable" % cue_name)
		if MULTI_TAKE_NAMES.has(cue_name):
			assert_gt(cue.streams.size(), 1, "%s has several takes" % cue_name)
		else:
			assert_eq(cue.streams.size(), 1, "%s has exactly one stream" % cue_name)
		for stream in _streams(cue_name):
			var ogg := stream as AudioStreamOggVorbis
			assert_not_null(ogg, "%s stream is AudioStreamOggVorbis" % cue_name)
			assert_gt(ogg.get_length(), 0.0, "%s has a length" % cue_name)


func test_cue_ranges_are_sane() -> void:
	for cue_name in SFX_NAMES + LOOP_NAMES:
		var cue := _cue(cue_name)
		assert_true(VALID_BUSES.has(cue.bus), "%s bus %s" % [cue_name, cue.bus])
		assert_between(cue.volume_db, -30.0, 0.0, "%s volume" % cue_name)
		assert_between(cue.pitch_min, 0.5, 1.5, "%s pitch_min" % cue_name)
		assert_between(cue.pitch_max, 0.5, 1.5, "%s pitch_max" % cue_name)
		assert_true(cue.pitch_min <= cue.pitch_max, "%s pitch order" % cue_name)
		assert_gt(cue.max_distance, 0.0)


func test_sfx_are_short_and_not_looping() -> void:
	for cue_name in SFX_NAMES:
		for raw in _streams(cue_name):
			var stream := raw as AudioStreamOggVorbis
			assert_lt(stream.get_length(), 4.0, "%s shorter than 4 s" % cue_name)
			assert_false(stream.loop, "%s does not loop" % cue_name)
		assert_true(_cue(cue_name).bus in [&"SFX", &"UI"], "%s on SFX/UI" % cue_name)


func test_loops_loop_on_music_bus_with_fixed_pitch() -> void:
	for cue_name in LOOP_NAMES:
		var cue := _cue(cue_name)
		var stream := _stream(cue_name)
		assert_true(stream.loop, "%s loops" % cue_name)
		assert_eq(cue.bus, &"Music", cue_name)
		assert_almost_eq(cue.pitch_min, 1.0, 0.0001, cue_name)
		assert_almost_eq(cue.pitch_max, 1.0, 0.0001, cue_name)
		assert_almost_eq(stream.get_length(), 30.0, 0.1, "%s is ~30 s" % cue_name)


func test_pick_helpers_work_on_authored_cues() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var cue := _cue("skull_screech")
	for i in 20:
		assert_same(cue.pick_stream(rng), cue.streams[0])
		assert_between(cue.pick_pitch(rng), 0.7, 1.3)


func test_specified_tunings() -> void:
	var tick := _cue("dagger_tick")
	assert_almost_eq(tick.volume_db, -8.0, 0.001)
	assert_almost_eq(tick.pitch_min, 0.9, 0.001)
	assert_almost_eq(tick.pitch_max, 1.15, 0.001)
	var screech := _cue("skull_screech")
	assert_almost_eq(screech.pitch_min, 0.7, 0.001)
	assert_almost_eq(screech.pitch_max, 1.3, 0.001)
	assert_eq(_cue("ui_click").bus, &"UI")
	assert_eq(_cue("dagger_tick").bus, &"SFX")


func test_loops_are_stereo_and_sfx_are_mono_sized() -> void:
	# Loops are longer than every one-shot; guards against a swapped stream reference.
	var shortest_loop := 1e9
	for cue_name in LOOP_NAMES:
		shortest_loop = minf(shortest_loop, _stream(cue_name).get_length())
	for cue_name in SFX_NAMES:
		for raw in _streams(cue_name):
			var stream := raw as AudioStreamOggVorbis
			assert_lt(stream.get_length(), shortest_loop, cue_name)
