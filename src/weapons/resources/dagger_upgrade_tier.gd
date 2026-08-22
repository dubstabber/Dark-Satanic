class_name DaggerUpgradeTier
extends Resource
## One rung of the dagger upgrade ladder. All numbers a designer tunes per tier.

@export var display_name: String = "I"
@export var gems_required: int = 0

@export_group("Stream (hold primary)")
@export_range(1.0, 60.0, 0.5) var stream_rate: float = 15.0
@export_range(1, 8) var stream_daggers_per_shot: int = 1
@export_range(0.0, 15.0, 0.1) var stream_spread_deg: float = 1.5

@export_group("Shotgun (press secondary)")
@export_range(1, 64) var shotgun_pellets: int = 12
@export_range(0.0, 45.0, 0.5) var shotgun_spread_deg: float = 12.0
@export_range(0.05, 3.0, 0.01) var shotgun_cooldown: float = 0.6

@export_group("Projectile")
@export_range(0.1, 20.0, 0.1) var damage: float = 1.0
@export_range(5.0, 200.0, 1.0) var projectile_speed: float = 60.0
@export_range(0.1, 5.0, 0.05) var projectile_lifetime: float = 1.0
@export var homing: bool = false
@export_range(0.0, 720.0, 1.0) var homing_turn_rate_deg: float = 0.0
@export_range(0.0, 100.0, 1.0) var homing_acquire_range: float = 0.0

@export_group("Visual")
@export_range(0.5, 3.0, 0.05) var dagger_scale: float = 1.0
@export_range(0.0, 8.0, 0.1) var emission_energy: float = 1.0
