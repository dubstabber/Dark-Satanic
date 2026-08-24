class_name SelfKnockback
extends Node
## Devil-Daggers shotgun jumping: a volley fired into a surface close enough to
## push off shoves the player away from it, so shooting the floor on the way up
## turns an ordinary jump into a launch.
##
## The geometry is KnockbackSolver's; this node only owns the ray and hands the
## impulse to the MovementController. It is inert until a weapon reports a shot.

signal knocked(impulse: Vector3)

## Only level geometry pushes back. Enemies deliberately do not: point-blank shots at
## a swarm are the whole game, and being flung backwards by every one of them would
## fight the player instead of arming them.
const PUSH_MASK := PhysicsLayers.WORLD

## Movement to push; when null the first MovementController sibling is used.
@export var movement: MovementController
## Where the shot ray starts and points (the camera).
@export var aim_source: Node3D

@export_group("Strength")
## Push (m/s) from one full-strength shotgun volley fired straight into a surface.
## Roughly a second jump's worth: 7 on top of the 7 m/s jump quadruples the apex.
@export_range(0.0, 40.0, 0.1) var shotgun_impulse: float = 7.0
## Push (m/s) per stream dagger. 0 by default: a 15-a-second stream that shoved you
## would fly the player around on its own.
@export_range(0.0, 5.0, 0.01) var stream_impulse: float = 0.0
## Share of the push that survives while standing on the floor — the ground absorbs
## the rest, so a real shotgun jump needs an actual jump under it.
@export_range(0.0, 1.0, 0.05) var grounded_scale: float = 0.25

@export_group("Range")
## Full push at this distance to the surface or nearer.
@export_range(0.1, 20.0, 0.1) var full_range: float = 3.0
## No push at all past this.
@export_range(0.5, 40.0, 0.1) var max_range: float = 8.0

@export_group("Limits")
## Upward speed the push may not carry the player past (0 = uncapped).
@export_range(0.0, 60.0, 0.5) var max_up_speed: float = 15.0
## Horizontal speed the push may not carry the player past (0 = uncapped).
@export_range(0.0, 60.0, 0.5) var max_horizontal_speed: float = 24.0

var last_impulse: Vector3 = Vector3.ZERO
var last_distance: float = -1.0


func _ready() -> void:
	if movement == null:
		movement = _find_sibling_movement()


## Hook for WeaponHolder.weapon_fired.
func on_fired(count: int, mode: StringName) -> void:
	if movement == null or aim_source == null:
		return
	var direction := -aim_source.global_basis.z.normalized()
	last_distance = surface_distance(direction)
	last_impulse = KnockbackSolver.impulse(
		direction, last_distance, strength_for(count, mode, movement.is_on_floor()), full_range, max_range
	)
	if last_impulse.is_zero_approx():
		return
	movement.add_impulse(last_impulse, max_horizontal_speed, max_up_speed)
	knocked.emit(last_impulse)


## Push for one report from the weapon. A volley pushes once however many pellets
## it threw; a stream pushes per dagger.
func strength_for(count: int, mode: StringName, on_floor: bool) -> float:
	var strength := shotgun_impulse if mode == &"shotgun" else stream_impulse * maxi(count, 0)
	return strength * (grounded_scale if on_floor else 1.0)


## Distance from the aim source to the surface it is pointed at, or -1 when nothing
## is within `max_range`.
func surface_distance(direction: Vector3) -> float:
	if aim_source == null or not aim_source.is_inside_tree():
		return -1.0
	var world := aim_source.get_world_3d()
	if world == null:
		return -1.0
	var origin := aim_source.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * max_range, PUSH_MASK)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result := world.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return -1.0
	return origin.distance_to(result["position"])


func _find_sibling_movement() -> MovementController:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is MovementController:
			return child
	return null
