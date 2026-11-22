extends StaticBody3D
## Mağazadan alınıp kurulan yapı (Balance.SHOP): wall, spike, trap, turret, frost.
## Hasar ve hedef seçimi yalnızca host'ta; görüntü (dönüş, iz, can çubuğu) her makinede.
## Tuzak çarpışmasızdır (üstünden geçilir); "hp"si kalan şarjıdır.

const Balance := preload("res://balance.gd")
const EnemyScript := preload("res://enemy.gd")
const Fx := preload("res://explosion.gd")
const W := 3.0 # duvar genişliği
const H := 2.2
const T := 0.5

var id := ""
var bid := 0
var d: Dictionary
var hp := 1
var max_hp := 1
var td: Node
var bar: MeshInstance3D
var head: Node3D # taretin dönen kısmı / totemin kristali
var orbit: Node3D # buz toteminin yörüngedeki yan kristalleri
var beam: MeshInstance3D # taretin atış izi (tek düğüm, her atışta yeniden kullanılır)
var tick := 0.0
var cd := 0.0


func _mat(k: String, c: Color, metal := 0.0, glow := 0.0, rough := -1.0) -> Material:
	return EnemyScript.shared("b_" + k, func() -> Resource:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = metal
		m.roughness = rough if rough >= 0.0 else (0.42 if metal > 0.0 else 0.88)
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = glow
		return m)


func _part(parent: Node, m: PrimitiveMesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	m.material = mat
	mi.mesh = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _cyl(r0: float, r1: float, h: float, seg := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r0; c.bottom_radius = r1; c.height = h
	c.radial_segments = seg; c.rings = 1
	return c


func _shape(sh: Shape3D, y: float) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = sh
	cs.position.y = y
	add_child(cs)


func _ready() -> void:
	add_to_group("builds")
	d = Balance.shop(id)
	hp = d.hp
	max_hp = hp
	var col: Color = d.color
	var wood := _mat("wood", Color(0.5, 0.36, 0.22))
	var iron := _mat("iron", Color(0.3, 0.3, 0.34), 0.8)
	match id:
		"wall", "spike": # sivri uçlu kütük çit + iki kuşak
			var body := _mat(id, col)
			for i in 6:
				var h := H - 0.25 + 0.25 * sin(i * 2.4)
				var x := -W * 0.5 + 0.25 + i * 0.5
				_part(self, _cyl(0.23, 0.26, h - 0.3, 6), body, Vector3(x, (h - 0.3) * 0.5, 0))
				_part(self, _cyl(0.0, 0.23, 0.3, 6), body, Vector3(x, h - 0.15, 0))
			for y in [0.6, 1.5]:
				var bm := BoxMesh.new()
				bm.size = Vector3(W, 0.16, T + 0.08)
				_part(self, bm, iron if id == "spike" else wood, Vector3(0, y, 0))
			if id == "spike":
				for i in 5:
					for s in [-1.0, 1.0]:
						for y in [0.6, 1.5]:
							_part(self, _cyl(0.0, 0.07, 0.55, 5), iron, Vector3(-1.2 + i * 0.6 + (0.3 if y > 1.0 else 0.0) - 0.15, y, s * 0.5), Vector3(s * PI / 2, 0, 0))
			var sh := BoxShape3D.new()
			sh.size = Vector3(W, H, T)
			_shape(sh, H * 0.5)
		"trap": # dişli yer plakası
			_part(self, _cyl(1.1, 1.2, 0.07, 12), iron, Vector3(0, 0.035, 0))
			_part(self, _cyl(0.35, 0.4, 0.1, 8), _mat("trap", col, 0.0, 1.5), Vector3(0, 0.06, 0))
			for i in 10:
				var a := TAU * i / 10.0
				_part(self, _cyl(0.0, 0.09, 0.35, 4), iron, Vector3(cos(a), 0.2, sin(a)) * Vector3(0.85, 1, 0.85))
		"turret": # zırhlı çift namlulu kuşatma tareti: taş-demir kaide, 4 ayak, pirinç çember, optik hedefleyici
			var stone_b := _mat("t_stone", Color(0.42, 0.41, 0.39), 0.0, 0.0, 0.92)
			var dark_iron := _mat("t_diron", Color(0.18, 0.20, 0.24), 0.85, 0.0, 0.36)
			var brass := _mat("t_brass", Color(0.86, 0.66, 0.24), 0.88, 0.0, 0.28)
			var armor := _mat("turret_armor", col, 0.48, 0.0, 0.38)
			var lens := _mat("t_lens", Color(1.0, 0.62, 0.14), 0.1, 2.6, 0.12)
			# Basamaklı sekizgen taş/demir temel + 4 eğimli destek ayağı
			_part(self, _cyl(0.68, 0.80, 0.22, 12), stone_b, Vector3(0, 0.11, 0))
			_part(self, _cyl(0.46, 0.58, 0.62, 12), wood, Vector3(0, 0.52, 0))
			_part(self, _cyl(0.56, 0.56, 0.09, 12), brass, Vector3(0, 0.84, 0))
			_part(self, _cyl(0.62, 0.64, 0.10, 12), dark_iron, Vector3(0, 0.92, 0))
			for i in 4:
				var a := i * PI * 0.5 + PI * 0.25
				var leg := BoxMesh.new()
				leg.size = Vector3(0.18, 0.72, 0.24)
				_part(self, leg, dark_iron, Vector3(cos(a) * 0.58, 0.38, sin(a) * 0.58), Vector3(0, -a + PI * 0.5, 0.38))
			var ring_t := TorusMesh.new()
			ring_t.inner_radius = 0.44; ring_t.outer_radius = 0.56; ring_t.rings = 16; ring_t.ring_segments = 8
			_part(self, ring_t, dark_iron, Vector3(0, 0.98, 0))
			# Dönen zırhlı kule kafası: eğimli gövde, mermi tamburu, hedef optiği, çift soğutmalı namlu
			head = Node3D.new()
			head.position.y = 1.28
			add_child(head)
			var hull := BoxMesh.new()
			hull.size = Vector3(0.68, 0.44, 0.86)
			_part(head, hull, armor, Vector3(0, 0.0, 0.04))
			var cowl := BoxMesh.new()
			cowl.size = Vector3(0.54, 0.18, 0.66)
			_part(head, cowl, dark_iron, Vector3(0, 0.28, 0.06), Vector3(-0.08, 0, 0))
			var drum := _cyl(0.24, 0.24, 0.42, 12)
			_part(head, drum, brass, Vector3(0, 0.04, 0.52), Vector3(0, 0, PI * 0.5))
			var shield_f := BoxMesh.new()
			shield_f.size = Vector3(0.76, 0.36, 0.10)
			_part(head, shield_f, dark_iron, Vector3(0, 0.02, -0.40), Vector3(0.18, 0, 0))
			# Optik hedefleme merceği (ön üstte sıcak kehribar parıltı)
			var opt := SphereMesh.new()
			opt.radius = 0.095; opt.height = 0.19; opt.radial_segments = 10; opt.rings = 5
			_part(head, opt, lens, Vector3(0, 0.30, -0.28))
			# Çift namlu + soğutma bilezikleri + namlu ağız freni
			for sx in [-0.17, 0.17]:
				_part(head, _cyl(0.068, 0.082, 0.88, 10), dark_iron, Vector3(sx, 0.02, -0.78), Vector3(PI * 0.5, 0, 0))
				_part(head, _cyl(0.092, 0.092, 0.14, 10), brass, Vector3(sx, 0.02, -0.56), Vector3(PI * 0.5, 0, 0))
				_part(head, _cyl(0.095, 0.075, 0.14, 10), iron, Vector3(sx, 0.02, -1.20), Vector3(PI * 0.5, 0, 0))
			beam = _part(self, _cyl(0.038, 0.038, 1.0, 6), Fx.mat("spark"), Vector3.ZERO)
			beam.top_level = true
			beam.visible = false
			beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var sh := CylinderShape3D.new()
			sh.radius = 0.65; sh.height = 1.5
			_shape(sh, 0.75)
		"frost": # rünik buz totemi: oymalı taş sunak, 4 kıvrımlı sütun, parlayan rün halkası, ana kristal + 3 yörünge parçası
			var slate := _mat("f_slate", Color(0.32, 0.36, 0.42), 0.05, 0.0, 0.86)
			var dark_slate := _mat("f_dslate", Color(0.20, 0.24, 0.30), 0.08, 0.0, 0.82)
			var ice := _mat("frost_ice", col.lightened(0.15), 0.18, 1.65, 0.14)
			var core_ice := _mat("frost_core", Color(0.82, 0.97, 1.0), 0.1, 2.8, 0.1)
			var rune_glow := _mat("frost_rune", Color(0.38, 0.86, 1.0), 0.1, 2.2, 0.2)
			# Basamaklı sekizgen taş kaide + 4 kavisli koruyucu taş sütun
			_part(self, _cyl(0.72, 0.86, 0.20, 8), dark_slate, Vector3(0, 0.10, 0))
			_part(self, _cyl(0.52, 0.66, 0.28, 8), slate, Vector3(0, 0.32, 0))
			_part(self, _cyl(0.38, 0.48, 0.32, 8), dark_slate, Vector3(0, 0.58, 0))
			for i in 4:
				var a := i * PI * 0.5 + PI * 0.25
				var prong := BoxMesh.new()
				prong.size = Vector3(0.16, 0.92, 0.20)
				_part(self, prong, slate, Vector3(cos(a) * 0.54, 0.66, sin(a) * 0.54), Vector3(0, -a + PI * 0.5, -0.22))
				# Her sütun ucunda küçük buz taşı
				_part(self, _cyl(0.0, 0.09, 0.22, 5), rune_glow, Vector3(cos(a) * 0.44, 1.16, sin(a) * 0.44))
			# Bel çevresinde parlayan rün halkası
			var r_torus := TorusMesh.new()
			r_torus.inner_radius = 0.44; r_torus.outer_radius = 0.51; r_torus.rings = 24; r_torus.ring_segments = 8
			_part(self, r_torus, rune_glow, Vector3(0, 0.78, 0))
			# Süzülen ana altıgen buz kristali + parlak çekirdek
			head = Node3D.new()
			head.position.y = 1.62
			add_child(head)
			_part(head, _cyl(0.0, 0.30, 0.86, 6), ice, Vector3(0, 0.43, 0))
			_part(head, _cyl(0.30, 0.0, 0.62, 6), ice, Vector3(0, -0.31, 0))
			_part(head, _cyl(0.0, 0.14, 0.46, 6), core_ice, Vector3(0, 0.20, 0))
			_part(head, _cyl(0.14, 0.0, 0.32, 6), core_ice, Vector3(0, -0.18, 0))
			# Ana kristalin çevresinde ters yöne dönen 3 küçük buz parçası
			orbit = Node3D.new()
			orbit.position.y = 1.62
			orbit.rotation.z = 0.22
			add_child(orbit)
			for i in 3:
				var a := TAU * i / 3.0
				var shard := Node3D.new()
				shard.position = Vector3(cos(a) * 0.68, sin(a * 2.0) * 0.12, sin(a) * 0.68)
				shard.rotation = Vector3(0.25, -a, 0.18)
				orbit.add_child(shard)
				_part(shard, _cyl(0.0, 0.09, 0.28, 5), ice, Vector3(0, 0.14, 0))
				_part(shard, _cyl(0.09, 0.0, 0.20, 5), ice, Vector3(0, -0.10, 0))
			# Yumuşak buz mavisi nokta ışığı
			var fl_light := OmniLight3D.new()
			fl_light.position = Vector3(0, 1.65, 0)
			fl_light.light_color = Color(0.42, 0.86, 1.0)
			fl_light.light_energy = 1.8
			fl_light.omni_range = 7.5
			fl_light.shadow_enabled = false
			add_child(fl_light)
			var fl := Fx.parts(Fx.quad("glow", 0.20), 16, 1.5, 0.2, 0.8,
				[Color(0.65, 0.94, 1.0, 0.0), Color(0.75, 0.96, 1.0, 0.72), Color(0.45, 0.85, 1.0, 0.0)], 0.8, 0.2, false)
			fl.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			fl.emission_ring_radius = 1.15
			fl.emission_ring_inner_radius = 0.4
			fl.emission_ring_height = 0.7
			fl.gravity = Vector3(0, 0.35, 0)
			fl.position.y = 1.35
			add_child(fl)
			fl.emitting = true
			var ring := Fx.ground(d.range, Color(col, 0.35), Vector4(0.97, 0.02, 0.05, 1.0))
			ring.position.y = 0.05
			add_child(ring)
			var sh := CylinderShape3D.new()
			sh.radius = 0.55; sh.height = 1.8
			_shape(sh, 0.9)
	for mi in find_children("*", "MeshInstance3D", true, false):
		if id == "trap":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar = EnemyScript.make_bar(1.2, 0.9 if id == "trap" else H + 0.4)
	add_child(bar)
	set_physics_process(multiplayer.is_server())
	set_process(id == "frost")
	scale = Vector3(1, 0.05, 1) # yerden yükselir
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	Sfx.play3d(Sfx.rumble, position + Vector3.UP, -6.0)


func _process(dt: float) -> void: # yalnız totem: ana kristal ve yörünge parçaları ters yönlere süzülür
	var t := Time.get_ticks_msec() * 0.003
	head.rotation.y += dt * 1.4
	head.position.y = 1.62 + sin(t) * 0.10
	if orbit:
		orbit.rotation.y -= dt * 2.1
		orbit.position.y = 1.62 + cos(t * 1.2) * 0.06


# ---------- Host ----------

func _physics_process(dt: float) -> void:
	tick -= dt
	if tick > 0.0:
		return
	tick += 0.1
	cd -= 0.1
	if cd > 0.0 or hp <= 0 or td == null or td.state != "fight":
		return
	match id:
		"turret":
			var best: Node3D = null
			var bd: float = d.range * d.range
			for e in td.elist:
				var dd := global_position.distance_squared_to(e.global_position)
				if dd < bd:
					bd = dd
					best = e
			if best:
				cd = d.rate
				td.build_fx.rpc(bid, best.global_position + Vector3.UP * best.height * 0.6)
				td.damage(best, d.dmg, false)
		"spike":
			cd = d.rate
			for e in td.elist.duplicate(): # hasar listeden düşürebilir
				var l := to_local(e.global_position)
				if absf(l.x) < W * 0.5 + e.radius and absf(l.z) < T * 0.5 + e.radius + 0.4:
					td.damage(e, d.dmg, false)
		"trap":
			var hit := false
			for e in td.elist.duplicate():
				if global_position.distance_to(e.global_position) < d.range + e.radius:
					hit = true
					e.slow_k = d.slow
					e.slow_t = d.slow_t
					td.damage(e, d.dmg, false)
			if hit:
				cd = d.rate
				td.build_fx.rpc(bid, global_position)
				td.hurt_build(self, 1) # bir şarj gitti
		"frost":
			cd = 0.4
			for e in td.elist:
				if global_position.distance_to(e.global_position) < d.range:
					e.slow_k = d.slow
					e.slow_t = d.slow_t


# ---------- Her makinede ----------

## td.build_fx: taret atışı (namlu döner, iz çizilir) / tuzak kapanması.
func fx(pos: Vector3) -> void:
	if id == "turret":
		var from := head.global_position
		var flat := Vector3(pos.x, from.y, pos.z)
		if flat.distance_squared_to(from) > 0.01:
			head.look_at(flat)
		var muzzle_p := from - head.global_basis.z * 1.15
		var v := pos - muzzle_p
		beam.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, v.normalized())).scaled(Vector3(1.1, v.length(), 1.1)), muzzle_p + v * 0.5)
		beam.visible = true
		var fl := Fx.parts(Fx.quad("glow", 0.36), 4, 0.08, 0.5, 2.2,
			[Color(1.0, 0.92, 0.55, 0.95), Color(1.0, 0.45, 0.1, 0.0)], 1.0, 0.2)
		fl.position = muzzle_p
		fl.direction = v.normalized()
		fl.spread = 28.0
		fl.finished.connect(fl.queue_free)
		td.get_parent().add_child(fl)
		fl.emitting = true
		var kick := head.create_tween() # geri tepme: namlu kısa ezilip toparlanır
		kick.tween_property(head, "scale", Vector3(1.15, 0.9, 0.78), 0.03)
		kick.tween_property(head, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT)
		create_tween().tween_callback(beam.hide).set_delay(0.08)
		Sfx.play3d(Sfx.fire, from, -16.0)
	elif id == "trap":
		var p := Fx.parts(EnemyScript.spark_mesh(), 12, 0.4, 3.0, 6.0, [Color(1, 0.9, 0.6), Color(1, 0.4, 0.1, 0.0)], 1.0, 0.3)
		p.position = Vector3.UP * 0.3
		p.direction = Vector3.UP
		p.spread = 50.0
		add_child(p)
		p.emitting = true
		p.create_tween().tween_callback(p.queue_free).set_delay(0.6)
		Sfx.play3d(Sfx.shield_break, global_position, -8.0)


## td._bhp: yeni can; sıfırsa yıkılır.
func set_hp(v: int) -> void:
	hp = v
	bar.visible = hp < max_hp and hp > 0
	bar.set_instance_shader_parameter("f", float(hp) / max_hp)
	if hp > 0:
		if id != "trap": # darbe: kısa sarsılma
			var tw := create_tween()
			tw.tween_property(self, "scale", Vector3(1.06, 0.94, 1.06), 0.05)
			tw.tween_property(self, "scale", Vector3.ONE, 0.1)
		return
	remove_from_group("builds")
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.14, 0.18)
	bm.material = Fx.mat("chunk")
	var c: Color = d.color
	var p := Fx.parts(bm, 14, 0.9, 3.0, 6.5, [c.darkened(0.3), c.darkened(0.5)], 1.0, 0.4)
	p.position = position + Vector3.UP * 0.6
	p.direction = Vector3.UP
	p.spread = 70.0
	p.gravity = Vector3(0, -16, 0)
	td.get_parent().add_child(p) # dünyaya: Builds altında yalnız yapılar dursun
	p.emitting = true
	p.create_tween().tween_callback(p.queue_free).set_delay(1.2)
	Sfx.play3d(Sfx.rumble, position + Vector3.UP, 0.0)
	queue_free()
