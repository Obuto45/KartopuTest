extends Node3D
## Patlama: beyaz parlama + gürültüyle eriyen ateş topu + şok halkası + kıvılcım, toprak, duman + yanık izi.
## Her şey düğümün ölçeğine (k) uyar: gülle ve meteor daha büyük patlar.
## Ortak malzeme / parçacık yardımcıları statik: roket, duvar, alan ve güdümlü mermi de bunları kullanır.

const LIFE := 4.0 # duman ~2.3 sn'de, yanık izi 4 sn'de biter
const PUFF := preload("res://shaders/fx_puff.gdshader")
const BALL := preload("res://shaders/fx_fireball.gdshader")
const GROUND := preload("res://shaders/fx_ground.gdshader")

static var _mats := {}


## Paylaşılan malzemeler: sürekli ateş edilirken her efekt yenisini üretmesin.
static func mat(k: String) -> Material:
	if _mats.has(k):
		return _mats[k]
	var m: Material
	if k == "spark" or k == "chunk":
		var s := StandardMaterial3D.new()
		s.vertex_color_use_as_albedo = true # renk rampası parçacıklara uygulansın
		if k == "spark":
			s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			s.albedo_color = Color(2.5, 2.0, 1.5) # 1'in üstü: ışıma (glow) yakalasın
		else:
			s.roughness = 1.0
		m = s
	else:
		var s := ShaderMaterial.new()
		s.shader = {"puff": PUFF, "ball": BALL, "ground": GROUND}.get(k)
		if k == "glow": # alev: aynı bulut, toplamalı ve parlak
			s.shader = Shader.new()
			s.shader.code = PUFF.code.replace("blend_mix", "blend_add").replace("COLOR.rgb *", "1.8 * COLOR.rgb *")
		s.render_priority = {"puff": -1, "glow": 1}.get(k, 0) # duman arkada, alev önde çizilsin
		m = s
	_mats[k] = m
	return m


static func quad(k: String, size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size
	q.material = mat(k)
	return q


## Yere yatık halka / leke (fx_ground): r yarıçap; shape = (halka, kalınlık, kenar bozulması, parlaklık).
static func ground(r: float, c: Color, shape: Vector4) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = PlaneMesh.new()
	mi.material_override = mat("ground")
	mi.scale = Vector3.ONE * r
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("col", c)
	mi.set_instance_shader_parameter("shape", shape)
	return mi


## Parçacık kümesi. cols: ömür boyunca renkler (eşit aralıklı), s0 -> s1: ömür boyunca boyut oranı.
static func parts(mesh: Mesh, n: int, life: float, vmin: float, vmax: float, cols: Array, s0 := 1.0, s1 := 1.0, burst := true) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.amount = n
	p.lifetime = life
	p.one_shot = burst
	p.explosiveness = 1.0 if burst else 0.0
	p.spread = 180.0
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = Vector3.ZERO
	p.angle_max = 360.0
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	for i in cols.size():
		offs.append(float(i) / (cols.size() - 1))
	g.offsets = offs
	g.colors = PackedColorArray(cols)
	p.color_ramp = g
	var c := Curve.new()
	c.add_point(Vector2(0, s0))
	c.add_point(Vector2(1, s1))
	p.scale_amount_curve = c
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Örnek başına gölgelendirici değerini canlandırır (tween_property bu değerleri okuyamıyor).
static func anim(tw: Tween, mi: GeometryInstance3D, param: String, from: Variant, to: Variant, d: float) -> MethodTweener:
	return tw.tween_method(func(v: Variant) -> void: mi.set_instance_shader_parameter(param, v), from, to, d)


## Efekti sahibinin yanına (dünyaya) bırakır: sahibi hareket etse de silinse de efekt yerinde kalır,
## sahibi gidince `linger` sn sonra kendini siler.
static func drop(owner: Node, fx: Node3D, linger: float) -> void:
	owner.get_parent().add_child.call_deferred(fx) # ebeveyn şu an sahibini eklemekle meşgul
	owner.tree_exiting.connect(func() -> void:
		if fx is CPUParticles3D:
			fx.emitting = false
		if fx.is_inside_tree():
			fx.create_tween().tween_callback(fx.queue_free).set_delay(linger)
		else:
			fx.queue_free())


func _ready() -> void:
	var k := scale.x
	get_tree().call_group("players", "shake", global_position, k)
	get_tree().call_group("chickens", "boom", global_position)
	preload("res://ragdoll.gd").poke(global_position, Vector3.UP * 14.0 * k, 3.5 * k) # cesetler ve ölenler savrulur
	var low := global_position.y < 1.2 * k # yere yakın: halka ve yanık izi zemine yapışır
	var gy := (0.04 - global_position.y) / k if low else 0.0

	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0; sm.height = 2.0
	sm.radial_segments = 24; sm.rings = 12
	ball.mesh = sm
	ball.material_override = mat("ball")
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.set_instance_shader_parameter("seed", randf() * 20.0)
	ball.scale = Vector3.ONE * 0.35
	add_child(ball)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 22.0
	light.omni_range = 9.0 * k # ışık menzili düğüm ölçeğinden etkilenmez
	add_child(light)

	# Parlama: yoğun beyaz-altın çekirdek + alev dili.
	var flash := parts(quad("glow", 3.8), 5, 0.14, 0.0, 1.2, [Color(1.0, 0.98, 0.85, 0.95), Color(1.0, 0.65, 0.2, 0.0)], 0.5, 1.15)
	var flame := parts(quad("glow", 1.9), 12, 0.52, 2.2, 6.0, [Color(1.0, 0.9, 0.45, 0.92), Color(1.0, 0.42, 0.08, 0.72), Color(0.5, 0.08, 0.0, 0.0)], 0.55, 1.05)
	flame.damping_min = 5.0; flame.damping_max = 8.0
	flame.gravity = Vector3(0, 2.8, 0)
	# Kıvılcım: uçuş yönünde uzamış sıcak izler.
	var sp := SphereMesh.new()
	sp.radius = 0.024; sp.height = 0.62
	sp.radial_segments = 4; sp.rings = 1
	sp.material = mat("spark")
	var sparks := parts(sp, 32, 0.65, 7.5, 19.0, [Color(1.0, 1.0, 0.85), Color(1.0, 0.58, 0.12), Color(0.85, 0.16, 0.0, 0.0)], 1.0, 0.18)
	sparks.particle_flag_align_y = true
	sparks.gravity = Vector3(0, -10.5, 0)
	sparks.damping_min = 2.0; sparks.damping_max = 4.5
	# Yükselen kor közleri: dumanla birlikte süzülür (patlama sonrası canlılık).
	var emb_m := SphereMesh.new()
	emb_m.radius = 0.032; emb_m.height = 0.064
	emb_m.radial_segments = 5; emb_m.rings = 2
	emb_m.material = mat("spark")
	var embers := parts(emb_m, 16, 1.8, 0.8, 3.2, [Color(1.0, 0.85, 0.35), Color(1.0, 0.4, 0.05), Color(0.6, 0.1, 0.0, 0.0)], 0.9, 0.15)
	embers.direction = Vector3.UP
	embers.spread = 65.0
	embers.gravity = Vector3(0, 1.8, 0)
	embers.damping_min = 1.4; embers.damping_max = 2.6
	# Toprak / taş parçaları: yukarı fırlar, yerçekimiyle düşer.
	var bm := BoxMesh.new()
	bm.size = Vector3(0.14, 0.09, 0.12)
	bm.material = mat("chunk")
	var dirt := parts(bm, 14, 1.15, 5.5, 12.0, [Color(0.24, 0.17, 0.11), Color(0.14, 0.11, 0.08)], 1.0, 0.25)
	dirt.direction = Vector3.UP
	dirt.spread = 58.0
	dirt.particle_flag_align_y = true
	dirt.gravity = Vector3(0, -21, 0)
	# Duman: alev sönerken belirir, yükselip dağılır.
	var smoke := parts(quad("puff", 2.8), 16, 2.4, 0.8, 2.8, [Color(0.32, 0.15, 0.06, 0.0), Color(0.11, 0.10, 0.09, 0.94), Color(0.18, 0.17, 0.16, 0.68), Color(0.26, 0.25, 0.24, 0.0)], 0.45, 1.08)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.55
	smoke.gravity = Vector3(0, 1.4, 0)
	smoke.damping_min = 1.0; smoke.damping_max = 2.0
	for p in [smoke, dirt, embers, flame, sparks, flash]:
		add_child(p)
		p.emitting = true

	# Çift katmanlı şok dalgası: hızlı parlak iç basınç halkası + geniş toz halkası.
	var wc := Color(1.0, 0.92, 0.74, 0.82)
	var wave := ground(3.9, wc, Vector4(0.08, 0.14, 0.10, 1.8))
	wave.position.y = gy
	add_child(wave)
	var wc2 := Color(0.95, 0.72, 0.42, 0.52)
	var wave2 := ground(4.8, wc2, Vector4(0.12, 0.18, 0.22, 1.2))
	wave2.position.y = gy - 0.005 / k
	add_child(wave2)

	var tw := create_tween().set_parallel()
	tw.tween_property(ball, "scale", Vector3.ONE * 1.82, 0.44).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	anim(tw, ball, "progress", 0.0, 1.0, 0.58)
	tw.tween_property(light, "light_energy", 0.0, 0.34).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	anim(tw, wave, "shape", Vector4(0.08, 0.14, 0.10, 1.8), Vector4(0.96, 0.025, 0.10, 1.8), 0.28).set_ease(Tween.EASE_OUT)
	anim(tw, wave, "col", wc, Color(wc, 0.0), 0.28).set_ease(Tween.EASE_IN)
	anim(tw, wave2, "shape", Vector4(0.12, 0.18, 0.22, 1.2), Vector4(0.98, 0.04, 0.22, 1.2), 0.42).set_ease(Tween.EASE_OUT)
	anim(tw, wave2, "col", wc2, Color(wc2, 0.0), 0.42).set_ease(Tween.EASE_IN)
	if low:
		var bc := Color(0.03, 0.02, 0.015, 0.82)
		var burn := ground(1.75, bc, Vector4(0.0, 0.95, 0.5, 1.0))
		burn.position.y = gy - 0.015 / k # halkanın altında kalsın
		add_child(burn)
		anim(tw, burn, "col", bc, Color(bc, 0.0), 2.5).set_delay(1.5)
		# Soğuyan kor merkezi: patlamadan hemen sonra kızıl parlar, 1.1 sn'de kömüre söner.
		var hc := Color(1.0, 0.38, 0.06, 0.72)
		var hot := ground(0.95, hc, Vector4(0.0, 0.85, 0.45, 2.2))
		hot.position.y = gy - 0.010 / k
		add_child(hot)
		anim(tw, hot, "col", hc, Color(hc, 0.0), 1.1).set_ease(Tween.EASE_IN)
	# Bitenler hemen gitsin: ışık ve saydam yüzeyler 4 oyunculu kavgada birikmesin.
	create_tween().tween_callback(func() -> void:
		for n in [ball, light, wave, wave2, flash, flame]:
			if is_instance_valid(n):
				n.queue_free()).set_delay(0.7)
	get_tree().create_timer(LIFE).timeout.connect(queue_free)
