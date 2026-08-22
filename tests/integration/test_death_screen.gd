extends GameTest

const DeathScene := preload("res://src/ui/death_screen/death_screen.tscn")

var _screen: DeathScreen


func before_each() -> void:
	super.before_each()
	_screen = DeathScene.instantiate()
	add_child_autofree(_screen)
	watch_signals(_screen)


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
	assert_true(rows[rank].has_theme_stylebox_override("panel"))
	assert_false(rows[0].has_theme_stylebox_override("panel"))


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
