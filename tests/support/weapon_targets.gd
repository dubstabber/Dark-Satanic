class_name WeaponTargets
extends RefCounted
## Builders for things daggers can hit in weapon tests.

const HurtboxScene := preload("res://src/components/hurtbox_component.tscn")


## A Node3D body with a HealthComponent and an enemy-layer hurtbox (sphere r=0.5) at `position`.
static func hurtbox_target(world: Node, position: Vector3, max_health: float = 1.0) -> Dictionary:
	var body := Node3D.new()
	body.name = "Target"
	body.position = position
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = max_health
	body.add_child(health)
	var hurtbox: HurtboxComponent = HurtboxScene.instantiate()
	body.add_child(hurtbox)
	world.add_child(body)
	return {"body": body, "health": health, "hurtbox": hurtbox}


## A StaticBody3D on the WORLD layer: a 20x0.2x20 slab whose top surface sits at `top_y`.
static func floor_body(world: Node, top_y: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Floor"
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 0.2, 20.0)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0.0, top_y - 0.1, 0.0)
	world.add_child(body)
	return body


## A pool (size `size`) under a spawner under `world`, both ready. Returns the spawner.
static func spawner(world: Node, size: int = 8, seed: int = 7) -> ProjectileSpawner:
	var pool := ProjectilePool.new()
	pool.name = "ProjectilePool"
	pool.initial_size = size
	var node := ProjectileSpawner.new()
	node.name = "ProjectileSpawner"
	node.rng_seed = seed
	node.add_child(pool)
	world.add_child(node)
	return node
