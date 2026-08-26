extends GameTest

const SCENES := {
	"hit_spark": preload("res://src/vfx/particles/hit_spark.tscn"),
	"death_burst": preload("res://src/vfx/particles/death_burst.tscn"),
	"gem_sparkle": preload("res://src/vfx/particles/gem_sparkle.tscn"),
	"spawn_rift": preload("res://src/vfx/particles/spawn_rift.tscn"),
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


func _all_particles(vfx: OneShotVfx) -> Array[GPUParticles3D]:
	var found: Array[GPUParticles3D] = []
	for child in vfx.get_children():
		if child is GPUParticles3D:
			found.append(child)
	return found


func test_scenes_are_one_shot_and_emitting() -> void:
	for scene_name in SCENES:
		var vfx: OneShotVfx = SCENES[scene_name].instantiate()
		_world.add_child(vfx)
		var emitters := _all_particles(vfx)
		assert_gt(emitters.size(), 0, scene_name)
		for particles in emitters:
			var tag := "%s/%s" % [scene_name, particles.name]
			assert_true(particles.one_shot, "%s one_shot" % tag)
			assert_true(particles.emitting, "%s emitting" % tag)
			assert_lte(particles.lifetime, 1.5, "%s short lifetime" % tag)
			assert_not_null(particles.process_material, tag)
			assert_not_null(particles.draw_pass_1, tag)
			var mat := particles.draw_pass_1.material as StandardMaterial3D
			assert_not_null(mat, "%s draw mesh material" % tag)
			assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, tag)
		assert_false(vfx.is_released())
		vfx.free()


## GPUParticles3D.finished never fires headless (and, in 4.7.1, not reliably with a
## renderer either), so the safety timer is the only release path and total_lifetime()
## has to be an upper bound on what is still drawing.
func test_total_lifetime_covers_every_emitter_including_slow_ones() -> void:
	for scene_name in SCENES:
		var vfx: OneShotVfx = SCENES[scene_name].instantiate()
		_world.add_child(vfx)
		for particles in _all_particles(vfx):
			var born_last := particles.lifetime * (1.0 - particles.explosiveness)
			var last_death := (born_last + particles.lifetime) / maxf(particles.speed_scale, 0.001)
			assert_true(
				vfx.total_lifetime() >= last_death,
				"%s/%s: freed at %f but still drawing until %f" % [scene_name, particles.name, vfx.total_lifetime(), last_death]
			)
		vfx.free()


## A trickling emitter is the case the old "lifetime + margin" formula got wrong.
func test_a_non_explosive_emitter_extends_the_lifetime() -> void:
	var vfx := OneShotVfx.new()
	vfx.safety_margin = 0.0
	var particles := GPUParticles3D.new()
	particles.lifetime = 1.0
	particles.explosiveness = 0.0
	particles.one_shot = true
	vfx.add_child(particles)
	_world.add_child(vfx)
	assert_almost_eq(vfx.total_lifetime(), 2.0, 0.0001, "births spread over 1 s, then a 1 s life")
	particles.explosiveness = 1.0
	assert_almost_eq(vfx.total_lifetime(), 1.0, 0.0001, "all at once: unchanged")
	particles.explosiveness = 0.5
	assert_almost_eq(vfx.total_lifetime(), 1.5, 0.0001)
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


func test_every_scene_frees_itself_within_its_total_lifetime() -> void:
	var longest := 0.0
	for scene_name in SCENES:
		var vfx: OneShotVfx = SCENES[scene_name].instantiate()
		vfx.name = scene_name
		_world.add_child(vfx)
		longest = maxf(longest, vfx.total_lifetime())
	assert_eq(_world.get_child_count(), SCENES.size())
	await wait_seconds(longest + 0.3)
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


## A billboarded quad has its model basis replaced by the camera's, which throws away
## the per-particle scale unless keep_scale is set — silently discarding scale_min /
## scale_max / scale_curve. Every emitter here authors a scale, so every one needs it.
func test_billboarded_emitters_that_scale_keep_their_scale() -> void:
	var checked := 0
	for scene_name in SCENES:
		var vfx: OneShotVfx = SCENES[scene_name].instantiate()
		_world.add_child(vfx)
		for particles in _all_particles(vfx):
			var process := particles.process_material as ParticleProcessMaterial
			var mat := particles.draw_pass_1.material as StandardMaterial3D
			var varies := (
				process.scale_curve != null or not is_equal_approx(process.scale_min, process.scale_max)
			)
			if not varies or mat.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED:
				continue
			checked += 1
			assert_true(
				mat.get_flag(BaseMaterial3D.FLAG_BILLBOARD_KEEP_SCALE),
				"%s/%s billboards and scales, so it needs billboard_keep_scale" % [scene_name, particles.name]
			)
		vfx.free()
	assert_gt(checked, 0, "the invariant found something to check")


func test_intensity_scales_the_debris_count_before_it_enters_the_tree() -> void:
	var vfx: OneShotVfx = SCENES["death_burst"].instantiate()
	var before := _particles(vfx).amount
	assert_gt(before, 0)
	vfx.set_intensity(3.0)
	assert_eq(_particles(vfx).amount, before * 3, "a boss throws three times the chips")
	_world.add_child(vfx)
	assert_eq(_particles(vfx).amount, before * 3, "and keeps them once it is emitting")


func test_intensity_never_empties_an_emitter() -> void:
	var vfx: OneShotVfx = SCENES["death_burst"].instantiate()
	vfx.set_intensity(0.0)
	assert_eq(_particles(vfx).amount, 1, "a burst of nothing would be a silent bug")
	_world.add_child(vfx)
