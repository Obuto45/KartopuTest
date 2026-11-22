shader_type spatial;
render_mode world_vertex_coords;
// Yaprak kümeleri (taç, çam katı, çalı): küre normalli, yumuşak boyalı ışık, rüzgârda salınım;
// benekli yaprak dokusu ve derin iç gölge.
// UV.y = ağ içindeki yükseklik (0 alt, 1 üst), UV.x = ağ merkezinin model y'si; renk örnekten (COLOR) gelir.
#include "wind.gdshaderinc"
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float sway = 1.0;
uniform float sphere_normal : hint_range(0.0, 1.0) = 0.92; // 1: tamamen küre normali (pürüzsüz taç)
varying float h;
varying float down; // alta bakan yüz (yumuşak geçişli) (çam eteğinin altı)
varying vec3 wp;

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
	wp = VERTEX;
}

void fragment() {
	// Dünya uzayında çok ölçekli benekli yaprak dokusu: düz üçgen hissini kırar, boyalı yaprak öbeği verir
	float n1 = texture(noise_tex, wp.xz * 0.42 + wp.y * 0.27).r;
	float n2 = texture(noise_tex, wp.xy * 1.35 + wp.z * 0.85).r;
	float leaf_mottle = mix(0.76, 1.24, smoothstep(0.22, 0.82, n1 * 0.6 + n2 * 0.4));

	// Alt derin serin gölge -> üst dengeli güneşli orman yeşili
	vec3 shadow_tint = COLOR.rgb * vec3(0.40, 0.52, 0.54);
	vec3 sunlit_tint = COLOR.rgb * vec3(1.06, 1.06, 0.90) + vec3(0.008, 0.012, 0.0);
	vec3 c = mix(shadow_tint, sunlit_tint, smoothstep(0.04, 0.92, h)) * leaf_mottle;

	// Çam eteği altı: dal kahvesi dokunuşu, kapkara kalmasın
	c = mix(c, vec3(0.16, 0.12, 0.07), down * 0.55);

	// Yumuşak Fresnel kenar parıltısı
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.4);
	c += sunlit_tint * fres * 0.06 * h;

	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.8, n2);
	SPECULAR = 0.12;
}

// Yarım Lambert + 3 kademeli yumuşak ton rampası (boyalı görünüm) + kenarda arkadan ışık geçirme.
void light() {
	float nl = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float tone = 0.3 + 0.3 * smoothstep(0.15, 0.55, nl) + 0.4 * smoothstep(0.5, 0.95, nl);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5) * smoothstep(0.0, 0.8, dot(LIGHT, -VIEW));
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (tone + rim * 0.7) / PI;
}
