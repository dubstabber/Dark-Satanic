// PSX-look vertex helpers shared by the psx_* spatial shaders.
// Reworked from references/godot-psx-master (MIT, AnalogFeelings): the snap
// runs in clip space through POSITION so normals and vertex lighting stay
// correct (the reference's skip_vertex_transform path never transformed
// NORMAL), and the affine warp is the exact perspective-cancelling form
// rather than a view-depth approximation.

// Snap a clip-space position onto a coarse virtual grid, the PS1's missing
// sub-pixel vertex precision. `strength` 0 leaves the vertex alone, 1 is the
// coarsest wobble; the grid follows the short viewport axis so the effect
// scales with render resolution.
vec4 psx_snap(vec4 clip, vec2 viewport_size, float strength) {
	if (strength <= 0.0 || clip.w <= 0.0) {
		return clip;
	}
	float grid = max((1.0 - strength) * min(viewport_size.x, viewport_size.y) * 0.5, 1.0);
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	return clip;
}

// Build the varying psx_affine_uv() needs: UV premultiplied by clip w, plus w.
vec3 psx_affine_varying(vec2 uv, vec4 clip) {
	return vec3(uv * clip.w, clip.w);
}

// Affine (PS1) texture coordinates. The GPU interpolates varyings
// perspective-correctly by dividing by w; premultiplying by w in the vertex
// stage cancels that division exactly, leaving the screen-linear
// interpolation the PS1 rasterised with. `strength` blends back toward the
// perspective-correct `uv`.
vec2 psx_affine_uv(vec2 uv, vec3 affine, float strength) {
	if (abs(affine.z) < 0.0001) {
		return uv;
	}
	return mix(uv, affine.xy / affine.z, strength);
}
