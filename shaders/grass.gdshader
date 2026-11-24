shader_type spatial;
render_mode cull_disabled, world_vertex_coords;
// Çimen ve çiçek: çok dalgalı rüzgâr, kök AO, güneş geçirgenliği (subsurface) ve uç parıltısı.
#include "ground_tint.gdshaderinc"
#include "wind.gdshaderinc"
uniform float tint_mix = 1.0;
uniform float top = 0.5; // sallanmanın tam olduğu yükseklik (m, örnek ölçeği öncesi)
uniform float fade_start = 20.0; // bu mesafeden sonra bıçaklar kısalıp zemine karışır
uniform float fade_end = 38.0;
varying vec3 base;
varying float h;
varying float far;
varying float gust_v;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	h = clamp((VERTEX.y - root.y) / max(top * length(MODEL_MATRIX[1].xyz), 0.001), 0.0, 1.0);
	// Uzakta bıçak köke doğru kısalır: aniden kesilmez; çiçekler solmaz.
	float fade = 1.0 - smoothstep(fade_start, fade_end, distance(root, CAMERA_POSITION_WORLD)) * step(0.5, tint_mix);
	far = 1.0 - fade;
	VERTEX = root + (VERTEX - root) * vec3(1.0, fade, 1.0);
	float gust = textureLod(noise_tex, root.xz * 0.02 + TIME * vec2(0.05, 0.03), 0.0).r;
	// İnce yaprak titreşimi: rüzgâr yönünde küçük dalgacık.
	float ripple = textureLod(noise_tex, root.xz * 0.075 - TIME * wind_dir_n() * 0.1, 0.0).r;
	gust_v = gust;
	vec2 sway = wind_dir_n() * (0.05 + 0.2 * wind_wave(root.xz, TIME) + 0.1 * (gust - 0.42) + 0.1 * (ripple - 0.5)) * wind_strength;
	sway += vec2(sin(TIME * 1.9 + root.x * 0.7 + root.z * 0.3), cos(TIME * 1.4 + root.z * 0.6)) * 0.02;
	VERTEX.xz += sway * h * h * top * 2.0 * fade;
	VERTEX.y -= length(sway) * h * h * top * 0.6 * fade;
	base = ground_info(root.xz).rgb * (0.85 + 0.5 * gust);
}

void fragment() {
	// Kök koyu, uç açık ve sarımsı; uzakta zemin rengine yaklaşır.
	vec3 root_c = base * 0.45;
	vec3 tip_c = base * 1.9 + vec3(0.05, 0.06, 0.0) * (0.7 + 0.6 * gust_v);
	vec3 grass = mix(root_c, tip_c, smoothstep(0.0, 1.0, pow(max(h, 0.0001), 1.35))) * COLOR.rgb;
	grass = mix(grass, base * COLOR.rgb, far * 0.85);
	ALBEDO = mix(COLOR.rgb, grass, tint_mix);
	BACKLIGHT = tip_c * h * h * 0.5 * (1.0 - far) * tint_mix; // uçta sahte subsurface
	// Normal yukarı (zeminle aynı ışık, arka yüz kararmaz); rüzgâr yönüne hafif eğim ışıkta ipek dalgası verir.
	vec2 tilt = wind_dir_n() * (gust_v - 0.45) * 0.38 * h * (1.0 - far);
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(tilt.x, 1.0, tilt.y)), 0.0)).xyz);
	float sp = h * h * tint_mix * (1.0 - far);
	ROUGHNESS = mix(1.0, 0.6, sp);
	SPECULAR = mix(0.0, 0.24, sp);
}
