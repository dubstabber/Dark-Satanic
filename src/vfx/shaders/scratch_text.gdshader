// Label shader: erodes glyph alpha with a noise texture and flickers whole
// frames out, like scratched film titles.
shader_type canvas_item;

#include "res://src/vfx/shaders/includes/noise.gdshaderinc"

uniform sampler2D noise_tex : repeat_enable, filter_nearest;
uniform float erosion : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float flicker_chance : hint_range(0.0, 1.0, 0.01) = 0.06;
uniform float noise_scale : hint_range(0.1, 8.0, 0.1) = 1.0;
uniform float fps_quantize : hint_range(1.0, 60.0, 1.0) = 24.0;

void fragment() {
	float frame = floor(TIME * fps_quantize);
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	vec2 drift = vec2(hash12(vec2(frame, 1.0)), hash12(vec2(frame, 2.0))) * 0.1;
	float n = texture(noise_tex, UV * noise_scale + drift).r;
	float alpha = tex.a * step(erosion, n + (1.0 - erosion) * 0.5);
	float flicker = step(hash12(vec2(frame, 5.0)), flicker_chance);
	alpha *= 1.0 - flicker;
	COLOR = vec4(tex.rgb, alpha);
}
