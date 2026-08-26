extends GameTest
## The PSX spatial shaders parse and expose the uniforms the scenes and
## MaterialEnergy rely on. A shader with a parse error reports no uniforms,
## so the contract checks double as compile checks.

const LIT := preload("res://src/vfx/shaders/psx_lit.gdshader")
const UNLIT := preload("res://src/vfx/shaders/psx_unlit.gdshader")

const SHARED_UNIFORMS: Array[StringName] = [
	&"albedo_color", &"albedo_texture", &"uv_scale", &"snap_strength", &"affine_strength",
]
const LIT_UNIFORMS: Array[StringName] = [
	&"emission_color", &"emission_texture", &"emission_energy",
]


func _uniform_names(shader: Shader) -> Array[StringName]:
	var names: Array[StringName] = []
	for info in shader.get_shader_uniform_list():
		names.append(StringName(info["name"]))
	return names


func test_lit_shader_parses_and_exposes_the_material_contract() -> void:
	var names := _uniform_names(LIT)
	assert_true(names.size() > 0, "psx_lit parsed and exposes uniforms")
	for uniform_name in SHARED_UNIFORMS + LIT_UNIFORMS:
		assert_has(names, uniform_name, "psx_lit uniform '%s'" % uniform_name)


func test_unlit_shader_parses_and_exposes_the_material_contract() -> void:
	var names := _uniform_names(UNLIT)
	assert_true(names.size() > 0, "psx_unlit parsed and exposes uniforms")
	for uniform_name in SHARED_UNIFORMS:
		assert_has(names, uniform_name, "psx_unlit uniform '%s'" % uniform_name)
	assert_does_not_have(names, &"emission_energy", "unlit surfaces have no flash channel")


func test_lit_energy_uniform_matches_material_energy() -> void:
	assert_has(_uniform_names(LIT), MaterialEnergy.UNIFORM,
		"MaterialEnergy drives psx_lit through this uniform")
	assert_true(MaterialEnergy.supports(_lit_material()), "psx_lit materials are flashable")


func test_unlit_material_is_not_flashable() -> void:
	var material := ShaderMaterial.new()
	material.shader = UNLIT
	assert_false(MaterialEnergy.supports(material))


func _lit_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = LIT
	return material
