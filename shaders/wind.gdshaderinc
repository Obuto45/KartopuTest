// Ortak rüzgâr: çim ve ağaç aynı dalgayı kullanır; dalga wind_dir yönünde yürür (çimden ağaca esinti).
global uniform vec2 wind_dir;
global uniform float wind_strength;

vec2 wind_dir_n() {
	return normalize(wind_dir + vec2(1e-4));
}

// 0..1: p konumundaki esinti şiddeti (iki dalga toplamı, düzensiz).
float wind_wave(vec2 p, float t) {
	float ph = dot(p, wind_dir_n()) * 0.14 - t * 1.4;
	return 0.5 + 0.3 * sin(ph) + 0.2 * sin(ph * 2.3 + 1.7);
}
