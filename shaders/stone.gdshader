shader_type spatial;
// Kaya, ağaç kabuğu ve taş duvar: prosedürel normal kabartması, yontulmuş derzli taş bloklar,
// dikey kabuk yarıkları, kadifemsi yosun ve zemin temas gölgesi (AO).
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 moss_col : source_color = vec3(0.24, 0.39, 0.09);
uniform float moss = 0.7;
uniform float blocks = 0.0;
uniform float streak = 0.0; // kabuk için dikey çizgiler
varying vec3 wp;
varying vec3 wn;

float surface_h(vec2 uv, float is_side) {
	float n = texture(noise_tex, uv * 0.14).r;
	float fine = texture(noise_tex, uv * vec2(1.25, mix(1.25, 0.13, streak))).r;
	float h = n * 0.45 + fine * 0.55;
	if (blocks > 0.5 && is_side > 0.5) {
		float row = floor(uv.y / 0.5);
		vec2 b = vec2(uv.x / 1.15 + fract(row * 0.37), uv.y / 0.5);
		vec2 f = fract(b);
		float edge = min(min(f.x, 1.0 - f.x) * 1.15, min(f.y, 1.0 - f.y) * 0.5);
		float bevel = smoothstep(0.01, 0.065, edge);
		h = h * 0.45 + bevel * 0.55;
	}
	return h;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 nrm = normalize(wn);
	vec3 an = abs(nrm);
	vec2 uv = an.y > 0.6 ? wp.xz : (an.x > an.z ? wp.zy : wp.xy);
	float is_side = an.y < 0.6 ? 1.0 : 0.0;

	float n = texture(noise_tex, uv * 0.13).r;
	float fine = texture(noise_tex, uv * vec2(1.2, mix(1.2, 0.13, streak))).r;
	float micro = texture(noise_tex, uv * vec2(3.4, mix(3.4, 0.55, streak))).r;

	vec3 col = tint * COLOR.rgb * (0.72 + 0.52 * n) * (0.80 + 0.38 * fine);
	// Yumuşak renk kırılımı: düşük frekanslı gürültüyle sıcak/soğuk ton kayması (düz yüz hissi azalır).
	float br = texture(noise_tex, uv * 0.045 + 0.3).r;
	col *= mix(vec3(0.94, 0.96, 1.05), vec3(1.08, 1.02, 0.92), smoothstep(0.3, 0.7, br));
	// Kabukta koyu dikey yarıklar
	if (streak > 0.5) {
		float furrow = smoothstep(0.25, 0.65, fine);
		col *= mix(0.58, 1.12, furrow);
	}

	float m = smoothstep(0.46, 0.78, nrm.y * 0.58 + n * 0.55);
	float mortar_ao = 1.0;
	if (blocks > 0.5) {
		if (is_side > 0.5) {
			float row = floor(uv.y / 0.5);
			vec2 b = vec2(uv.x / 1.15 + fract(row * 0.37), uv.y / 0.5);
			vec2 f = fract(b);
			float hsh = fract(sin(dot(floor(b), vec2(12.9898, 78.233))) * 43758.5453);
			col *= 0.74 + 0.46 * hsh;
			col = mix(col, col * vec3(1.14, 1.02, 0.86), step(0.68, hsh)); // sıcak kumtaşı bloklar
			col = mix(col, col * vec3(0.88, 0.92, 0.98), step(0.84, fract(hsh * 7.3))); // serin gri bloklar
			float edge = min(min(f.x, 1.0 - f.x) * 1.15, min(f.y, 1.0 - f.y) * 0.5);
			mortar_ao = mix(0.30, 1.0, smoothstep(0.012, 0.055, edge));
			col *= mortar_ao;
		}
		// Duvarın tepesinden sarkan ve dibinden tırmanan yosun
		m = max(m, smoothstep(0.52, 0.88, n * 0.9 + (min(wp.y, 3.0) - 2.55) * 0.52));
		m = max(m, smoothstep(0.48, 0.88, n * 0.8 + (0.95 - wp.y) * 0.5) * 0.75);
	}

	float moss_w = clamp(m * moss, 0.0, 1.0);
	vec3 moss_shaded = moss_col * (0.62 + 0.72 * fine + 0.16 * micro);
	col = mix(col, moss_shaded, moss_w);
	// Yükseklikten bağımsız yumuşak ortam gölgesi (tepe/vadi haritalarında kararma yapmaz)
	col *= mix(0.76, 1.0, smoothstep(-0.35, 0.45, nrm.y));

	// Hafif rim: kenarlar açılır, sert siluet yumuşar (NaN korumalı).
	float rim = pow(max(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 0.0001), 3.0);
	col += col * rim * 0.30;

	// Prosedürel normal kabartması (6 ek örnek): yalnızca yakında; blok derzleri, çatlak ve kabuk yarıkları ışığı yakalar
	if (length(VERTEX) < 30.0) {
		float eps = 0.025;
		float h0 = surface_h(uv, is_side);
		float hx = surface_h(uv + vec2(eps, 0.0), is_side);
		float hy = surface_h(uv + vec2(0.0, eps), is_side);
		float bump = mix(blocks > 0.5 ? 0.14 : (streak > 0.5 ? 0.11 : 0.12), 0.04, moss_w);
		vec2 grad = vec2(h0 - hx, h0 - hy) * (bump / eps);
		vec3 t1 = an.y > 0.6 ? vec3(1.0, 0.0, 0.0) : (an.x > an.z ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0));
		vec3 t2 = an.y > 0.6 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
		vec3 perturbed = normalize(nrm + t1 * grad.x + t2 * grad.y);
		NORMAL = normalize((VIEW_MATRIX * vec4(perturbed, 0.0)).xyz);
	}

	ALBEDO = col;
	ROUGHNESS = mix(mix(0.80, 0.92, streak), 0.96, moss_w);
	SPECULAR = mix(0.28, 0.08, moss_w) * mortar_ao;
}
