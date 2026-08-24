class_name KnockbackSolver
## Pure math for shooting yourself around: how hard a shot fired into a nearby
## surface shoves the shooter, and the ceiling that stops repeated blasts from
## stacking into orbit. Stateless.

const EPSILON := 0.000001


## 1 at `full_range` or nearer, falling linearly to 0 at `max_range`. A negative
## distance (nothing was hit) gives 0 — you cannot push off thin air.
static func falloff(distance: float, full_range: float, max_range: float) -> float:
	if distance < 0.0:
		return 0.0
	var far := maxf(max_range, full_range)
	if distance <= full_range:
		return 1.0
	if distance >= far or far - full_range < EPSILON:
		return 0.0
	return (far - distance) / (far - full_range)


## Push applied to the shooter: back along the shot, scaled by `strength` and the
## distance falloff. Shoot the floor and it points up.
static func impulse(
	shot_direction: Vector3, distance: float, strength: float, full_range: float, max_range: float
) -> Vector3:
	var scale := falloff(distance, full_range, max_range) * strength
	if scale <= 0.0 or shot_direction.length_squared() < EPSILON:
		return Vector3.ZERO
	return -shot_direction.normalized() * scale


## Caps a velocity that an impulse just added to: the horizontal plane as a whole,
## and upward speed only — falling is never slowed.
static func clamp_velocity(velocity: Vector3, max_horizontal: float, max_up: float) -> Vector3:
	var flat := Vector2(velocity.x, velocity.z)
	if max_horizontal > 0.0 and flat.length() > max_horizontal:
		flat = flat.normalized() * max_horizontal
	return Vector3(flat.x, minf(velocity.y, max_up) if max_up > 0.0 else velocity.y, flat.y)
