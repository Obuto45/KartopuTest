shader_type spatial;
// Duvar taşı: katmanlı kaya + çatlaklar, dibe doğru toprak. Desen bloğun kendi uzayında: yükselirken kaymaz.
varying vec3 lp;
varying float up;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1) * 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	up = VERTEX.y; // bloğun ortasına göre yükseklik
	lp = VERTEX + MODEL_MATRIX[3].xzx * 3.7; // her blok farklı desen
}

void fragment() {
	float n = noise(lp * 2.5) * 0.6 + noise(lp * 7.0) * 0.4;
	float band = (lp.y + n * 0.25) * 5.0; // yatay katmanlar
	float tone = 0.75 + hash(vec3(floor(band), 3.0, 7.0)) * 0.3 + (n - 0.5) * 0.3;
	float crack = smoothstep(0.035, 0.0, abs(noise(lp * vec3(3.0, 1.5, 3.0) + 9.0) - 0.5))
		+ smoothstep(0.42, 0.5, abs(fract(band) - 0.5)) * 0.6;
	vec3 c = vec3(0.5, 0.47, 0.43) * tone;
	c = mix(c, vec3(0.3, 0.2, 0.12) * (0.8 + n * 0.5), smoothstep(-0.5, -1.0, up + (n - 0.5) * 0.5)); // dipte toprak
	ALBEDO = c * (1.0 - clamp(crack, 0.0, 1.0) * 0.55);
	ROUGHNESS = 0.95;
}
