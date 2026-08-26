extends GameTest

const PostProcessScene := preload("res://src/vfx/post_process/post_process.tscn")
const MENU := preload("res://src/vfx/post_process/profiles/menu.tres")
const GAMEPLAY := preload("res://src/vfx/post_process/profiles/gameplay.tres")
const DEATH := preload("res://src/vfx/post_process/profiles/death.tres")

var _controller: PostProcessController


func before_each() -> void:
	super.before_each()
	_controller = PostProcessScene.instantiate()
	add_child_autofree(_controller)


func test_scene_structure() -> void:
	assert_eq(_controller.layer, 100)
	assert_not_null(_controller.material_target, "child ColorRect discovered")
	assert_eq(_controller.material_target.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_not_null(_controller.material(), "ShaderMaterial present")
	assert_eq(_controller.material().shader.resource_path, "res://src/vfx/shaders/sad_satan_post.gdshader")


func test_default_profile_applied_at_ready() -> void:
	assert_same(_controller.default_profile, GAMEPLAY)
	assert_almost_eq(float(_controller.get_parameter(&"grain_amount")), 0.28, 0.0001)
	assert_almost_eq(float(_controller.get_parameter(&"crush_gamma")), 1.35, 0.0001)


func test_apply_sets_parameters_immediately() -> void:
	_controller.apply(DEATH)
	assert_almost_eq(float(_controller.get_parameter(&"crush_gamma")), 2.2, 0.0001)
	assert_almost_eq(float(_controller.get_parameter(&"vignette_strength")), 1.6, 0.0001)
	assert_almost_eq(float(_controller.get_parameter(&"grain_amount")), 0.5, 0.0001)
	assert_false(_controller.is_transitioning())


func test_apply_null_is_noop() -> void:
	_controller.apply(null)
	assert_almost_eq(float(_controller.get_parameter(&"grain_amount")), 0.28, 0.0001)


func test_apply_with_duration_tweens_to_target() -> void:
	_controller.apply(DEATH, 0.2)
	assert_true(_controller.is_transitioning())
	await wait_process_frames(2)
	var mid := float(_controller.get_parameter(&"crush_gamma"))
	assert_between(mid, 1.35, 2.2)
	await wait_seconds(0.4)
	assert_almost_eq(float(_controller.get_parameter(&"crush_gamma")), 2.2, 0.001)
	assert_almost_eq(float(_controller.get_parameter(&"grain_amount")), 0.5, 0.001)
	assert_false(_controller.is_transitioning())


func test_apply_replaces_running_tween() -> void:
	_controller.apply(DEATH, 1.0)
	_controller.apply(MENU)
	assert_almost_eq(float(_controller.get_parameter(&"grain_amount")), 0.35, 0.0001)
	await wait_seconds(0.1)
	assert_almost_eq(float(_controller.get_parameter(&"grain_amount")), 0.35, 0.0001, "killed tween must not keep writing")


func test_pulse_bumps_then_restores() -> void:
	_controller.pulse(0.5, 0.2)
	assert_almost_eq(float(_controller.get_parameter(&"brightness")), 1.5, 0.0001)
	assert_almost_eq(float(_controller.get_parameter(&"invert")), 0.0, 0.0001)
	await wait_seconds(0.4)
	assert_almost_eq(float(_controller.get_parameter(&"brightness")), 1.0, 0.001)
	assert_almost_eq(float(_controller.get_parameter(&"invert")), 0.0, 0.001)


func test_strong_pulse_inverts() -> void:
	_controller.pulse(1.6, 0.2)
	assert_almost_eq(float(_controller.get_parameter(&"invert")), 0.6, 0.0001)
	await wait_seconds(0.4)
	assert_almost_eq(float(_controller.get_parameter(&"invert")), 0.0, 0.001)


func test_pulse_zero_duration_restores_immediately() -> void:
	_controller.pulse(1.0, 0.0)
	assert_almost_eq(float(_controller.get_parameter(&"brightness")), 1.0, 0.0001)
	assert_false(_controller.is_transitioning())


func test_virtual_res_follows_viewport_and_scale() -> void:
	var size := Vector2(get_viewport().size)
	var expected := (size * 0.4).floor()
	assert_eq(_controller.get_parameter(&"virtual_res"), expected)
	_controller.set_virtual_scale(0.5)
	assert_eq(_controller.get_parameter(&"virtual_res"), (size * 0.5).floor())
	assert_eq(_controller.scaling_3d_scale, 0.5)


func test_virtual_res_never_below_one() -> void:
	_controller.set_virtual_scale(0.0)
	var res: Vector2 = _controller.get_parameter(&"virtual_res")
	assert_gte(res.x, 1.0)
	assert_gte(res.y, 1.0)


func test_bare_controller_without_material_is_safe() -> void:
	var bare := PostProcessController.new()
	add_child_autofree(bare)
	bare.apply(DEATH, 0.5)
	bare.pulse(1.0, 0.5)
	bare.set_virtual_scale(0.3)
	assert_null(bare.material())
	assert_null(bare.get_parameter(&"grain_amount"))
	assert_false(bare.is_transitioning())


## A pulse fired during a profile crossfade used to decay to base and then get yanked back
## up when the pulse ended and the longer crossfade took the uniforms over again - the death
## flash visibly blinking twice. brightness and invert belong to pulse() alone.
func test_a_pulse_during_a_crossfade_decays_once_and_stays_down() -> void:
	var profile := PostFxProfile.new()
	_controller.apply(profile, 0.6)
	_controller.pulse(1.3, 0.5)
	assert_almost_eq(float(_controller.get_parameter(&"brightness")), profile.brightness + 1.3, 0.001)
	var settled := false
	var rose_after_settling := 0.0
	for i in 45:
		await wait_seconds(1.0 / 60.0)
		var brightness := float(_controller.get_parameter(&"brightness"))
		if settled:
			rose_after_settling = maxf(rose_after_settling, brightness - profile.brightness)
		elif brightness <= profile.brightness + 0.001:
			settled = true
	assert_true(settled, "the flash decayed back to the profile's brightness")
	assert_lt(rose_after_settling, 0.001, "and never flared again (peaked %.3f above base)" % rose_after_settling)
	assert_almost_eq(float(_controller.get_parameter(&"invert")), profile.invert, 0.001)
