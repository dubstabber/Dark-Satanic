// Ordered dither thresholds computed arithmetically (no const arrays).
// bayer4 returns the 4x4 Bayer threshold in [0,1) for an integer pixel cell.

float bayer2(ivec2 p) {
	int x = p.x & 1;
	int y = p.y & 1;
	return float((x ^ y) * 2 + y) / 4.0;
}

float bayer4(ivec2 p) {
	int x = p.x & 3;
	int y = p.y & 3;
	int v = ((x ^ y) & 1) * 8 + (y & 1) * 4 + (((x ^ y) >> 1) & 1) * 2 + ((y >> 1) & 1);
	return float(v) / 16.0;
}

float bayer8(ivec2 p) {
	return (bayer4(p) * 16.0 + bayer2(p >> 2) * 4.0) / 64.0;
}
