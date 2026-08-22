class_name MaterialFactory
extends RefCounted
## Static, cached material builders for the monochrome look. Cached materials
## are shared; use flash_copy() when a single instance needs its own state.

const MONO_TOON := preload("res://src/vfx/shaders/mono_toon.gdshader")
const VOID_FLOOR := preload("res://src/vfx/shaders/void_floor.gdshader")

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


## Triplanar noise floor (StandardMaterial3D with procedural albedo + normal).
static func floor_material() -> StandardMaterial3D:
	var key := "floor"
	if not _cache.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.55, 0.55)
		mat.albedo_texture = noise_texture(3, false)
		mat.normal_enabled = true
		mat.normal_texture = noise_texture(4, true)
		mat.normal_scale = 0.6
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3(0.15, 0.15, 0.15)
		mat.roughness = 1.0
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_cache[key] = mat
	return _cache[key]


## Void floor shader material with the arena edge parameters set.
static func void_floor(radius: float = 30.0, center: Vector3 = Vector3.ZERO) -> ShaderMaterial:
	var key := "void_floor:%f:%s" % [radius, center]
	if not _cache.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = VOID_FLOOR
		mat.set_shader_parameter(&"noise_tex", noise_texture(5, false))
		mat.set_shader_parameter(&"radius", radius)
		mat.set_shader_parameter(&"center", center)
		_cache[key] = mat
	return _cache[key]


## Banded monochrome toon material (mono_toon.gdshader).
static func toon(base_color: Color = Color(0.7, 0.7, 0.7), emission_energy: float = 0.0) -> ShaderMaterial:
	var key := "toon:%s:%f" % [base_color.to_html(), emission_energy]
	if not _cache.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = MONO_TOON
		mat.set_shader_parameter(&"base_color", base_color)
		mat.set_shader_parameter(&"emission_energy", emission_energy)
		mat.set_shader_parameter(&"hit_flash", 0.0)
		_cache[key] = mat
	return _cache[key]


## Flat unlit glow for daggers, gems and particles.
static func unshaded_emissive(color: Color = Color.WHITE, energy: float = 1.0) -> StandardMaterial3D:
	var key := "emissive:%s:%f" % [color.to_html(), energy]
	if not _cache.has(key):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = energy
		_cache[key] = mat
	return _cache[key]


## Uncached duplicate with the hit flash fully on; give it to one instance only.
static func flash_copy(source: Material, strength: float = 1.0) -> Material:
	if source == null:
		return null
	var copy := source.duplicate() as Material
	if copy is ShaderMaterial:
		copy.set_shader_parameter(&"hit_flash", clampf(strength, 0.0, 1.0))
	elif copy is StandardMaterial3D:
		copy.emission_enabled = true
		copy.emission = Color.WHITE
		copy.emission_energy_multiplier = maxf(strength, 0.0) * 4.0
	return copy


## Seamless FastNoiseLite texture; small so it stays crunchy at 0.4x.
static func noise_texture(seed: int, as_normal: bool, size: int = 128) -> NoiseTexture2D:
	var key := "noise:%d:%s:%d" % [seed, as_normal, size]
	if not _cache.has(key):
		var noise := FastNoiseLite.new()
		noise.seed = seed
		noise.frequency = 0.08
		noise.fractal_octaves = 3
		var tex := NoiseTexture2D.new()
		tex.noise = noise
		tex.width = size
		tex.height = size
		tex.seamless = true
		tex.as_normal_map = as_normal
		tex.generate_mipmaps = true
		_cache[key] = tex
	return _cache[key]
