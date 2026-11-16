// Zemin ve çimen aynı renk haritasını kullanır: çim kökleri zemine karışır, yama sınırı görünmez.
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D mask_tex : repeat_disable, filter_linear; // R: ağaç altı gölge, G: toprak
uniform float mask_half = 50.0; // maskenin kapladığı yarı kenar (m)

// rgb: o noktadaki çimen rengi, a: toprak oranı
vec4 ground_info(vec2 p) {
	float n1 = texture(noise_tex, p * 0.011).r;
	float n2 = texture(noise_tex, p * 0.047 + 0.37).r;
	float n3 = texture(noise_tex, p * 0.23 + 0.11).r;
	vec2 m = texture(mask_tex, p / (mask_half * 2.0) + 0.5).rg;
	vec3 g = mix(vec3(0.07, 0.19, 0.035), vec3(0.20, 0.33, 0.05), smoothstep(0.3, 0.72, n1 * 0.55 + n2 * 0.45));
	g = mix(g, vec3(0.33, 0.34, 0.07), smoothstep(0.6, 0.8, n2) * 0.55); // kurumuş sarı yamalar
	g *= mix(1.0, 0.6, m.r);
	float dirt = smoothstep(0.38, 0.62, m.g + (n3 - 0.5) * 0.55 + (n2 - 0.5) * 0.25);
	return vec4(g, dirt);
}
