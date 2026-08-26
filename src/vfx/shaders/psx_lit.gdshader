// PSX-look lit surface: Gouraud (per-vertex) lighting, clip-space vertex
// snap, affine texture mapping and nearest-filtered textures. Stands in for
// StandardMaterial3D on gameplay meshes. Emission follows the standard
// EMISSION_OP_ADD convention — (colour + texel) * energy — so the
// `emission_energy` uniform behaves like emission_energy_multiplier and
// MaterialEnergy can drive hit flashes and windup glows through it.
shader_type spatial;
render_mode vertex_lighting, cull_back, depth_draw_opaque, diffuse_lambert_wrap, specular_disabled;

#include "res://src/vfx/shaders/includes/psx.gdshaderinc"

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_nearest, repeat_enable;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform sampler2D emission_texture : source_color, hint_default_black, filter_nearest, repeat_enable;
uniform float emission_energy : hint_range(0.0, 16.0, 0.01) = 0.0;
uniform vec2 uv_scale = vec2(1.0);
uniform float snap_strength : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float affine_strength : hint_range(0.0, 1.0, 0.01) = 1.0;

varying vec3 affine;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	clip = psx_snap(clip, VIEWPORT_SIZE, snap_strength);
	POSITION = clip;
	affine = psx_affine_varying(UV * uv_scale, clip);
}

void fragment() {
	vec2 uv = psx_affine_uv(UV * uv_scale, affine, affine_strength);
	ALBEDO = albedo_color.rgb * texture(albedo_texture, uv).rgb;
	EMISSION = (emission_color.rgb + texture(emission_texture, uv).rgb) * emission_energy;
}
