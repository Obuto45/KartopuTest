// Can iksiri sıvısı: yüzey dünya yukarısına göre düz kalır (şişe eğilse de).
shader_type spatial;
render_mode cull_disabled, shadows_disabled;

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform vec4 color : source_color = vec4(0.9, 0.12, 0.18, 1.0);
uniform float emission_energy = 0.55;
// yerel uzayda sıvının alt ve üst uç yüksekliği (eşik bu aralıkta kayar)
uniform float lo = -0.045;
uniform float hi = 0.058;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 center = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[1].xyz); // ölçekli kullanımda eşik de ölçeklensin
	float h = world_pos.y - center.y;
	float level = mix(lo, hi, fill) * s;
	if (fill <= 0.001 || h > level) {
		discard;
	}
	vec3 c = color.rgb;
	if (FRONT_FACING) {
		// yüzeye yakın ince parlak menisküs çizgisi
		float rim = 1.0 - smoothstep(0.0, 0.003 * s, level - h);
		ALBEDO = c * (0.55 + rim * 0.6);
		EMISSION = c * emission_energy * (0.8 + rim * 0.8);
		ROUGHNESS = 0.15;
		SPECULAR = 0.6;
	} else {
		// kesitten görünen arka yüzler = sıvı yüzeyi: normal dünya yukarısı, biraz koyu
		NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
		ALBEDO = c * 0.7;
		EMISSION = c * emission_energy * 0.65;
		ROUGHNESS = 0.08;
		SPECULAR = 0.8;
	}
}
