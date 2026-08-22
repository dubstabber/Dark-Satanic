class_name MeshFactory
extends RefCounted
## Static, cached builders for the game's primitive silhouettes. Every call
## returns a non-null Mesh; the same arguments return the same instance.

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


## Sphere with two eye sockets: CSG-baked when the engine can evaluate it,
## otherwise a SurfaceTool sphere with the sockets pushed in, otherwise a SphereMesh.
static func skull(radius: float = 0.5) -> Mesh:
	var key := "skull:%f" % radius
	if not _cache.has(key):
		var mesh: Mesh = _bake_skull(radius)
		if mesh == null or mesh.get_surface_count() == 0:
			mesh = _displaced_skull(radius)
		if mesh == null or mesh.get_surface_count() == 0:
			var sphere := SphereMesh.new()
			sphere.radius = radius
			sphere.height = radius * 2.0
			sphere.radial_segments = 10
			sphere.rings = 6
			mesh = sphere
		_cache[key] = mesh
	return _cache[key]


## Spawner body: a thick low-poly ring.
static func nest(radius: float = 1.6) -> Mesh:
	var key := "nest:%f" % radius
	if not _cache.has(key):
		var torus := TorusMesh.new()
		torus.inner_radius = radius * 0.45
		torus.outer_radius = radius
		torus.rings = 10
		torus.ring_segments = 6
		_cache[key] = torus
	return _cache[key]


## Tall triangular prism for lanky stalkers.
static func stalker_prism(height: float = 2.4, width: float = 0.8) -> Mesh:
	var key := "stalker:%f:%f" % [height, width]
	if not _cache.has(key):
		var prism := PrismMesh.new()
		prism.size = Vector3(width, height, width)
		prism.left_to_right = 0.5
		_cache[key] = prism
	return _cache[key]


## Octahedron built from 6 vertices / 8 triangles.
static func gem_octahedron(size: float = 0.3) -> Mesh:
	var key := "gem:%f" % size
	if not _cache.has(key):
		_cache[key] = _octahedron(Vector3(size, size * 1.4, size))
	return _cache[key]


## Blade: a stretched flat octahedron pointing down -Z.
static func dagger(length: float = 0.6, width: float = 0.08) -> Mesh:
	var key := "dagger:%f:%f" % [length, width]
	if not _cache.has(key):
		_cache[key] = _octahedron(Vector3(width, width * 0.4, length))
	return _cache[key]


## Chunky cube used for the player's hand.
static func hand_block(size: float = 0.3) -> Mesh:
	var key := "hand:%f" % size
	if not _cache.has(key):
		var box := BoxMesh.new()
		box.size = Vector3(size, size * 0.8, size * 1.3)
		_cache[key] = box
	return _cache[key]


static func _octahedron(half_extents: Vector3) -> ArrayMesh:
	var points: Array[Vector3] = [
		Vector3(0, half_extents.y, 0), Vector3(0, -half_extents.y, 0),
		Vector3(half_extents.x, 0, 0), Vector3(-half_extents.x, 0, 0),
		Vector3(0, 0, half_extents.z), Vector3(0, 0, -half_extents.z),
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in points:
		st.set_normal(p.normalized())
		st.add_vertex(p)
	# top (0) and bottom (1) fans over the equator ring 2 -> 4 -> 3 -> 5.
	var ring: Array[int] = [2, 4, 3, 5]
	for i in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		st.add_index(0)
		st.add_index(a)
		st.add_index(b)
		st.add_index(1)
		st.add_index(b)
		st.add_index(a)
	return st.commit()


## CSG sphere minus two socket boxes. Off-tree CSG usually cannot evaluate
## (null headless), in which case the caller uses the displaced sphere.
static func _bake_skull(radius: float) -> Mesh:
	var combiner := CSGCombiner3D.new()
	var sphere := CSGSphere3D.new()
	sphere.radius = radius
	sphere.radial_segments = 10
	sphere.rings = 6
	combiner.add_child(sphere)
	for side in [-1.0, 1.0]:
		var socket := CSGBox3D.new()
		socket.operation = CSGShape3D.OPERATION_SUBTRACTION
		socket.size = Vector3(radius * 0.45, radius * 0.45, radius * 0.6)
		socket.position = _socket_dir(side) * radius * 0.95
		combiner.add_child(socket)
	var baked: Mesh = combiner.bake_static_mesh()
	combiner.free()
	return baked


## UV sphere whose vertices inside the two socket cones are pushed inward.
static func _displaced_skull(radius: float, rings: int = 8, segments: int = 12) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in rings + 1:
		var v := float(ring) / rings
		var polar := v * PI
		for seg in segments + 1:
			var azimuth := float(seg) / segments * TAU
			var dir := Vector3(sin(polar) * cos(azimuth), cos(polar), sin(polar) * sin(azimuth))
			var r := radius
			for side in [-1.0, 1.0]:
				if dir.dot(_socket_dir(side)) > 0.9:
					r = radius * 0.7
			st.set_normal(dir)
			st.set_uv(Vector2(float(seg) / segments, v))
			st.add_vertex(dir * r)
	for ring in rings:
		for seg in segments:
			var a := ring * (segments + 1) + seg
			var b := a + segments + 1
			for index in [a, b, a + 1, a + 1, b, b + 1]:
				st.add_index(index)
	return st.commit()


static func _socket_dir(side: float) -> Vector3:
	return Vector3(side * 0.35, 0.15, -0.85).normalized()
