extends GameTest
## The player's own movement foley: a grunt on take-off, a thud on a hard landing.

const DT := 1.0 / 60.0

var _world: Node3D
var _input: FakeInputReader
var _player: Player
var _audio: PlayerAudio


func before_each() -> void:
	super.before_each()
	_world = make_world()
	PlayerTestWorld.add_floor(_world)
	_input = FakeInputReader.new()
	_player = PlayerTestWorld.spawn_player(_world, _input)
	_audio = _player.player_audio
	watch_signals(_audio)


func test_scene_wires_the_cues_to_the_movement_edges() -> void:
	assert_not_null(_audio)
	assert_same(_audio.movement, _player.movement)
	assert_true(_audio.jump_cue is AudioCue, "jump cue authored in player.tscn")
	assert_true(_audio.land_cue is AudioCue, "land cue authored in player.tscn")
	assert_true(_player.movement.jumped.is_connected(_audio.on_jumped))
	assert_true(_player.movement.landed.is_connected(_audio.on_landed))


func test_jumping_plays_the_jump_cue() -> void:
	await wait_physics_frames(20)
	_input.push(FakeInputReader.frame(Vector3.ZERO, false, true))
	await wait_physics_frames(2)
	assert_signal_emitted(_audio, "played")
	assert_same(get_signal_parameters(_audio, "played")[0], _audio.jump_cue)


func test_a_hard_landing_thuds() -> void:
	_audio.on_landed(9.0)
	assert_signal_emitted(_audio, "played")
	assert_same(get_signal_parameters(_audio, "played")[0], _audio.land_cue)


func test_a_gentle_landing_is_silent() -> void:
	_audio.on_landed(_audio.land_min_fall_speed - 0.01)
	assert_signal_not_emitted(_audio, "played", "stepping off a kerb makes no noise")


func test_a_full_jump_and_landing_plays_both_cues() -> void:
	await wait_physics_frames(20)
	_input.push(FakeInputReader.frame(Vector3.ZERO, false, true))
	for i in 120:
		await wait_physics_frames(1)
		if get_signal_emit_count(_audio, "played") >= 2:
			break
	assert_signal_emit_count(_audio, "played", 2)
	assert_true(_player.movement.is_on_floor(), "back on the ground")


func test_missing_cues_are_silent_rather_than_fatal() -> void:
	_audio.jump_cue = null
	_audio.land_cue = null
	_audio.on_jumped()
	_audio.on_landed(30.0)
	assert_signal_not_emitted(_audio, "played")
	assert_eq(AudioManager.playing_count(), 0)


func test_a_loose_node_finds_its_sibling_movement() -> void:
	var holder := Node3D.new()
	var movement := MovementController.new()
	movement.stats = PlayerMovementStats.new()
	holder.add_child(movement)
	var audio := PlayerAudio.new()
	holder.add_child(audio)
	add_child_autofree(holder)
	assert_same(audio.movement, movement)
