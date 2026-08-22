class_name StreamFire
extends FireMode
## Hold-to-fire stream: an accumulator turns elapsed time into whole shots so the
## rate is exact over time regardless of tick length. The accumulator is primed
## on release so the first dagger leaves the instant primary is pressed.

var rate: float = 15.0
var daggers_per_shot: int = 1
var spread_deg: float = 1.5

var _accumulator: float = 1.0


func _configure(tier: DaggerUpgradeTier) -> void:
	rate = tier.stream_rate
	daggers_per_shot = tier.stream_daggers_per_shot
	spread_deg = tier.stream_spread_deg


func update(held: bool, _just_pressed: bool, origin: Vector3, direction: Vector3, delta: float) -> int:
	if not held:
		_accumulator = 1.0
		return 0
	_accumulator += rate * delta
	var shots := floori(_accumulator)
	if shots <= 0:
		return 0
	_accumulator -= shots
	return _launch(origin, direction, shots * daggers_per_shot, spread_deg)
