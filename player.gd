extends CharacterBody3D
## Silindir gövde + yuvarlak kafa. Her oyuncu kendi hareketinin sahibi (client-authoritative):
## pozisyon 60 Hz unreliable gider, diğer tarafta yumuşatılır -> girişte gecikme hissi yok.

const RocketScript := preload("res://rocket.gd")
const ExplosionScript := preload("res://explosion.gd")
const LightningScript := preload("res://lightning.gd")
const WallScript := preload("res://wall.gd")
const Chars := preload("res://characters.gd")
const BLINK_DIST := 8.0
const HYPE_TIME := 4.0
const WAVE_R := 5.0
const WAVE_DMG := 15
const DRONE_RANGE := 30.0
const DRONE_R := 3.0
const DRONE_DMG := 35
const SPEED := 7.0
const ACCEL := 60.0 # yerde hızlanma (m/s²)
const FRICTION := 45.0 # yerde tuş yokken yavaşlama
const AIR_ACCEL := 16.0 # havada kontrol (momentum korunur)
const JUMP := 8.5 # ~1.4 m zıplama
const AIR_JUMP := 7.5 # çift zıplama
const GRAVITY := 26.0
const FALL_MULT := 1.6 # düşerken daha hızlı (oyun hissi)
const MAX_FALL := 45.0
const DASH_SPEED := 20.0
const DASH_TIME := 0.15
const DASH_CD := 0.9
const MAX_HP := 100
const DAMAGE := 20 # 5 isabette ölüm
const THROW_CD := 0.8 # roket atış aralığı
const SHIELD_CD := 8.0
const SHIELD_R := 1.25
const BLAST_RADIUS := 2.5 # patlama bu mesafedekilere hasar verir
const LIGHTNING_CD := 2.5
const LIGHTNING_RANGE := 25.0 # en fazla bu uzaklığa yıldırım indirilir
const LIGHTNING_R := 2.2
const LIGHTNING_DMG := 40 # ateş topunun 2 katı
const WALL_CD := 6.0
const WALL_DIST := 2.5 # duvar önümüzde bu mesafede çıkar
const SWORD_CD := 0.5
const SWORD_RANGE := 2.3 # kılıç bu mesafeye kadar önündekine vurur
const SWORD_DMG := 20
const SLOT_COLORS := {1: Color(1.0, 0.4, 0.05), 3: Color(0.4, 0.75, 1.0), 4: Color(0.6, 0.45, 0.3)}

var spawn_pos := Vector3.ZERO
var rocket_n := 0
var flash := 0.0 # hasar efekti süresi
var body_mat: StandardMaterial3D
var base_col: Color
var hp := MAX_HP
var max_hp := MAX_HP
var ch: Dictionary # seçilen karakter (characters.gd)
var skill_cd := 0.0
var hype_t := 0.0 # > 0 iken Hype Modu açık
var calm_t := 0.0 # son hasardan beri geçen süre (can yenileme için)
var regen_t := 0.0
var cd := 0.0
var slot := 1 # 1 = ateş asası, 2 = kalkan, 3 = yıldırım asası, 4 = duvar asası
var lightning_cd := 0.0
var wall_cd := 0.0
var gem_mat: StandardMaterial3D
var gem_glow: OmniLight3D
var shield_on := false
var shield_cd := 0.0
var shield_mesh: MeshInstance3D
var gun: MeshInstance3D
var air_jumps := 1
var dash_t := 0.0
var dash_cd := 0.0
var walk_t := 0.0

var vis: Node3D
var look: Node3D # kafa / kamera pivotu (pitch)
var cam: Camera3D
var leg_l: Node3D
var leg_r: Node3D

var sword: Node3D
var sword_cd := 0.0
var swing_t := 0.0 # > 0 iken savurma animasyonu
var name_lbl: Label3D # kafa üstü isim (yalnızca başkalarında)
var hp_bar: Node3D
var hp_fill: MeshInstance3D

# Ölünce izleme (yalnızca yerel oyuncu): yaşayan birinin arkasından 3. şahıs kamera.
var spec_target: Node3D
var spec_arm: SpringArm3D
var spec_cam: Camera3D
var spec_yaw := 0.0
var spec_pitch := -0.35
var dead_t := 0.0

var net_pos := Vector3.ZERO
var net_yaw := 0.0
var net_pitch := 0.0
var net_speed := 0.0


func _mesh(parent: Node, m: Mesh, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _bar_mat(mi: MeshInstance3D) -> void:
	var m: StandardMaterial3D = mi.material_override
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _ready() -> void:
	add_to_group("players")
	position = spawn_pos
	net_pos = spawn_pos

	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.9
	cs.shape = cap
	cs.position.y = 0.95
	add_child(cs)

	ch = Chars.get_char(Net.chars.get(get_multiplayer_authority(), 0))
	max_hp = ch.hp
	hp = max_hp
	var col: Color = ch.color
	vis = Node3D.new()
	add_child(vis)

	var body := CylinderMesh.new()
	body.top_radius = 0.36; body.bottom_radius = 0.38; body.height = 0.95
	base_col = col
	body_mat = _mesh(vis, body, Vector3(0, 1.05, 0), col).material_override

	look = Node3D.new()
	look.position.y = 1.7
	vis.add_child(look)
	var head := SphereMesh.new()
	head.radius = 0.3; head.height = 0.6
	_mesh(look, head, Vector3.ZERO, Color(1.0, 0.85, 0.7))
	var eye := SphereMesh.new()
	eye.radius = 0.05; eye.height = 0.1
	_mesh(look, eye, Vector3(-0.11, 0.06, -0.27), Color.BLACK)
	_mesh(look, eye, Vector3(0.11, 0.06, -0.27), Color.BLACK)
	_accessory(ch.look, col)

	var leg := CylinderMesh.new()
	leg.top_radius = 0.11; leg.bottom_radius = 0.1; leg.height = 0.58
	leg_l = Node3D.new(); leg_l.position = Vector3(-0.17, 0.58, 0); vis.add_child(leg_l)
	leg_r = Node3D.new(); leg_r.position = Vector3(0.17, 0.58, 0); vis.add_child(leg_r)
	_mesh(leg_l, leg, Vector3(0, -0.29, 0), col.darkened(0.4))
	_mesh(leg_r, leg, Vector3(0, -0.29, 0), col.darkened(0.4))

	if is_multiplayer_authority():
		cam = Camera3D.new()
		cam.fov = 80
		cam.near = 0.05
		look.add_child(cam)
		cam.current = true
		for mi in vis.find_children("*", "MeshInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY # kendini görme, gölgen kalsın
	else:
		name_lbl = Label3D.new()
		name_lbl.position.y = 2.3 # vis'e değil gövdeye bağlı: ölünce devrilmez
		name_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_lbl.pixel_size = 0.006 # dünya ölçeğinde: uzaklaştıkça oyuncuyla birlikte küçülür
		name_lbl.font_size = 36
		name_lbl.outline_size = 12
		name_lbl.modulate = col.lightened(0.35)
		name_lbl.text = Net.display_name(get_multiplayer_authority())
		add_child(name_lbl)
		# Can barı: ismin altında, her karede kameraya döner.
		hp_bar = Node3D.new()
		hp_bar.position.y = 2.1
		add_child(hp_bar)
		var bg := QuadMesh.new()
		bg.size = Vector2(0.84, 0.11)
		_bar_mat(_mesh(hp_bar, bg, Vector3.ZERO, Color(0, 0, 0, 0.6)))
		var fg := QuadMesh.new()
		fg.size = Vector2(0.8, 0.07)
		hp_fill = _mesh(hp_bar, fg, Vector3(0, 0, 0.005), Color(0.3, 0.9, 0.3))
		_bar_mat(hp_fill)

	# Ateş asası: kafa pivotuna bağlı, sağ altta (herkes görür). Yerel +Y ileriyi gösterir.
	var pole := CylinderMesh.new()
	pole.top_radius = 0.022; pole.bottom_radius = 0.035; pole.height = 1.0
	gun = _mesh(look, pole, Vector3(0.3, -0.35, -0.45), Color(0.4, 0.24, 0.12))
	gun.rotation.x = -PI / 2 + 0.45 # ucu hafif yukarı bakar, kristal görünsün
	var ring := TorusMesh.new()
	ring.inner_radius = 0.04; ring.outer_radius = 0.065
	for y in [0.3, 0.44]:
		var gm := _mesh(gun, ring, Vector3(0, y, 0), Color(0.95, 0.75, 0.2)).material_override as StandardMaterial3D
		gm.metallic = 1.0; gm.roughness = 0.3
	var claw := CylinderMesh.new() # kristali tutan altın pençeler
	claw.top_radius = 0.008; claw.bottom_radius = 0.015; claw.height = 0.16
	for i in 3:
		var a := TAU * i / 3.0
		var c := _mesh(gun, claw, Vector3(cos(a) * 0.05, 0.53, sin(a) * 0.05), Color(0.95, 0.75, 0.2))
		c.basis = Basis(Vector3(-sin(a), 0, cos(a)), -0.35) # uçları dışa açık
	var gem := PrismMesh.new()
	gem.size = Vector3(0.11, 0.2, 0.11)
	var crystal := _mesh(gun, gem, Vector3(0, 0.6, 0), Color(1.0, 0.45, 0.1))
	var cm: StandardMaterial3D = crystal.material_override
	cm.emission_enabled = true
	cm.emission = Color(1.0, 0.4, 0.05)
	cm.emission_energy_multiplier = 3.0
	var gem_lo := _mesh(gun, gem, Vector3(0, 0.5, 0), Color.WHITE) # alt yarısı: ters prizma, aynı malzeme
	gem_lo.material_override = cm
	gem_lo.rotation.x = PI
	gem_lo.scale.y = 0.5
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.5, 0.15)
	glow.light_energy = 0.8
	glow.omni_range = 1.5
	glow.position.y = 0.6
	gun.add_child(glow)
	gem_mat = cm
	gem_glow = glow

	# Kılıç: sağ elde, yerel -Z ileri. Pivot kabzada; savurunca Y ekseninde döner.
	sword = Node3D.new()
	sword.position = Vector3(0.34, -0.36, -0.4)
	look.add_child(sword)
	var blade := BoxMesh.new()
	blade.size = Vector3(0.015, 0.07, 0.75) # keskin kenar yukarı
	var bm := _mesh(sword, blade, Vector3(0, 0, -0.47), Color(0.85, 0.87, 0.9)).material_override as StandardMaterial3D
	bm.metallic = 0.5; bm.roughness = 0.3
	var guard := BoxMesh.new()
	guard.size = Vector3(0.04, 0.24, 0.04)
	_mesh(sword, guard, Vector3(0, 0, -0.08), Color(0.95, 0.75, 0.2))
	var grip := CylinderMesh.new()
	grip.top_radius = 0.022; grip.bottom_radius = 0.022; grip.height = 0.18
	_mesh(sword, grip, Vector3(0, 0, 0.02), Color(0.3, 0.18, 0.1)).rotation.x = PI / 2
	sword.rotation = Vector3(0.9, 0.2, 0) # dinlenme: ucu yukarıda, hafif içe dönük
	sword.visible = false
	if is_multiplayer_authority():
		for mi in sword.find_children("*", "MeshInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Kalkan: yarı saydam mavi küre, içeriden de görünsün.
	var sph := SphereMesh.new()
	sph.radius = SHIELD_R; sph.height = SHIELD_R * 2
	shield_mesh = _mesh(self, sph, Vector3(0, 0.95, 0), Color(0.3, 0.7, 1.0, 0.25))
	var smat: StandardMaterial3D = shield_mesh.material_override
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shield_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shield_mesh.visible = false


## Karakteri tanıtan kafa süsü. Kafa pivotuna bağlı; yerel oyuncu kendininkini görmez.
func _accessory(kind: String, col: Color) -> void:
	match kind:
		"antenna":
			var rod := CylinderMesh.new()
			rod.top_radius = 0.012; rod.bottom_radius = 0.018; rod.height = 0.28
			_mesh(look, rod, Vector3(0, 0.38, 0), Color(0.4, 0.42, 0.48))
			var tip := SphereMesh.new()
			tip.radius = 0.05; tip.height = 0.1
			var m: StandardMaterial3D = _mesh(look, tip, Vector3(0, 0.54, 0), Color(0.3, 0.9, 1.0)).material_override
			m.emission_enabled = true
			m.emission = Color(0.3, 0.9, 1.0)
		"headphones":
			var band := TorusMesh.new()
			band.inner_radius = 0.3; band.outer_radius = 0.34
			_mesh(look, band, Vector3(0, 0.02, 0), Color(0.12, 0.12, 0.14)).rotation.z = PI / 2
			var cup := CylinderMesh.new()
			cup.top_radius = 0.1; cup.bottom_radius = 0.1; cup.height = 0.07
			for x in [-0.32, 0.32]:
				_mesh(look, cup, Vector3(x, 0, 0), col.lightened(0.3)).rotation.z = PI / 2
		"leaves":
			var leaf := PrismMesh.new()
			leaf.size = Vector3(0.1, 0.16, 0.03)
			for i in 7:
				var a := TAU * i / 7.0
				var l := _mesh(look, leaf, Vector3(cos(a) * 0.27, 0.22, sin(a) * 0.27), Color(0.2, 0.65, 0.2))
				l.rotation.y = -a + PI / 2 # yüzü dışarı baksın
		"helmet":
			var dome := SphereMesh.new()
			dome.radius = 0.33; dome.height = 0.33; dome.is_hemisphere = true
			_mesh(look, dome, Vector3(0, 0.04, 0), col)
			var visor := BoxMesh.new()
			visor.size = Vector3(0.4, 0.04, 0.16)
			_mesh(look, visor, Vector3(0, 0.06, -0.3), Color(0.15, 0.15, 0.18))


func _speed() -> float:
	return SPEED * ch.speed * (1.3 if hype_t > 0.0 else 1.0)


func _unhandled_input(e: InputEvent) -> void:
	if not is_multiplayer_authority() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if hp <= 0: # izleme modu: fare kamerayı döndürür, sol/sağ tık oyuncu değiştirir
		if e is InputEventMouseMotion:
			spec_yaw -= e.relative.x * 0.0025
			spec_pitch = clamp(spec_pitch - e.relative.y * 0.0025, -1.2, 0.6)
		elif e is InputEventMouseButton and e.pressed:
			if e.button_index == MOUSE_BUTTON_LEFT:
				_spec_cycle(1)
			elif e.button_index == MOUSE_BUTTON_RIGHT:
				_spec_cycle(-1)
		return
	if e is InputEventMouseMotion:
		rotation.y -= e.relative.x * 0.0025
		look.rotation.x = clamp(look.rotation.x - e.relative.y * 0.0025, -1.45, 1.45)


## Yaşayan diğer oyuncular arasında sıradakine geç (step: 1 ileri, -1 geri).
func _spec_cycle(step: int) -> void:
	var alive := get_parent().get_children().filter(func(p): return p != self and p.hp > 0)
	if alive.is_empty():
		spec_target = null
		return
	var i := alive.find(spec_target)
	spec_target = alive[posmod(i + step, alive.size())] if i >= 0 else alive[0]
	spec_yaw = spec_target.rotation.y # arkasından başla
	if spec_arm:
		spec_arm.clear_excluded_objects()
		spec_arm.add_excluded_object(spec_target.get_rid())


func _spectate(dt: float) -> void:
	dead_t += dt
	if dead_t < 1.2: # önce kendi düşüşünü gör
		return
	if spec_target == null or not is_instance_valid(spec_target) or spec_target.hp <= 0:
		_spec_cycle(1)
	if spec_target == null:
		return # izlenecek kimse yok
	if spec_arm == null:
		spec_arm = SpringArm3D.new()
		spec_arm.top_level = true
		spec_arm.spring_length = 4.5
		spec_arm.margin = 0.3 # ağaç/kayanın içine girme
		var sh := SphereShape3D.new()
		sh.radius = 0.25
		spec_arm.shape = sh
		spec_arm.add_excluded_object(get_rid())
		spec_arm.add_excluded_object(spec_target.get_rid())
		add_child(spec_arm)
		spec_cam = Camera3D.new()
		spec_cam.fov = 80
		spec_arm.add_child(spec_cam)
	spec_arm.global_position = spec_target.global_position + Vector3.UP * 1.7
	spec_arm.rotation = Vector3(spec_pitch, spec_yaw, 0)
	spec_cam.current = true


func _physics_process(dt: float) -> void:
	if is_multiplayer_authority():
		_local(dt)
	else:
		_remote(dt)
	_animate(dt)


func _local(dt: float) -> void:
	var alive := hp > 0
	var active := alive and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var on_floor := is_on_floor()
	if not alive:
		_spectate(dt)
	if on_floor:
		air_jumps = 1
	cd -= dt
	dash_cd -= dt
	shield_cd -= dt
	lightning_cd -= dt
	wall_cd -= dt
	sword_cd -= dt
	skill_cd -= dt
	if alive and ch.regen and hp < max_hp: # Yeşil Eda pasifi
		calm_t += dt
		regen_t += dt
		if calm_t > 3.0 and regen_t >= 0.25:
			regen_t = 0.0
			set_hp.rpc(mini(hp + 1, max_hp))

	var dir := Vector3.ZERO
	if active:
		var iv := Input.get_vector("left", "right", "fwd", "back")
		dir = (transform.basis * Vector3(iv.x, 0, iv.y)).normalized()
		if Input.is_action_just_pressed("jump"):
			if on_floor:
				velocity.y = JUMP
			elif air_jumps > 0: # çift zıplama
				air_jumps -= 1
				velocity.y = AIR_JUMP
		if Input.is_action_just_pressed("dash") and dash_cd <= 0.0: # yerde ve havada
			var d := dir if dir != Vector3.ZERO else -transform.basis.z
			velocity = d * DASH_SPEED
			dash_t = DASH_TIME
			dash_cd = DASH_CD
			Sfx.play2d(Sfx.whoosh, -2.0)
		if Input.is_action_just_pressed("slot1"):
			_set_slot(1)
		if Input.is_action_just_pressed("slot2"):
			_set_slot(2)
			_try_shield()
		if Input.is_action_just_pressed("slot3"):
			_set_slot(3)
		if Input.is_action_just_pressed("slot4"):
			_set_slot(4)
		if Input.is_action_just_pressed("slot5"):
			_set_slot(5)
		if Input.is_action_just_pressed("skill") and skill_cd <= 0.0:
			_use_skill()

	if dash_t > 0.0:
		dash_t -= dt # dash sırasında yerçekimi/sürtünme yok
	else:
		if not on_floor:
			var g := GRAVITY * (FALL_MULT if velocity.y < 0.0 else 1.0)
			velocity.y = max(velocity.y - g * dt, -MAX_FALL)
		var a := AIR_ACCEL
		if on_floor:
			a = ACCEL if dir != Vector3.ZERO else FRICTION
		var hv := Vector2(velocity.x, velocity.z).move_toward(Vector2(dir.x, dir.z) * _speed(), a * dt)
		velocity.x = hv.x
		velocity.z = hv.y

	if active and Input.is_action_just_pressed("throw"):
		if slot == 2:
			_try_shield()
		elif slot == 3 and lightning_cd <= 0.0:
			_cast_lightning()
		elif slot == 4 and wall_cd <= 0.0:
			_place_wall()
		elif slot == 5 and sword_cd <= 0.0:
			sword_cd = SWORD_CD
			swing.rpc(global_position, -transform.basis.z)
	if active and slot == 1 and Input.is_action_pressed("throw") and cd <= 0.0:
		cd = THROW_CD * (0.5 if hype_t > 0.0 else 1.0)
		var b := cam.global_basis
		var target := cam.global_position - b.z * 200.0
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, target)
		q.exclude = [get_rid()]
		var r := get_world_3d().direct_space_state.intersect_ray(q)
		if r:
			target = r.position
		# Asanın kristalinden çık, nişangahın gösterdiği noktaya git.
		var origin := cam.global_position + b.x * 0.3 - b.y * 0.09 - b.z * 0.99 # kristalin konumu
		rocket_n += 1
		fire_rocket.rpc(origin, (target - origin).normalized(), rocket_n)

	move_and_slide()
	if global_position.y < -20.0:
		global_position = spawn_pos
		velocity = Vector3.ZERO
	sync_state.rpc(global_position, rotation.y, look.rotation.x, Vector2(velocity.x, velocity.z).length(), slot)


@rpc("authority", "unreliable_ordered")
func sync_state(p: Vector3, yaw: float, pitch: float, spd: float, s: int) -> void:
	net_pos = p
	net_yaw = yaw
	net_pitch = pitch
	net_speed = spd
	if s != slot:
		_set_slot(s)


func _set_slot(s: int) -> void:
	slot = s
	gun.visible = s != 2 and s != 5 # kalkanda ve kılıçta asa yok
	sword.visible = s == 5
	if SLOT_COLORS.has(s): # her asanın kristal rengi farklı
		gem_mat.albedo_color = SLOT_COLORS[s]
		gem_mat.emission = SLOT_COLORS[s]
		gem_glow.light_color = SLOT_COLORS[s]


func _player_rids() -> Array:
	return get_tree().get_nodes_in_group("players").map(func(p): return p.get_rid())


func _cast_lightning() -> void:
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var to := from - cam.global_basis.z * LIGHTNING_RANGE
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	var r := space.intersect_ray(q)
	var p: Vector3 = r.position if r else to
	# Nişan havadaysa (ya da oyuncuya denk geldiyse) altındaki zemine indir.
	var dq := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.5, p + Vector3.DOWN * 60.0)
	dq.exclude = _player_rids()
	var down := space.intersect_ray(dq)
	if down:
		p = down.position
	elif not r:
		return # harita dışı
	lightning_cd = LIGHTNING_CD
	cast_lightning.rpc(p)


@rpc("authority", "call_local", "reliable")
func cast_lightning(pos: Vector3) -> void:
	var l: Node3D = LightningScript.new()
	l.caster = self
	l.radius = LIGHTNING_R
	l.position = pos
	get_parent().get_parent().add_child(l)


func _place_wall() -> void:
	var p := global_position - transform.basis.z * WALL_DIST
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.0, p + Vector3.DOWN * 6.0)
	q.exclude = _player_rids()
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r:
		p.y = r.position.y
	wall_cd = WALL_CD
	spawn_wall.rpc(p, rotation.y)


## Oyuncu başına tek duvar: yenisi eskisini siler.
@rpc("authority", "call_local", "reliable")
func spawn_wall(pos: Vector3, yaw: float) -> void:
	var world := get_parent().get_parent()
	var wname := "W%d" % get_multiplayer_authority()
	var old := world.get_node_or_null(wname)
	if old:
		world.remove_child(old) # isim hemen boşalsın
		old.queue_free()
	var w: Node3D = WallScript.new()
	w.name = wname
	w.position = pos
	w.rotation.y = yaw
	world.add_child(w)


## Q: karakterin özel yeteneği. Karar yerel makinede, etkiyi use_skill herkese yayar.
func _use_skill() -> void:
	match ch.skill:
		"blink":
			var fwd := -transform.basis.z
			var from := global_position + Vector3.UP
			var q := PhysicsRayQueryParameters3D.create(from, from + fwd * BLINK_DIST)
			q.exclude = [get_rid()]
			var r := get_world_3d().direct_space_state.intersect_ray(q)
			var d: float = maxf(from.distance_to(r.position) - 0.6, 0.0) if r else BLINK_DIST
			use_skill.rpc("blink", global_position)
			global_position += fwd * d
			velocity.y = maxf(velocity.y, 0.0)
		"drone":
			var from := cam.global_position
			var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_basis.z * DRONE_RANGE)
			q.exclude = _player_rids()
			var r := get_world_3d().direct_space_state.intersect_ray(q)
			if not r:
				return # menzilde zemin yok: bekleme süresi harcanmasın
			use_skill.rpc("drone", r.position)
		_:
			use_skill.rpc(ch.skill, global_position)
	skill_cd = ch.cd


@rpc("authority", "call_local", "reliable")
func use_skill(kind: String, pos: Vector3) -> void:
	match kind:
		"blink":
			_ring_fx(pos + Vector3.UP * 0.1, Color(0.4, 0.85, 1.0, 0.8), 1.2, 0.3)
			Sfx.play3d(Sfx.whoosh, pos + Vector3.UP, 2.0)
		"hype":
			hype_t = HYPE_TIME
			Sfx.play3d(Sfx.shield_up, pos + Vector3.UP, 0.0)
		"wave":
			_ring_fx(pos + Vector3.UP * 0.2, Color(0.2, 0.55, 1.0, 0.7), WAVE_R, 0.45)
			Sfx.play3d(Sfx.boom, pos, -2.0)
			apply_blast(pos + Vector3.UP * 0.95, WAVE_R, WAVE_DMG)
		"drone":
			# Uyarı halkası 1 sn'de daralır, sonra bomba patlar.
			var mark := _ring_fx(pos + Vector3.UP * 0.05, Color(1.0, 0.2, 0.1, 0.7), DRONE_R, 0.0)
			var tw := mark.create_tween()
			tw.tween_property(mark, "scale", Vector3.ONE * 0.3, 1.0).from(Vector3.ONE * DRONE_R)
			tw.tween_callback(_drone_hit.bind(pos, mark)) # mark ya da oyuncu silinirse çağrılmaz


func _drone_hit(pos: Vector3, mark: Node3D) -> void:
	mark.queue_free()
	var fx: Node3D = ExplosionScript.new()
	fx.position = pos
	get_parent().get_parent().add_child(fx)
	Sfx.play3d(Sfx.boom, pos, 4.0)
	apply_blast(pos + Vector3.UP * 0.5, DRONE_R, DRONE_DMG)


## Yere yatık halka efekti. fade > 0 ise o sürede genişleyip söner ve silinir.
func _ring_fx(pos: Vector3, c: Color, r: float, fade: float) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = 0.9; t.outer_radius = 1.0
	var mi := _mesh(get_parent().get_parent(), t, pos, c)
	_bar_mat(mi)
	mi.scale = Vector3.ONE * r
	if fade > 0.0:
		var tw := mi.create_tween().set_parallel()
		tw.tween_property(mi, "scale", Vector3.ONE * r, fade).from(Vector3.ONE * 0.2)
		tw.tween_property(mi.material_override, "albedo_color:a", 0.0, fade)
		tw.chain().tween_callback(mi.queue_free)
	return mi


func _try_shield() -> void:
	if not shield_on and shield_cd <= 0.0:
		shield_cd = ch.shield_cd
		set_shield.rpc(true)


@rpc("authority", "call_local", "reliable")
func set_shield(on: bool) -> void:
	if on == shield_on:
		return
	shield_on = on
	shield_mesh.visible = on
	var pos := global_position + Vector3.UP
	Sfx.play3d(Sfx.shield_up if on else Sfx.shield_break, pos, 0.0)


func _remote(dt: float) -> void:
	var k: float = min(1.0, dt * 18.0)
	if global_position.distance_to(net_pos) > 6.0:
		global_position = net_pos # ışınlanma (respawn)
	else:
		global_position = global_position.lerp(net_pos, k)
	rotation.y = lerp_angle(rotation.y, net_yaw, k)
	look.rotation.x = lerp(look.rotation.x, net_pitch, k)


func _animate(dt: float) -> void:
	var spd: float = Vector2(velocity.x, velocity.z).length() if is_multiplayer_authority() else net_speed
	var amp: float = clamp(spd / SPEED, 0.0, 1.0) * 0.7
	walk_t += dt * spd * 2.0
	leg_l.rotation.x = sin(walk_t) * amp
	leg_r.rotation.x = -sin(walk_t) * amp
	vis.rotation.z = lerp(vis.rotation.z, 1.5 if hp <= 0 else 0.0, 0.1) # ölünce devril
	if swing_t > 0.0: # sağdan sola yatay savurma
		swing_t = maxf(swing_t - dt, 0.0)
		var k := 1.0 - swing_t / 0.25
		sword.rotation = Vector3(0.25, lerpf(1.3, -1.1, k), -0.5)
	else:
		sword.rotation = sword.rotation.lerp(Vector3(0.9, 0.2, 0), 0.2)
	if name_lbl: # isim lobiden sonra gelebilir
		var n := Net.display_name(get_multiplayer_authority())
		if name_lbl.text != n:
			name_lbl.text = n
		var f := clampf(float(hp) / max_hp, 0.0, 1.0)
		hp_fill.scale.x = maxf(f, 0.001)
		hp_fill.position.x = -0.4 * (1.0 - f) # sola yaslı
		(hp_fill.material_override as StandardMaterial3D).albedo_color = Color(0.95, 0.2, 0.15).lerp(Color(0.3, 0.9, 0.3), f)
		hp_bar.visible = hp > 0
		var c := get_viewport().get_camera_3d()
		if c:
			hp_bar.global_basis = c.global_basis # kameraya dön
	flash = max(flash - dt, 0.0)
	hype_t = maxf(hype_t - dt, 0.0)
	body_mat.albedo_color = base_col.lerp(Color(1, 0.1, 0.1), flash / 0.35)
	body_mat.emission_enabled = flash > 0.0 or hype_t > 0.0
	body_mat.emission = Color(1, 0, 0) * (flash / 0.35) if flash > 0.0 else Color(0.7, 0.2, 1.0) * 0.6 # mor: hype


@rpc("authority", "call_local", "reliable")
func fire_rocket(origin: Vector3, dir: Vector3, n: int) -> void:
	var r: Node3D = RocketScript.new()
	r.name = "R%d_%d" % [get_multiplayer_authority(), n]
	r.shooter = self
	r.dir = dir
	r.position = origin
	get_parent().get_parent().add_child(r)
	Sfx.play3d(Sfx.fire, origin, -2.0)


## Atanın makinesi çarpışmayı bulunca herkese yayınlar.
@rpc("authority", "call_local", "reliable")
func explode(rocket_name, pos: Vector3) -> void:
	var world := get_parent().get_parent()
	var r := world.get_node_or_null(NodePath(str(rocket_name)))
	if r:
		r.queue_free()
	var fx: Node3D = ExplosionScript.new()
	fx.position = pos
	world.add_child(fx)
	Sfx.play3d(Sfx.boom, pos, 4.0)
	apply_blast(pos, BLAST_RADIUS)


## Kılıç savurma: herkes animasyonu görür, her makine kendi oyuncusu vurulduysa hasarı uygular.
@rpc("authority", "call_local", "reliable")
func swing(from: Vector3, fwd: Vector3) -> void:
	swing_t = 0.25
	Sfx.play3d(Sfx.whoosh, from + Vector3.UP * 1.5, 0.0)
	var me = get_parent().get_node_or_null(str(multiplayer.get_unique_id()))
	if me == null or me == self or me.hp <= 0:
		return
	var to: Vector3 = me.global_position - from
	to.y = 0.0
	if to.length() > SWORD_RANGE or (to.length() > 0.3 and fwd.dot(to.normalized()) < 0.4):
		return # menzil dışı ya da önünde değil (~65° yay)
	me.velocity += fwd * 6.0 + Vector3.UP * 2.0 # geri savrulma
	if me.shield_on:
		me.set_shield.rpc(false)
	else:
		me.take_hit(SWORD_DMG)


## Hasarı her makine yalnızca kendi oyuncusu için uygular (atan hariç).
func apply_blast(pos: Vector3, radius: float, dmg := DAMAGE) -> void:
	var me = get_parent().get_node_or_null(str(multiplayer.get_unique_id()))
	if me == null or me == self or me.hp <= 0:
		return
	var c: Vector3 = me.global_position + Vector3(0, 0.95, 0)
	if c.distance_to(pos) < radius:
		me.velocity += (c - pos).normalized() * 7.0 + Vector3.UP * 3.0 # sarsıntı / itme
		if me.shield_on:
			me.set_shield.rpc(false) # kalkan tek roketi emer
		else:
			me.take_hit(dmg)


## Roket kurbanın kendi makinesinde hasar uygular.
func take_hit(dmg := DAMAGE) -> void:
	set_hp.rpc(hp - dmg)
	if hp <= 0:
		get_node("/root/Main").report_death.rpc_id(1, get_multiplayer_authority())


@rpc("authority", "call_local", "reliable")
func set_hp(v: int) -> void:
	if v < hp:
		flash = 0.35
		calm_t = 0.0
		if is_multiplayer_authority():
			Sfx.play2d(Sfx.hurt)
		else:
			Sfx.play3d(Sfx.hurt, global_position + Vector3.UP)
	hp = max(v, 0)


func respawn() -> void:
	hp = max_hp
	skill_cd = 0.0
	hype_t = 0.0
	calm_t = 0.0
	shield_on = false
	shield_mesh.visible = false
	shield_cd = 0.0
	dash_cd = 0.0
	lightning_cd = 0.0
	wall_cd = 0.0
	sword_cd = 0.0
	velocity = Vector3.ZERO
	global_position = spawn_pos
	net_pos = spawn_pos
	dead_t = 0.0
	spec_target = null
	if cam:
		cam.current = true # izlemeden kendi gözüne dön
