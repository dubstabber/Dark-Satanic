class_name LeaderboardRow
extends PanelContainer
## One leaderboard line: rank, name, time, gems, tier. `highlighted` inverts the colours.

const HIGHLIGHT_STYLE := preload("res://src/ui/death_screen/leaderboard_row_highlight.tres")
## The row's resting frame. Assigned rather than removed when un-highlighting: the
## scene sets it as a theme override too, so removing the override would fall back to
## the theme's ornate 96 px PanelContainer frame instead of restoring this.
const NORMAL_STYLE := preload("res://src/ui/death_screen/leaderboard_row_normal.tres")

@onready var rank_label: Label = %RankLabel
@onready var name_label: Label = %NameLabel
@onready var time_label: Label = %TimeLabel
@onready var gems_label: Label = %GemsLabel
@onready var tier_label: Label = %TierLabel

var rank: int = -1
var highlighted: bool = false


func set_entry(p_rank: int, entry: LeaderboardEntry, p_highlighted: bool = false) -> void:
	rank = p_rank
	rank_label.text = "#%d" % (p_rank + 1)
	name_label.text = entry.player_name
	time_label.text = TimeFormat.seconds(entry.time_survived)
	gems_label.text = str(entry.gems)
	tier_label.text = TimeFormat.roman(entry.tier_index)
	set_highlighted(p_highlighted)


func set_highlighted(value: bool) -> void:
	highlighted = value
	var text_color := Color.BLACK if value else Color.WHITE
	var outline := Color.WHITE if value else Color.BLACK
	for label: Label in [rank_label, name_label, time_label, gems_label, tier_label]:
		label.add_theme_color_override("font_color", text_color)
		label.add_theme_color_override("font_outline_color", outline)
	add_theme_stylebox_override("panel", HIGHLIGHT_STYLE if value else NORMAL_STYLE)
