shader_type spatial;
// Zemin: gürültüyle çimen yamaları, toprak patikalar, ağaç altı koyuluk. Geometri düz kalır.
#include "ground_tint.gdshaderinc"
uniform float arena_half = 30.0;
uniform bool uv2_dirt = false; // world.gd: UV2.x = toprak yol oranı
varying vec3 wp;
varying vec3 wn;

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
	vec3 dirt = mix(vec3(0.11, 0.07, 0.035), vec3(0.24, 0.17, 0.09), n) * (0.8 + 0.4 * fine);
	dirt *= mix(1.0, 0.7, texture(mask_tex, wp.xz / (mask_half * 2.0) + 0.5).r);
	if (uv2_dirt) {
		dirt *= mix(0.62, 1.0, smoothstep(0.55, 0.95, g.a)); // açık dünya: patika kenarı koyu, belirgin
	}
	vec3 col = mix(g.rgb * (0.62 + 0.25 * fine), dirt, g.a);
	if (uv2_dirt) {
		// Dik yamaç: gürültülü gri kaya/çakıl (açık dünya dağları); yalnızca eğime bağlı.
		float rk = smoothstep(0.88, 0.7, wn.y) * (0.6 + 0.8 * n);
		vec3 rock = mix(vec3(0.2, 0.19, 0.19), vec3(0.4, 0.37, 0.34), fine) * (0.8 + 0.4 * n);
		col = mix(col, rock, clamp(rk, 0.0, 1.0));
	}
	// Duvarın dışı sık orman: zemin koyulaşır, ufuk çizgisi ağırlaşmaz.
	col *= mix(1.0, 0.55, smoothstep(arena_half, arena_half + 20.0, max(abs(wp.x), abs(wp.z))));
	// Köşe rengi (world.gd biyom tonu): a = doygunluk, rgb = çarpan. Rengi olmayan ağda beyaz -> değişmez.
	col = mix(vec3(dot(col, vec3(0.3, 0.59, 0.11))), col, COLOR.a) * COLOR.rgb;
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
