class_name GemPickup
extends Area3D
## A gem dropped by an enemy. Scatters ballistically, rests spinning, then flies to any
## collector (an Area3D on the PICKUP layer with `collect`) that enters the MagnetArea.
## The collector calls `consume()` once the gem overlaps the collector itself.

enum State { SCATTER, REST, MAGNET, COLLECTED }

@export var stats: GemStats
## Height of the ground the gem lands on.
@export var floor_y: float = 0.0
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
		mesh_instance.mesh = GemMesh.octahedron(0.3, 0.45)
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
		State.MAGNET:
			_advance_magnet(delta)
	if stats.lifetime > 0.0 and age >= stats.lifetime and state != State.MAGNET:
		_expire()


func consume() -> void:
	if state == State.COLLECTED:
		return
	state = State.COLLECTED
	if stats.collect_cue != null:
		AudioManager.play(stats.collect_cue, global_position)
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
		state = State.MAGNET if _has_magnet_target() else State.REST


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
