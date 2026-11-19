shader_type sky;
// Altın saat göğü: sıcak ufuk, güneş halesi ve gürültü dokusundan sabit bulutlar.
// TIME kullanılmaz: gök bir kez çizilir, ortam ışığı her karede yeniden hesaplanmaz.
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 top_col : source_color = vec3(0.16, 0.36, 0.72);
uniform vec3 horizon_col : source_color = vec3(0.98, 0.78, 0.56);
uniform vec3 sun_col : source_color = vec3(1.0, 0.72, 0.4);
uniform vec3 ground_col : source_color = vec3(0.42, 0.4, 0.26);

void sky() {
	float y = EYEDIR.y;
	// Ufuk bandı geniş: uzak tepeler/sis (horizon_col) göğe erir.
	vec3 col = mix(horizon_col, top_col, pow(clamp(y, 0.0, 1.0), 0.55));
	float sd = max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0);
	// Yumuşak halo + güneş diski.
	col += sun_col * (pow(sd, 4.0) * 0.22 + pow(sd, 24.0) * 0.3);
	if (y > 0.0) {
		// 3 katman bulut: farklı ölçek/ofset; ufka doğru sis rengine karışır.
		vec2 uv = EYEDIR.xz / (y + 0.15) * 0.06;
		float c1 = texture(noise_tex, uv).r;
		float c2 = texture(noise_tex, uv * 2.3 + 0.4).r;
		float c3 = texture(noise_tex, uv * 0.45 + 0.7).r;
		float c = smoothstep(0.42, 0.78, c1 * 0.5 + c2 * 0.2 + c3 * 0.3);
		c *= smoothstep(0.0, 0.22, y);
		float lit = smoothstep(0.35, 0.8, c3 + (c1 - 0.5) * 0.4); // bulut altı gölge / üstü aydınlık
		vec3 cloud = mix(vec3(0.82, 0.8, 0.84), vec3(1.0, 0.97, 0.94), lit);
		cloud = mix(cloud, horizon_col * 1.1 + sun_col * 0.2, pow(sd, 3.0) * 0.6 + (1.0 - smoothstep(0.0, 0.35, y)) * 0.4);
		col = mix(col, cloud, c * 0.85);
	}
	col += sun_col * smoothstep(0.9993, 0.9998, sd) * 3.0; // güneş diski
	// Zemin altı: ufuk rengine yumuşak geçiş (sert çizgi yok).
	COLOR = mix(mix(horizon_col, ground_col, 0.5), col, smoothstep(-0.12, 0.02, y));
}
