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
	float far_k = 0.0; // açık dünya: ince detay mesafeyle sönür (moire/titreme yok)
	if (uv2_dirt) {
		far_k = smoothstep(18.0, 70.0, length(VERTEX));
		fine = mix(fine, 0.5, far_k);
	}
	vec3 dirt = mix(vec3(0.11, 0.07, 0.035), vec3(0.24, 0.17, 0.09), n) * (0.8 + 0.4 * fine);
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
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
