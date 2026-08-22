extends Node3D
## Minimal spawnable used by component tests: exposes the inherited `target` property
## and the `died` signal SpawnDirector.is_enemy() looks for.

signal died(enemy: Node3D, last_hit: HitInfo)

var target: Node3D
var arena: Node
var rng_seed: int = 0
