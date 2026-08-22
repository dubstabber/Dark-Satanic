extends GameTest

const SHADER := preload("res://src/vfx/shaders/sad_satan_post.gdshader")
const PROFILE_PATHS := [
	"res://src/vfx/post_process/profiles/menu.tres",
	"res://src/vfx/post_process/profiles/gameplay.tres",
	"res://src/vfx/post_process/profiles/death.tres",
]


func _shader_uniform_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for info in SHADER.get_shader_uniform_list():
		names.append(StringName(info["name"]))
	return names


func _exported_names(profile: PostFxProfile) -> Array[StringName]:
	var names: Array[StringName] = []
	for prop in profile.get_property_list():
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and prop["usage"] & PROPERTY_USAGE_EDITOR:
			names.append(StringName(prop["name"]))
	return names


func test_profiles_load_with_script() -> void:
	for path in PROFILE_PATHS:
		var profile := load(path) as PostFxProfile
		assert_not_null(profile, path)


func test_every_exported_field_is_a_shader_uniform() -> void:
	var uniforms := _shader_uniform_names()
	assert_true(uniforms.size() > 10, "shader parsed and exposes uniforms")
	var profile := PostFxProfile.new()
	for field in _exported_names(profile):
		assert_has(uniforms, field, "profile field '%s' must be a shader uniform" % field)


func test_uniform_constant_matches_exported_fields() -> void:
	var exported := _exported_names(PostFxProfile.new())
	assert_eq(exported.size(), PostFxProfile.UNIFORMS.size())
	for field in exported:
		assert_has(PostFxProfile.UNIFORMS, field)


func test_every_shader_uniform_except_controller_owned_is_on_profile() -> void:
	var controller_owned: Array[StringName] = [&"screen_tex", &"virtual_res"]
	for uniform_name in _shader_uniform_names():
		if uniform_name in controller_owned:
			continue
		assert_has(PostFxProfile.UNIFORMS, uniform_name, "shader uniform '%s' missing on profile" % uniform_name)


func test_values_returns_every_uniform() -> void:
	var profile := PostFxProfile.new()
	profile.grain_amount = 0.9
	var values := profile.values()
	assert_eq(values.size(), PostFxProfile.UNIFORMS.size())
	assert_eq(values[&"grain_amount"], 0.9)
	assert_eq(values[&"tint"], Color(0.93, 0.90, 0.82))


func test_gameplay_profile_has_shader_defaults() -> void:
	var profile := load("res://src/vfx/post_process/profiles/gameplay.tres") as PostFxProfile
	var fresh := PostFxProfile.new()
	for uniform_name in PostFxProfile.UNIFORMS:
		assert_eq(profile.get(uniform_name), fresh.get(uniform_name), String(uniform_name))
	assert_almost_eq(profile.crush_black, 0.08, 0.0001)
	assert_almost_eq(profile.crush_gamma, 1.35, 0.0001)
	assert_eq(profile.dither_levels, 5.0)
	assert_almost_eq(profile.scanline_strength, 0.3, 0.0001)
	assert_almost_eq(profile.grain_amount, 0.28, 0.0001)
	assert_almost_eq(profile.invert_chance, 0.002, 0.0001)


func test_menu_profile_overrides() -> void:
	var profile := load("res://src/vfx/post_process/profiles/menu.tres") as PostFxProfile
	assert_almost_eq(profile.grain_amount, 0.35, 0.0001)
	assert_almost_eq(profile.tracking_strength, 0.03, 0.0001)


func test_death_profile_overrides() -> void:
	var profile := load("res://src/vfx/post_process/profiles/death.tres") as PostFxProfile
	assert_almost_eq(profile.crush_gamma, 2.2, 0.0001)
	assert_almost_eq(profile.tracking_strength, 0.08, 0.0001)
	assert_almost_eq(profile.grain_amount, 0.5, 0.0001)
	assert_almost_eq(profile.vignette_strength, 1.6, 0.0001)
