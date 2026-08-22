class_name GemMesh
extends RefCounted
## Builds the six-vertex octahedron used by gem pickups (flat shaded, no texture).


static func octahedron(half_width: float = 0.3, half_height: float = 0.45) -> ArrayMesh:
	var top := Vector3(0.0, half_height, 0.0)
	var bottom := Vector3(0.0, -half_height, 0.0)
	var ring: Array[Vector3] = [
		Vector3(half_width, 0.0, 0.0),
		Vector3(0.0, 0.0, half_width),
		Vector3(-half_width, 0.0, 0.0),
		Vector3(0.0, 0.0, -half_width),
	]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		_triangle(surface, top, a, b)
		_triangle(surface, bottom, b, a)
	surface.generate_normals()
	return surface.commit()


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
