class_name ProjectileSpawner
extends Node
## Launches pooled daggers in a cone around an aim direction.

## Pool to draw from; when null the first ProjectilePool child is used.
@export var pool: ProjectilePool
@export var rng_seed: int = 0

var rng := RandomNumberGenerator.new()
## Forwarded to each launched projectile (homing candidates).
var target_provider: Callable = Callable()
## Reported as HitInfo.source (the weapon).
var source: Node


func _ready() -> void:
	if rng_seed != 0:
		rng.seed = rng_seed
	ensure_pool()


## Resolves the pool from children when none was injected; usable before _ready.
func ensure_pool() -> ProjectilePool:
	if pool == null:
		pool = _find_child_pool()
	return pool


## `spread_deg` is the cone half-angle; directions are uniform on the cone's cap.
func spawn(
	origin: Vector3,
	direction: Vector3,
	count: int,
	spread_deg: float,
	params: ProjectileParams,
	p_rng: RandomNumberGenerator = null
) -> Array[DaggerProjectile]:
	var launched: Array[DaggerProjectile] = []
	if ensure_pool() == null or count <= 0:
		return launched
	var generator := p_rng if p_rng != null else rng
	var forward := direction.normalized() if direction.length_squared() > 0.0 else Vector3.FORWARD
	for i in count:
		var projectile := pool.acquire()
		if projectile == null:
			continue
		projectile.target_provider = target_provider
		projectile.launch(origin, cone_direction(forward, spread_deg, generator), params, source)
		launched.append(projectile)
	return launched


## A unit vector uniformly distributed on the spherical cap of half-angle `spread_deg` around `forward`.
static func cone_direction(forward: Vector3, spread_deg: float, generator: RandomNumberGenerator) -> Vector3:
	if spread_deg <= 0.0:
		return forward
	var cos_max := cos(deg_to_rad(spread_deg))
	var cos_theta := generator.randf_range(cos_max, 1.0)
	var sin_theta := sqrt(maxf(0.0, 1.0 - cos_theta * cos_theta))
	var phi := generator.randf_range(0.0, TAU)
	var helper := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.999 else Vector3.RIGHT
	var right := forward.cross(helper).normalized()
	var up := right.cross(forward).normalized()
	return (forward * cos_theta + right * (sin_theta * cos(phi)) + up * (sin_theta * sin(phi))).normalized()


func _find_child_pool() -> ProjectilePool:
	for child in get_children():
		if child is ProjectilePool:
			return child
	return null
