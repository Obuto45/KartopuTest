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
var beam: MeshInstance3D # taretin atış izi (tek düğüm, her atışta yeniden kullanılır)
var tick := 0.0
var cd := 0.0


func _mat(k: String, c: Color, metal := 0.0, glow := 0.0) -> Material:
	return EnemyScript.shared("b_" + k, func() -> Resource:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = metal
		m.roughness = 0.5 if metal > 0.0 else 0.9
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
		"turret": # ahşap kaide + dönen namlu
			_part(self, _cyl(0.5, 0.7, 0.9, 8), wood, Vector3(0, 0.45, 0))
			_part(self, _cyl(0.62, 0.62, 0.1, 8), iron, Vector3(0, 0.9, 0))
			head = Node3D.new()
			head.position.y = 1.2
			add_child(head)
			var bm := BoxMesh.new()
			bm.size = Vector3(0.6, 0.45, 0.8)
			_part(head, bm, _mat("turret", col, 0.4), Vector3.ZERO)
			_part(head, _cyl(0.09, 0.11, 0.9, 6), iron, Vector3(0, 0.02, -0.75), Vector3(PI / 2, 0, 0))
			beam = _part(self, _cyl(0.035, 0.035, 1.0, 4), Fx.mat("spark"), Vector3.ZERO)
			beam.top_level = true
			beam.visible = false
			beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var sh := CylinderShape3D.new()
			sh.radius = 0.65; sh.height = 1.5
			_shape(sh, 0.75)
		"frost": # taş kaide + süzülen buz kristali + menzil halkası
			_part(self, _cyl(0.4, 0.6, 0.7, 6), _mat("stone", Color(0.5, 0.5, 0.52)), Vector3(0, 0.35, 0))
			head = Node3D.new()
			head.position.y = 1.35
			add_child(head)
			var ice := _mat("frost", col, 0.2, 1.2)
			_part(head, _cyl(0.0, 0.32, 0.7, 5), ice, Vector3(0, 0.35, 0))
			_part(head, _cyl(0.32, 0.0, 0.5, 5), ice, Vector3(0, -0.25, 0))
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


func _process(dt: float) -> void: # yalnız totem: kristal döner, süzülür
	head.rotation.y += dt * 1.5
	head.position.y = 1.35 + sin(Time.get_ticks_msec() * 0.003) * 0.08


# ---------- Host ----------

func _physics_process(dt: float) -> void:
	tick -= dt
	if tick > 0.0:
		return
	tick += 0.1
	cd -= 0.1
	if cd > 0.0 or hp <= 0 or td.state != "fight":
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
		var v := pos - from
		beam.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, v.normalized())).scaled(Vector3(1, v.length(), 1)), from + v * 0.5)
		beam.visible = true
		create_tween().tween_callback(beam.hide).set_delay(0.07)
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
