class_name ShotgunFire
extends FireMode
## Press-to-fire burst: all pellets at once, then a cooldown counted down in update().

var pellets: int = 12
var spread_deg: float = 12.0
var cooldown: float = 0.6

var _remaining: float = 0.0


func _configure(tier: DaggerUpgradeTier) -> void:
	pellets = tier.shotgun_pellets
	spread_deg = tier.shotgun_spread_deg
	cooldown = tier.shotgun_cooldown


func cooldown_remaining() -> float:
	return _remaining


func update(_held: bool, just_pressed: bool, origin: Vector3, direction: Vector3, delta: float) -> int:
	_remaining = maxf(_remaining - delta, 0.0)
	if not just_pressed or _remaining > 0.0:
		return 0
	var launched := _launch(origin, direction, pellets, spread_deg)
	if launched > 0:
		_remaining = cooldown
	return launched
