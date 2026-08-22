extends Node
## Application root: builds the persistence store, hands it to GameFlow and starts at
## the menu (or straight into a run with the `--autostart` user argument).

@export var game_flow: GameFlow
@export var leaderboard_path: String = "user://leaderboard.cfg"
## Skip the menu and start a run at once; initialised from `--autostart`, tests set it directly.
@export var autostart: bool = false


func _init() -> void:
	autostart = "--autostart" in OS.get_cmdline_user_args()


func _ready() -> void:
	game_flow.setup(LeaderboardStore.new(leaderboard_path))
	# Deferred: screens cannot be added while this subtree is still being set up.
	if autostart:
		game_flow.start_run.call_deferred()
	else:
		game_flow.show_menu.call_deferred()
