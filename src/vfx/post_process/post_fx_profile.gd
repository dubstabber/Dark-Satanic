class_name PostFxProfile
extends Resource
## Designer-tunable snapshot of every sad_satan_post.gdshader uniform (same
## names). PostProcessController.apply() copies these onto the ShaderMaterial.
## virtual_res is owned by the controller (it follows the viewport) and is
## deliberately absent here.

## Uniform names in the order they are applied; must match the shader.
const UNIFORMS: Array[StringName] = [
	&"fps_quantize", &"jitter_chance", &"jitter_amount", &"tracking_strength", &"tracking_speed",
	&"tracking_band", &"chroma_smear", &"crush_black", &"crush_gamma", &"dither_levels",
	&"dither_strength", &"scanline_strength", &"grain_amount", &"vignette_strength", &"invert_chance",
	&"brightness", &"invert", &"tint",
]

@export_group("Timing")
@export_range(1.0, 60.0, 1.0) var fps_quantize: float = 24.0

@export_group("VHS")
@export_range(0.0, 1.0, 0.001) var jitter_chance: float = 0.03
@export_range(0.0, 0.2, 0.001) var jitter_amount: float = 0.02
@export_range(0.0, 0.2, 0.001) var tracking_strength: float = 0.015
@export_range(0.0, 2.0, 0.01) var tracking_speed: float = 0.25
@export_range(0.005, 0.5, 0.005) var tracking_band: float = 0.06
@export_range(0.0, 0.02, 0.0001) var chroma_smear: float = 0.0025

@export_group("Tone")
@export_range(0.0, 0.5, 0.005) var crush_black: float = 0.08
@export_range(0.2, 4.0, 0.01) var crush_gamma: float = 1.35
@export_range(2.0, 32.0, 1.0) var dither_levels: float = 5.0
@export_range(0.0, 1.0, 0.01) var dither_strength: float = 1.0
@export_range(0.0, 1.0, 0.01) var scanline_strength: float = 0.3
@export_range(0.0, 1.0, 0.01) var grain_amount: float = 0.28
@export_range(0.0, 3.0, 0.01) var vignette_strength: float = 1.0
@export_range(0.0, 1.0, 0.0001) var invert_chance: float = 0.002
@export_range(0.0, 3.0, 0.01) var brightness: float = 1.0
@export_range(0.0, 1.0, 0.01) var invert: float = 0.0
@export var tint: Color = Color(0.93, 0.90, 0.82)


## Uniform name -> value, ready for ShaderMaterial.set_shader_parameter.
func values() -> Dictionary:
	var out := {}
	for uniform_name in UNIFORMS:
		out[uniform_name] = get(uniform_name)
	return out
