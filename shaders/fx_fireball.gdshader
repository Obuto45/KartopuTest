shader_type spatial;
// Ateş topu: gürültüyle yamulan küre; "progress" arttıkça beyaz çekirdek -> turuncu -> is rengine soğur ve erir.
render_mode unshaded, depth_draw_never, shadows_disabled;

instance uniform float progress = 0.0;
instance uniform float seed = 0.0;
varying vec3 lp;

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

float fbm(vec3 p) {
	return noise(p) * 0.6 + noise(p * 2.3) * 0.28 + noise(p * 5.1) * 0.12;
}

void vertex() {
	lp = VERTEX * 2.4 + vec3(seed, seed * 1.7 - progress * 1.2, seed * 0.3);
	VERTEX += NORMAL * (fbm(lp) - 0.45) * 0.5;
}

void fragment() {
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float heat = fbm(lp * 1.6) * 0.8 + f * 0.5 - progress * 1.3;
	vec3 c = mix(vec3(0.07, 0.05, 0.04), vec3(1.6, 0.3, 0.03), smoothstep(0.0, 0.22, heat));
	c = mix(c, vec3(2.4, 1.3, 0.3), smoothstep(0.22, 0.5, heat));
	c = mix(c, vec3(3.0, 2.7, 2.0), smoothstep(0.5, 0.85, heat));
	ALBEDO = c;
	ALPHA = smoothstep(-0.14, 0.02, heat) * smoothstep(0.0, 0.4, f); // kenar yumuşak: düz küre silüeti görünmesin
}
