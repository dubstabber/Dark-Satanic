extends GameTest
## The generated models (assets/models/*.glb → assets/models/meshes/*.res) are wired into the scenes:
## every drop-in keeps the node the scripts look for, fills its collision shape and carries a textured
## psx_lit ShaderMaterial so EnemyVisual's flash and DaggerProjectile's tier glow still have something
## to drive (through MaterialEnergy).

const MESH_DIR := "res://assets/models/meshes/"
const TEXTURE_DIR := "res://assets/textures/"

## archetype scene -> [mesh name, expected visual size (x, y, z), tolerance]
const ARCHETYPE_FITS := {
	"res://src/enemies/archetypes/weeper.tscn": ["weeper", Vector3(0.7, 0.9, 0.73), 0.1],
	"res://src/enemies/archetypes/mourner.tscn": ["mourner", Vector3(1.64, 2.4, 1.53), 0.15],
	"res://src/enemies/archetypes/lament.tscn": ["lament", Vector3(2.2, 3.9, 2.2), 0.2],
	"res://src/enemies/archetypes/vesper.tscn": ["vesper", Vector3(0.72, 0.56, 1.56), 0.15],
	"res://src/enemies/archetypes/glutton.tscn": ["glutton", Vector3(2.0, 1.3, 2.0), 0.1],
	"res://src/enemies/archetypes/cantor.tscn": ["cantor", Vector3(1.56, 2.49, 1.33), 0.15],
	"res://src/enemies/archetypes/thurible.tscn": ["thurible", Vector3(0.74, 2.29, 0.75), 0.15],
}

var _world: Node3D


func before_each() -> void:
	super.before_each()
	_world = make_world()


func _visual_mesh(scene_path: String) -> MeshInstance3D:
	var enemy: Enemy = load(scene_path).instantiate()
	enemy.target = Node3D.new()
	_world.add_child(enemy.target)
	_world.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy.get_node("Visual/Mesh") as MeshInstance3D


## Bounds of the actual vertices under the node transform (a rotated AABB would over-estimate).
static func _fitted_aabb(mesh_instance: MeshInstance3D) -> AABB:
	var faces := mesh_instance.mesh.get_faces()
	var box := AABB(mesh_instance.transform * faces[0], Vector3.ZERO)
	for vertex in faces:
		box = box.expand(mesh_instance.transform * vertex)
	return box


func test_every_archetype_uses_its_saved_model_and_fills_its_shape() -> void:
	for scene_path: String in ARCHETYPE_FITS:
		var spec: Array = ARCHETYPE_FITS[scene_path]
		var mesh := _visual_mesh(scene_path)
		assert_not_null(mesh, "%s keeps Visual/Mesh" % scene_path)
		assert_eq(mesh.mesh.resource_path, MESH_DIR + spec[0] + ".res", scene_path)
		var size: Vector3 = _fitted_aabb(mesh).size
		for axis in 3:
			assert_almost_eq(size[axis], (spec[1] as Vector3)[axis], spec[2], "%s fitted size axis %d" % [spec[0], axis])


func test_every_archetype_material_is_textured_and_flashable() -> void:
	for scene_path: String in ARCHETYPE_FITS:
		var mesh := _visual_mesh(scene_path)
		var material := mesh.material_override as ShaderMaterial
		assert_not_null(material, "%s has a PSX ShaderMaterial override for EnemyVisual" % scene_path)
		assert_eq(material.shader.resource_path, "res://src/vfx/shaders/psx_lit.gdshader", scene_path)
		var albedo: Texture2D = material.get_shader_parameter(&"albedo_texture")
		assert_not_null(albedo, "%s albedo texture" % scene_path)
		assert_true(albedo.resource_path.begins_with(TEXTURE_DIR), scene_path)
		assert_true(MaterialEnergy.supports(material), "%s emission drives the hit flash" % scene_path)
		assert_gt(MaterialEnergy.get_energy(material), 0.0, "%s rests lit so the flash has a base" % scene_path)
		var visual: EnemyVisual = mesh.get_parent()
		assert_not_null(visual.material(), "%s visual duplicated the material" % scene_path)
		var emission: Texture2D = material.get_shader_parameter(&"emission_texture")
		if emission != null:
			# psx_lit mirrors EMISSION_OP_ADD — (colour + texel) * energy — so the texture only
			# lifts the bright texels; it must be the albedo map or the two would disagree.
			assert_same(emission, albedo, scene_path)


func test_enemy_forward_features_face_minus_z() -> void:
	# The dart tip and the glutton maw are the gameplay-facing ends; both models were exported facing +Z/+X.
	var vesper := _visual_mesh("res://src/enemies/archetypes/vesper.tscn")
	var vesper_box := _fitted_aabb(vesper)
	assert_almost_eq(vesper_box.position.z, -0.85, 0.05, "vesper tip sits at the capsule's -Z end")
	assert_almost_eq((vesper.get_parent().get_node("Tip") as Node3D).position.z, -0.85, 0.001)
	var lament := _visual_mesh("res://src/enemies/archetypes/lament.tscn")
	var lament_box := _fitted_aabb(lament)
	assert_lt(lament_box.position.y, -1.3, "lament body reaches down into the armour cylinder")
	assert_gt(lament_box.end.y, 2.0, "lament spire rises to the weak-point eye")


func test_dagger_projectile_mesh_is_the_bone_dagger() -> void:
	var dagger: DaggerProjectile = load("res://src/weapons/projectiles/dagger_projectile.tscn").instantiate()
	dagger.autonomous = false
	_world.add_child(dagger)
	var mesh := dagger.get_node("Mesh") as MeshInstance3D
	assert_eq(mesh.mesh.resource_path, MESH_DIR + "dagger.res")
	var box := _fitted_aabb(mesh)
	assert_almost_eq(box.size.z, 0.55, 0.02, "0.55 m long along Z")
	assert_lt(box.size.x, 0.12, "thin")
	var material := mesh.get_surface_override_material(0) as ShaderMaterial
	assert_not_null(material, "tier material is the surface override DaggerProjectile reads")
	assert_eq(material.shader.resource_path, "res://src/vfx/shaders/psx_lit.gdshader",
		"psx_lit is shaded, so the tier glow's emission renders")
	assert_not_null(material.get_shader_parameter(&"albedo_texture"))
	assert_true(MaterialEnergy.supports(material), "DaggerProjectile drives the tier glow through this")
	assert_null(material.get_shader_parameter(&"emission_texture"),
		"tier glow is a flat emission colour; a texture would tint it per-texel")


func test_player_hand_model_replaces_the_finger_boxes() -> void:
	var player: Node3D = load("res://src/player/player.tscn").instantiate()
	_world.add_child(player)
	player.set_physics_process(false)
	var hands := player.get_node("CameraRig/Camera3D/HandViewModel") as HandViewModel
	assert_null(hands.get_node_or_null("FingerL"), "placeholder fingers are gone")
	var hand := hands.get_node("Hand") as MeshInstance3D
	assert_eq(hand.mesh.resource_path, MESH_DIR + "hand.res")
	var box := _fitted_aabb(hand)
	assert_lt(box.position.z, -0.15, "fingers reach forward (-Z)")
	assert_gt(box.end.z, 0.1, "forearm trails back toward the camera")
	assert_lt(box.size.length(), 1.3, "a full arm, its elbow half reaching off-screen")
	var muzzle := hands.muzzle().position
	assert_lt(muzzle.z, box.position.z, "daggers leave from past the fingertips, not out of the palm")
	assert_gt(muzzle.z, box.position.z - 0.15, "but only just past them")
	var lined_up := box.grow(0.1)
	assert_between(muzzle.x, lined_up.position.x, lined_up.end.x, "muzzle lines up with the hand in x")
	assert_between(muzzle.y, lined_up.position.y, lined_up.end.y, "and in y")
	assert_not_null((hand.material_override as ShaderMaterial).get_shader_parameter(&"albedo_texture"))
