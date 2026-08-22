class_name Arena
extends Node3D
## The circular void platform. `radius` drives the floor mesh, the collision
## shape, the edge ring and the ArenaInfo handed to spawners and enemies.

signal radius_changed(radius: float)

const FLOOR_THICKNESS := 2.0
const RING_WIDTH := 0.4
## Collision shapes are only rebuilt when the radius moved at least this much.
const SHAPE_EPSILON := 0.1

@export_range(1.0, 200.0, 0.5) var start_radius: float = 30.0
## Player; feeds ArenaInfo.target_position.
@export var target: Node3D

var radius: float = 30.0:
	set(value):
		radius = maxf(value, 0.0)
		_apply_radius()
		radius_changed.emit(radius)

var _shape_radius: float = -1.0

@onready var floor_mesh: MeshInstance3D = $Floor
@onready var floor_body: StaticBody3D = $FloorBody
@onready var floor_shape: CollisionShape3D = $FloorBody/CollisionShape3D
@onready var edge_ring: MeshInstance3D = $EdgeRing


func _ready() -> void:
	radius = start_radius


func floor_y() -> float:
	return 0.0


func info() -> ArenaInfo:
	var center := global_position if is_inside_tree() else position
	var target_position := Vector3.ZERO
	if target != null:
		target_position = target.global_position if target.is_inside_tree() else target.position
	return ArenaInfo.new(center, radius, center.y + floor_y(), target_position)


func _apply_radius() -> void:
	if floor_mesh == null:
		return
	var cylinder := floor_mesh.mesh as CylinderMesh
	if cylinder != null:
		cylinder.top_radius = radius
		cylinder.bottom_radius = radius
	var shape := floor_shape.shape as CylinderShape3D
	if shape != null and absf(radius - _shape_radius) >= SHAPE_EPSILON:
		shape.radius = radius
		_shape_radius = radius
	var torus := edge_ring.mesh as TorusMesh
	if torus != null:
		torus.outer_radius = maxf(radius, RING_WIDTH + 0.1)
		torus.inner_radius = torus.outer_radius - RING_WIDTH
