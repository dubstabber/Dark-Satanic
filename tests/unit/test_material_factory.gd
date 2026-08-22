extends GameTest


func before_each() -> void:
	super.before_each()
	MaterialFactory.clear_cache()


func test_floor_material_is_triplanar_noise() -> void:
	var mat := MaterialFactory.floor_material()
	assert_not_null(mat)
	assert_true(mat.uv1_triplanar)
	assert_true(mat.normal_enabled)
	assert_true(mat.albedo_texture is NoiseTexture2D)
	assert_true(mat.normal_texture is NoiseTexture2D)
	assert_true((mat.normal_texture as NoiseTexture2D).as_normal_map)
	assert_false((mat.albedo_texture as NoiseTexture2D).as_normal_map)
	assert_same(mat, MaterialFactory.floor_material())


func test_void_floor_material_parameters() -> void:
	var mat := MaterialFactory.void_floor(12.0, Vector3(1, 0, 2))
	assert_eq(mat.shader.resource_path, "res://src/vfx/shaders/void_floor.gdshader")
	assert_eq(mat.get_shader_parameter(&"radius"), 12.0)
	assert_eq(mat.get_shader_parameter(&"center"), Vector3(1, 0, 2))
	assert_true(mat.get_shader_parameter(&"noise_tex") is NoiseTexture2D)
	assert_same(mat, MaterialFactory.void_floor(12.0, Vector3(1, 0, 2)))
	assert_ne(mat, MaterialFactory.void_floor(13.0, Vector3(1, 0, 2)))


func test_toon_material_uses_mono_toon_shader() -> void:
	var mat := MaterialFactory.toon(Color(0.5, 0.5, 0.5), 1.5)
	assert_eq(mat.shader.resource_path, "res://src/vfx/shaders/mono_toon.gdshader")
	assert_eq(mat.get_shader_parameter(&"base_color"), Color(0.5, 0.5, 0.5))
	assert_eq(mat.get_shader_parameter(&"emission_energy"), 1.5)
	assert_eq(mat.get_shader_parameter(&"hit_flash"), 0.0)


func test_toon_cache_keyed_by_arguments() -> void:
	assert_same(MaterialFactory.toon(Color.WHITE, 1.0), MaterialFactory.toon(Color.WHITE, 1.0))
	assert_ne(MaterialFactory.toon(Color.WHITE, 1.0), MaterialFactory.toon(Color.WHITE, 2.0))
	assert_ne(MaterialFactory.toon(Color.WHITE, 1.0), MaterialFactory.toon(Color.GRAY, 1.0))


func test_unshaded_emissive() -> void:
	var mat := MaterialFactory.unshaded_emissive(Color(1, 0.9, 0.8), 3.0)
	assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_true(mat.emission_enabled)
	assert_eq(mat.emission, Color(1, 0.9, 0.8))
	assert_eq(mat.emission_energy_multiplier, 3.0)
	assert_eq(mat.albedo_color, Color(1, 0.9, 0.8))
	assert_same(mat, MaterialFactory.unshaded_emissive(Color(1, 0.9, 0.8), 3.0))


func test_flash_copy_of_toon_is_independent() -> void:
	var base := MaterialFactory.toon(Color.WHITE, 0.0)
	var flash := MaterialFactory.flash_copy(base) as ShaderMaterial
	assert_ne(flash, base)
	assert_same(flash.shader, base.shader)
	assert_eq(flash.get_shader_parameter(&"hit_flash"), 1.0)
	assert_eq(base.get_shader_parameter(&"hit_flash"), 0.0, "cached original untouched")
	var half := MaterialFactory.flash_copy(base, 0.5) as ShaderMaterial
	assert_eq(half.get_shader_parameter(&"hit_flash"), 0.5)
	var clamped := MaterialFactory.flash_copy(base, 4.0) as ShaderMaterial
	assert_eq(clamped.get_shader_parameter(&"hit_flash"), 1.0)


func test_flash_copy_of_standard_material_glows_white() -> void:
	var base := MaterialFactory.unshaded_emissive(Color.BLACK, 0.0)
	var flash := MaterialFactory.flash_copy(base, 1.0) as StandardMaterial3D
	assert_ne(flash, base)
	assert_eq(flash.emission, Color.WHITE)
	assert_gt(flash.emission_energy_multiplier, 0.0)
	assert_eq(base.emission, Color.BLACK)


func test_flash_copy_null_is_null() -> void:
	assert_null(MaterialFactory.flash_copy(null))


func test_noise_texture_cached_and_seamless() -> void:
	var tex := MaterialFactory.noise_texture(9, false, 32)
	assert_true(tex.seamless)
	assert_eq(tex.width, 32)
	assert_true(tex.noise is FastNoiseLite)
	assert_same(tex, MaterialFactory.noise_texture(9, false, 32))
	assert_ne(tex, MaterialFactory.noise_texture(9, true, 32))


func test_clear_cache_rebuilds() -> void:
	var before := MaterialFactory.toon()
	MaterialFactory.clear_cache()
	assert_ne(before, MaterialFactory.toon())
