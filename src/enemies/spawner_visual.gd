class_name SpawnerVisual
extends Node
## Animates a nest's eye: opens as the nest wakes, flares wide and squeezes shut
## again whenever the spawner releases a burst. Purely cosmetic — the weak point
## collision shape never moves.

@export var spawner: SpawnerComponent
@export var eye: Node3D
## Seconds the eye takes to open when the nest first appears.
@export_range(0.0, 10.0, 0.05) var wake_time: float = 2.2
@export_range(1.0, 3.0, 0.05) var burst_scale: float = 1.5
@export_range(0.05, 2.0, 0.05) var open_time: float = 0.18
@export_range(0.05, 3.0, 0.05) var close_time: float = 0.7

var _rest_scale: Vector3 = Vector3.ONE
var _tween: Tween


func _ready() -> void:
	if eye == null:
		return
	_rest_scale = eye.scale
	if spawner != null:
		spawner.burst_released.connect(_on_burst_released)
	eye.scale = _rest_scale * 0.05
	_tween = create_tween()
	_tween.tween_property(eye, "scale", _rest_scale, wake_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_burst_released(_nodes: Array[Node3D]) -> void:
	if eye == null:
		return
	if _tween != null and _tween.is_running():
		_tween.kill()
	eye.scale = _rest_scale
	_tween = create_tween()
	_tween.tween_property(eye, "scale", _rest_scale * burst_scale, open_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(eye, "scale", _rest_scale * 0.25, close_time * 0.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(eye, "scale", _rest_scale, close_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
