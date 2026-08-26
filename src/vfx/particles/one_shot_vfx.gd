class_name OneShotVfx
extends Node3D
## Root of a fire-and-forget particle scene: frees itself when every child
## GPUParticles3D reports finished, or after the longest lifetime plus a
## safety margin counted through advance(delta) (headless renderers never
## emit finished).

## Extra seconds past the longest particle lifetime before the safety free.
@export_range(0.0, 5.0, 0.1) var safety_margin: float = 0.5

var elapsed: float = 0.0
var _particles: Array[GPUParticles3D] = []
var _pending: int = 0
var _released: bool = false


func _ready() -> void:
	for child in get_children():
		if child is GPUParticles3D:
			_particles.append(child)
			child.finished.connect(_on_particles_finished)
	_pending = _particles.size()
	if _pending == 0:
		_release()


func _process(delta: float) -> void:
	advance(delta)


## Multiplies every emitter's particle count. Safe before the scene enters the tree, which
## is when the death handler calls it: a body three times the size of a skull should throw
## three times the debris rather than the same forty chips blown up bigger.
func set_intensity(multiplier: float) -> void:
	for child in get_children():
		if child is GPUParticles3D:
			var particles := child as GPUParticles3D
			particles.amount = maxi(1, int(round(particles.amount * maxf(multiplier, 0.0))))


## Restarts every emitter so a pooled instance can replay.
func restart() -> void:
	elapsed = 0.0
	_pending = _particles.size()
	for particles in _particles:
		particles.restart()


func advance(delta: float) -> void:
	if _released:
		return
	elapsed += delta
	if elapsed >= total_lifetime():
		_release()


## How long the longest emitter can still be drawing, plus the safety margin.
##
## An emitter with `explosiveness` below 1 spreads its births over
## `lifetime * (1 - explosiveness)`, and the last particle born still lives a full
## lifetime after that — so the visible span is up to `lifetime * (2 - explosiveness)`.
## Fully explosive emitters (every other VFX scene here) are unaffected.
func total_lifetime() -> float:
	var longest := 0.0
	for particles in _particles:
		var span := particles.lifetime * (2.0 - clampf(particles.explosiveness, 0.0, 1.0))
		longest = maxf(longest, span / maxf(particles.speed_scale, 0.001))
	return longest + safety_margin


func is_released() -> bool:
	return _released


func _on_particles_finished() -> void:
	_pending -= 1
	if _pending <= 0:
		_release()


func _release() -> void:
	if _released:
		return
	_released = true
	queue_free()
