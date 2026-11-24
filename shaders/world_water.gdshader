shader_type spatial;
// Bataklık suyu. world.gd, Düşük kalitede başa "#define CHEAP" ekler (derinlik okunmaz, köpük yok).
render_mode blend_mix, cull_back, specular_schlick_ggx;

#ifndef CHEAP
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
#endif
uniform vec3 shallow_col : source_color = vec3(0.30, 0.28, 0.12); // kıyı: çamurlu zeytin-kahve
uniform vec3 deep_col : source_color = vec3(0.05, 0.11, 0.07);    // derin: koyu yeşil
uniform vec3 foam_col : source_color = vec3(0.62, 0.6, 0.42);     // kıyı çizgisi: kirli köpük/çamur
uniform vec3 sky_col : source_color = vec3(0.45, 0.52, 0.5); // fresnel ile yansıyan soluk gök
uniform float density = 1.6;    // derinlikle koyulaşma hızı (1/m)
uniform float foam_width = 0.4; // köpük çizgisi genişliği (m)

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Zamanla kayan iki cos katmanından hafif normal dalgacığı (doku okumadan).
	vec2 p = wpos.xz;
	float t = TIME;
	// İki farklı hız/yönde, birbirine asal frekanslı dalga çifti: tekrarlayan karo/çizgi yok.
	// Büyük ölçekli, düşük genlikli dalga: güneş yansıması lekeye bölünmeden geniş ve yumuşak kalır.
	float w1 = cos(p.x * 0.45 + p.y * 0.27 + t * 0.25);
	float w2 = cos(p.x * 0.83 - p.y * 0.61 - t * 0.35);
	float w3 = cos(p.x * 0.31 - p.y * 0.57 + t * 0.15);
	vec2 sl = vec2(w1 * 0.012 + w2 * 0.014 + w3 * 0.01, w1 * 0.008 - w2 * 0.012 + w3 * 0.012);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(sl.x, 0.0, sl.y, 0.0)).xyz);

	vec3 col = mix(shallow_col, deep_col, 0.6);
	float a = 0.82;
	float rough = 0.6;
#ifndef CHEAP
	float d = texture(depth_tex, SCREEN_UV).x;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float wz = abs(sv.w) > 0.0001 ? sv.z / sv.w : VERTEX.z;
	float depth = clamp(VERTEX.z - wz, 0.0, 60.0); // suyun arkasındaki zemine metre
	float k = 1.0 - exp(-depth * density);
	col = mix(shallow_col, deep_col, k);
	a = mix(0.45, 0.93, k);
	// Kıyıda dalgalı köpük/çamur çizgisi; en kıyıda alfa sıfıra iner (sert kenar yok).
	float wob = 0.6 + 0.4 * sin(p.x * 2.7 + p.y * 3.3 + t * 0.8);
	float foam = (1.0 - smoothstep(0.0, foam_width * wob, depth)) * 0.85;
	col = mix(col, foam_col, foam);
	a = max(a, foam) * smoothstep(0.0, 0.5, depth); // geniş yumuşak kıyı geçişi (sert koyu kenar yok)
	rough = mix(0.4, 0.65, 1.0 - k); // sığda mat, derinde yansıtıcı
#endif
	// Fresnel: sığ açıdan bakınca gök rengi karışır (NaN korumalı).
	float fres = pow(max(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 0.0001), 4.0);
	col = mix(col, sky_col, fres * 0.55);
	ALBEDO = col;
	ALPHA = a;
	ROUGHNESS = rough;
	SPECULAR = 0.2;
	METALLIC = 0.0;
}
