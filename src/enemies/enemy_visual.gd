class_name EnemyVisual
extends Node3D
## Spawn scale-in, hit flash and death pop for an enemy mesh. Driven by enemy.gd through
## `spawn_in`, `flash` and `death`; the material is duplicated so flashes never leak.

## Mesh whose material flashes; when null the first MeshInstance3D descendant is used.
@export var mesh_instance: MeshInstance3D
@export_range(0.0, 10.0, 0.1) var flash_emission: float = 2.0
@export_range(0.01, 2.0, 0.01) var flash_duration: float = 0.12
## Total length of the death animation. `DeathHandlerComponent.free_delay` must be at least
## this, or the corpse is freed part-way through the fall.
@export_range(0.0, 2.0, 0.01) var death_duration: float = 0.45
@export_range(1.0, 3.0, 0.05) var death_pop_scale: float = 1.3
## Scale bump used for the hit flash when the mesh has no StandardMaterial3D.
@export_range(1.0, 3.0, 0.05) var flash_scale: float = 1.15
## Share of `death_duration` spent lurching before the corpse starts to fall.
@export_range(0.0, 1.0, 0.05) var death_pop_fraction: float = 0.25
## Degrees per second the corpse tumbles on its way down.
@export_range(0.0, 1440.0, 5.0) var death_spin_deg: float = 320.0
## Metres the corpse falls across the whole animation. Deliberately short: a body killed
## just above the deck has to shrink away before it can sink through it.
@export_range(0.0, 10.0, 0.05) var death_drop: float = 0.8

var base_scale: Vector3 = Vector3.ONE
var _material: StandardMaterial3D
var _base_emission: float = 0.0
var _tween: Tween
var _flash_tween: Tween
var _dying: bool = false
var _death_elapsed: float = 0.0
var _death_axis: Vector3 = Vector3.RIGHT
var _base_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	base_scale = scale
	_base_position = position
	if mesh_instance == null:
		mesh_instance = _find_mesh(self)
	if mesh_instance != null and mesh_instance.material_override is StandardMaterial3D:
		_material = mesh_instance.material_override.duplicate() as StandardMaterial3D
		mesh_instance.material_override = _material
		_base_emission = _material.emission_energy_multiplier


func material() -> StandardMaterial3D:
	return _material


## Scales from zero to the resting scale over `duration` seconds (instant when 0).
func spawn_in(duration: float) -> void:
	_kill(_tween)
	_kill(_flash_tween)
	if duration <= 0.0:
		scale = base_scale
		return
	scale = Vector3.ONE * 0.001
	_tween = create_tween()
	_tween.tween_property(self, "scale", base_scale, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Brief emission bump (or a scale bump when there is no material).
##
## A flash already in flight is left alone rather than restarted: a tier-IV stream lands
## about forty hits a second, and re-triggering on every one pinned high-health enemies
## permanently white. Ignoring the extras turns that into a ~8 Hz pulse you can read.
func flash() -> void:
	if _dying:
		return
	if is_flashing():
		return
	_flash_tween = create_tween()
	if _material != null:
		# Emission is the flash's own channel, so it can play over the spawn-in scale tween
		# instead of aborting it and leaving a half-materialised enemy at 5% size.
		_material.emission_enabled = true
		_material.emission_energy_multiplier = flash_emission
		_flash_tween.tween_property(_material, "emission_energy_multiplier", _base_emission, flash_duration)
	else:
		# No material: the flash has to borrow scale, which is what spawn_in animates.
		_kill(_tween)
		scale = base_scale * flash_scale
		_flash_tween.tween_property(self, "scale", base_scale, flash_duration)


## Kills the body: a lurch, then a tumbling fall that shrinks away to nothing.
##
## Every mesh in the game is a static ArrayMesh, so the animation is all transform - the
## body swells for a beat, tips onto an axis drawn from the enemy's own rng, spins, drops
## and shrinks out while its emission burns down to black. A flyer shot out of the air
## reads as falling rather than as politely deflating. Stepped by advance(delta) instead of
## a Tween so it is deterministic and can be checked frame by frame.
func death(rng: RandomNumberGenerator = null) -> void:
	_kill(_tween)
	_kill(_flash_tween)
	_dying = true
	_death_elapsed = 0.0
	_base_position = position
	_death_axis = EnemyVisual.tumble_axis(rng)
	_apply_death(0.0)


func advance(delta: float) -> void:
	if not _dying or delta <= 0.0:
		return
	_death_elapsed += delta
	_apply_death(clampf(_death_elapsed / maxf(death_duration, 0.0001), 0.0, 1.0))


func is_dying() -> bool:
	return _dying


## Progress through the death, 0 at the killing hit and 1 when there is nothing left.
func _apply_death(t: float) -> void:
	var pop := clampf(death_pop_fraction, 0.0001, 0.9999)
	var size: float = lerpf(1.0, death_pop_scale, t / pop) if t <= pop \
		else lerpf(death_pop_scale, 0.001, (t - pop) / (1.0 - pop))
	basis = Basis(_death_axis, deg_to_rad(death_spin_deg) * t * death_duration).scaled(base_scale * size)
	position = _base_position + Vector3.DOWN * death_drop * t * t
	if _material != null:
		_material.emission_enabled = true
		_material.emission_energy_multiplier = lerpf(flash_emission, 0.0, t)


## Mostly-level axis to tumble around, so bodies tip over rather than spin like tops.
static func tumble_axis(rng: RandomNumberGenerator) -> Vector3:
	if rng == null:
		return Vector3.RIGHT
	var axis := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.35, 0.35), rng.randf_range(-1.0, 1.0))
	return axis.normalized() if axis.length_squared() > 0.0001 else Vector3.RIGHT


## True while a hit flash is still playing out. Deliberately its own tween: the spawn-in
## scale tween lives in `_tween`, and conflating them meant an enemy shot while it was
## still materialising could never flash.
func is_flashing() -> bool:
	return _flash_tween != null and _flash_tween.is_valid() and _flash_tween.is_running()


func is_animating() -> bool:
	return (_tween != null and _tween.is_valid() and _tween.is_running()) \
		or is_flashing() \
		or _dying


func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


static func _find_mesh(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		var nested := _find_mesh(child)
		if nested != null:
			return nested
	return null
