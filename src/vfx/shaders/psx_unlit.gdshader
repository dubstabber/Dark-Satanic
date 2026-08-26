// PSX-look unshaded surface for self-lit set dressing (the arena edge ring):
// same clip-space vertex snap and affine texture mapping as psx_lit, no
// lighting or emission.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

#include "res://src/vfx/shaders/includes/psx.gdshaderinc"

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_nearest, repeat_enable;
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
}
