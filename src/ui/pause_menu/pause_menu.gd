class_name PauseMenu
extends Control
## Pause overlay; keeps processing while the tree is paused and emits intent only.

signal resume_requested
signal menu_requested

@onready var title_label: Label = %TitleLabel
@onready var resume_button: Button = %ResumeButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(resume_requested.emit)
	menu_button.pressed.connect(menu_requested.emit)
	resume_button.grab_focus()


func focus_resume() -> void:
	resume_button.grab_focus()
