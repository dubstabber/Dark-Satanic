extends GameTest
## Every authored AudioCue in assets/audio/cues loads and points at usable streams.
##
## Two stream flavours live side by side: the sox-synthesised set in tools/gen_audio.sh
## is Ogg Vorbis, while the fire / jump / land / rift takes generated with the local
## moss-sfx server stay uncompressed WAV (they are all well under a second). Both are
## AudioStream, so the cues themselves do not care — these tests do.

const CUE_DIR := "res://assets/audio/cues"
## One-shot cue -> the number of interchangeable takes pick_stream() randomises between.
const SFX_TAKES := {
	"dagger_tick": 3,
	"shotgun_thump": 3,
	"jump": 2,
	"land": 2,
	"spawn_rift": 2,
	"whispers": 9,
	"hit": 2,
	"skull_screech": 3,
	"spawner_groan": 1,
	"gem_chime": 3,
	"tier_up": 1,
	"death_stinger": 1,
	"ui_click": 1,
	"skull_arrive": 1,
	"death_wail": 2,
	"armor_clang": 1,
	"snuff": 1,
	"scream_far": 3,
	"scream_near": 3,
	"laugh_broken": 2,
	"tape_static": 2,
	"metal_drag": 1,
	"breath_close": 1,
	"herald_choir": 3,
	"herald_bell": 3,
	"herald_maw": 3,
	"herald_swarm": 3,
	"herald_boss": 3,
}
## The heralds announce an arrival; the atmosphere cues announce nothing at all, which is
## the whole trick - they share a register so a scream is never proof of anything.
const HERALDS: Array[String] = ["herald_choir", "herald_bell", "herald_maw", "herald_swarm", "herald_boss"]
const ATMOSPHERE: Array[String] = [
	"scream_far", "scream_near", "laugh_broken", "tape_static", "metal_drag", "breath_close", "whispers",
]
const LOOP_NAMES: Array[String] = ["amb_drone", "menu_hum"]
## The cues whose takes come from the local moss-sfx server as uncompressed WAV, rather
## than from tools/gen_audio.sh as sox-synthesised Ogg.
const GENERATED: Array[String] = [
	"dagger_tick", "shotgun_thump", "jump", "land", "spawn_rift", "skull_screech", "hit", "gem_chime",
	"death_wail", "snuff", "scream_far", "scream_near", "laugh_broken", "tape_static", "metal_drag",
	"breath_close", "armor_clang", "herald_choir", "herald_bell", "herald_maw", "herald_swarm", "herald_boss",
]
const VALID_BUSES: Array[StringName] = [&"SFX", &"UI", &"Music"]


func _sfx_names() -> Array[String]:
	var names: Array[String] = []
	for key: String in SFX_TAKES:
		names.append(key)
	return names


func _all_names() -> Array[String]:
	return _sfx_names() + LOOP_NAMES


func _cue(cue_name: String) -> AudioCue:
	var cue := load("%s/%s.tres" % [CUE_DIR, cue_name]) as AudioCue
	assert_not_null(cue, "%s.tres loads as an AudioCue" % cue_name)
	return cue


func _streams(cue_name: String) -> Array[AudioStream]:
	var cue := _cue(cue_name)
	return [] as Array[AudioStream] if cue == null else cue.streams


func _first(cue_name: String) -> AudioStream:
	var streams := _streams(cue_name)
	return null if streams.is_empty() else streams[0]


## Ogg and WAV spell "loops" differently; both are used in this project.
static func _loops(stream: AudioStream) -> bool:
	if stream is AudioStreamWAV:
		return (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	if stream is AudioStreamOggVorbis:
		return (stream as AudioStreamOggVorbis).loop
	return false


func test_every_expected_cue_file_exists() -> void:
	for cue_name in _all_names():
		assert_true(ResourceLoader.exists("%s/%s.tres" % [CUE_DIR, cue_name]), cue_name)


func test_no_stray_cue_files() -> void:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(CUE_DIR):
		if file.ends_with(".tres"):
			found.append(file.get_basename())
	found.sort()
	var expected := _all_names()
	expected.sort()
	assert_eq(found, expected)


func test_every_cue_is_playable_with_the_expected_take_count() -> void:
	for cue_name in _all_names():
		var cue := _cue(cue_name)
		assert_true(cue.is_playable(), "%s is playable" % cue_name)
		var expected: int = SFX_TAKES.get(cue_name, 1)
		assert_eq(cue.streams.size(), expected, "%s take count" % cue_name)
		for stream in cue.streams:
			assert_true(
				stream is AudioStreamOggVorbis or stream is AudioStreamWAV,
				"%s stream is ogg or wav, got %s" % [cue_name, stream]
			)
			assert_gt(stream.get_length(), 0.0, "%s has a length" % cue_name)


func test_cue_ranges_are_sane() -> void:
	for cue_name in _all_names():
		var cue := _cue(cue_name)
		assert_true(VALID_BUSES.has(cue.bus), "%s bus %s" % [cue_name, cue.bus])
		assert_between(cue.volume_db, -30.0, 0.0, "%s volume" % cue_name)
		assert_between(cue.pitch_min, 0.5, 1.5, "%s pitch_min" % cue_name)
		assert_between(cue.pitch_max, 0.5, 1.5, "%s pitch_max" % cue_name)
		assert_true(cue.pitch_min <= cue.pitch_max, "%s pitch order" % cue_name)
		assert_gt(cue.max_distance, 0.0)


func test_sfx_are_short_and_not_looping() -> void:
	for cue_name in _sfx_names():
		for stream in _streams(cue_name):
			assert_lt(stream.get_length(), 4.0, "%s shorter than 4 s" % cue_name)
			assert_false(_loops(stream), "%s does not loop" % cue_name)
		assert_true(_cue(cue_name).bus in [&"SFX", &"UI"], "%s on SFX/UI" % cue_name)


## The stream fires 15 times a second and the shotgun every 0.6 s; a take longer than
## its own fire interval would pile up into mush.
func test_fire_takes_stay_inside_their_fire_interval() -> void:
	for stream in _streams("dagger_tick"):
		assert_lt(stream.get_length(), 0.25, "one stream dagger")
	for stream in _streams("shotgun_thump"):
		assert_lt(stream.get_length(), 1.1, "one shotgun volley")


func test_generated_takes_are_uncompressed_wav() -> void:
	for cue_name in GENERATED:
		for stream in _streams(cue_name):
			assert_true(stream is AudioStreamWAV, "%s take is a WAV" % cue_name)


func test_loops_loop_on_music_bus_with_fixed_pitch() -> void:
	for cue_name in LOOP_NAMES:
		var cue := _cue(cue_name)
		var stream := _first(cue_name)
		assert_true(_loops(stream), "%s loops" % cue_name)
		assert_eq(cue.bus, &"Music", cue_name)
		assert_almost_eq(cue.pitch_min, 1.0, 0.0001, cue_name)
		assert_almost_eq(cue.pitch_max, 1.0, 0.0001, cue_name)
		assert_almost_eq(stream.get_length(), 30.0, 0.1, "%s is ~30 s" % cue_name)


func test_pick_helpers_work_on_authored_cues() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var cue := _cue("spawner_groan")
	for i in 20:
		assert_same(cue.pick_stream(rng), cue.streams[0])
		assert_between(cue.pick_pitch(rng), 0.7, 1.3)


func test_multi_take_cues_actually_rotate_between_takes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for cue_name in GENERATED:
		var cue := _cue(cue_name)
		var seen: Array[AudioStream] = []
		for i in 60:
			var stream := cue.pick_stream(rng)
			if stream not in seen:
				seen.append(stream)
		assert_eq(seen.size(), cue.streams.size(), "%s reaches every take" % cue_name)


func test_specified_tunings() -> void:
	var tick := _cue("dagger_tick")
	assert_almost_eq(tick.volume_db, -15.0, 0.001, "quiet: it fires 15 times a second")
	assert_almost_eq(tick.pitch_min, 0.92, 0.001)
	assert_almost_eq(tick.pitch_max, 1.12, 0.001)
	assert_gt(_cue("shotgun_thump").volume_db, tick.volume_db, "the volley is the loud one")
	var screech := _cue("skull_screech")
	assert_almost_eq(screech.pitch_min, 0.8, 0.001)
	assert_almost_eq(screech.pitch_max, 1.25, 0.001)
	assert_lt(screech.volume_db, 0.0)
	assert_eq(_cue("ui_click").bus, &"UI")
	assert_eq(tick.bus, &"SFX")


func test_loops_are_longer_than_every_one_shot() -> void:
	# Loops are longer than every one-shot; guards against a swapped stream reference.
	var shortest_loop := 1e9
	for cue_name in LOOP_NAMES:
		shortest_loop = minf(shortest_loop, _first(cue_name).get_length())
	for cue_name in _sfx_names():
		for stream in _streams(cue_name):
			assert_lt(stream.get_length(), shortest_loop, cue_name)


## A herald has to carry across the arena to be a warning; atmosphere has to sit behind the
## fight without ever becoming the loudest thing in it.
func test_heralds_carry_further_than_the_atmosphere_they_hide_among() -> void:
	for cue_name in HERALDS:
		var cue := _cue(cue_name)
		assert_gt(cue.max_distance, 55.0, "%s reaches across the arena" % cue_name)
		assert_gt(cue.volume_db, -12.0, "%s is meant to be heard" % cue_name)
	for cue_name in ATMOSPHERE:
		var cue := _cue(cue_name)
		assert_lt(cue.volume_db, -9.0, "%s sits under the fight" % cue_name)
