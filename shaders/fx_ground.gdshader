shader_type spatial;
// Yere yatık halka / leke: şok dalgası, yanık izi, etki alanı uyarı halkası aynı gölgelendiriciyi kullanır.
// shape = (halka yarıçapı 0..1, kalınlık, kenar bozulması, parlaklık); yarıçap 0 ve geniş kalınlık -> dolu leke.
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

instance uniform vec4 col : source_color = vec4(1.0);
instance uniform vec4 shape = vec4(0.8, 0.1, 0.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 x) {
	vec2 i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 w = (MODEL_MATRIX * vec4(p.x, 0.0, p.y, 0.0)).xz; // dünya ölçeğinde gürültü: her leke farklı
	float n = noise(w * 3.0 + MODEL_MATRIX[3].xz) * 0.6 + noise(w * 8.0) * 0.4;
	float r = length(p) + (n - 0.5) * shape.z;
	ALBEDO = col.rgb * shape.w;
	ALPHA = col.a * (1.0 - smoothstep(shape.y * 0.35, shape.y, abs(r - shape.x))) * step(length(p), 1.0);
}
