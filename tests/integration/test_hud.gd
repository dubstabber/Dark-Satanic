extends GameTest

const HudScene := preload("res://src/ui/hud/hud.tscn")
const Ladder := preload("res://src/weapons/resources/default_ladder.tres")

var _hud: HUD
var _state: RunState


func before_each() -> void:
	super.before_each()
	_hud = HudScene.instantiate()
	add_child_autofree(_hud)
	_state = RunState.new(Ladder)
	_state.start()


func test_scene_exposes_typed_children() -> void:
	assert_not_null(_hud.timer_label)
	assert_not_null(_hud.gems_label)
	assert_not_null(_hud.tier_label)
	assert_not_null(_hud.kills_label)
	assert_not_null(_hud.crosshair)
	assert_false(_hud.is_bound())


func test_bind_refreshes_immediately_with_formatted_values() -> void:
	_state.tick(12.345)
	_state.add_gems(12)
	_state.add_kill()
	_hud.bind(_state)
	assert_true(_hud.is_bound())
	assert_eq(_hud.timer_label.text, "12.35")
	assert_eq(_hud.gems_label.text, "GEMS 12")
	assert_eq(_hud.kills_label.text, "KILLS 1")
	assert_eq(_hud.tier_label.text, TimeFormat.roman(_state.tier_index))


func test_signals_update_labels() -> void:
	_hud.bind(_state)
	_state.tick(1.5)
	assert_eq(_hud.timer_label.text, "1.50")
	_state.add_gems(5)
	assert_eq(_hud.gems_label.text, "GEMS 5")
	_state.add_kill()
	_state.add_kill()
	assert_eq(_hud.kills_label.text, "KILLS 2")


func test_tier_label_follows_tier_changes() -> void:
	_hud.bind(_state)
	assert_eq(_hud.tier_label.text, "I")
	var needed := _state.gems_to_next_tier()
	assert_gt(needed, 0, "default ladder has a second tier")
	_state.add_gems(needed)
	assert_eq(_hud.tier_label.text, "II")


func test_unbind_stops_updates() -> void:
	_hud.bind(_state)
	_state.tick(2.0)
	_hud.unbind()
	assert_false(_hud.is_bound())
	_state.tick(3.0)
	_state.add_gems(9)
	_state.add_kill()
	assert_eq(_hud.timer_label.text, "2.00")
	assert_eq(_hud.gems_label.text, "GEMS 0")
	assert_eq(_hud.kills_label.text, "KILLS 0")
	assert_false(_state.time_changed.is_connected(_hud._on_time_changed))


func test_rebind_switches_to_the_new_state() -> void:
	_hud.bind(_state)
	var other := RunState.new(Ladder)
	other.start()
	other.tick(7.0)
	_hud.bind(other)
	assert_eq(_hud.timer_label.text, "7.00")
	_state.tick(100.0)
	assert_eq(_hud.timer_label.text, "7.00", "old state no longer drives the HUD")
	other.tick(1.0)
	assert_eq(_hud.timer_label.text, "8.00")


func test_bind_null_just_unbinds() -> void:
	_hud.bind(_state)
	_hud.bind(null)
	assert_false(_hud.is_bound())
	_hud.unbind()
	assert_false(_hud.is_bound())


func test_crosshair_setters_request_a_redraw() -> void:
	assert_true(_hud.crosshair is Crosshair)
	await wait_process_frames(1)
	watch_signals(_hud.crosshair)
	await wait_process_frames(1)
	assert_signal_not_emitted(_hud.crosshair, "draw", "idle once drawn")
	_hud.crosshair.size_px = 20.0
	await wait_process_frames(1)
	assert_signal_emit_count(_hud.crosshair, "draw", 1, "size setter schedules a redraw")
	_hud.crosshair.color = Color.RED
	await wait_process_frames(1)
	assert_signal_emit_count(_hud.crosshair, "draw", 2, "colour setter schedules a redraw")
	assert_eq(_hud.crosshair.color, Color.RED)


func test_kills_label_uses_the_theme_font_size() -> void:
	assert_false(_hud.kills_label.has_theme_font_size_override("font_size"), "no 16 px override")
	assert_eq(_hud.kills_label.get_theme_font_size("font_size"), _hud.gems_label.get_theme_font_size("font_size"))
