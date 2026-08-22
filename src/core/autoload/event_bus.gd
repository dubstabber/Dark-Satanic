extends Node
## Global signal hub for events whose emitter cannot know its listeners.
## Signals only — no state, no logic. Only src/core and src/game may emit or connect.
##
## Game emits every signal below; GameFlow listens to `tier_changed` (tier-up flash and
## cue). The rest are extension points for future listeners (analytics, VFX directors,
## achievements) and for tests, which is why they exist even without a consumer today.

signal run_started(state: RunState)
signal run_ended(result: RunResult)
signal player_died(cause: StringName)
signal enemy_spawned(enemy: Node3D)
signal enemy_died(enemy: Node3D, position: Vector3)
signal gem_collected(total: int)
signal tier_changed(tier: DaggerUpgradeTier, index: int)
