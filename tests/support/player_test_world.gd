class_name PlayerTestWorld
## Helpers for player integration tests: a static floor and a player driven by a
## FakeInputReader.

const PlayerScene := preload("res://src/player/player.tscn")


## A big StaticBody3D slab whose top surface is at y = 0 on the WORLD layer.
static func add_floor(world: Node3D, size: float = 400.0) -> StaticBody3D:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = PhysicsLayers.WORLD
	floor_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 1.0, size)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(shape)
	world.add_child(floor_body)
	return floor_body


## Instantiates player.tscn with `input` injected (a fresh FakeInputReader when null).
static func spawn_player(world: Node3D, input: InputReader = null, at: Vector3 = Vector3(0, 0.05, 0)) -> Player:
	var player: Player = PlayerScene.instantiate()
	if input == null:
		input = FakeInputReader.new()
	input.name = "FakeInput"
	player.add_child(input)
	player.input_reader = input
	player.position = at
	world.add_child(player)
	return player
