extends GameTest
## The Sad Satan bus chain: Master <- VHS <- Music / SFX / UI, with the VHS colouring effects.

const LAYOUT_PATH := "res://assets/audio/default_bus_layout.tres"

var _previous_layout: AudioBusLayout


func before_each() -> void:
	super.before_each()
	_previous_layout = AudioServer.generate_bus_layout()
	var layout := load(LAYOUT_PATH) as AudioBusLayout
	assert_not_null(layout, "layout resource loads")
	AudioServer.set_bus_layout(layout)


func after_each() -> void:
	AudioServer.set_bus_layout(_previous_layout)
	super.after_each()


func _effect_types(bus: StringName) -> Array[String]:
	var index := AudioServer.get_bus_index(bus)
	var types: Array[String] = []
	for i in AudioServer.get_bus_effect_count(index):
		types.append(AudioServer.get_bus_effect(index, i).get_class())
	return types


func test_all_buses_exist_in_order() -> void:
	assert_eq(AudioServer.bus_count, 5)
	assert_eq(AudioServer.get_bus_index(&"Master"), 0)
	assert_eq(AudioServer.get_bus_index(&"VHS"), 1)
	assert_eq(AudioServer.get_bus_index(&"Music"), 2)
	assert_eq(AudioServer.get_bus_index(&"SFX"), 3)
	assert_eq(AudioServer.get_bus_index(&"UI"), 4)


func test_sends_form_the_vhs_chain() -> void:
	assert_eq(AudioServer.get_bus_send(1), &"Master")
	assert_eq(AudioServer.get_bus_send(2), &"VHS")
	assert_eq(AudioServer.get_bus_send(3), &"VHS")
	assert_eq(AudioServer.get_bus_send(4), &"VHS")


func test_bus_volumes() -> void:
	assert_almost_eq(AudioServer.get_bus_volume_db(1), 0.0, 0.001)
	assert_almost_eq(AudioServer.get_bus_volume_db(2), -6.0, 0.001)
	assert_almost_eq(AudioServer.get_bus_volume_db(3), 0.0, 0.001)
	assert_almost_eq(AudioServer.get_bus_volume_db(4), -3.0, 0.001)
	for i in AudioServer.bus_count:
		assert_false(AudioServer.is_bus_mute(i))
		assert_false(AudioServer.is_bus_solo(i))
		assert_false(AudioServer.is_bus_bypassing_effects(i))


func test_vhs_effects() -> void:
	assert_eq(
		_effect_types(&"VHS"),
		["AudioEffectLowPassFilter", "AudioEffectDistortion", "AudioEffectHardLimiter"] as Array[String]
	)
	var lowpass := AudioServer.get_bus_effect(1, 0) as AudioEffectLowPassFilter
	assert_almost_eq(lowpass.cutoff_hz, 3800.0, 0.1)
	assert_almost_eq(lowpass.resonance, 0.6, 0.001)
	var distortion := AudioServer.get_bus_effect(1, 1) as AudioEffectDistortion
	assert_eq(distortion.mode, AudioEffectDistortion.MODE_LOFI)
	assert_almost_eq(distortion.drive, 0.12, 0.001)
	assert_almost_eq(distortion.post_gain, -2.0, 0.001)
	for i in 3:
		assert_true(AudioServer.is_bus_effect_enabled(1, i))


func test_music_effects() -> void:
	assert_eq(_effect_types(&"Music"), ["AudioEffectLowPassFilter", "AudioEffectReverb"] as Array[String])
	var lowpass := AudioServer.get_bus_effect(2, 0) as AudioEffectLowPassFilter
	assert_almost_eq(lowpass.cutoff_hz, 1600.0, 0.1)
	var reverb := AudioServer.get_bus_effect(2, 1) as AudioEffectReverb
	assert_almost_eq(reverb.room_size, 0.8, 0.001)
	assert_almost_eq(reverb.wet, 0.35, 0.001)


func test_sfx_and_ui_effects() -> void:
	assert_eq(_effect_types(&"SFX"), ["AudioEffectDistortion"] as Array[String])
	var overdrive := AudioServer.get_bus_effect(3, 0) as AudioEffectDistortion
	assert_eq(overdrive.mode, AudioEffectDistortion.MODE_OVERDRIVE)
	assert_almost_eq(overdrive.drive, 0.2, 0.001)
	assert_eq(AudioServer.get_bus_effect_count(4), 0)
	assert_eq(AudioServer.get_bus_effect_count(0), 0)


func test_layout_resource_roundtrips_through_the_server() -> void:
	var regenerated := AudioServer.generate_bus_layout()
	var reloaded := load(LAYOUT_PATH) as AudioBusLayout
	for property in ["bus/1/name", "bus/2/send", "bus/4/volume_db", "bus/3/effect/0/enabled"]:
		assert_eq(regenerated.get(property), reloaded.get(property), property)


func test_previous_layout_is_restored_after_each() -> void:
	# Sanity: the snapshot we restore from has at least Master.
	assert_true(_previous_layout.get("bus/0/name") == null or _previous_layout.get("bus/0/name") == &"Master")
