extends Node
## Global signal hub for events whose emitter cannot know its listeners.
## Signals only — no state, no logic. Only src/core and src/game may emit or connect.

signal run_started(state: RunState)
signal run_ended(result: RunResult)
signal player_died(cause: StringName)
signal enemy_spawned(enemy: Node3D)
signal enemy_died(enemy: Node3D, position: Vector3)
signal gem_collected(total: int)
signal tier_changed(tier: DaggerUpgradeTier, index: int)
