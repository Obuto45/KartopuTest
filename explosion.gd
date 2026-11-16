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
	light.light_energy = 14.0
	light.omni_range = 9.0 * k # ışık menzili düğüm ölçeğinden etkilenmez
	add_child(light)

	# Parlama: birkaç iri, çok kısa ömürlü toplamalı bulut.
	var flash := parts(quad("glow", 3.4), 4, 0.16, 0.0, 1.0, [Color(1, 0.95, 0.75, 0.9), Color(1, 0.6, 0.2, 0.0)], 0.45, 1.0)
	var flame := parts(quad("glow", 1.7), 10, 0.5, 2.0, 5.5, [Color(1, 0.85, 0.4, 0.9), Color(1, 0.4, 0.08, 0.7), Color(0.5, 0.08, 0.0, 0.0)], 0.5, 1.0)
	flame.damping_min = 5.0; flame.damping_max = 8.0
	flame.gravity = Vector3(0, 2.5, 0)
	# Kıvılcım: uçuş yönünde uzamış ince parça -> iz bırakıyormuş gibi görünür.
	var sp := SphereMesh.new()
	sp.radius = 0.022; sp.height = 0.55
	sp.radial_segments = 4; sp.rings = 1
	sp.material = mat("spark")
	var sparks := parts(sp, 26, 0.6, 7.0, 17.0, [Color(1, 1, 0.8), Color(1, 0.55, 0.1), Color(0.8, 0.15, 0.0, 0.0)], 1.0, 0.2)
	sparks.particle_flag_align_y = true
	sparks.gravity = Vector3(0, -9, 0)
	sparks.damping_min = 2.0; sparks.damping_max = 5.0
	# Toprak / taş parçaları: yukarı fırlar, yerçekimiyle düşer.
	var bm := BoxMesh.new()
	bm.size = Vector3(0.13, 0.09, 0.11)
	bm.material = mat("chunk")
	var dirt := parts(bm, 12, 1.1, 5.0, 11.0, [Color(0.22, 0.16, 0.1), Color(0.14, 0.11, 0.08)], 1.0, 0.3)
	dirt.direction = Vector3.UP
	dirt.spread = 55.0
	dirt.particle_flag_align_y = true
	dirt.gravity = Vector3(0, -20, 0)
	# Duman: alev sönerken belirir (ilk renk saydam), yükselip dağılır.
	var smoke := parts(quad("puff", 2.6), 14, 2.3, 0.8, 2.6, [Color(0.3, 0.14, 0.05, 0.0), Color(0.1, 0.09, 0.08, 0.95), Color(0.17, 0.16, 0.15, 0.7), Color(0.25, 0.24, 0.23, 0.0)], 0.45, 1.0)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.5
	smoke.gravity = Vector3(0, 1.3, 0)
	smoke.damping_min = 1.0; smoke.damping_max = 2.0
	for p in [smoke, dirt, flame, sparks, flash]:
		add_child(p)
		p.emitting = true

	var wc := Color(1.0, 0.9, 0.7, 0.75)
	var wave := ground(3.6, wc, Vector4(0.1, 0.16, 0.12, 1.5))
	wave.position.y = gy
	add_child(wave)

	var tw := create_tween().set_parallel()
	tw.tween_property(ball, "scale", Vector3.ONE * 1.75, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	anim(tw, ball, "progress", 0.0, 1.0, 0.6)
	tw.tween_property(light, "light_energy", 0.0, 0.35)
	anim(tw, wave, "shape", Vector4(0.1, 0.16, 0.12, 1.5), Vector4(0.96, 0.03, 0.12, 1.5), 0.32).set_ease(Tween.EASE_OUT)
	anim(tw, wave, "col", wc, Color(wc, 0.0), 0.32).set_ease(Tween.EASE_IN)
	if low:
		var bc := Color(0.03, 0.02, 0.015, 0.8)
		var burn := ground(1.6, bc, Vector4(0.0, 0.95, 0.5, 1.0))
		burn.position.y = gy - 0.015 / k # halkanın altında kalsın
		add_child(burn)
		anim(tw, burn, "col", bc, Color(bc, 0.0), 2.5).set_delay(1.5)
	# Bitenler hemen gitsin: ışık ve saydam yüzeyler 4 oyunculu kavgada birikmesin.
	create_tween().tween_callback(func() -> void:
		for n in [ball, light, wave, flash, flame]:
			n.queue_free()).set_delay(0.7)
	get_tree().create_timer(LIFE).timeout.connect(queue_free)
