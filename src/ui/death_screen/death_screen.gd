class_name DeathScreen
extends Control
## Post-run overlay: stats, rank, optional name entry and the leaderboard. Emits intent only.

signal retry_requested
signal menu_requested
signal name_submitted(name: String)

const MAX_NAME_LENGTH := 12
const DEFAULT_NAME := LeaderboardEntry.DEFAULT_NAME

@onready var title_label: Label = %TitleLabel
@onready var time_label: Label = %TimeLabel
@onready var gems_label: Label = %GemsLabel
@onready var kills_label: Label = %KillsLabel
@onready var rank_label: Label = %RankLabel
@onready var name_entry: LineEdit = %NameEntry
@onready var submit_button: Button = %SubmitButton
@onready var name_box: Control = %NameBox
@onready var leaderboard_list: LeaderboardList = %LeaderboardList
## The board's viewport. It is the only thing in the column that expands, which is what
## keeps RETRY / MENU on screen no matter how many rows the board holds.
@onready var board_scroll: ScrollContainer = %BoardScroll
@onready var retry_button: Button = %RetryButton
@onready var menu_button: Button = %MenuButton

var rank: int = -1


func _ready() -> void:
	name_entry.max_length = MAX_NAME_LENGTH
	submit_button.pressed.connect(submit_name)
	name_entry.text_submitted.connect(func(_text: String) -> void: submit_name())
	retry_button.pressed.connect(retry_requested.emit)
	menu_button.pressed.connect(menu_requested.emit)


func show_result(result: RunResult, data: LeaderboardData, p_rank: int) -> void:
	rank = p_rank
	time_label.text = "TIME %s" % TimeFormat.seconds(result.time_survived)
	gems_label.text = "GEMS %d" % result.gems
	kills_label.text = "KILLS %d" % result.kills
	rank_label.text = "RANK #%d" % (p_rank + 1) if p_rank >= 0 else "UNRANKED"
	name_box.visible = p_rank >= 0
	name_entry.text = DEFAULT_NAME
	leaderboard_list.render(data, p_rank)
	if p_rank >= 0:
		name_entry.grab_focus()
		name_entry.select_all()
	else:
		retry_button.grab_focus()


## Emits name_submitted with the trimmed, upper-cased name (ANON when blank) and hides the entry.
func submit_name() -> void:
	name_submitted.emit(sanitize_name(name_entry.text))
	name_box.visible = false
	retry_button.grab_focus()


static func sanitize_name(raw: String) -> String:
	var text := raw.strip_edges().to_upper().left(MAX_NAME_LENGTH)
	return text if not text.is_empty() else DEFAULT_NAME
