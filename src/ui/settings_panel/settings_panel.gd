class_name SettingsPanel
extends Control
## Sliders for mouse sensitivity and volumes. Values come in via bind() and go out as signals;
## this panel never touches the settings autoload.

signal sensitivity_changed(value: float)
signal volume_changed(bus: StringName, value: float)
signal closed

@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	sensitivity_slider.value_changed.connect(sensitivity_changed.emit)
	master_slider.value_changed.connect(_on_volume.bind(&"Master"))
	music_slider.value_changed.connect(_on_volume.bind(&"Music"))
	sfx_slider.value_changed.connect(_on_volume.bind(&"SFX"))
	close_button.pressed.connect(closed.emit)
	sensitivity_slider.grab_focus()


## Sets every slider without emitting any change signal.
func bind(sensitivity: float, master: float, music: float, sfx: float) -> void:
	sensitivity_slider.set_value_no_signal(sensitivity)
	master_slider.set_value_no_signal(master)
	music_slider.set_value_no_signal(music)
	sfx_slider.set_value_no_signal(sfx)


func _on_volume(value: float, bus: StringName) -> void:
	volume_changed.emit(bus, value)
