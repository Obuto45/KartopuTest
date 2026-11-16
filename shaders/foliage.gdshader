shader_type spatial;
render_mode world_vertex_coords;
// Yaprak kümeleri (taç, çam katı, çalı): alt koyu üst açık, rüzgârda hafif salınım.
// UV.y = ağ içindeki yükseklik (0 alt, 1 üst); renk örnekten (COLOR) gelir.
uniform float sway = 1.0;
varying float h;

void vertex() {
	h = UV.y;
	vec3 o = MODEL_MATRIX[3].xyz;
	float t = TIME * 1.1 + o.x * 0.31 + o.z * 0.23;
	vec3 d = vec3(sin(t), 0.0, cos(t * 0.8)) * 0.09; // bütün küme birlikte
	d += vec3(sin(TIME * 2.7 + VERTEX.y * 1.9 + VERTEX.z), sin(TIME * 2.2 + VERTEX.x * 1.7), cos(TIME * 2.4 + VERTEX.x)) * 0.035; // yaprak hışırtısı
	VERTEX += d * sway * clamp(o.y * 0.4, 0.0, 1.0); // yere yakın çalılar az oynar
}

void fragment() {
	vec3 c = COLOR.rgb * mix(0.5, 1.2, smoothstep(0.05, 0.95, h));
	ALBEDO = c;
	BACKLIGHT = c * 0.35; // güneş arkadan vurunca yaprak ışık geçirir
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
