class_name LeaderboardList
extends VBoxContainer
## Renders LeaderboardData as a column of LeaderboardRow scenes.

@export var row_scene: PackedScene = preload("res://src/ui/death_screen/leaderboard_row.tscn")
@export var empty_text: String = "NO ONE HAS SURVIVED"

var _empty_label: Label


func render(data: LeaderboardData, highlight_rank: int = -1) -> void:
	clear()
	if data == null or data.entries.is_empty():
		_empty_label = Label.new()
		_empty_label.text = empty_text
		_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_empty_label)
		return
	for i in data.entries.size():
		var row: LeaderboardRow = row_scene.instantiate()
		add_child(row)
		row.set_entry(i, data.entries[i], i == highlight_rank)


func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_empty_label = null


func rows() -> Array[LeaderboardRow]:
	var result: Array[LeaderboardRow] = []
	for child in get_children():
		if child is LeaderboardRow:
			result.append(child)
	return result


func is_empty_state() -> bool:
	return _empty_label != null
