shader_type spatial;
// Kaya, kabuk ve duvar: dünya konumundan gürültülü renk, üste bakan yüzlerde yosun,
// zemine değen yerde koyuluk. blocks=1 -> örülmüş taş blok deseni (sınır duvarı).
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 moss_col : source_color = vec3(0.22, 0.36, 0.1);
uniform float moss = 0.7;
uniform float blocks = 0.0;
uniform float streak = 0.0; // kabuk için dikey çizgiler
varying vec3 wp;
varying flat vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 an = abs(wn);
	vec2 uv = an.y > 0.6 ? wp.xz : (an.x > an.z ? wp.zy : wp.xy);
	float n = texture(noise_tex, uv * 0.13).r;
	float fine = texture(noise_tex, uv * vec2(1.1, mix(1.1, 0.12, streak))).r;
	vec3 col = tint * COLOR.rgb * (0.7 + 0.6 * n) * (0.8 + 0.4 * fine);
	float m = smoothstep(0.5, 0.8, wn.y * 0.55 + n * 0.6);
	if (blocks > 0.5) {
		if (an.y < 0.6) {
			float row = floor(uv.y / 0.5);
			vec2 b = vec2(uv.x / 1.15 + fract(row * 0.37), uv.y / 0.5);
			vec2 f = fract(b);
			float hsh = fract(sin(dot(floor(b), vec2(12.9898, 78.233))) * 43758.5453);
			col *= 0.72 + 0.5 * hsh;
			col = mix(col, col * vec3(1.12, 1.0, 0.85), step(0.7, hsh)); // bazı taşlar sıcak tonda
			float edge = min(min(f.x, 1.0 - f.x) * 1.15, min(f.y, 1.0 - f.y) * 0.5); // derze uzaklık (m)
			col *= mix(0.35, 1.0, smoothstep(0.012, 0.05, edge));
		}
		// Duvarın tepesinden aşağı sarkan ve dibinden tırmanan yosun.
		m = max(m, smoothstep(0.55, 0.9, n * 0.9 + (wp.y - 2.3) * 0.5));
		m = max(m, smoothstep(0.5, 0.9, n * 0.8 + (0.9 - wp.y) * 0.5) * 0.7);
	}
	col = mix(col, moss_col * (0.6 + 0.8 * fine), m * moss);
	col *= mix(0.55, 1.0, smoothstep(0.0, 0.6, wp.y));
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
