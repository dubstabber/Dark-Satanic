extends GameTest

const MenuScene := preload("res://src/ui/main_menu/main_menu.tscn")

var _menu: MainMenu


func before_each() -> void:
	super.before_each()
	_menu = MenuScene.instantiate()
	add_child_autofree(_menu)
	watch_signals(_menu)


func _board(count: int) -> LeaderboardData:
	var data := LeaderboardData.new()
	for i in count:
		data.insert(LeaderboardEntry.make("P%d" % i, float(i + 1)))
	return data


func test_title_and_theme() -> void:
	assert_eq(_menu.title_label.text, "DARK SATANIC")
	assert_not_null(_menu.theme)
	assert_not_null(_menu.title_label.label_settings)


func test_start_button_has_focus_on_ready() -> void:
	await wait_process_frames(1)
	assert_true(_menu.start_button.has_focus())


func test_buttons_emit_intent_signals() -> void:
	_menu.start_button.pressed.emit()
	assert_signal_emitted(_menu, "play_requested")
	_menu.settings_button.pressed.emit()
	assert_signal_emitted(_menu, "settings_requested")
	_menu.quit_button.pressed.emit()
	assert_signal_emitted(_menu, "quit_requested")
	assert_signal_emit_count(_menu, "play_requested", 1)


func test_leaderboard_button_toggles_panel() -> void:
	assert_false(_menu.leaderboard_panel.visible)
	_menu.leaderboard_button.pressed.emit()
	assert_true(_menu.leaderboard_panel.visible)
	_menu.leaderboard_button.pressed.emit()
	assert_false(_menu.leaderboard_panel.visible)


func test_show_leaderboard_renders_rows() -> void:
	_menu.show_leaderboard(_board(4))
	var rows := _menu.leaderboard_list.rows()
	assert_eq(rows.size(), 4)
	assert_eq(rows[0].name_label.text, "P3", "best time first")
	assert_eq(rows[0].time_label.text, "4.00")
	assert_eq(rows[0].rank_label.text, "#1")
	assert_eq(rows[3].rank_label.text, "#4")
	for row in rows:
		assert_false(row.highlighted)


func test_show_leaderboard_twice_replaces_rows() -> void:
	_menu.show_leaderboard(_board(5))
	_menu.show_leaderboard(_board(2))
	await wait_process_frames(1)
	assert_eq(_menu.leaderboard_list.rows().size(), 2)
	assert_eq(_menu.leaderboard_list.get_child_count(), 2)


func test_empty_leaderboard_shows_placeholder() -> void:
	_menu.show_leaderboard(LeaderboardData.new())
	assert_eq(_menu.leaderboard_list.rows().size(), 0)
	assert_true(_menu.leaderboard_list.is_empty_state())
	_menu.show_leaderboard(null)
	assert_true(_menu.leaderboard_list.is_empty_state())
	await wait_process_frames(1)
