extends GameTest


func test_defaults_are_idle() -> void:
	var frame := PlayerInputFrame.new()
	assert_eq(frame.wish_dir, Vector3.ZERO)
	assert_false(frame.jump_pressed)
	assert_false(frame.jump_held)
	assert_false(frame.primary_held)
	assert_false(frame.secondary_pressed)
	assert_eq(frame.look_delta, Vector2.ZERO)
	assert_true(frame.is_idle())
	assert_true(PlayerInputFrame.idle().is_idle())


func test_any_field_makes_it_not_idle() -> void:
	var frame := PlayerInputFrame.new()
	frame.wish_dir = Vector3(0, 0, -1)
	assert_false(frame.is_idle())
	frame = PlayerInputFrame.new()
	frame.jump_held = true
	assert_false(frame.is_idle())
	frame = PlayerInputFrame.new()
	frame.primary_held = true
	assert_false(frame.is_idle())
	frame = PlayerInputFrame.new()
	frame.secondary_pressed = true
	assert_false(frame.is_idle())
	frame = PlayerInputFrame.new()
	frame.look_delta = Vector2(1, 0)
	assert_false(frame.is_idle())


func test_copy_is_independent() -> void:
	var frame := FakeInputReader.frame(Vector3(1, 0, 0), true, true, true, true, Vector2(3, 4))
	var copy := frame.copy()
	assert_eq(copy.wish_dir, frame.wish_dir)
	assert_true(copy.jump_held and copy.jump_pressed and copy.primary_held and copy.secondary_pressed)
	assert_eq(copy.look_delta, Vector2(3, 4))
	copy.wish_dir = Vector3.ZERO
	assert_eq(frame.wish_dir, Vector3(1, 0, 0))


func test_input_reader_maps_axis_onto_yaw_basis() -> void:
	var forward := InputReader.wish_from_axis(Basis.IDENTITY, Vector2(0, -1))
	assert_almost_eq(forward, Vector3(0, 0, -1), Vector3.ONE * 0.0001)
	var right := InputReader.wish_from_axis(Basis.IDENTITY, Vector2(1, 0))
	assert_almost_eq(right, Vector3(1, 0, 0), Vector3.ONE * 0.0001)
	var turned := Basis(Vector3.UP, deg_to_rad(90.0))
	var turned_forward := InputReader.wish_from_axis(turned, Vector2(0, -1))
	assert_almost_eq(turned_forward, Vector3(-1, 0, 0), Vector3.ONE * 0.0001)
	var diagonal := InputReader.wish_from_axis(Basis.IDENTITY, Vector2(1, -1))
	assert_almost_eq(diagonal.length(), 1.0, 0.0001, "never faster than 1")
	assert_eq(diagonal.y, 0.0)


func test_input_reader_wish_ignores_pitch_of_basis() -> void:
	var pitched := Basis(Vector3.RIGHT, deg_to_rad(60.0))
	var forward := InputReader.wish_from_axis(pitched, Vector2(0, -1))
	assert_eq(forward.y, 0.0)
	assert_almost_eq(forward.length(), 1.0, 0.0001)


func test_input_reader_tracks_pressed_edges_per_tick() -> void:
	var reader := InputReader.new()
	autofree(reader)
	Input.action_press(&"jump")
	Input.action_press(&"fire_secondary")
	Input.action_press(&"fire_primary")
	var first := reader.read(Basis.IDENTITY, Vector2(2, 3))
	var second := reader.read(Basis.IDENTITY)
	Input.action_release(&"jump")
	Input.action_release(&"fire_secondary")
	Input.action_release(&"fire_primary")
	var third := reader.read(Basis.IDENTITY)
	assert_true(first.jump_pressed and first.jump_held, "first tick: pressed + held")
	assert_true(first.secondary_pressed)
	assert_true(first.primary_held)
	assert_eq(first.look_delta, Vector2(2, 3))
	assert_true(second.jump_held)
	assert_false(second.jump_pressed, "still held: not pressed again")
	assert_false(second.secondary_pressed)
	assert_eq(second.look_delta, Vector2.ZERO)
	assert_false(third.jump_held)
	assert_false(third.primary_held)
	reader.reset()


func test_input_reader_reads_movement_axis() -> void:
	var reader := InputReader.new()
	autofree(reader)
	Input.action_press(&"move_forward")
	var frame := reader.read(Basis.IDENTITY)
	Input.action_release(&"move_forward")
	assert_almost_eq(frame.wish_dir, Vector3(0, 0, -1), Vector3.ONE * 0.0001)
	assert_eq(reader.read(Basis.IDENTITY).wish_dir, Vector3.ZERO)
