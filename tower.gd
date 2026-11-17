extends StaticBody3D
## TD'nin korunan kulesi (0,0,0): yuvarlak taş kule, tepede çatılı balkon ve Rapunzel.
## Rapunzel kapıya (içeri) dönük durur: dışarıdan yalnızca sırtı ve saçı görünür, yüzü hiç görünmez.
## Saç örgüsü korkuluğun üstünden aşağı, neredeyse yere kadar sarkar; salınım gölgelendiricide (kare başına kod yok).
## Çarpışma: yarıçap 2,1 m silindir. Görsel durumlar: set_hp (çatlak, is, duman, eğilme), collapse (yıkılış).

const Fx := preload("res://explosion.gd")
const R := 2.1 # çarpışma yarıçapı (sözleşme: <= 2,2)
const BODY_H := 10.5
const FLOOR_Y := 10.8 # balkon zemini
const BX := 2.3 # balkonun merkezi (+X yönünde çıkıntı)
const STONE := Color(0.62, 0.58, 0.52)
const HAIR_CODE := "shader_type spatial;
render_mode cull_disabled;
// UV.y: örgü boyunca 0 (baş) -> 1 (uç). Sarkan kısım uca doğru artarak salınır.
void vertex() {
	float k = smoothstep(0.14, 1.0, UV.y);
	k *= k;
	VERTEX.z += sin(TIME * 1.1 + UV.y * 4.0) * 0.5 * k;
	VERTEX.x += (0.5 + 0.5 * sin(TIME * 0.7 + UV.y * 3.0)) * 0.3 * k;
}
void fragment() {
	float tw = sin(UV.y * 260.0 + sin(UV.x * 6.2832) * 2.2); // örgü kıvrımı
	vec3 gold = mix(vec3(0.78, 0.5, 0.1), vec3(1.0, 0.82, 0.3), 0.5 + 0.5 * tw);
	ALBEDO = (UV.y > 0.955 && UV.y < 0.972) ? vec3(0.55, 0.2, 0.7) : gold; // uçta mor kurdele
	ROUGHNESS = 0.45;
	EMISSION = gold * 0.12; // gölgede de altın kalsın
}"

var vis: Node3D # tüm görüntü: eğilme ve yıkılış bunu oynatır
var stone: ShaderMaterial
var cracks := []
var smoke: CPUParticles3D
var fire: CPUParticles3D
var dust: CPUParticles3D
var fallen := false


func _std(c: Color, rough := 0.9, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _part(m: PrimitiveMesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	m.material = mat
	mi.mesh = m
	mi.position = pos
	mi.rotation = rot
	(parent if parent else vis).add_child(mi)
	return mi


func _cyl(r0: float, r1: float, h: float, seg := 16, rings := 1) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r0; c.bottom_radius = r1; c.height = h
	c.radial_segments = seg; c.rings = rings
	return c


func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


func _ball(r: float, seg := 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r; s.height = r * 2.0
	s.radial_segments = seg; s.rings = seg / 2
	return s


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = R
	sh.height = 16.0
	cs.shape = sh
	cs.position.y = 8.0
	add_child(cs)
	vis = Node3D.new()
	add_child(vis)

	# Taş: haritanın duvar gölgelendiricisi (örülmüş blok + yosun); gürültü dokusu burada üretilir.
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.03
	stone = ShaderMaterial.new()
	stone.shader = load("res://shaders/stone.gdshader")
	stone.set_shader_parameter("noise_tex", ImageTexture.create_from_image(fn.get_seamless_image(128, 128)))
	stone.set_shader_parameter("tint", STONE)
	stone.set_shader_parameter("blocks", 1.0)
	stone.set_shader_parameter("moss", 0.55)
	var wood := _std(Color(0.36, 0.24, 0.14))
	var tile := _std(Color(0.42, 0.2, 0.5), 0.7) # mor kiremit
	var gold := _std(Color(1.0, 0.78, 0.25), 0.35, 0.3)

	_part(_cyl(2.2, 2.4, 0.9, 18), stone, Vector3(0, 0.45, 0)) # kaide
	_part(_cyl(1.65, 2.05, BODY_H, 18, 8), stone, Vector3(0, BODY_H * 0.5, 0)) # gövde: yukarı daralır
	_part(_cyl(2.3, 1.65, 0.7, 18), stone, Vector3(0, BODY_H - 0.05, 0)) # dışa taşan konsol
	_part(_cyl(2.2, 2.3, 2.5, 18), stone, Vector3(0, BODY_H + 1.5, 0)) # oda
	_part(_cyl(2.45, 2.45, 0.18, 18), wood, Vector3(0, BODY_H + 2.8, 0)) # saçak kirişi
	_part(_cyl(0.0, 2.85, 3.8, 14), tile, Vector3(0, BODY_H + 4.75, 0)) # külah çatı
	_part(_ball(0.18), gold, Vector3(0, BODY_H + 6.7, 0))
	for i in 3: # gövdede küçük mazgal pencereler
		var a := 2.2 + i * 2.0
		var r := 1.92 - i * 0.1
		_part(_box(0.12, 0.8, 0.32), _std(Color(0.03, 0.02, 0.02)), Vector3(cos(a) * r, 2.6 + i * 2.6, sin(a) * r), Vector3(0, -a, 0))

	# Balkon kapısı: karanlık açıklık + ahşap çerçeve + içeriden sızan sıcak ışık.
	var dark := _std(Color(0.05, 0.03, 0.03))
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_part(_box(0.1, 1.9, 1.1), dark, Vector3(2.24, FLOOR_Y + 0.95, 0))
	for z in [-0.62, 0.62]:
		_part(_box(0.2, 2.0, 0.16), wood, Vector3(2.27, FLOOR_Y + 1.0, z))
	_part(_box(0.24, 0.2, 1.5), wood, Vector3(2.27, FLOOR_Y + 2.0, 0))
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.75, 0.45)
	glow.light_energy = 1.6
	glow.omni_range = 4.0
	glow.position = Vector3(2.6, FLOOR_Y + 1.6, 0)
	vis.add_child(glow)
	# Balkon: ahşap döşeme, payandalar, korkuluk, kendi küçük çatısı.
	_part(_cyl(1.3, 1.3, 0.16, 16), wood, Vector3(BX, FLOOR_Y - 0.08, 0))
	for z in [-0.7, 0.7]:
		_part(_box(1.5, 0.14, 0.14), wood, Vector3(BX + 0.25, FLOOR_Y - 0.75, z), Vector3(0, 0, 0.75))
	for i in 7:
		var a := -1.35 + i * 0.45
		_part(_cyl(0.05, 0.05, 0.85, 6), wood, Vector3(BX + cos(a) * 1.2, FLOOR_Y + 0.42, sin(a) * 1.2))
	var rail := TorusMesh.new()
	rail.inner_radius = 1.13; rail.outer_radius = 1.27
	rail.rings = 24; rail.ring_segments = 6
	_part(rail, wood, Vector3(BX, FLOOR_Y + 0.85, 0))
	_part(_cyl(0.0, 1.6, 1.1, 12), tile, Vector3(BX + 0.1, FLOOR_Y + 3.0, 0))
	for z in [-1.0, 1.0]: # çatıyı taşıyan iki ince direk
		_part(_cyl(0.05, 0.05, 1.7, 6), wood, Vector3(BX + 0.75, FLOOR_Y + 1.7, z))

	_rapunzel()
	_damage_fx()


## Elle kurulmuş küçük figür (modellerin hepsinde yüz var; bunda yok). Yerel +X = dışarı, o -X'e bakar.
func _rapunzel() -> void:
	var g := Node3D.new()
	g.position = Vector3(BX + 0.42, FLOOR_Y, 0)
	vis.add_child(g)
	var dress := _std(Color(0.62, 0.3, 0.72), 0.8)
	var skin := _std(Color(0.96, 0.8, 0.68), 0.8)
	var hair := ShaderMaterial.new()
	hair.shader = Shader.new()
	hair.shader.code = HAIR_CODE
	_part(_cyl(0.16, 0.42, 1.0, 10), dress, Vector3(0, 0.5, 0), Vector3.ZERO, g) # etek
	_part(_cyl(0.2, 0.15, 0.42, 10), _std(Color(0.75, 0.45, 0.85), 0.8), Vector3(0, 1.2, 0), Vector3.ZERO, g) # korse
	for z in [-0.25, 0.25]:
		_part(_ball(0.12, 8), dress, Vector3(0, 1.36, z), Vector3.ZERO, g) # kabarık kol
		_part(_cyl(0.045, 0.05, 0.5, 6), skin, Vector3(-0.1, 1.12, z * 1.1), Vector3(0, 0, -0.4), g) # kollar önde
	_part(_cyl(0.06, 0.07, 0.12, 6), skin, Vector3(0, 1.46, 0), Vector3.ZERO, g)
	_part(_ball(0.19), skin, Vector3(0, 1.68, 0), Vector3.ZERO, g)
	# Saç: başı arkadan, üstten ve yanlardan saran kabuk + alına düşen perçem. (Renk: örgüyle aynı gölgelendirici.)
	var cap := _part(_ball(0.235), hair, Vector3(0.035, 1.71, 0), Vector3.ZERO, g)
	cap.scale = Vector3(1.0, 1.0, 1.08)
	_part(_ball(0.16, 8), hair, Vector3(-0.1, 1.82, 0), Vector3.ZERO, g).scale = Vector3(1.0, 0.6, 1.3)
	for z in [-0.17, 0.17]: # yanlardan inen tutamlar: yandan bakınca profil de saçın arkasında
		_part(_cyl(0.07, 0.05, 0.5, 6), hair, Vector3(-0.06, 1.5, z), Vector3.ZERO, g)
	_part(_cyl(0.07, 0.085, 0.05, 10), _std(Color(1.0, 0.85, 0.3), 0.3, 0.6), Vector3(0.02, 1.93, 0), Vector3.ZERO, g) # taç

	# Örgü: baş arkası -> sırt -> korkuluğun üstü -> aşağı. Eğri boyunca 8 kenarlı, boğumlu tüp.
	var pts := [Vector3(0.17, 1.72, 0), Vector3(0.3, 1.35, 0), Vector3(0.5, 1.02, 0), Vector3(0.82, 0.98, 0),
		Vector3(0.98, 0.6, 0), Vector3(1.0, -3.5, 0), Vector3(1.0, -7.0, 0), Vector3(1.02, -10.1, 0)]
	var curve := Curve3D.new()
	for i in pts.size():
		var t: Vector3 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]) * 0.25
		curve.add_point(pts[i], -t, t)
	var n := 90
	var total := curve.get_baked_length()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n + 1:
		var v := float(i) / n
		var c := curve.sample_baked(v * total)
		var tg := (curve.sample_baked(minf(v * total + 0.05, total)) - curve.sample_baked(maxf(v * total - 0.05, 0.0))).normalized()
		var nx := tg.cross(Vector3.BACK).normalized()
		# Kalınlık: başta ince, sırtta dolgun, uca doğru incelir; örgü boğumları; en uçta püskül.
		var r := lerpf(0.1, 0.19, smoothstep(0.0, 0.12, v)) * lerpf(1.0, 0.55, smoothstep(0.3, 0.95, v)) * (1.0 + 0.16 * sin(v * 130.0))
		if v > 0.972:
			r *= 1.5 * (1.0 - (v - 0.972) / 0.028 * 0.9)
		for j in 9:
			var a := TAU * j / 8.0
			var o := nx * cos(a) + Vector3.BACK * sin(a)
			st.set_normal(o)
			st.set_uv(Vector2(j / 8.0, v))
			st.add_vertex(c + o * r)
	for i in n:
		for j in 8:
			var k := i * 9 + j
			for q in [k, k + 9, k + 1, k + 1, k + 9, k + 10]:
				st.add_index(q)
	var braid := MeshInstance3D.new()
	braid.mesh = st.commit()
	braid.material_override = hair
	braid.extra_cull_margin = 2.0 # salınım gölgelendiricide: kutunun dışına taşar
	g.add_child(braid)


## Hasar görselleri: gövdede çatlaklar (gizli başlar), tepede duman / alev, dipte darbe tozu.
func _damage_fx() -> void:
	var black := _std(Color(0.04, 0.03, 0.03))
	for i in 7:
		var a := 0.6 + i * 2.3
		var y := 1.5 + fmod(i * 3.7, 7.5)
		var r := 2.03 - y * 0.038 # gövde yüzeyi
		var seg := Node3D.new()
		seg.position = Vector3(cos(a) * r, y, sin(a) * r)
		seg.rotation.y = -a
		seg.visible = false
		vis.add_child(seg)
		for k in 3: # zikzak üç parça
			_part(_box(0.06, 0.75, 0.1), black, Vector3(0, k * 0.6, (k % 2) * 0.22 - 0.11), Vector3(0.45 * (1 if k % 2 == 0 else -1), 0, 0), seg)
		cracks.append(seg)
	smoke = Fx.parts(Fx.quad("puff", 2.4), 14, 3.0, 0.4, 1.2, [Color(0.1, 0.09, 0.08, 0.0), Color(0.12, 0.11, 0.1, 0.8), Color(0.3, 0.29, 0.28, 0.0)], 0.5, 1.3, false)
	smoke.position = Vector3(-0.8, BODY_H + 1.0, 1.4)
	smoke.gravity = Vector3(0.4, 1.6, 0)
	fire = Fx.parts(Fx.quad("glow", 1.3), 10, 0.7, 0.5, 1.5, [Color(1, 0.8, 0.3, 0.8), Color(1, 0.35, 0.05, 0.6), Color(0.5, 0.1, 0.0, 0.0)], 0.6, 1.0, false)
	fire.position = Vector3(-1.0, BODY_H * 0.55, 1.7)
	fire.gravity = Vector3(0, 2.5, 0)
	dust = Fx.parts(Fx.quad("puff", 1.6), 12, 0.9, 1.0, 3.0, [Color(0.5, 0.45, 0.38, 0.8), Color(0.5, 0.46, 0.4, 0.0)], 0.5, 1.0)
	dust.position.y = 0.6
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 2.3
	for p in [smoke, fire, dust]:
		p.emitting = false
		add_child(p) # vis'e değil: eğilmeden etkilenmesin


## f: kalan can oranı (0..1). hit: bu çağrıda hasar alındı (toz + sarsılma).
func set_hp(f: float, hit: bool) -> void:
	if fallen:
		return
	var lost := 1.0 - clampf(f, 0.0, 1.0)
	stone.set_shader_parameter("tint", STONE.lerp(Color(0.3, 0.24, 0.22), lost * 0.8)) # islenir
	for i in cracks.size():
		cracks[i].visible = lost > 0.12 + i * 0.11
	smoke.emitting = f < 0.6
	fire.emitting = f < 0.3
	var tilt := 0.045 if f < 0.3 else (0.02 if f < 0.6 else 0.0)
	if hit:
		dust.restart()
		var tw := create_tween() # darbe: kısa sarsılma, sonra kalıcı eğime döner
		tw.tween_property(vis, "rotation:x", 0.012, 0.04)
		tw.tween_property(vis, "rotation:x", 0.0, 0.12)
	vis.rotation.z = tilt


## Kule canı bitti: patlamalar eşliğinde devrilip yere gömülür, yerinde moloz kalır.
func collapse() -> void:
	if fallen:
		return
	fallen = true
	smoke.emitting = true
	fire.emitting = true
	for i in 4:
		create_tween().tween_callback(func() -> void:
			var fx: Node3D = Fx.new()
			fx.position = global_position + Vector3(randf_range(-1.5, 1.5), 1.0 + i * 3.0, randf_range(-1.5, 1.5))
			fx.scale = Vector3.ONE * 1.6
			get_parent().add_child(fx)
			Sfx.play3d(Sfx.boom, fx.position, 4.0)
			dust.restart()).set_delay(i * 0.45)
	var tw := create_tween().set_parallel()
	tw.tween_property(vis, "rotation:z", 0.5, 2.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(vis, "position:y", -13.0, 2.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD).set_delay(0.3)
	for i in 9: # moloz yığını
		var a := i * 0.7
		var rock := _part(_ball(randf_range(0.5, 1.0), 6), stone, Vector3(cos(a), 0, sin(a)) * randf_range(0.4, 2.0) + Vector3.UP * 0.2, Vector3.ZERO, self)
		rock.scale = Vector3.ONE * 0.01
		tw.tween_property(rock, "scale", Vector3(1, 0.7, 1), 0.4).set_delay(1.6 + i * 0.1)
