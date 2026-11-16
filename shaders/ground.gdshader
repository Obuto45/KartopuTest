shader_type spatial;
// Zemin: gürültüyle çimen yamaları, toprak patikalar, ağaç altı koyuluk. Geometri düz kalır.
#include "ground_tint.gdshaderinc"
uniform float arena_half = 30.0;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 g = ground_info(wp.xz);
	float n = texture(noise_tex, wp.xz * 0.23 + 0.11).r;
	float fine = texture(noise_tex, wp.xz * 1.7).r;
	vec3 dirt = mix(vec3(0.11, 0.07, 0.035), vec3(0.24, 0.17, 0.09), n) * (0.8 + 0.4 * fine);
	dirt *= mix(1.0, 0.7, texture(mask_tex, wp.xz / (mask_half * 2.0) + 0.5).r);
	vec3 col = mix(g.rgb * (0.62 + 0.25 * fine), dirt, g.a);
	// Duvarın dışı sık orman: zemin koyulaşır, ufuk çizgisi ağırlaşmaz.
	col *= mix(1.0, 0.55, smoothstep(arena_half, arena_half + 20.0, max(abs(wp.x), abs(wp.z))));
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
