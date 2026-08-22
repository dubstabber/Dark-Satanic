extends GameTest

const SCENES := {
	"hit_spark": preload("res://src/vfx/particles/hit_spark.tscn"),
	"death_burst": preload("res://src/vfx/particles/death_burst.tscn"),
	"gem_sparkle": preload("res://src/vfx/particles/gem_sparkle.tscn"),
}

var _world: Node3D


func before_each() -> void:
	super.before_each()
	_world = make_world()


func _particles(vfx: OneShotVfx) -> GPUParticles3D:
	for child in vfx.get_children():
		if child is GPUParticles3D:
			return child
	return null


func test_scenes_are_one_shot_explosive_and_emitting() -> void:
	for scene_name in SCENES:
		var vfx: OneShotVfx = SCENES[scene_name].instantiate()
		_world.add_child(vfx)
		var particles := _particles(vfx)
		assert_not_null(particles, scene_name)
		assert_true(particles.one_shot, "%s one_shot" % scene_name)
		assert_true(particles.emitting, "%s emitting" % scene_name)
		assert_eq(particles.explosiveness, 1.0, "%s explosiveness" % scene_name)
		assert_lte(particles.lifetime, 1.0, "%s short lifetime" % scene_name)
		assert_not_null(particles.process_material, scene_name)
		assert_not_null(particles.draw_pass_1, scene_name)
		var mat := particles.draw_pass_1.material as StandardMaterial3D
		assert_not_null(mat, "%s draw mesh material" % scene_name)
		assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, scene_name)
		assert_false(vfx.is_released())
		vfx.free()


func test_total_lifetime_is_lifetime_plus_margin() -> void:
	var vfx: OneShotVfx = SCENES["death_burst"].instantiate()
	_world.add_child(vfx)
	assert_almost_eq(vfx.total_lifetime(), 0.6 + 0.5, 0.0001)
	_particles(vfx).speed_scale = 2.0
	assert_almost_eq(vfx.total_lifetime(), 0.3 + 0.5, 0.0001)
	vfx.free()


func test_advance_releases_after_total_lifetime() -> void:
	var vfx: OneShotVfx = SCENES["hit_spark"].instantiate()
	vfx.set_process(false)
	_world.add_child(vfx)
	vfx.advance(0.7)
	assert_false(vfx.is_released(), "0.7 < 0.75")
	vfx.advance(0.1)
	assert_true(vfx.is_released())
	assert_true(vfx.is_queued_for_deletion())
	await wait_process_frames(2)
	assert_eq(_world.get_child_count(), 0)


func test_every_scene_frees_itself_within_lifetime_plus_one_second() -> void:
	var longest := 0.0
	for scene_name in SCENES:
		var vfx: OneShotVfx = SCENES[scene_name].instantiate()
		vfx.name = scene_name
		_world.add_child(vfx)
		longest = maxf(longest, _particles(vfx).lifetime)
	assert_eq(_world.get_child_count(), 3)
	await wait_seconds(longest + 1.0)
	assert_eq(_world.get_child_count(), 0, "all scenes freed themselves")


func test_finished_signal_frees_early() -> void:
	var vfx: OneShotVfx = SCENES["gem_sparkle"].instantiate()
	vfx.set_process(false)
	_world.add_child(vfx)
	_particles(vfx).finished.emit()
	assert_true(vfx.is_released())
	await wait_process_frames(2)
	assert_eq(_world.get_child_count(), 0)


func test_release_is_idempotent() -> void:
	var vfx: OneShotVfx = SCENES["gem_sparkle"].instantiate()
	vfx.set_process(false)
	_world.add_child(vfx)
	_particles(vfx).finished.emit()
	vfx.advance(5.0)
	_particles(vfx).finished.emit()
	assert_true(vfx.is_released())
	await wait_process_frames(2)
	assert_eq(_world.get_child_count(), 0)


func test_restart_resets_elapsed_and_pending() -> void:
	var vfx: OneShotVfx = SCENES["hit_spark"].instantiate()
	vfx.set_process(false)
	_world.add_child(vfx)
	vfx.advance(0.5)
	vfx.restart()
	assert_eq(vfx.elapsed, 0.0)
	vfx.advance(0.5)
	assert_false(vfx.is_released())
	vfx.free()


func test_root_without_particles_frees_itself() -> void:
	var vfx := OneShotVfx.new()
	_world.add_child(vfx)
	assert_true(vfx.is_released())
	await wait_process_frames(2)
	assert_eq(_world.get_child_count(), 0)
