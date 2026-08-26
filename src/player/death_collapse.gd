class_name PlayerDeathCollapse
extends Node
## Drops the first-person view when the player dies: the camera rig falls from eye height,
## rolls onto its side and settles, so death reads as the body going down rather than as the
## view freezing mid-stride. Nothing else moves - the run is over - so this is the whole
## animation, and it is deliberately in the rig's LOCAL space: a player who died falling into
## the void collapses just the same, wherever the body happens to be.
##
## Runs with PROCESS_MODE_ALWAYS (set on the node in player.tscn) because GameFlow disables
## the entire Game the moment the run ends. This is the one thing left in there with
## something to do, and its own `autonomous` tick is what keeps it going.

signal finished

## The pivot the camera hangs off; when null the sibling named "CameraRig" is used.
@export var rig: Node3D
@export_range(0.05, 5.0, 0.05) var duration: float = 0.9
## Local height the view ends at: a head lying on the floor.
@export_range(0.0, 2.0, 0.01) var fallen_height: float = 0.28
## How far the view rolls onto its side. Which side is drawn from `rng_seed`.
@export_range(0.0, 90.0, 1.0) var roll_deg: float = 74.0
## Where the view ends up looking; negative tips the head back toward the ceiling.
@export_range(-89.0, 89.0, 1.0) var pitch_deg: float = -14.0
## Share of `duration` spent falling. The rest is the settle after the body lands.
@export_range(0.05, 1.0, 0.05) var land_fraction: float = 0.7
## How far the body rebounds off the floor, as a share of the fall.
@export_range(0.0, 1.0, 0.01) var bounce: float = 0.12
@export var rng_seed: int = 0
## Tick itself. Off in tests that step advance(delta) by hand.
@export var autonomous: bool = true

var _rng := RandomNumberGenerator.new()
var _falling: bool = false
var _elapsed: float = 0.0
var _side: float = 1.0
var _start_height: float = 0.0
var _start_pitch: float = 0.0


func _ready() -> void:
	if rng_seed != 0:
		_rng.seed = rng_seed
	if rig == null:
		var parent := get_parent()
		rig = parent.get_node_or_null("CameraRig") as Node3D if parent != null else null


func _physics_process(delta: float) -> void:
	if autonomous:
		advance(delta)


## Begins the collapse from wherever the view currently is.
func start() -> void:
	if _falling or rig == null:
		return
	_falling = true
	_elapsed = 0.0
	_side = 1.0 if _rng.randf() < 0.5 else -1.0
	_start_height = rig.position.y
	_start_pitch = rig.rotation.x


func advance(delta: float) -> void:
	if not _falling or delta <= 0.0:
		return
	_elapsed += delta
	_apply(clampf(_elapsed / maxf(duration, 0.0001), 0.0, 1.0))
	if _elapsed >= duration:
		_falling = false
		finished.emit()


func is_falling() -> bool:
	return _falling


## True once the body has come to rest (and false before it ever started).
func has_fallen() -> bool:
	return not _falling and _elapsed > 0.0


## How far through the collapse the body is, 0..1: it accelerates like a falling body until
## it lands at `land_fraction`, then settles out of the small bounce that follows. Pure, so
## the shape of the fall can be checked without a scene tree.
static func fall_curve(t: float, land: float, rebound: float) -> float:
	var landing := clampf(land, 0.05, 1.0)
	if t <= landing:
		var drop := clampf(t / landing, 0.0, 1.0)
		return drop * drop
	var after := clampf((t - landing) / maxf(1.0 - landing, 0.0001), 0.0, 1.0)
	return 1.0 - sin(after * PI) * (1.0 - after) * rebound


func _apply(t: float) -> void:
	if rig == null:
		return
	var fall := PlayerDeathCollapse.fall_curve(t, land_fraction, bounce)
	rig.position.y = lerpf(_start_height, fallen_height, fall)
	rig.rotation.x = lerpf(_start_pitch, deg_to_rad(pitch_deg), fall)
	rig.rotation.z = deg_to_rad(roll_deg) * _side * fall
