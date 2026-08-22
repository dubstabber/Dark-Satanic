extends GameTest


func before_each() -> void:
	super.before_each()
	MeshFactory.clear_cache()


func _all_meshes() -> Dictionary:
	return {
		"skull": MeshFactory.skull(0.5),
		"nest": MeshFactory.nest(),
		"stalker_prism": MeshFactory.stalker_prism(),
		"gem_octahedron": MeshFactory.gem_octahedron(),
		"dagger": MeshFactory.dagger(),
		"hand_block": MeshFactory.hand_block(),
	}


func test_every_mesh_non_null_with_surfaces() -> void:
	var meshes := _all_meshes()
	for mesh_name in meshes:
		var mesh: Mesh = meshes[mesh_name]
		assert_not_null(mesh, mesh_name)
		assert_gt(mesh.get_surface_count(), 0, "%s has surfaces" % mesh_name)
		assert_gt(mesh.get_aabb().size.length(), 0.0, "%s has extent" % mesh_name)


func test_cache_returns_same_instance() -> void:
	var first := _all_meshes()
	var second := _all_meshes()
	for mesh_name in first:
		assert_same(first[mesh_name], second[mesh_name], mesh_name)


func test_different_arguments_are_different_meshes() -> void:
	assert_ne(MeshFactory.skull(0.5), MeshFactory.skull(1.0))
	assert_ne(MeshFactory.gem_octahedron(0.3), MeshFactory.gem_octahedron(0.6))
	assert_almost_eq(MeshFactory.skull(1.0).get_aabb().size.x, 2.0, 0.25)


func test_clear_cache_rebuilds() -> void:
	var before := MeshFactory.nest()
	MeshFactory.clear_cache()
	assert_ne(before, MeshFactory.nest())


func test_octahedron_six_vertices_eight_triangles() -> void:
	var mesh := MeshFactory.gem_octahedron(0.3) as ArrayMesh
	assert_not_null(mesh)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_eq(vertices.size(), 6)
	assert_eq(indices.size(), 24, "8 triangles")
	assert_eq(normals.size(), 6)
	assert_almost_eq(mesh.get_aabb().size, Vector3(0.6, 0.84, 0.6), Vector3.ONE * 0.001)


func test_octahedron_winding_faces_outward() -> void:
	var mesh := MeshFactory.gem_octahedron(0.3) as ArrayMesh
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for t in 8:
		var a := vertices[indices[t * 3]]
		var b := vertices[indices[t * 3 + 1]]
		var c := vertices[indices[t * 3 + 2]]
		var face_normal := (b - a).cross(c - a)
		var centroid := (a + b + c) / 3.0
		# Godot front faces wind clockwise, so the CCW cross product points inward.
		assert_lt(face_normal.dot(centroid), 0.0, "triangle %d is clockwise from outside" % t)


func test_dagger_is_longer_than_wide() -> void:
	var aabb := MeshFactory.dagger().get_aabb()
	assert_gt(aabb.size.z, aabb.size.x * 4.0)
	assert_gt(aabb.size.x, aabb.size.y)


func test_skull_is_roughly_radius_sized() -> void:
	var aabb := MeshFactory.skull(0.5).get_aabb()
	assert_almost_eq(aabb.size.y, 1.0, 0.15)
	assert_almost_eq(aabb.size.x, 1.0, 0.15)


func test_skull_has_eye_sockets_pushed_in() -> void:
	var mesh := MeshFactory.skull(1.0)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var socket_dir := Vector3(0.35, 0.15, -0.85).normalized()
	var nearest_socket := 10.0
	var nearest_back := 10.0
	for v in vertices:
		if v.normalized().dot(socket_dir) > 0.95:
			nearest_socket = minf(nearest_socket, v.length())
		if v.normalized().dot(Vector3.BACK) > 0.95:
			nearest_back = minf(nearest_back, v.length())
	assert_lt(nearest_socket, 0.9, "socket vertices sit inside the sphere")
	assert_almost_eq(nearest_back, 1.0, 0.05, "back of the skull is untouched")


func test_skull_triangles_wind_clockwise() -> void:
	var mesh := MeshFactory.skull(0.5)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices = PackedInt32Array(range(vertices.size()))
	var inward := 0
	for t in indices.size() / 3:
		var a := vertices[indices[t * 3]]
		var b := vertices[indices[t * 3 + 1]]
		var c := vertices[indices[t * 3 + 2]]
		var centroid := (a + b + c) / 3.0
		if (b - a).cross(c - a).dot(centroid) > 0.0:
			inward += 1
	assert_eq(inward, 0, "no triangle faces inward")


func test_skull_from_ready_does_not_error() -> void:
	var holder := MeshInstance3D.new()
	holder.ready.connect(func() -> void: holder.mesh = MeshFactory.skull(0.4))
	add_child_autofree(holder)
	assert_not_null(holder.mesh)
	assert_same(holder.mesh, MeshFactory.skull(0.4))
