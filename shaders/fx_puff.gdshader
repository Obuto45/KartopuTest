shader_type spatial;
// Parçacık bulutu (duman / alev / toz): kameraya bakan dörtgen, gürültüyle yenen yumuşak kenar.
// Renk ve saydamlık parçacığın renk rampasından gelir; saydamlaştıkça kenardan içe doğru erir.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
varying float ang;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 x) {
	vec2 i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	ang = INSTANCE_CUSTOM.x + float(INSTANCE_ID) * 2.4;
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s.x, INV_VIEW_MATRIX[1] * s.y, INV_VIEW_MATRIX[2] * s.z, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	// Gürültü parçacığa göre döner, tepe aydınlığı dönmez: her bulut farklı ama ışık hep yukarıdan.
	vec2 q = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang))) * p + ang;
	float n = noise(q * 1.8) * 0.75 + noise(q * 4.3) * 0.25;
	float body = 1.0 - length(p) + (n - 0.5) * 0.7;
	float eat = (1.0 - COLOR.a) * 0.45;
	ALBEDO = COLOR.rgb * (0.8 - p.y * 0.3 + n * 0.25);
	// Zemine / duvara gömülen bulut keskin çizgi bırakmasın.
	vec4 back = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, texture(depth_tex, SCREEN_UV).r, 1.0);
	ALPHA = smoothstep(0.05 + eat, 0.6 + eat, body) * COLOR.a * smoothstep(1.0, 0.7, length(p)) * clamp((VERTEX.z - back.z / back.w) * 2.5, 0.0, 1.0);
}
