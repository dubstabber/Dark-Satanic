extends GameTest

const DeathScene := preload("res://src/ui/death_screen/death_screen.tscn")

var _screen: DeathScreen
var _frame: Control


func before_each() -> void:
	super.before_each()
	# The screen fills whatever it is parented to, and the GUT tree is not the game
	# window. Pin it to the real viewport size so the layout tests below mean something.
	_frame = Control.new()
	_frame.name = "Viewport1280x720"
	add_child_autofree(_frame)
	_frame.size = Vector2(1280, 720)
	_screen = DeathScene.instantiate()
	_frame.add_child(_screen)
	watch_signals(_screen)


func test_the_fixture_really_is_window_sized() -> void:
	await wait_process_frames(2)
	assert_almost_eq(_screen.size, Vector2(1280, 720), Vector2.ONE * 0.5)


func _board(count: int) -> LeaderboardData:
	var data := LeaderboardData.new()
	for i in count:
		data.insert(LeaderboardEntry.make("P%d" % i, float(i + 1) * 10.0, i, i, i))
	return data


func _result(time: float = 25.5) -> RunResult:
	return RunResult.new(time, 14, 9, 2, &"enemy", 123)


func test_title_and_signals_from_buttons() -> void:
	assert_eq(_screen.title_label.text, "REQUIESCAT")
	_screen.retry_button.pressed.emit()
	assert_signal_emitted(_screen, "retry_requested")
	_screen.menu_button.pressed.emit()
	assert_signal_emitted(_screen, "menu_requested")


func test_ranked_result_populates_and_shows_name_entry() -> void:
	var data := _board(3)
	var rank := data.insert(LeaderboardEntry.make("ANON", 25.5, 14, 2, 9))
	assert_eq(rank, 1)
	_screen.show_result(_result(), data, rank)
	assert_eq(_screen.time_label.text, "TIME 25.50")
	assert_eq(_screen.gems_label.text, "GEMS 14")
	assert_eq(_screen.kills_label.text, "KILLS 9")
	assert_eq(_screen.rank_label.text, "RANK #2")
	assert_eq(_screen.rank, 1)
	assert_true(_screen.name_box.visible)
	assert_eq(_screen.name_entry.text, "ANON")
	assert_eq(_screen.name_entry.max_length, 12)
	await wait_process_frames(1)
	assert_true(_screen.name_entry.has_focus())


func test_unranked_result_hides_name_entry() -> void:
	_screen.show_result(_result(0.2), _board(3), -1)
	assert_eq(_screen.rank_label.text, "UNRANKED")
	assert_false(_screen.name_box.visible)
	assert_eq(_screen.leaderboard_list.rows().size(), 3)
	for row in _screen.leaderboard_list.rows():
		assert_false(row.highlighted)
	await wait_process_frames(1)
	assert_true(_screen.retry_button.has_focus())


func test_ranked_row_is_highlighted() -> void:
	var data := _board(3)
	var rank := data.insert(LeaderboardEntry.make("ME", 25.5))
	_screen.show_result(_result(), data, rank)
	var rows := _screen.leaderboard_list.rows()
	assert_eq(rows.size(), 4)
	for i in rows.size():
		assert_eq(rows[i].highlighted, i == rank, "only row %d highlighted" % rank)
	assert_eq(rows[rank].name_label.text, "ME")
	assert_same(rows[rank].get_theme_stylebox("panel"), LeaderboardRow.HIGHLIGHT_STYLE)
	assert_same(rows[0].get_theme_stylebox("panel"), LeaderboardRow.NORMAL_STYLE)


func test_row_shows_every_column() -> void:
	_screen.show_result(_result(), _board(1), -1)
	var row := _screen.leaderboard_list.rows()[0]
	assert_eq(row.rank_label.text, "#1")
	assert_eq(row.name_label.text, "P0")
	assert_eq(row.time_label.text, "10.00")
	assert_eq(row.gems_label.text, "0")
	assert_eq(row.tier_label.text, "I")


func test_submit_emits_trimmed_upper_name_and_hides_entry() -> void:
	_screen.show_result(_result(), _board(0), 0)
	_screen.name_entry.text = "  zed  "
	_screen.submit_button.pressed.emit()
	assert_signal_emitted_with_parameters(_screen, "name_submitted", ["ZED"])
	assert_false(_screen.name_box.visible)


func test_submit_blank_name_defaults_to_anon() -> void:
	_screen.show_result(_result(), _board(0), 0)
	_screen.name_entry.text = "   "
	_screen.name_entry.text_submitted.emit(_screen.name_entry.text)
	assert_signal_emitted_with_parameters(_screen, "name_submitted", ["ANON"])


func test_sanitize_name_truncates_to_12() -> void:
	assert_eq(DeathScreen.sanitize_name("abcdefghijklmnop"), "ABCDEFGHIJKL")
	assert_eq(DeathScreen.sanitize_name(""), "ANON")
	assert_eq(DeathScreen.sanitize_name(" ok "), "OK")


func test_show_result_resets_name_and_rerenders() -> void:
	_screen.show_result(_result(), _board(2), 0)
	_screen.name_entry.text = "OLD"
	_screen.submit_button.pressed.emit()
	_screen.show_result(_result(), _board(5), -1)
	await wait_process_frames(1)
	assert_eq(_screen.name_entry.text, "ANON")
	assert_false(_screen.name_box.visible)
	assert_eq(_screen.leaderboard_list.rows().size(), 5)


func test_highlighting_a_row_does_not_change_its_height() -> void:
	_screen.show_result(_result(), _board(4), -1)
	await wait_process_frames(2)
	var rows := _screen.leaderboard_list.rows()
	var plain := rows[0].size.y
	rows[0].set_highlighted(true)
	await wait_process_frames(2)
	assert_almost_eq(rows[0].size.y, plain, 0.5, "the list must not jump when a row lights up")


func test_the_board_lives_in_a_vertical_only_scroll_container() -> void:
	assert_not_null(_screen.board_scroll)
	assert_eq(_screen.board_scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	assert_same(_screen.leaderboard_list.get_parent(), _screen.board_scroll)


func test_a_full_board_scrolls_instead_of_growing_the_column() -> void:
	_screen.show_result(_result(), _board(10), -1)
	await wait_process_frames(2)
	var list: Control = _screen.leaderboard_list
	assert_eq(list.rows().size(), 10)
	assert_gt(list.size.y, _screen.board_scroll.size.y, "ten rows overflow the viewport")
	assert_true(_screen.board_scroll.get_v_scroll_bar().visible, "so the scrollbar appears")


func test_a_short_board_needs_no_scrollbar() -> void:
	_screen.show_result(_result(), _board(2), -1)
	await wait_process_frames(2)
	assert_false(_screen.board_scroll.get_v_scroll_bar().visible)


func test_a_full_board_never_pushes_the_buttons_off_screen() -> void:
	_screen.show_result(_result(), _board(10), 0)
	await wait_process_frames(2)
	var screen_rect := _screen.get_global_rect()
	assert_gt(screen_rect.size.y, 0.0, "the screen has been laid out")
	for button: Button in [_screen.retry_button, _screen.menu_button, _screen.submit_button]:
		assert_true(
			screen_rect.encloses(button.get_global_rect()),
			"%s at %s escaped %s" % [button.name, button.get_global_rect(), screen_rect]
		)
