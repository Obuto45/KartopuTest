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
	vec3 col = mix(horizon_col, top_col, pow(clamp(y, 0.0, 1.0), 0.42));
	float sd = max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0);
	col += sun_col * (pow(sd, 5.0) * 0.3 + pow(sd, 40.0) * 0.4);
	if (y > 0.0) {
		vec2 uv = EYEDIR.xz / (y + 0.12) * 0.07;
		float c = texture(noise_tex, uv).r * 0.65 + texture(noise_tex, uv * 3.1 + 0.4).r * 0.35;
		c = smoothstep(0.5, 0.72, c) * smoothstep(0.0, 0.12, y);
		vec3 cloud = mix(vec3(0.95, 0.9, 0.9), vec3(1.0, 0.8, 0.6), pow(sd, 2.0)) * mix(0.75, 1.1, smoothstep(0.5, 0.9, texture(noise_tex, uv * 1.7).r));
		col = mix(col, cloud, c * 0.8);
	}
	col += sun_col * pow(sd, 1500.0) * 6.0; // güneş diski
	COLOR = mix(ground_col, col, smoothstep(-0.06, 0.0, y));
}
