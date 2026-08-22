class_name GemStats
extends Resource
## Designer numbers for a gem pickup: worth, scatter arc, magnet pull and looks.

@export_range(0, 1000) var value: int = 1
@export_range(0.0, 50.0, 0.1) var scatter_speed_min: float = 2.0
@export_range(0.0, 50.0, 0.1) var scatter_speed_max: float = 5.0
## Vertical launch speed when scattered.
@export_range(0.0, 50.0, 0.1) var scatter_up: float = 3.0
@export_range(0.0, 100.0, 0.1) var scatter_gravity: float = 12.0
## Height above the floor the gem rests at.
@export_range(0.0, 5.0, 0.01) var rest_height: float = 0.35
## Radius of the MagnetArea (applied to its shape in _ready).
@export_range(0.0, 50.0, 0.1) var magnet_radius: float = 4.0
@export_range(0.0, 500.0, 0.5) var magnet_accel: float = 30.0
@export_range(0.0, 200.0, 0.5) var magnet_max_speed: float = 25.0
## Idle rotation speed (rad/s) while resting.
@export_range(0.0, 50.0, 0.1) var spin_speed: float = 2.0
## Seconds before the gem disappears on its own; 0 = never.
@export_range(0.0, 600.0, 0.5) var lifetime: float = 0.0
@export var collect_cue: AudioCue
