// Karakter dış çizgisi: mesafeye göre dengeli kalınlaşan temiz çizgi roman/stilize kontur.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, skip_vertex_transform;

uniform float width = 0.016;
uniform vec4 color : source_color = vec4(0.09, 0.06, 0.09, 1.0);

void vertex() {
	vec3 view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(view_pos);
	float scaled_w = width * clamp(dist * 0.15, 0.55, 2.0);
	vec3 view_nrm = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	VERTEX = view_pos + view_nrm * scaled_w;
	NORMAL = view_nrm;
}

void fragment() {
	ALBEDO = color.rgb;
}
