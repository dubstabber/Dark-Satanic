class_name MaterialEnergy
extends RefCounted
## Uniform access to a material's emission-energy knob, so the flash and glow
## drivers (EnemyVisual, WindupVisual, DaggerProjectile) work over both
## StandardMaterial3D (emission_energy_multiplier) and the PSX ShaderMaterials
## (the emission_energy uniform). ShaderMaterials must set the uniform
## explicitly in their scene: an unset parameter reads back as 0.

const UNIFORM := &"emission_energy"


## Property path for Tween.tween_property on the material's energy knob.
static func property(material: Material) -> String:
	if material is ShaderMaterial:
		return "shader_parameter/%s" % UNIFORM
	return "emission_energy_multiplier"


static func get_energy(material: Material) -> float:
	if material is ShaderMaterial:
		var value: Variant = (material as ShaderMaterial).get_shader_parameter(UNIFORM)
		return float(value) if value != null else 0.0
	if material is BaseMaterial3D:
		return (material as BaseMaterial3D).emission_energy_multiplier
	return 0.0


static func set_energy(material: Material, value: float) -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter(UNIFORM, value)
	elif material is BaseMaterial3D:
		var base := material as BaseMaterial3D
		base.emission_enabled = true
		base.emission_energy_multiplier = value


## True when the material exposes an energy knob this helper can drive.
static func supports(material: Material) -> bool:
	if material is BaseMaterial3D:
		return true
	if material is ShaderMaterial:
		var shader := (material as ShaderMaterial).shader
		if shader == null:
			return false
		for info in shader.get_shader_uniform_list():
			if StringName(info["name"]) == UNIFORM:
				return true
	return false
