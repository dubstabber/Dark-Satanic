extends Node3D
## Windowed compile check for the VFX shaders: assigns procedural meshes and
## materials to the showcase children so every shader is actually compiled.

@export var toon_target: MeshInstance3D
@export var floor_target: MeshInstance3D


func _ready() -> void:
	if toon_target != null:
		toon_target.mesh = MeshFactory.skull(0.6)
		toon_target.material_override = MaterialFactory.toon(Color(0.8, 0.8, 0.8), 0.2)
	if floor_target != null:
		floor_target.material_override = MaterialFactory.void_floor(6.0)
