shader_type spatial;
// Zemin: prosedürel normal kabartmalı çimen çayırı, çakıllı toprak patikalar ve ağaç altı nemli gölge.
#include "ground_tint.gdshaderinc"
uniform float arena_half = 30.0;
uniform bool uv2_dirt = false; // world.gd: UV2.x = toprak yol oranı
varying vec3 wp;
varying vec3 wn;

float ground_h(vec2 p, float dirt_mask) {
	float macro = texture(noise_tex, p * 0.14 + 0.21).r;
	float med = texture(noise_tex, p * 0.75 + 0.07).r;
	float micro = texture(noise_tex, p * 2.6).r;
	float grass_h = macro * 0.5 + med * 0.3 + micro * 0.2;
	float dirt_h = macro * 0.25 + med * 0.45 + micro * 0.30;
	return mix(grass_h, dirt_h, dirt_mask);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec4 g = ground_info(wp.xz);
	float n = texture(noise_tex, wp.xz * 0.23 + 0.11).r;
	if (uv2_dirt) {
		g.a = max(g.a, smoothstep(0.42, 0.58, UV2.x + (n - 0.5) * 0.4));
	}
	float fine = texture(noise_tex, wp.xz * 1.7).r;
	float far_k = 0.0; // açık dünya: ince detay mesafeyle sönür (moire/titreme yok)
	if (uv2_dirt) {
		far_k = smoothstep(18.0, 70.0, length(VERTEX));
		fine = mix(fine, 0.5, far_k);
	}
	float pebble = smoothstep(0.74, 0.88, texture(noise_tex, wp.xz * 3.6 + 0.43).r) * (1.0 - far_k);
	vec3 dirt = mix(vec3(0.11, 0.07, 0.035), vec3(0.24, 0.17, 0.09), n) * (0.8 + 0.4 * fine);
	dirt = mix(dirt, vec3(0.39, 0.36, 0.31), pebble * 0.55); // serpilmiş minik çakıl
	dirt *= mix(1.0, 0.7, texture(mask_tex, wp.xz / (mask_half * 2.0) + 0.5).r);
	if (uv2_dirt) {
		dirt *= mix(0.62, 1.0, smoothstep(0.55, 0.95, g.a)); // açık dünya: patika kenarı koyu, belirgin
	}
	vec3 col = mix(g.rgb * (0.62 + 0.25 * fine), dirt, g.a);
	if (uv2_dirt) {
		// Dik yamaç: gürültülü gri kaya/çakıl (açık dünya dağları); yalnızca eğime bağlı.
		// Geniş geçiş: çim -> toprak (orta eğim) -> kaya (dik); keskin sınır yok.
		float slope = smoothstep(0.96, 0.6, wn.y);
		float rk = smoothstep(0.35, 1.0, slope) * (0.7 + 0.6 * n);
		col = mix(col, dirt * 1.15, smoothstep(0.0, 0.45, slope) * 0.8 * (1.0 - g.a));
		vec3 rock = mix(vec3(0.2, 0.19, 0.19), vec3(0.4, 0.37, 0.34), fine) * (0.8 + 0.4 * n);
		// Kül zemini (g.a 0.25-0.4 bandı): çatlak çizgileri ve hafif eğimde koyu kaya tonu.
		float ash = smoothstep(0.25, 0.4, g.a) * (1.0 - smoothstep(0.6, 0.8, g.a));
		float crack = (1.0 - smoothstep(0.0, 0.05, abs(fine - 0.5))) * (1.0 - far_k);
		col *= 1.0 - 0.4 * crack * ash;
		col = mix(col, col * vec3(0.55, 0.52, 0.5), smoothstep(0.97, 0.85, wn.y) * ash);
		col = mix(col, rock, clamp(rk, 0.0, 1.0));
		// Painterly: büyük ölçekli yumuşak ton lekeleri.
		float blot = texture(noise_tex, wp.xz * 0.006 + 0.5).r;
		col *= mix(0.88, 1.12, smoothstep(0.25, 0.75, blot));
		col = mix(col, col * vec3(1.06, 1.02, 0.9), smoothstep(0.55, 0.85, blot) * 0.5);
	}
	// Duvarın dışı sık orman: zemin koyulaşır, ufuk çizgisi ağırlaşmaz.
	col *= mix(1.0, 0.55, smoothstep(arena_half, arena_half + 20.0, max(abs(wp.x), abs(wp.z))));
	// Köşe rengi (world.gd biyom tonu): a = doygunluk, rgb = çarpan. Rengi olmayan ağda beyaz -> değişmez.
	col = mix(vec3(dot(col, vec3(0.3, 0.59, 0.11))), col, COLOR.a) * COLOR.rgb;
	// Prosedürel kabartma (sonlu fark, 9 örnek): yalnızca yakında; mesh normaline eklenir, yamaç eğimi korunur.
	float bump_k = 1.0 - smoothstep(12.0, 25.0, length(VERTEX));
	if (bump_k > 0.0) {
		float eps = 0.08;
		float h0 = ground_h(wp.xz, g.a);
		float hx = ground_h(wp.xz + vec2(eps, 0.0), g.a);
		float hz = ground_h(wp.xz + vec2(0.0, eps), g.a);
		float bs = mix(0.26, 0.55, g.a) * bump_k / eps;
		vec3 bn = normalize(wn + vec3((h0 - hx) * bs, 0.0, (h0 - hz) * bs));
		NORMAL = normalize((VIEW_MATRIX * vec4(bn, 0.0)).xyz);
	}
	ALBEDO = col;
	ROUGHNESS = mix(0.88, mix(0.94, 0.64, pebble), g.a);
	SPECULAR = mix(0.14, mix(0.18, 0.34, pebble), g.a);
}
