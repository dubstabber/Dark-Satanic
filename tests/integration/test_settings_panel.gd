extends GameTest

const PanelScene := preload("res://src/ui/settings_panel/settings_panel.tscn")

var _panel: SettingsPanel


func before_each() -> void:
	super.before_each()
	_panel = PanelScene.instantiate()
	add_child_autofree(_panel)
	watch_signals(_panel)


func test_slider_ranges() -> void:
	assert_almost_eq(_panel.sensitivity_slider.min_value, 0.0005, 0.00001)
	assert_almost_eq(_panel.sensitivity_slider.max_value, 0.01, 0.00001)
	for slider in [_panel.master_slider, _panel.music_slider, _panel.sfx_slider]:
		assert_eq(slider.min_value, 0.0)
		assert_eq(slider.max_value, 1.0)


func test_bind_sets_sliders_without_emitting() -> void:
	_panel.bind(0.004, 0.5, 0.25, 0.75)
	assert_almost_eq(_panel.sensitivity_slider.value, 0.004, 0.0001)
	assert_almost_eq(_panel.master_slider.value, 0.5, 0.001)
	assert_almost_eq(_panel.music_slider.value, 0.25, 0.001)
	assert_almost_eq(_panel.sfx_slider.value, 0.75, 0.001)
	assert_signal_not_emitted(_panel, "sensitivity_changed")
	assert_signal_not_emitted(_panel, "volume_changed")


func test_sensitivity_slider_emits_value() -> void:
	_panel.sensitivity_slider.value = 0.008
	assert_signal_emitted(_panel, "sensitivity_changed")
	var value: float = get_signal_parameters(_panel, "sensitivity_changed")[0]
	assert_almost_eq(value, 0.008, 0.0001)
	assert_signal_not_emitted(_panel, "volume_changed")


func test_volume_sliders_emit_bus_and_value() -> void:
	_panel.master_slider.value = 0.5
	assert_signal_emitted_with_parameters(_panel, "volume_changed", [&"Master", 0.5])
	_panel.music_slider.value = 0.25
	assert_signal_emitted_with_parameters(_panel, "volume_changed", [&"Music", 0.25])
	_panel.sfx_slider.value = 0.75
	assert_signal_emitted_with_parameters(_panel, "volume_changed", [&"SFX", 0.75])
	assert_signal_emit_count(_panel, "volume_changed", 3)
	assert_signal_not_emitted(_panel, "sensitivity_changed")


func test_setting_same_value_does_not_emit() -> void:
	_panel.bind(0.002, 1.0, 0.8, 1.0)
	_panel.master_slider.value = 1.0
	assert_signal_not_emitted(_panel, "volume_changed")


func test_close_button_emits_closed() -> void:
	_panel.close_button.pressed.emit()
	assert_signal_emitted(_panel, "closed")


func test_sensitivity_has_focus_on_ready() -> void:
	await wait_process_frames(1)
	assert_true(_panel.sensitivity_slider.has_focus())
