class_name GemPickup
extends Area3D
## A gem dropped by an enemy. Scatters ballistically, rests spinning, then flies to any
## collector (an Area3D on the PICKUP layer with `collect`) that enters the MagnetArea.
## The collector calls `consume()` once the gem overlaps the collector itself.

enum State { SCATTER, REST, MAGNET, COLLECTED, FALL }

@export var stats: GemStats
## Height of the ground the gem lands on.
@export var floor_y: float = 0.0
## Anything with `func info() -> ArenaInfo`; keeps the gem on the platform and drops it into
## the void when the platform shrinks away from under it. Optional.
@export var arena: Node
## Horizontal margin kept from the platform edge when landing.
@export_range(0.0, 5.0, 0.05) var edge_margin: float = 0.5
## Depth below the floor at which a fallen gem is freed.
@export_range(0.0, 50.0, 0.5) var fall_depth: float = 2.0
## Octahedron (half extents) built in _ready when the Mesh child has no mesh.
@export_range(0.01, 5.0, 0.01) var mesh_half_width: float = 0.3
@export_range(0.01, 5.0, 0.01) var mesh_half_height: float = 0.45
## Bigger area that acquires the magnet target; when null the child "MagnetArea" is used.
@export var magnet_area: Area3D
## Mesh that spins; when null the first MeshInstance3D child is used.
@export var mesh_instance: MeshInstance3D

var state: State = State.SCATTER
var velocity: Vector3 = Vector3.ZERO
var magnet_target: Node3D
var age: float = 0.0
var value: int:
	get:
		return stats.value if stats != null else 1


func _ready() -> void:
	if stats == null:
		stats = GemStats.new()
	if magnet_area == null:
		magnet_area = get_node_or_null("MagnetArea") as Area3D
	if mesh_instance == null:
		for child in get_children():
			if child is MeshInstance3D:
				mesh_instance = child
				break
	if mesh_instance != null and mesh_instance.mesh == null:
		mesh_instance.mesh = GemMesh.octahedron(mesh_half_width, mesh_half_height)
	_apply_magnet_radius()
	area_entered.connect(_on_area_entered)
	if magnet_area != null:
		magnet_area.area_entered.connect(_on_magnet_area_entered)


func _physics_process(delta: float) -> void:
	advance(delta)


## Initial launch velocity (random horizontal direction, speed and upward kick).
func scatter(rng: RandomNumberGenerator) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
	if stats == null:
		stats = GemStats.new()
	var angle := rng.randf_range(0.0, TAU)
	var speed := rng.randf_range(stats.scatter_speed_min, stats.scatter_speed_max)
	velocity = Vector3(cos(angle) * speed, stats.scatter_up, sin(angle) * speed)
	state = State.SCATTER


func advance(delta: float) -> void:
	if state == State.COLLECTED or delta <= 0.0:
		return
	age += delta
	match state:
		State.SCATTER:
			_advance_scatter(delta)
		State.REST:
			_spin(delta)
			if not _on_platform():
				state = State.FALL
		State.MAGNET:
			_advance_magnet(delta)
		State.FALL:
			_advance_fall(delta)
	if stats.lifetime > 0.0 and age >= stats.lifetime and state != State.MAGNET:
		_expire()


func consume() -> void:
	if state == State.COLLECTED:
		return
	state = State.COLLECTED
	if stats.collect_cue != null:
		AudioManager.play(stats.collect_cue, global_position)
	_spawn_collect_vfx()
	set_deferred("monitoring", false)
	queue_free()


func rest_y() -> float:
	return floor_y + stats.rest_height


func _advance_scatter(delta: float) -> void:
	velocity.y -= stats.scatter_gravity * delta
	global_position += velocity * delta
	if velocity.y <= 0.0 and global_position.y <= rest_y():
		global_position.y = rest_y()
		velocity = Vector3.ZERO
		var info := arena_info()
		if info != null:
			global_position = info.clamp_to_platform(global_position, edge_margin)
		state = State.MAGNET if _has_magnet_target() else State.REST


## Drops into the void; freed once `fall_depth` below the floor.
func _advance_fall(delta: float) -> void:
	velocity.y -= stats.scatter_gravity * delta
	global_position += velocity * delta
	if global_position.y <= floor_y - fall_depth:
		_expire()


func arena_info() -> ArenaInfo:
	if arena == null or not is_instance_valid(arena) or not arena.has_method("info"):
		return null
	var info: Variant = arena.call("info")
	return info if info is ArenaInfo else null


func _on_platform() -> bool:
	var info := arena_info()
	return info == null or info.is_on_platform(global_position)


func _spawn_collect_vfx() -> void:
	if stats.collect_vfx == null or get_parent() == null or not is_inside_tree():
		return
	var parent := get_parent()
	var vfx := stats.collect_vfx.instantiate()
	if vfx is Node3D:
		vfx.position = parent.to_local(global_position) if parent is Node3D else global_position
	parent.add_child.call_deferred(vfx)


func _has_magnet_target() -> bool:
	return magnet_target != null and is_instance_valid(magnet_target) and magnet_target.is_inside_tree()


func _advance_magnet(delta: float) -> void:
	if not _has_magnet_target():
		magnet_target = null
		velocity = Vector3.ZERO
		state = State.REST
		return
	var to_target := magnet_target.global_position - global_position
	if to_target.length_squared() > 0.0001:
		velocity += to_target.normalized() * stats.magnet_accel * delta
	velocity = velocity.limit_length(stats.magnet_max_speed)
	global_position += velocity * delta


func _spin(delta: float) -> void:
	if mesh_instance != null and stats.spin_speed > 0.0:
		mesh_instance.rotate_y(stats.spin_speed * delta)


func _expire() -> void:
	state = State.COLLECTED
	queue_free()


func _apply_magnet_radius() -> void:
	if magnet_area == null:
		return
	for child in magnet_area.get_children():
		if child is CollisionShape3D and child.shape is SphereShape3D:
			var shape := (child.shape as SphereShape3D).duplicate() as SphereShape3D
			shape.radius = stats.magnet_radius
			child.shape = shape


func _on_magnet_area_entered(area: Area3D) -> void:
	if state == State.COLLECTED or not area.has_method("collect"):
		return
	magnet_target = area
	# A scattering gem finishes its arc first; the magnet takes over once landed.
	if state == State.REST:
		state = State.MAGNET


func _on_area_entered(area: Area3D) -> void:
	if state == State.COLLECTED or not area.has_method("collect"):
		return
	area.call("collect", self)
