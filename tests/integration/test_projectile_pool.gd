extends GameTest

var _world: Node3D
var _pool: ProjectilePool


func before_each() -> void:
	super.before_each()
	_world = make_world()
	_pool = ProjectilePool.new()
	_pool.initial_size = 4
	_world.add_child(_pool)


func test_initial_size_prefilled_hidden_and_inactive() -> void:
	assert_eq(_pool.free_count(), 4)
	assert_eq(_pool.active_count(), 0)
	assert_eq(_pool.total_count(), 4)
	assert_eq(_pool.get_child_count(), 4, "projectiles live under the pool by default")
	for child in _pool.get_children():
		assert_true(child is DaggerProjectile)
		assert_false(child.visible)
		assert_false(child.active)
		assert_false(child.is_physics_processing())


func test_acquire_and_release_counts() -> void:
	var a := _pool.acquire()
	var b := _pool.acquire()
	assert_not_null(a)
	assert_ne(a, b)
	assert_eq(_pool.active_count(), 2)
	assert_eq(_pool.free_count(), 2)
	_pool.release(a)
	assert_eq(_pool.active_count(), 1)
	assert_eq(_pool.free_count(), 3)
	_pool.release(a)
	assert_eq(_pool.free_count(), 3, "double release is ignored")


func test_reuse_after_release() -> void:
	var taken: Array[DaggerProjectile] = []
	for i in 4:
		taken.append(_pool.acquire())
	_pool.release(taken[1])
	assert_same(_pool.acquire(), taken[1])
	assert_eq(_pool.total_count(), 4)


func test_grows_when_exhausted() -> void:
	for i in 4:
		_pool.acquire()
	var extra := _pool.acquire()
	assert_not_null(extra)
	assert_eq(_pool.total_count(), 5)
	assert_eq(_pool.active_count(), 5)
	assert_eq(_pool.free_count(), 0)
	assert_same(extra.get_parent(), _pool)


func test_projectile_release_returns_it_to_the_pool() -> void:
	var projectile := _pool.acquire()
	projectile.autonomous = false
	projectile.launch(Vector3.ZERO, Vector3.FORWARD, ProjectileParams.new(), null)
	assert_true(projectile.visible)
	assert_eq(_pool.active_count(), 1)
	projectile.release()
	assert_false(projectile.visible)
	assert_false(projectile.active)
	assert_eq(_pool.active_count(), 0)
	assert_eq(_pool.free_count(), 4)


func test_pool_release_deactivates_active_projectile() -> void:
	var projectile := _pool.acquire()
	projectile.autonomous = false
	projectile.launch(Vector3.ZERO, Vector3.FORWARD, ProjectileParams.new(), null)
	_pool.release(projectile)
	assert_false(projectile.active)
	assert_false(projectile.visible)
	assert_eq(_pool.free_count(), 4)
	assert_false(projectile.is_physics_processing())


func test_container_moves_projectiles() -> void:
	var root := Node3D.new()
	_world.add_child(root)
	var projectile := _pool.acquire()
	_pool.container = root
	assert_eq(root.get_child_count(), 4)
	assert_same(projectile.get_parent(), root)
	assert_eq(_pool.get_child_count(), 0)
	for i in 4:
		_pool.acquire()
	assert_eq(root.get_child_count(), 5, "new projectiles are created under the container")


func test_container_set_before_ready() -> void:
	var root := Node3D.new()
	_world.add_child(root)
	var pool := ProjectilePool.new()
	pool.initial_size = 3
	pool.container = root
	_world.add_child(pool)
	assert_eq(root.get_child_count(), 3)
	assert_eq(pool.free_count(), 3)


func test_null_scene_falls_back_to_plain_projectile() -> void:
	var pool := ProjectilePool.new()
	pool.projectile_scene = null
	pool.initial_size = 1
	_world.add_child(pool)
	assert_true(pool.acquire() is DaggerProjectile)
