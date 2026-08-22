class_name GameFlow
extends Node
## MENU → PLAYING ⇄ PAUSED → DEAD state machine. Owns screen instances and the live
## Game; screens only emit intent signals, this node decides what happens.
## Runs with PROCESS_MODE_ALWAYS so the pause action still reaches it while the tree is paused.

enum State { MENU, PLAYING, PAUSED, DEAD }

signal state_changed(from: State, to: State)

@export var scene_slot: Node
@export var ui_layer: CanvasLayer
@export var post_process: PostProcessController
@export var config: GameConfig
@export_group("Scenes")
@export var game_scene: PackedScene
@export var main_menu_scene: PackedScene
@export var death_screen_scene: PackedScene
@export var pause_menu_scene: PackedScene
@export var settings_panel_scene: PackedScene
@export_group("Presentation")
@export var menu_profile: PostFxProfile
@export var gameplay_profile: PostFxProfile
@export var death_profile: PostFxProfile
## Seconds the post-process crossfades when the state changes.
@export_range(0.0, 5.0, 0.05) var screen_fade_duration: float = 0.6
## Brightness bump (>1 also inverts) and its decay on every tier-up.
@export_range(0.0, 3.0, 0.05) var tier_pulse_strength: float = 0.6
@export_range(0.0, 3.0, 0.05) var tier_pulse_duration: float = 0.3
@export var menu_music: AudioCue
@export var game_music: AudioCue
@export var death_cue: AudioCue
@export var tier_up_cue: AudioCue
## Played when any button of a screen this node shows is pressed.
@export var ui_cue: AudioCue

var state: State = State.MENU
var game: Game
var store: LeaderboardStore
var leaderboard: LeaderboardData
var last_entry: LeaderboardEntry
var _screen: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(p_store: LeaderboardStore) -> void:
	store = p_store
	leaderboard = store.load()
	if not EventBus.tier_changed.is_connected(_on_tier_changed):
		EventBus.tier_changed.connect(_on_tier_changed)


func show_menu() -> void:
	RunManager.finish(&"aborted")
	_clear_game()
	get_tree().paused = false
	var menu := _show_screen(main_menu_scene)
	if menu != null:
		menu.play_requested.connect(start_run)
		menu.settings_requested.connect(open_settings)
		menu.quit_requested.connect(get_tree().quit)
		menu.show_leaderboard(leaderboard)
	_present(State.MENU, menu_profile, menu_music, Input.MOUSE_MODE_VISIBLE)


func start_run() -> void:
	_clear_game()
	_clear_screen()
	get_tree().paused = false
	game = game_scene.instantiate()
	game.config = config
	game.run_ended.connect(_on_run_ended)
	scene_slot.add_child(game)
	_present(State.PLAYING, gameplay_profile, game_music, Input.MOUSE_MODE_CAPTURED)


func pause() -> void:
	if state != State.PLAYING:
		return
	get_tree().paused = true
	var menu := _show_screen(pause_menu_scene)
	if menu != null:
		menu.resume_requested.connect(resume)
		menu.menu_requested.connect(show_menu)
	_set_state(State.PAUSED)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume() -> void:
	if state != State.PAUSED:
		return
	_clear_screen()
	get_tree().paused = false
	_set_state(State.PLAYING)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func open_settings() -> void:
	var panel := settings_panel_scene.instantiate()
	ui_layer.add_child(panel)
	_wire_button_clicks(panel)
	panel.bind(SettingsManager.mouse_sensitivity, SettingsManager.master_volume,
		SettingsManager.music_volume, SettingsManager.sfx_volume, SettingsManager.fullscreen)
	panel.sensitivity_changed.connect(SettingsManager.set_mouse_sensitivity)
	panel.volume_changed.connect(SettingsManager.set_volume)
	panel.fullscreen_changed.connect(SettingsManager.set_fullscreen)
	panel.closed.connect(func() -> void:
		SettingsManager.save()
		panel.queue_free())


func _on_run_ended(result: RunResult) -> void:
	# Deferred: death usually arrives from a physics callback, where collision
	# objects may not be disabled synchronously.
	game.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	last_entry = LeaderboardEntry.from_result(result)
	var rank := leaderboard.insert(last_entry)
	store.save(leaderboard)
	var screen := _show_screen(death_screen_scene)
	if screen != null:
		screen.retry_requested.connect(start_run)
		screen.menu_requested.connect(show_menu)
		screen.name_submitted.connect(_on_name_submitted)
		screen.show_result(result, leaderboard, rank)
	AudioManager.play(death_cue)
	_present(State.DEAD, death_profile, null, Input.MOUSE_MODE_VISIBLE)


func _on_name_submitted(player_name: String) -> void:
	if last_entry == null:
		return
	last_entry.player_name = player_name
	store.save(leaderboard)


func _on_tier_changed(_tier: DaggerUpgradeTier, index: int) -> void:
	if index > 0 and state == State.PLAYING:
		AudioManager.play(tier_up_cue)
		if post_process != null:
			post_process.pulse(tier_pulse_strength, tier_pulse_duration)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == State.PLAYING:
			pause()
		elif state == State.PAUSED:
			resume()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("retry") and state == State.DEAD:
		start_run()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


## F11 / Alt+Enter: flips the persisted setting; Main applies it to the window.
func toggle_fullscreen() -> void:
	SettingsManager.toggle_fullscreen()
	SettingsManager.save()


func _present(new_state: State, profile: PostFxProfile, music: AudioCue, mouse_mode: Input.MouseMode) -> void:
	_set_state(new_state)
	Input.mouse_mode = mouse_mode
	if post_process != null and profile != null:
		post_process.apply(profile, screen_fade_duration)
	if music != null:
		AudioManager.play_music_cue(music)
	elif new_state == State.DEAD:
		AudioManager.stop_music()


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	var previous := state
	state = new_state
	state_changed.emit(previous, new_state)


func _show_screen(scene: PackedScene) -> Control:
	_clear_screen()
	if scene == null:
		return null
	_screen = scene.instantiate()
	ui_layer.add_child(_screen)
	_wire_button_clicks(_screen)
	return _screen


## Every Button under `root` plays ui_cue when pressed (null cue = silent).
func _wire_button_clicks(root: Node) -> void:
	if root is BaseButton:
		root.pressed.connect(_play_ui_cue)
	for child in root.get_children():
		_wire_button_clicks(child)


func _play_ui_cue() -> void:
	AudioManager.play(ui_cue)


func _clear_screen() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null


func _clear_game() -> void:
	if game != null and is_instance_valid(game):
		game.queue_free()
	game = null
