shader_type spatial;
render_mode world_vertex_coords;
// Yaprak kümeleri (taç, çam katı, çalı): küre normalli, yumuşak boyalı ışık, rüzgârda salınım.
// UV.y = ağ içindeki yükseklik (0 alt, 1 üst), UV.x = ağ merkezinin model y'si; renk örnekten (COLOR) gelir.
#include "wind.gdshaderinc"
uniform float sway = 1.0;
uniform float sphere_normal : hint_range(0.0, 1.0) = 0.92; // 1: tamamen küre normali (pürüzsüz taç)
varying float h;
varying float down; // alta bakan yüz (yumuşak geçişli) (çam eteğinin altı)

void vertex() {
	h = UV.y;
	down = smoothstep(0.3, 0.9, -NORMAL.y);
	vec3 o = MODEL_MATRIX[3].xyz;
	// Taç normali kümenin merkezinden dışa: düz yüzler kaybolur, top gibi yumuşak aydınlanır.
	vec3 center = o + MODEL_MATRIX[1].xyz * UV.x;
	NORMAL = normalize(mix(NORMAL, normalize(VERTEX - center), sphere_normal));
	float t = TIME * 1.1 + o.x * 0.31 + o.z * 0.23;
	vec3 d = vec3(sin(t), 0.0, cos(t * 0.8)) * 0.04; // bütün küme birlikte
	vec2 w = wind_dir_n() * (0.04 + 0.16 * wind_wave(o.xz, TIME)) * wind_strength; // çimle aynı dalga
	d.xz += w;
	d += vec3(sin(TIME * 2.7 + VERTEX.y * 1.9 + VERTEX.z), sin(TIME * 2.2 + VERTEX.x * 1.7), cos(TIME * 2.4 + VERTEX.x)) * 0.035; // yaprak hışırtısı
	VERTEX += d * sway * clamp(o.y * 0.4, 0.0, 1.0); // yere yakın çalılar az oynar
}

void fragment() {
	vec3 c = COLOR.rgb * mix(0.62, 1.2, smoothstep(0.05, 0.95, h));
	c = mix(c, vec3(0.2, 0.15, 0.08), down * 0.7); // etek altı: dal rengi, kapkara kalmasın
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}

// Yarım Lambert + 3 kademeli yumuşak ton rampası (boyalı görünüm) + kenarda arkadan ışık geçirme.
void light() {
	float nl = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float tone = 0.3 + 0.3 * smoothstep(0.15, 0.55, nl) + 0.4 * smoothstep(0.5, 0.95, nl);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5) * smoothstep(0.0, 0.8, dot(LIGHT, -VIEW));
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (tone + rim * 0.7) / PI;
}
