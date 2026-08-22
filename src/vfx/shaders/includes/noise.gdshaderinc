// Cheap hash-based noise helpers shared by the Sad Satan shaders.
// hash12: 2D -> [0,1), hash13: 3D -> [0,1). Deterministic per input.

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 p) {
	vec3 p3 = fract(p * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}
