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
	// Zengin orman çayırı: derin zümrüt gölge -> canlı bahar yeşili -> altın güneşli çayır tonları
	vec3 g = mix(vec3(0.06, 0.185, 0.042), vec3(0.20, 0.36, 0.058), smoothstep(0.28, 0.74, n1 * 0.55 + n2 * 0.45));
	g = mix(g, vec3(0.35, 0.37, 0.075), smoothstep(0.58, 0.82, n2) * 0.52); // güneş gören sıcak sarı-yeşil yamalar
	g *= mix(1.0, 0.56, m.r); // ağaç altı serin gölge
	float dirt = smoothstep(0.36, 0.64, m.g + (n3 - 0.5) * 0.52 + (n2 - 0.5) * 0.24);
	return vec4(g, dirt);
}
