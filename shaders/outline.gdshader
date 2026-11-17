// Karakter dış çizgisi: ağın ters yüzlerini normal boyunca biraz şişirip koyu çizer (çizgi film hissi).
// Görüş uzayında şişirir: kalınlık modelin iç ölçeğinden bağımsız, metre cinsindendir.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, skip_vertex_transform;

uniform float width = 0.02;
uniform vec4 color : source_color = vec4(0.12, 0.08, 0.1, 1.0);

void vertex() {
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz + normalize(MODELVIEW_NORMAL_MATRIX * NORMAL) * width;
	NORMAL = MODELVIEW_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	ALBEDO = color.rgb;
}
