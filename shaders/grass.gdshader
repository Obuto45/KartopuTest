shader_type spatial;
render_mode cull_disabled, world_vertex_coords;
// Çimen ve çiçek: rüzgârda sallanır (kök sabit, uç oynar). tint_mix=1 -> zemin renginden kök-uç geçişi.
#include "ground_tint.gdshaderinc"
uniform float tint_mix = 1.0;
uniform float top = 0.5; // sallanmanın tam olduğu yükseklik (m)
varying vec3 base;
varying float h;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	h = clamp(VERTEX.y / top, 0.0, 1.0);
	// Gürültü dokusu zamanla kayar: çayırda gezen rüzgâr dalgaları.
	float gust = textureLod(noise_tex, root.xz * 0.02 + TIME * vec2(0.05, 0.03), 0.0).r;
	vec2 sway = vec2(sin(TIME * 1.9 + root.x * 0.7 + root.z * 0.3), cos(TIME * 1.4 + root.z * 0.6)) * 0.03;
	sway += vec2(0.85, 0.5) * (gust - 0.42) * 0.32;
	VERTEX.xz += sway * h * h * top * 2.0;
	VERTEX.y -= length(sway) * h * h * top * 0.6;
	base = ground_info(root.xz).rgb * (0.85 + 0.5 * gust);
}

void fragment() {
	vec3 grass = mix(base * 0.6, base * 1.7 + vec3(0.03, 0.035, 0.0), h * h) * COLOR.rgb;
	ALBEDO = mix(COLOR.rgb, grass, tint_mix);
	// Çift yüzlü ince yaprak: normal hep yukarı -> zeminle aynı ışığı alır, arka yüz kararmaz.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
