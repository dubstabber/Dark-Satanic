// Sad Satan post-process: VHS jitter/tracking, pixel snap to the 0.4x virtual
// grid, chromatic smear, black crush, ordered dither, scanlines, grain,
// vignette, rare inversion and a warm monochrome tint. Every number is a
// uniform mirrored by PostFxProfile (same names).
shader_type canvas_item;
render_mode unshaded;

#include "res://src/vfx/shaders/includes/noise.gdshaderinc"
#include "res://src/vfx/shaders/includes/dither.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

uniform vec2 virtual_res = vec2(512.0, 288.0);
uniform float fps_quantize : hint_range(1.0, 60.0, 1.0) = 24.0;
uniform float jitter_chance : hint_range(0.0, 1.0, 0.001) = 0.03;
uniform float jitter_amount : hint_range(0.0, 0.2, 0.001) = 0.02;
uniform float tracking_strength : hint_range(0.0, 0.2, 0.001) = 0.015;
uniform float tracking_speed : hint_range(0.0, 2.0, 0.01) = 0.25;
uniform float tracking_band : hint_range(0.005, 0.5, 0.005) = 0.06;
uniform float chroma_smear : hint_range(0.0, 0.02, 0.0001) = 0.0025;
uniform float crush_black : hint_range(0.0, 0.5, 0.005) = 0.08;
uniform float crush_gamma : hint_range(0.2, 4.0, 0.01) = 1.35;
uniform float dither_levels : hint_range(2.0, 32.0, 1.0) = 5.0;
uniform float dither_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float scanline_strength : hint_range(0.0, 1.0, 0.01) = 0.3;
uniform float grain_amount : hint_range(0.0, 1.0, 0.01) = 0.28;
uniform float vignette_strength : hint_range(0.0, 3.0, 0.01) = 1.0;
uniform float invert_chance : hint_range(0.0, 1.0, 0.0001) = 0.002;
uniform float brightness : hint_range(0.0, 3.0, 0.01) = 1.0;
uniform float invert : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec3 tint : source_color = vec3(0.93, 0.90, 0.82);

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	float frame = floor(TIME * fps_quantize);
	vec2 uv = SCREEN_UV;

	// Frame jitter: the whole frame hops vertically on rare quantised frames.
	float jitter_roll = hash12(vec2(frame, 7.0));
	float jitter = step(jitter_roll, jitter_chance) * jitter_amount * (hash12(vec2(frame, 11.0)) - 0.5) * 2.0;
	uv.y = fract(uv.y + jitter);

	// VHS tracking band: a horizontal shear sweeping down the frame.
	float band_y = fract(TIME * tracking_speed);
	float band = 1.0 - smoothstep(0.0, tracking_band, abs(uv.y - band_y));
	uv.x += band * tracking_strength * (hash12(vec2(frame, floor(uv.y * 40.0))) - 0.5) * 2.0;
	uv.x = clamp(uv.x, 0.0, 1.0);

	// Pixel snap to the virtual grid.
	vec2 cell = floor(uv * virtual_res);
	vec2 snapped = (cell + 0.5) / virtual_res;

	// Chromatic smear: three horizontal taps.
	float r = textureLod(screen_tex, snapped + vec2(chroma_smear, 0.0), 0.0).r;
	float g = textureLod(screen_tex, snapped, 0.0).g;
	float b = textureLod(screen_tex, snapped - vec2(chroma_smear, 0.0), 0.0).b;

	// Luminance, black crush, gamma.
	float l = luma(vec3(r, g, b));
	l = clamp((l - crush_black) / max(1.0 - crush_black, 0.001), 0.0, 1.0);
	l = pow(l, crush_gamma) * brightness;

	// Ordered dither to a handful of grey levels.
	float levels = max(dither_levels - 1.0, 1.0);
	float threshold = (bayer4(ivec2(cell)) - 0.5) * dither_strength;
	l = floor(l * levels + threshold + 0.5) / levels;

	// Scanlines on the virtual rows.
	float scan = mix(1.0, 0.5 + 0.5 * step(0.5, fract(cell.y * 0.5)), scanline_strength);
	l *= scan;

	// Grain hashed per cell and frame.
	float noise = hash13(vec3(cell, frame));
	l += (noise - 0.5) * grain_amount;

	// Vignette.
	vec2 centered = SCREEN_UV - 0.5;
	float vig = 1.0 - dot(centered, centered) * vignette_strength;
	l *= clamp(vig, 0.0, 1.0);

	// Rare invert flash plus the controller's pulse invert.
	float flash = step(hash12(vec2(frame, 3.0)), invert_chance);
	float inv = clamp(flash + invert, 0.0, 1.0);
	l = mix(l, 1.0 - l, inv);

	COLOR = vec4(clamp(l, 0.0, 1.0) * tint, 1.0);
}
