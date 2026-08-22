extends GameTest

const PauseScene := preload("res://src/ui/pause_menu/pause_menu.tscn")

var _menu: PauseMenu


func before_each() -> void:
	super.before_each()
	_menu = PauseScene.instantiate()
	add_child_autofree(_menu)
	watch_signals(_menu)


func test_title_and_process_mode() -> void:
	assert_eq(_menu.title_label.text, "PAUSED")
	assert_eq(_menu.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_not_null(_menu.theme)


func test_resume_button_emits() -> void:
	_menu.resume_button.pressed.emit()
	assert_signal_emitted(_menu, "resume_requested")
	assert_signal_not_emitted(_menu, "menu_requested")


func test_menu_button_emits() -> void:
	_menu.menu_button.pressed.emit()
	assert_signal_emitted(_menu, "menu_requested")
	assert_signal_not_emitted(_menu, "resume_requested")


func test_resume_has_focus_on_ready_and_can_be_refocused() -> void:
	await wait_process_frames(1)
	assert_true(_menu.resume_button.has_focus())
	_menu.menu_button.grab_focus()
	_menu.focus_resume()
	assert_true(_menu.resume_button.has_focus())


func test_buttons_still_work_while_tree_is_paused() -> void:
	get_tree().paused = true
	assert_true(_menu.can_process())
	_menu.resume_button.pressed.emit()
	get_tree().paused = false
	assert_signal_emitted(_menu, "resume_requested")
