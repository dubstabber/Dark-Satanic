// Arena floor: triplanar-ish noise albedo in world space with a dithered
// radial fade to black toward the platform edge.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

#include "res://src/vfx/shaders/includes/dither.gdshaderinc"

uniform sampler2D noise_tex : repeat_enable, filter_nearest_mipmap;
uniform vec3 center = vec3(0.0, 0.0, 0.0);
uniform float radius : hint_range(1.0, 200.0, 0.5) = 30.0;
uniform float fade_width : hint_range(0.1, 50.0, 0.1) = 8.0;
uniform float texel_scale : hint_range(0.01, 2.0, 0.01) = 0.15;
uniform float brightness : hint_range(0.0, 2.0, 0.01) = 0.5;
uniform float dither_cell : hint_range(1.0, 16.0, 1.0) = 3.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 blend = abs(world_normal);
	blend /= max(blend.x + blend.y + blend.z, 0.001);
	float nx = texture(noise_tex, world_pos.yz * texel_scale).r;
	float ny = texture(noise_tex, world_pos.xz * texel_scale).r;
	float nz = texture(noise_tex, world_pos.xy * texel_scale).r;
	float n = nx * blend.x + ny * blend.y + nz * blend.z;
	float dist = distance(world_pos.xz, center.xz);
	float fade = clamp((radius - dist) / fade_width, 0.0, 1.0);
	float threshold = bayer4(ivec2(floor(FRAGCOORD.xy / dither_cell)));
	float lit = step(threshold, fade);
	ALBEDO = vec3(n * brightness * lit);
	ROUGHNESS = 1.0;
}
