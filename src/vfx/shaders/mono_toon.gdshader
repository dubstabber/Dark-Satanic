// Monochrome 3-band toon lighting with a white rim and an additive hit flash.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform vec3 base_color : source_color = vec3(0.7, 0.7, 0.7);
uniform float emission_energy : hint_range(0.0, 8.0, 0.05) = 0.0;
uniform float hit_flash : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float rim_width : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float rim_strength : hint_range(0.0, 2.0, 0.01) = 0.6;
uniform float band_low : hint_range(0.0, 1.0, 0.01) = 0.2;
uniform float band_high : hint_range(0.0, 1.0, 0.01) = 0.6;

void fragment() {
	float grey = dot(base_color, vec3(0.299, 0.587, 0.114));
	ALBEDO = vec3(grey);
	float rim = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	rim = step(1.0 - rim_width, rim) * rim_strength;
	EMISSION = vec3(grey * emission_energy + rim + hit_flash);
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float band = 0.15 + 0.35 * step(band_low, ndl) + 0.5 * step(band_high, ndl);
	float light_grey = dot(LIGHT_COLOR, vec3(0.299, 0.587, 0.114));
	DIFFUSE_LIGHT += ALBEDO * band * light_grey * ATTENUATION;
}
