class_name AimSolver
## Pure math for firing an offset muzzle through the crosshair.
##
## The camera decides *what* is aimed at; the muzzle only decides where a dagger
## starts. Launch along the camera's forward and every shot flies parallel to the
## crosshair instead of through it — permanently off by the muzzle offset. These
## helpers reconcile the two by aiming the muzzle at the point the crosshair is on.

const EPSILON := 0.000001


## The point the crosshair sits on: `hit_distance` along `forward` when a ray found
## something (negative means the ray was clear, so `max_distance` is used). Clamped
## to at least `min_distance` — a surface pressed against the face would otherwise
## swing the shot sideways by the whole muzzle offset.
static func convergence_point(
	origin: Vector3,
	forward: Vector3,
	hit_distance: float,
	max_distance: float,
	min_distance: float = 1.0
) -> Vector3:
	var dir := forward.normalized() if forward.length_squared() > EPSILON else Vector3.FORWARD
	var distance := hit_distance if hit_distance >= 0.0 else max_distance
	return origin + dir * clampf(distance, minf(min_distance, max_distance), max_distance)


## Unit direction from `muzzle` to `point`; `fallback` when the two coincide.
static func direction(muzzle: Vector3, point: Vector3, fallback: Vector3) -> Vector3:
	var offset := point - muzzle
	if offset.length_squared() < EPSILON:
		return fallback.normalized() if fallback.length_squared() > EPSILON else Vector3.FORWARD
	return offset.normalized()
