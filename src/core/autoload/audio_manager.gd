extends Node
## Pooled playback of AudioCue resources. Sounds outlive their emitters (an enemy
## freed on death still plays its death cue). Knows nothing about gameplay.

const POOL_3D_SIZE := 24
const POOL_2D_SIZE := 4

var rng := RandomNumberGenerator.new()
var _players_3d: Array[AudioStreamPlayer3D] = []
var _players_2d: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer


func _ready() -> void:
	for i in POOL_3D_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.name = "Sfx3D%d" % i
		add_child(player)
		_players_3d.append(player)
	for i in POOL_2D_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx2D%d" % i
		add_child(player)
		_players_2d.append(player)
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = _existing_bus(&"Music")
	add_child(_music)
	SettingsManager.changed.connect(_apply_settings)
	_apply_settings()


## Plays a cue, positional when `position` is finite, otherwise on a 2D player.
## Returns the player used (null when the cue is missing or empty).
func play(cue: AudioCue, position: Vector3 = Vector3.INF) -> Node:
	if cue == null or not cue.is_playable():
		return null
	var stream := cue.pick_stream(rng)
	if position.is_finite():
		var player := _acquire(_players_3d) as AudioStreamPlayer3D
		if player == null:
			return null
		player.global_position = position
		player.max_distance = cue.max_distance
		_start(player, stream, cue)
		return player
	var player_2d := _acquire(_players_2d) as AudioStreamPlayer
	if player_2d == null:
		return null
	_start(player_2d, stream, cue)
	return player_2d


func play_music(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		stop_music()
		return
	_music.stream = stream
	_music.volume_db = volume_db
	_music.play()


func stop_music() -> void:
	_music.stop()


func is_music_playing() -> bool:
	return _music.playing


func set_bus_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(clampf(linear, 0.0001, 1.0)))


func playing_count() -> int:
	var count := 0
	for player in _players_3d:
		if player.playing:
			count += 1
	for player in _players_2d:
		if player.playing:
			count += 1
	return count


## Release stream references before the engine tears down (avoids "resource still
## in use at exit" reports from a looping music stream).
func _exit_tree() -> void:
	reset()
	for player in _players_3d:
		player.stream = null
	for player in _players_2d:
		player.stream = null
	_music.stream = null


## Stops everything; used between tests and when returning to the menu.
func reset() -> void:
	for player in _players_3d:
		player.stop()
	for player in _players_2d:
		player.stop()
	stop_music()


func _start(player: Node, stream: AudioStream, cue: AudioCue) -> void:
	player.stream = stream
	player.volume_db = cue.volume_db
	player.pitch_scale = cue.pick_pitch(rng)
	player.bus = _existing_bus(cue.bus)
	player.play()


func _acquire(pool: Array) -> Node:
	for player in pool:
		if not player.playing:
			return player
	# Everything busy: steal the first one (oldest in round-robin terms).
	if pool.is_empty():
		return null
	var stolen: Node = pool.pop_front()
	pool.append(stolen)
	stolen.stop()
	return stolen


func _existing_bus(bus: StringName) -> StringName:
	return bus if AudioServer.get_bus_index(bus) != -1 else &"Master"


func _apply_settings() -> void:
	set_bus_volume(&"Master", SettingsManager.master_volume)
	set_bus_volume(&"Music", SettingsManager.music_volume)
	set_bus_volume(&"SFX", SettingsManager.sfx_volume)
	set_bus_volume(&"UI", SettingsManager.sfx_volume)
