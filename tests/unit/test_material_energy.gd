extends GameTest
## MaterialEnergy gives the flash/glow drivers one knob across
## StandardMaterial3D and the PSX ShaderMaterials.

const PSX_LIT := preload("res://src/vfx/shaders/psx_lit.gdshader")
const VOID_FLOOR := preload("res://src/vfx/shaders/void_floor.gdshader")


func _psx_material(energy: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PSX_LIT
	material.set_shader_parameter(MaterialEnergy.UNIFORM, energy)
	return material


func test_standard_material_round_trip() -> void:
	var material := StandardMaterial3D.new()
	MaterialEnergy.set_energy(material, 2.0)
	assert_true(material.emission_enabled, "setting energy turns emission on")
	assert_eq(material.emission_energy_multiplier, 2.0)
	assert_eq(MaterialEnergy.get_energy(material), 2.0)


func test_shader_material_round_trip() -> void:
	var material := _psx_material(0.42)
	assert_eq(MaterialEnergy.get_energy(material), 0.42)
	MaterialEnergy.set_energy(material, 3.0)
	assert_eq(MaterialEnergy.get_energy(material), 3.0)


func test_unset_shader_parameter_reads_zero() -> void:
	var material := ShaderMaterial.new()
	material.shader = PSX_LIT
	assert_eq(MaterialEnergy.get_energy(material), 0.0)


func test_property_paths_drive_a_tween() -> void:
	for material: Material in [StandardMaterial3D.new(), _psx_material(0.0)]:
		MaterialEnergy.set_energy(material, 0.0)
		var tween := create_tween()
		tween.tween_property(material, MaterialEnergy.property(material), 5.0, 1.0)
		tween.custom_step(2.0)
		tween.kill()
		assert_eq(MaterialEnergy.get_energy(material), 5.0,
			"tween resolves '%s'" % MaterialEnergy.property(material))


func test_supports_reports_the_energy_knob() -> void:
	assert_true(MaterialEnergy.supports(StandardMaterial3D.new()))
	assert_true(MaterialEnergy.supports(_psx_material(0.0)))
	var no_knob := ShaderMaterial.new()
	no_knob.shader = VOID_FLOOR
	assert_false(MaterialEnergy.supports(no_knob), "void_floor has no emission_energy uniform")
	assert_false(MaterialEnergy.supports(ShaderMaterial.new()), "no shader, no knob")


func test_unrelated_material_is_inert() -> void:
	var particles := ParticleProcessMaterial.new()
	assert_eq(MaterialEnergy.get_energy(particles), 0.0)
	MaterialEnergy.set_energy(particles, 1.0)
	assert_false(MaterialEnergy.supports(particles))
