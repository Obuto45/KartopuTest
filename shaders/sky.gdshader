shader_type sky;
// Altın saat göğü: atmosferik saçılım, çok katmanlı boyalı bulutlar (güneş kenar parıltısı + alt gölge) ve güneş diski.
// TIME kullanılmaz: TIME gök radyansını her kare yeniden hesaplatır (pahalı); bulutlar bu yüzden sabit.
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 top_col : source_color = vec3(0.11, 0.29, 0.66);
uniform vec3 mid_col : source_color = vec3(0.32, 0.56, 0.86);
uniform vec3 horizon_col : source_color = vec3(0.99, 0.76, 0.50);
uniform vec3 sun_col : source_color = vec3(1.0, 0.76, 0.44);
uniform vec3 ground_col : source_color = vec3(0.28, 0.30, 0.20);

float cloud_fbm(vec2 uv) {
	float a = texture(noise_tex, uv).r;
	float b = texture(noise_tex, uv * 2.15 + vec2(0.37, 0.19)).r;
	float c = texture(noise_tex, uv * 4.7 + vec2(0.71, 0.63)).r;
	return a * 0.55 + b * 0.30 + c * 0.15;
}

void sky() {
	float y = EYEDIR.y;
	float hy = clamp(y, 0.0, 1.0);

	// Üç bantlı altın saat göğü: sıcak şeftali ufuk -> açık mavi orta -> derin lacivert tepe
	vec3 col = mix(horizon_col, mid_col, smoothstep(0.0, 0.34, pow(hy, 0.72)));
	col = mix(col, top_col, smoothstep(0.25, 0.92, pow(hy, 0.58)));

	// Atmosferik ufuk sıcaklığı ve güneş yönünde Mie saçılımı
	float sd = max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0);
	float horizon_band = exp(-abs(y) * 9.5);
	col += sun_col * horizon_band * (0.14 + 0.34 * pow(sd, 2.2));
	col += sun_col * (pow(sd, 6.0) * 0.28 + pow(sd, 48.0) * 0.48);

	if (y > 0.0) {
		// Yüksek ince sirüs bulutları
		vec2 cuv = EYEDIR.xz / (y + 0.22) * 0.045;
		float cirrus = texture(noise_tex, cuv * vec2(1.8, 0.55) + 0.2).r;
		float cirrus_mask = smoothstep(0.56, 0.84, cirrus) * smoothstep(0.04, 0.28, y) * 0.26;
		vec3 cirrus_col = mix(vec3(0.95, 0.92, 0.96), vec3(1.0, 0.84, 0.62), pow(sd, 1.6));
		col = mix(col, cirrus_col, cirrus_mask);

		// Ana kümülüs bulutları: güneşe doğru kaydırılmış örneklemle hacimsel gölge + gümüş kenar
		vec2 uv = EYEDIR.xz / (y + 0.13) * 0.068;
		float d = cloud_fbm(uv);
		vec2 sun_off = normalize(LIGHT0_DIRECTION.xz + vec2(0.0001)) * 0.016;
		float d_lit = cloud_fbm(uv + sun_off);
		float light_term = clamp((d - d_lit) * 3.2 + 0.52, 0.0, 1.0);

		float cov = smoothstep(0.47, 0.72, d) * smoothstep(0.01, 0.14, y);
		vec3 cloud_shadow = mix(vec3(0.46, 0.49, 0.64), vec3(0.76, 0.58, 0.54), pow(sd, 1.8));
		vec3 cloud_lit = mix(vec3(0.99, 0.95, 0.90), vec3(1.0, 0.84, 0.58), pow(sd, 1.5));
		vec3 cloud = mix(cloud_shadow, cloud_lit, smoothstep(0.18, 0.85, light_term));
		// Güneş arkadan vurduğunda bulut kenarında sıcak parlama (silver lining)
		float rim = pow(sd, 5.0) * (1.0 - smoothstep(0.55, 0.82, d)) * 0.65;
		cloud += sun_col * rim;

		col = mix(col, cloud, cov * 0.88);
	}

	// Güneş diski (HDR parıltı ile glow tetikler)
	col += sun_col * pow(sd, 1400.0) * 6.5;

	// Ufuk altı yumuşak yer yansıması
	vec3 low = mix(ground_col, horizon_col * 0.52, smoothstep(-0.28, 0.0, y));
	COLOR = mix(low, col, smoothstep(-0.04, 0.01, y));
}
