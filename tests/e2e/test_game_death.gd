extends GameTest

var _main: Node
var _flow: GameFlow
var _path: String


func before_each() -> void:
	super.before_each()
	_path = temp_user_path("e2e_leaderboard")
	watch_signals(EventBus)


func after_each() -> void:
	E2EHelpers.release_input()
	super.after_each()


func _boot(config: GameConfig) -> void:
	_main = E2EHelpers.boot(self, config, _path)
	_flow = _main.get_node("GameFlow")
	await wait_process_frames(1)


func _ui() -> CanvasLayer:
	return _main.get_node("UiLayer")


## The score screen is deliberately held back until the corpse has finished falling.
func _await_death_screen() -> DeathScreen:
	await wait_seconds(_flow.death_screen_delay + 0.1)
	return _ui().get_node_or_null("DeathScreen") as DeathScreen


func _die_in_the_void() -> void:
	_flow.start_run()
	await wait_physics_frames(5)
	_flow.game.player.global_position = Vector3(0, -12, 0)
	await wait_physics_frames(6)
	assert_eq(_flow.state, GameFlow.State.DEAD)


func test_contact_death_shows_screen_and_saves_score() -> void:
	await _boot(E2EHelpers.weeper_config())
	_flow.start_run()
	await wait_physics_frames(30)
	var enemy := E2EHelpers.first_enemy(_flow.game)
	assert_not_null(enemy, "a weeper spawned")
	await wait_physics_frames(30)
	_flow.game.player.global_position = enemy.global_position
	await wait_physics_frames(4)
	assert_eq(_flow.state, GameFlow.State.DEAD)
	assert_signal_emitted_with_parameters(EventBus, "player_died", [&"enemy"])
	assert_false(RunManager.is_running())
	assert_null(_ui().get_node_or_null("DeathScreen"), "the corpse view gets its moment first")
	var screen: DeathScreen = await _await_death_screen()
	assert_not_null(screen, "then the score screen")
	assert_eq(_flow.game.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_true(FileAccess.file_exists(ProjectSettings.globalize_path(_path)), "score saved on death")
	screen.name_submitted.emit("DUBSTABBER")
	var data := LeaderboardStore.new(_path).load()
	assert_eq(data.entries.size(), 1)
	assert_eq(data.entries[0].player_name, "DUBSTABBER")
	assert_true(data.entries[0].time_survived > 0.5)


func test_void_death_and_retry() -> void:
	await _boot(E2EHelpers.weeper_config())
	await _die_in_the_void()
	assert_signal_emitted_with_parameters(EventBus, "player_died", [&"void"])
	var old_game := _flow.game
	E2EHelpers.press_action(self, &"retry")
	await wait_process_frames(1)
	assert_eq(_flow.state, GameFlow.State.PLAYING)
	assert_ne(_flow.game, old_game)
	assert_true(RunManager.is_running())
	assert_almost_eq(RunManager.current.elapsed, 0.0, 0.05)


func test_death_presentation() -> void:
	await _boot(E2EHelpers.tiny_config())
	_flow.start_run()
	assert_true(AudioManager.is_music_playing(), "drone plays during the run")
	await _die_in_the_void()
	assert_false(AudioManager.is_music_playing(), "music stops on death")
	assert_true(AudioManager.is_playing_cue(_flow.death_cue), "death stinger plays")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	await wait_seconds(_flow.screen_fade_duration + 0.1)
	var post: PostProcessController = _flow.post_process
	assert_almost_eq(float(post.get_parameter(&"crush_gamma")), _flow.death_profile.crush_gamma, 0.01,
		"death profile applied after the fade")


func test_tier_up_pulses_and_plays_cue_only_while_playing() -> void:
	await _boot(E2EHelpers.tiny_config())
	_flow.start_run()
	var post: PostProcessController = _flow.post_process
	var base := float(post.get_parameter(&"brightness"))
	RunManager.current.add_gems(RunManager.current.gems_to_next_tier())
	assert_true(AudioManager.is_playing_cue(_flow.tier_up_cue), "tier-up cue")
	assert_almost_eq(float(post.get_parameter(&"brightness")), base + _flow.tier_pulse_strength, 0.01)
	assert_true(post.is_transitioning())
	_flow.show_menu()
	await wait_seconds(_flow.screen_fade_duration + 0.1)
	AudioManager.reset()
	EventBus.tier_changed.emit(_flow.config.ladder.tier(2), 2)
	assert_eq(AudioManager.playing_count(), 0, "no cue outside PLAYING")
	assert_almost_eq(float(post.get_parameter(&"brightness")), _flow.menu_profile.brightness, 0.01, "no pulse either")


func test_second_death_renames_only_the_second_entry() -> void:
	await _boot(E2EHelpers.tiny_config())
	await _die_in_the_void()
	var screen: DeathScreen = await _await_death_screen()
	screen.retry_button.pressed.emit()
	assert_eq(_flow.state, GameFlow.State.PLAYING, "retry button restarts through the flow")
	await wait_physics_frames(30)
	_flow.game.player.global_position = Vector3(0, -12, 0)
	await wait_physics_frames(6)
	assert_eq(_flow.state, GameFlow.State.DEAD)
	screen = await _await_death_screen()
	screen.name_entry.text = "second"
	screen.submit_name()
	var data := LeaderboardStore.new(_path).load()
	assert_eq(data.entries.size(), 2)
	assert_eq(data.entries[0].player_name, "SECOND", "longer second run ranks first")
	assert_eq(data.entries[1].player_name, LeaderboardEntry.DEFAULT_NAME)
	assert_true(data.entries[0].time_survived > data.entries[1].time_survived)
	screen.menu_button.pressed.emit()
	assert_eq(_flow.state, GameFlow.State.MENU)
	var menu: MainMenu = _ui().get_node("MainMenu")
	var rows := menu.leaderboard_list.rows()
	assert_eq(rows.size(), 2)
	assert_eq(rows[0].name_label.text, "SECOND", "menu shows the renamed entry")


func test_unranked_death_is_not_saved() -> void:
	var full := LeaderboardData.new()
	for i in full.max_entries:
		full.insert(LeaderboardEntry.make("VET%d" % i, 1000.0 + i))
	assert_eq(LeaderboardStore.new(_path).save(full), OK)
	await _boot(E2EHelpers.tiny_config())
	await _die_in_the_void()
	var screen: DeathScreen = await _await_death_screen()
	assert_eq(screen.rank, -1)
	assert_false(screen.name_box.visible, "no name entry when unranked")
	assert_eq(screen.rank_label.text, "UNRANKED")
	var data := LeaderboardStore.new(_path).load()
	assert_eq(data.entries.size(), full.max_entries)
	for entry in data.entries:
		assert_true(entry.player_name.begins_with("VET"))


func test_arena_shrink_drops_player_into_the_void() -> void:
	await _boot(E2EHelpers.tiny_config())
	_flow.start_run()
	var game := _flow.game
	game.arena_shrinker.start_time = 0.0
	game.arena_shrinker.end_time = 0.5
	game.arena_shrinker.end_radius = 5.0
	game.player.global_position = Vector3(20, 0.2, 0)
	await wait_physics_frames(150)
	assert_almost_eq(game.arena.radius, 5.0, 0.01, "arena shrank")
	assert_eq(_flow.state, GameFlow.State.DEAD)
	assert_signal_emitted_with_parameters(EventBus, "player_died", [&"void"])


## Handed to the death screen the way the engine hands it over on a real window: Godot picks
## the control under the cursor, marks the button handled and calls its _gui_input. A headless
## DisplayServer dispatches no mouse buttons at all, so pushing one through the viewport or
## Input.parse_input_event proves nothing here - that half was verified against a real window,
## where the click lands in DeathScreen._gui_input and restarts the run. This drives the same
## entry point with the same event, which covers everything downstream of the pick.
func _click(button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var screen: DeathScreen = _ui().get_node_or_null("DeathScreen")
	if screen == null:
		return
	var press := InputEventMouseButton.new()
	press.button_index = button
	press.pressed = true
	screen._gui_input(press)


func test_the_body_collapses_and_a_click_restarts_the_run() -> void:
	await _boot(E2EHelpers.tiny_config())
	_flow.start_run()
	await wait_physics_frames(5)
	var player: Player = _flow.game.player
	var rig: Node3D = player.camera_rig
	var eye_height: float = rig.position.y
	assert_gt(eye_height, 1.0, "standing up")
	player.global_position = Vector3(0, -12, 0)
	await wait_physics_frames(6)
	assert_eq(_flow.state, GameFlow.State.DEAD)
	assert_false(_flow.game.can_process(), "the whole Game switches off when the run ends")
	assert_true(player.death_collapse.can_process(), "except the collapse, which still has a job")
	_click()
	await wait_process_frames(1)
	assert_eq(_flow.state, GameFlow.State.DEAD, "the shot already in flight has nothing to click yet")
	assert_false(_flow.death_screen_shown())
	await _await_death_screen()
	assert_true(_flow.death_screen_shown(), "the screen arrives after the fall")
	assert_true(player.death_collapse.has_fallen(), "the body came to rest")
	_click(MOUSE_BUTTON_RIGHT)
	await wait_process_frames(1)
	assert_eq(_flow.state, GameFlow.State.DEAD, "only the left button counts")
	assert_lt(rig.position.y, eye_height - 0.8, "the view went down with it (y %.2f)" % rig.position.y)
	assert_gt(absf(rad_to_deg(rig.rotation.z)), 40.0, "and rolled onto its side")
	_click()
	await wait_process_frames(1)
	assert_eq(_flow.state, GameFlow.State.PLAYING, "a click anywhere on the corpse view restarts")


func test_escape_from_the_corpse_view_goes_back_to_the_menu() -> void:
	await _boot(E2EHelpers.tiny_config())
	await _die_in_the_void()
	E2EHelpers.press_action(self, &"pause")
	await wait_process_frames(1)
	assert_eq(_flow.state, GameFlow.State.MENU)
	assert_not_null(_ui().get_node_or_null("MainMenu"), "back at the menu, not a paused corpse")
	assert_false(RunManager.is_running())
