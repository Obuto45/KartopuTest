shader_type spatial;
// Stilize karakter kenar ışığı (altın saat rim-light) + hasar flaşı katmanı.
// material_overlay olarak kullanılır; next_pass ile outline.gdshader'a bağlanır.
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled;

uniform vec4 flash_color : source_color = vec4(1.0, 0.1, 0.1, 0.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.86, 0.62, 0.32);
uniform float rim_power = 3.2;

void fragment() {
	float fres = pow(max(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 0.0001), rim_power);
	float rim_a = fres * rim_color.a;
	float flash_a = flash_color.a;
	ALBEDO = mix(rim_color.rgb, flash_color.rgb, clamp(flash_a * 2.5, 0.0, 1.0));
	ALPHA = clamp(max(rim_a, flash_a), 0.0, 1.0);
}
