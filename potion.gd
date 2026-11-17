extends Node3D
## Elde tutulan can iksiri şişesi. Orijin gövde merkezi, Y şişe ekseni.
## Çocuklar: glass, liquid (ShaderMaterial, fill), cork, muzzle (Marker3D, ağız).

const LIQUID_SHADER := preload("res://shaders/potion_liquid.gdshader")
const GLASS_CODE := """
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, shadows_disabled;
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = vec3(0.78, 0.9, 1.0);
	ALPHA = mix(0.06, 0.65, f);
	ROUGHNESS = 0.04;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	EMISSION = vec3(0.6, 0.75, 0.9) * f * 0.25;
}
"""
const LIQUID_COLOR := Color(0.9, 0.12, 0.18)

## 1 = dolu, 0 = boş. Animasyon Rig/Weapon:fill değer iziyle sürer.
var fill := 1.0:
	set(v):
		fill = v
		if _liq_mat:
			_liq_mat.set_shader_parameter(&"fill", v)

var _liq_mat: ShaderMaterial


static func make() -> Node3D:
	return load("res://potion.gd").new()


func _init() -> void:
	# --- cam: basık küre gövde + boyun + ağız dudağı tek düğümde
	var glass_mat := ShaderMaterial.new()
	var gs := Shader.new()
	gs.code = GLASS_CODE
	glass_mat.shader = gs
	var body := SphereMesh.new()
	body.radius = 0.045
	body.height = 0.084
	body.radial_segments = 32
	body.rings = 16
	var neck := CylinderMesh.new()
	neck.top_radius = 0.013
	neck.bottom_radius = 0.014
	neck.height = 0.04
	neck.cap_top = false
	neck.cap_bottom = false
	var lip := TorusMesh.new()
	lip.inner_radius = 0.0115
	lip.outer_radius = 0.0175
	var st := SurfaceTool.new()
	st.append_from(body, 0, Transform3D.IDENTITY)
	st.append_from(neck, 0, Transform3D(Basis(), Vector3(0, 0.058, 0)))
	st.append_from(lip, 0, Transform3D(Basis(), Vector3(0, 0.078, 0)))
	_add_mesh("glass", st.commit(), glass_mat)

	# --- sıvı: gövdeden küçük küre + boyun altı, tek mesh (merkez = kök)
	_liq_mat = ShaderMaterial.new()
	_liq_mat.shader = LIQUID_SHADER
	_liq_mat.set_shader_parameter(&"color", LIQUID_COLOR)
	_liq_mat.set_shader_parameter(&"fill", fill)
	var lb := SphereMesh.new()
	lb.radius = 0.041
	lb.height = 0.077
	lb.radial_segments = 32
	lb.rings = 16
	var ln := CylinderMesh.new()
	ln.top_radius = 0.0105
	ln.bottom_radius = 0.0115
	ln.height = 0.024
	var sl := SurfaceTool.new()
	sl.append_from(lb, 0, Transform3D.IDENTITY)
	sl.append_from(ln, 0, Transform3D(Basis(), Vector3(0, 0.045, 0)))
	_add_mesh("liquid", sl.commit(), _liq_mat)

	# --- boyuna sarılı ip
	var twine := TorusMesh.new()
	twine.inner_radius = 0.0135
	twine.outer_radius = 0.0165
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.72, 0.6, 0.42)
	tm.roughness = 1.0
	var tw := _add_mesh("twine", twine, tm)
	tw.position.y = 0.05
	tw.scale = Vector3(1, 1.6, 1)
	var tw2 := _add_mesh("twine2", twine, tm)
	tw2.position.y = 0.055
	tw2.scale = Vector3(1, 1.6, 1)

	# --- mantar tıpa (pivot merkezde, alt dar)
	var cork_mesh := CylinderMesh.new()
	cork_mesh.top_radius = 0.0125
	cork_mesh.bottom_radius = 0.0098
	cork_mesh.height = 0.022
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.62, 0.45, 0.28)
	cm.roughness = 1.0
	var cork := _add_mesh("cork", cork_mesh, cm)
	cork.position.y = 0.085

	var mk := Marker3D.new()
	mk.name = "muzzle"
	mk.position.y = 0.08
	add_child(mk)

	# sıvının hafif kızıl ışıması; yalnız viewmodel katmanı (2)
	var glow := OmniLight3D.new()
	glow.name = "glow"
	glow.light_color = LIQUID_COLOR
	glow.light_energy = 0.25
	glow.omni_range = 0.18
	glow.light_cull_mask = 2
	glow.shadow_enabled = false
	add_child(glow)


func _add_mesh(n: String, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
