class_name PostProcessController
extends CanvasLayer
## Owns the full-screen Sad Satan ShaderMaterial: applies PostFxProfiles
## (instantly or tweened), fires short brightness/invert pulses and keeps the
## shader's virtual_res locked to the viewport's 3D scaling grid. Every shader
## write is guarded so the controller is safe headless and without a material.

## ColorRect carrying the ShaderMaterial; when null the first ColorRect child is used.
@export var material_target: ColorRect
## Profile applied at _ready (gameplay in production).
@export var default_profile: PostFxProfile
## Mirrors rendering/scaling_3d/scale so the pixel snap matches the 3D grid.
@export_range(0.05, 1.0, 0.05) var scaling_3d_scale: float = 0.4

var _tween: Tween
var _pulse_tween: Tween
## brightness/invert the current profile asked for; pulses return to these.
var _base_brightness: float = 1.0
var _base_invert: float = 0.0


func _ready() -> void:
	if material_target == null:
		material_target = _find_child_rect()
	if default_profile != null:
		apply(default_profile)
	var viewport := get_viewport()
	if viewport != null:
		viewport.size_changed.connect(_update_virtual_res)
	_update_virtual_res()


## Copies every profile uniform onto the shader, tweening when duration > 0.
func apply(profile: PostFxProfile, duration: float = 0.0) -> void:
	if profile == null:
		return
	_kill(_tween)
	_tween = null
	_base_brightness = profile.brightness
	_base_invert = profile.invert
	var values := profile.values()
	if duration <= 0.0 or material() == null or not is_inside_tree():
		for uniform_name in values:
			set_parameter(uniform_name, values[uniform_name])
		return
	_tween = create_tween().set_parallel(true)
	for uniform_name in values:
		_tween.tween_property(material(), "shader_parameter/%s" % uniform_name, values[uniform_name], duration)


## Bumps brightness (and inverts the frame when strength > 1) then eases back.
func pulse(strength: float, duration: float) -> void:
	_kill(_pulse_tween)
	_pulse_tween = null
	set_parameter(&"brightness", _base_brightness + maxf(strength, 0.0))
	set_parameter(&"invert", clampf(_base_invert + strength - 1.0, 0.0, 1.0))
	if duration <= 0.0 or material() == null or not is_inside_tree():
		set_parameter(&"brightness", _base_brightness)
		set_parameter(&"invert", _base_invert)
		return
	_pulse_tween = create_tween().set_parallel(true)
	_pulse_tween.tween_property(material(), "shader_parameter/brightness", _base_brightness, duration)
	_pulse_tween.tween_property(material(), "shader_parameter/invert", _base_invert, duration)


## Changes the virtual grid scale (e.g. when the 3D scaling setting changes).
func set_virtual_scale(scale: float) -> void:
	scaling_3d_scale = maxf(scale, 0.01)
	_update_virtual_res()


## The virtual_res the shader snaps to: viewport size * scale, at least 1x1.
func virtual_res() -> Vector2:
	var viewport := get_viewport()
	var size := Vector2(1280, 720)
	if viewport != null:
		size = Vector2(viewport.size)
	var res := (size * scaling_3d_scale).floor()
	return Vector2(maxf(res.x, 1.0), maxf(res.y, 1.0))


func material() -> ShaderMaterial:
	if material_target == null:
		return null
	return material_target.material as ShaderMaterial


func set_parameter(uniform_name: StringName, value: Variant) -> void:
	var mat := material()
	if mat != null:
		mat.set_shader_parameter(uniform_name, value)


func get_parameter(uniform_name: StringName) -> Variant:
	var mat := material()
	if mat == null:
		return null
	return mat.get_shader_parameter(uniform_name)


func is_transitioning() -> bool:
	return (_tween != null and _tween.is_running()) or (_pulse_tween != null and _pulse_tween.is_running())


func _update_virtual_res() -> void:
	set_parameter(&"virtual_res", virtual_res())


func _find_child_rect() -> ColorRect:
	for child in get_children():
		if child is ColorRect:
			return child
	return null


func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
