class_name MainMenu
extends Control
## Title screen. Emits intent signals only; GameFlow decides what happens.

signal play_requested
signal settings_requested
signal quit_requested

@onready var title_label: Label = %TitleLabel
@onready var start_button: Button = %StartButton
@onready var leaderboard_button: Button = %LeaderboardButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var leaderboard_panel: Control = %LeaderboardPanel
@onready var leaderboard_list: LeaderboardList = %LeaderboardList


func _ready() -> void:
	start_button.pressed.connect(play_requested.emit)
	settings_button.pressed.connect(settings_requested.emit)
	quit_button.pressed.connect(quit_requested.emit)
	leaderboard_button.pressed.connect(toggle_leaderboard)
	leaderboard_panel.visible = false
	start_button.grab_focus()


func show_leaderboard(data: LeaderboardData) -> void:
	leaderboard_list.render(data)


func toggle_leaderboard() -> void:
	leaderboard_panel.visible = not leaderboard_panel.visible


func focus_start() -> void:
	start_button.grab_focus()
