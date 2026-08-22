class_name GameConfig
extends Resource
## Everything a run needs that a designer might swap: the wave table, the upgrade
## ladder and the arena shrink schedule. Tests point this at tiny tables.

@export var wave_table: WaveTable
@export var ladder: UpgradeLadder
## Optional easing for the arena shrink (x = 0..1 progress, y = 0..1 shrink amount).
@export var shrink_curve: Curve
@export_range(0.1, 5.0, 0.05) var difficulty_scale: float = 1.0
## Seed for the spawn director (0 = random every run).
@export var rng_seed: int = 0
