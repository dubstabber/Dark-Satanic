extends Node
## Owns the current RunState so it outlives the Game scene: `is_running()` and
## `last_result` stay valid after the Game is freed (GameFlow aborts the run when the
## player quits to the menu). Thin on purpose: all run logic lives in RunState /
## UpgradeLadder.

signal run_started(state: RunState)
signal run_ended(result: RunResult)

var current: RunState
var last_result: RunResult


func begin(ladder: UpgradeLadder) -> RunState:
	if current != null and current.is_running:
		finish(&"aborted")
	current = RunState.new(ladder)
	current.ended.connect(_on_run_ended, CONNECT_ONE_SHOT)
	current.start()
	run_started.emit(current)
	EventBus.run_started.emit(current)
	return current


func finish(cause: StringName) -> RunResult:
	if current == null or not current.is_running:
		return last_result
	return current.end(cause)


func is_running() -> bool:
	return current != null and current.is_running


func reset() -> void:
	if current != null and current.is_running:
		current.is_running = false
	current = null
	last_result = null


func _on_run_ended(result: RunResult) -> void:
	last_result = result
	run_ended.emit(result)
	EventBus.run_ended.emit(result)
