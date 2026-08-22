class_name HUD
extends Control
## In-run overlay: timer, gems, tier, kills and crosshair. Labels update only from RunState
## signals; nothing is polled.

@onready var timer_label: Label = %TimerLabel
@onready var gems_label: Label = %GemsLabel
@onready var tier_label: Label = %TierLabel
@onready var kills_label: Label = %KillsLabel
@onready var crosshair: Control = %Crosshair

var _run_state: RunState


func bind(run_state: RunState) -> void:
	unbind()
	if run_state == null:
		return
	_run_state = run_state
	_run_state.time_changed.connect(_on_time_changed)
	_run_state.gems_changed.connect(_on_gems_changed)
	_run_state.kills_changed.connect(_on_kills_changed)
	_run_state.tier_changed.connect(_on_tier_changed)
	_on_time_changed(run_state.elapsed)
	_on_gems_changed(run_state.gems)
	_on_kills_changed(run_state.kills)
	_on_tier_changed(null, run_state.tier_index)


func unbind() -> void:
	if _run_state == null:
		return
	_run_state.time_changed.disconnect(_on_time_changed)
	_run_state.gems_changed.disconnect(_on_gems_changed)
	_run_state.kills_changed.disconnect(_on_kills_changed)
	_run_state.tier_changed.disconnect(_on_tier_changed)
	_run_state = null


func is_bound() -> bool:
	return _run_state != null


func _on_time_changed(elapsed: float) -> void:
	timer_label.text = TimeFormat.seconds(elapsed)


func _on_gems_changed(total: int) -> void:
	gems_label.text = "GEMS %d" % total


func _on_kills_changed(total: int) -> void:
	kills_label.text = "KILLS %d" % total


func _on_tier_changed(_tier: DaggerUpgradeTier, index: int) -> void:
	tier_label.text = TimeFormat.roman(index)
