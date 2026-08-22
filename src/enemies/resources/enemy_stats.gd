class_name EnemyStats
extends Resource
## Designer-facing numbers for one enemy archetype. Behaviours read speeds from here;
## enemy.gd applies health, scale and contact damage at _ready.

@export var display_name: String = "Enemy"
@export_range(0.0, 1000.0, 0.5) var max_health: float = 1.0
## Top speed in m/s (the mover clamps the blended desired velocity to this).
@export_range(0.0, 100.0, 0.1) var move_speed: float = 5.0
## How fast the actual velocity chases the desired velocity (m/s^2).
@export_range(0.0, 500.0, 1.0) var acceleration: float = 40.0
## Heading turn rate for steering behaviours (deg/s). Low values overshoot the target.
@export_range(0.0, 3600.0, 1.0) var turn_speed_deg: float = 540.0
## Minimum height above the arena floor.
@export_range(0.0, 50.0, 0.05) var min_height: float = 0.45
## Floor enemies are pulled back down to `min_height` when something leaves them in the air
## (e.g. a nest emitting them at hover height). Flyers (nests, vespers) set this false.
@export var grounded: bool = true
@export_range(0.01, 20.0, 0.01) var scale: float = 1.0
@export_range(0, 64) var gem_count: int = 0
@export_range(0.0, 100.0, 0.5) var contact_damage: float = 1.0
## Scale-in time after spawning; the contact hitbox is inactive meanwhile.
@export_range(0.0, 10.0, 0.05) var spawn_duration: float = 0.4
@export var hurt_cue: AudioCue
## Played when a hit lands on an armoured (0-multiplier) hurtbox; optional.
@export var armor_cue: AudioCue
@export var death_cue: AudioCue
@export var spawn_cue: AudioCue
