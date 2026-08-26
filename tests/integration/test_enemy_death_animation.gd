extends GameTest
## The death animation. EnemyVisual steps it from advance(delta) rather than a Tween, so
## every frame of it can be checked here instead of being taken on trust.

const DT := 1.0 / 60.0
const Weeper := preload("res://src/enemies/archetypes/weeper.tscn")

var _visual: EnemyVisual


func before_each() -> void:
	super.before_each()
	var world := make_world()
	_visual = EnemyVisual.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	var material := StandardMaterial3D.new()
	material.emission_energy_multiplier = 0.3
	mesh.material_override = material
	_visual.add_child(mesh)
	world.add_child(_visual)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _advance(seconds: float) -> void:
	for i in int(round(seconds / DT)):
		_visual.advance(DT)


func test_a_living_visual_never_moves_on_its_own() -> void:
	_advance(1.0)
	assert_false(_visual.is_dying())
	assert_almost_eq(_visual.position, Vector3.ZERO, Vector3.ONE * 0.0001)
	assert_almost_eq(_visual.scale, Vector3.ONE, Vector3.ONE * 0.0001)


func test_death_lurches_then_tumbles_down_and_shrinks_away() -> void:
	_visual.death(_rng(7))
	assert_true(_visual.is_dying())
	assert_true(_visual.is_animating())
	assert_almost_eq(_visual.position.y, 0.0, 0.0001, "still where it died on the first frame")
	_advance(_visual.death_duration * _visual.death_pop_fraction)
	assert_gt(_visual.scale.x, 1.2, "lurches bigger before the fall")
	_advance(_visual.death_duration)
	assert_lt(_visual.scale.x, 0.01, "shrunk away to nothing")
	assert_almost_eq(_visual.position.y, -_visual.death_drop, 0.01, "fell its full drop")


func test_the_corpse_tumbles_at_its_spin_rate() -> void:
	_visual.death(_rng(7))
	_advance(_visual.death_duration * 0.5)
	var half := _visual.basis.get_rotation_quaternion().get_angle()
	assert_almost_eq(half, deg_to_rad(_visual.death_spin_deg * _visual.death_duration) * 0.5, 0.05,
		"half the tumble at the halfway point")
	_advance(_visual.death_duration)
	assert_almost_eq(_visual.basis.get_rotation_quaternion().get_angle(),
		deg_to_rad(_visual.death_spin_deg * _visual.death_duration), 0.05, "and all of it by the end")


func test_the_fall_accelerates_rather_than_sliding_down_linearly() -> void:
	_visual.death(_rng(7))
	_advance(_visual.death_duration * 0.5)
	assert_lt(absf(_visual.position.y), _visual.death_drop * 0.5,
		"only a quarter of the drop is behind it at the halfway point (%.2f m)" % _visual.position.y)


func test_the_tumble_axis_comes_from_the_injected_rng() -> void:
	var a := EnemyVisual.tumble_axis(_rng(7))
	var b := EnemyVisual.tumble_axis(_rng(99))
	assert_almost_eq(a.length(), 1.0, 0.0001)
	assert_gt(a.distance_to(b), 0.1, "different enemies tip different ways")
	assert_almost_eq(EnemyVisual.tumble_axis(_rng(7)).distance_to(a), 0.0, 0.0001, "same seed, same fall")
	assert_lt(absf(a.y), 0.4, "mostly level axis, so bodies tip over instead of spinning like tops")
	assert_eq(EnemyVisual.tumble_axis(null), Vector3.RIGHT, "no rng: a fixed axis, never an error")


func test_death_burns_the_emission_down_to_black() -> void:
	var material := _visual.material()
	assert_not_null(material, "the visual duplicated the mesh material")
	_visual.death(_rng(7))
	assert_almost_eq(material.emission_energy_multiplier, _visual.flash_emission, 0.001, "flares white")
	_advance(_visual.death_duration)
	assert_almost_eq(material.emission_energy_multiplier, 0.0, 0.01, "and goes out")


func test_a_flash_never_fights_the_death_animation() -> void:
	_visual.death(_rng(7))
	_advance(_visual.death_duration * 0.5)
	var mid := _visual.scale.x
	_visual.flash()
	assert_false(_visual.is_flashing(), "a corpse does not flash")
	_advance(DT)
	assert_lt(_visual.scale.x, mid, "the fall carried on")


func test_the_enemy_steps_its_own_corpse_until_the_handler_frees_it() -> void:
	var world := make_world()
	var enemy: Enemy = Weeper.instantiate()
	enemy.rng_seed = 5
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.health.kill()
	var visual := enemy.visual
	assert_true(visual.is_dying())
	for i in 15:
		enemy.advance(DT)
	assert_lt(visual.position.y, -0.01, "the corpse fell while the enemy ticked it")
	assert_lt(visual.scale.x, enemy.visual.base_scale.x * 1.4)
	assert_almost_eq(enemy.global_position.y, 0.0, 0.0001, "the body itself stayed put")
