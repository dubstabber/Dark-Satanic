class_name FlockBehavior
extends EnemyBehavior
## Two of the three boid rules over the neighbours inside `radius`, in 3D: pull toward the
## middle of the local flock and match its heading. A wave of flyers then travels as one
## cloud that bunches, splits and rejoins instead of a column of identical chasers.
## SeparationBehavior is the third rule (avoid) and stays its own node.

@export_range(0.1, 30.0, 0.1) var radius: float = 6.0
## Pull toward the flock's centre, in m/s per metre of offset.
@export_range(0.0, 10.0, 0.05) var cohesion: float = 0.5
## How much of the flock's average velocity is matched (m/s per m/s).
@export_range(0.0, 2.0, 0.05) var alignment: float = 0.35


func steer(ctx: EnemyContext, _delta: float) -> Vector3:
	var origin := ctx.body_position()
	var center := Vector3.ZERO
	var flow := Vector3.ZERO
	var count := 0
	for neighbor in ctx.neighbors():
		if not is_instance_valid(neighbor) or not neighbor.is_inside_tree():
			continue
		if origin.distance_squared_to(neighbor.global_position) > radius * radius:
			continue
		center += neighbor.global_position
		flow += FlockBehavior.velocity_of(neighbor)
		count += 1
	if count == 0:
		return Vector3.ZERO
	var flock := float(count)
	return (center / flock - origin) * cohesion + (flow / flock) * alignment


## What a neighbour is actually doing: its mover's velocity (zero for anything else).
static func velocity_of(node: Node3D) -> Vector3:
	if node is Enemy:
		var mover := (node as Enemy).mover
		return mover.velocity if mover != null else Vector3.ZERO
	return Vector3.ZERO
