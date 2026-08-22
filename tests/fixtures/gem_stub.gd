extends Node3D
## Records scatter() calls so GemDropComponent can be tested without the real gem.

var scattered: bool = false


func scatter(_rng: RandomNumberGenerator) -> void:
	scattered = true
