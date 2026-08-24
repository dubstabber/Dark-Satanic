class_name PlayerMovementStats
extends Resource
## Every number a designer tunes for Quake-style player movement.

@export_group("Ground")
@export_range(0.0, 50.0, 0.1) var walk_speed: float = 9.0
@export_range(0.0, 100.0, 0.1) var ground_accel: float = 10.0
@export_range(0.0, 50.0, 0.1) var friction: float = 6.0
## Below this horizontal speed friction behaves as if moving at this speed (snappy stops).
@export_range(0.0, 10.0, 0.1) var stop_speed: float = 1.0

@export_group("Air")
@export_range(0.0, 100.0, 0.1) var air_accel: float = 12.0
## Quake air speed cap: strafing only adds speed while the wish-dir component is below this.
@export_range(0.0, 20.0, 0.1) var air_speed_cap: float = 1.0
## Weak full-speed air control so holding forward in the air still steers a little.
@export_range(0.0, 20.0, 0.1) var air_control_accel: float = 0.8
@export_range(0.0, 100.0, 0.1) var gravity: float = 18.0

@export_group("Jump")
@export_range(0.0, 50.0, 0.1) var jump_velocity: float = 7.0
## Horizontal speed multiplier applied on the tick a jump starts (bunny hop gain).
@export_range(1.0, 2.0, 0.01) var jump_horizontal_boost: float = 1.08
## Horizontal speed the jump boost never pushes past.
@export_range(0.0, 100.0, 0.1) var max_bhop_speed: float = 14.0
## Holding jump re-jumps on landing without re-pressing.
@export var auto_bhop: bool = true

@export_group("Jump assist")
## Grace period after walking off an edge in which a jump still works (coyote time).
@export_range(0.0, 0.5, 0.005) var coyote_time: float = 0.1
## A jump pressed this long before touchdown fires the moment the floor is reached,
## so a chained bunny hop is never eaten by a frame of bad timing.
@export_range(0.0, 0.5, 0.005) var jump_buffer_time: float = 0.15

@export_group("Camera")
@export_range(0.0, 89.9, 0.1) var pitch_limit_deg: float = 89.0
@export_range(0.0, 5.0, 0.01) var camera_height: float = 1.6
