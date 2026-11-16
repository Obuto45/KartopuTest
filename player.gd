extends CharacterBody3D
## Animasyonlu 3D karakter. Her oyuncu kendi hareketinin sahibi (client-authoritative):
## pozisyon 60 Hz unreliable gider, diğer tarafta yumuşatılır -> girişte gecikme hissi yok.
## Hasar ve olumsuz etkileri her makine yalnızca kendi oyuncusuna uygular.

const RocketScript := preload("res://rocket.gd")
const ExplosionScript := preload("res://explosion.gd")
const WallScript := preload("res://wall.gd")
const Chars := preload("res://characters.gd")
const HomingScript := preload("res://slipper.gd")
const ZoneScript := preload("res://zone.gd")
const SIT_TIME := 2.0 # sit_shield pasifi: bu kadar durunca kalkan alır
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
const SHIELD_R := 1.25
const BLAST_RADIUS := 2.5 # patlama bu mesafedekilere hasar verir
const BIG_RADIUS := 4.5 # gülle
const BIG_DMG := 40
const WALL_CD := 6.0
const WALL_DIST := 2.5 # duvar önümüzde bu mesafede çıkar
const SWORD_CD := 0.5
const SWORD_RANGE := 2.3 # kılıç bu mesafeye kadar önündekine vurur
const SWORD_DMG := 20
const MODEL_SCALE := 0.72 # Quaternius modelleri ~2,6 birim boyunda
const TIMED := ["haste", "power", "rapid", "multi", "armor", "size"] # atanın [değer, süre] güçleri
const DEBUFFS := ["slow", "vuln", "burn"] # kurbana [değer, süre]
const FLAGS := ["stun", "blind", "silence", "confuse"] # kurbana süre


## Animasyondan sonra çalışır: sağ kolu silaha uzatır, kafayı bakışa çevirir.
class ArmAim extends SkeletonModifier3D:
	var p: Node

	func _process_modification() -> void:
		p._pose(get_skeleton())


var spawn_pos := Vector3.ZERO
var rocket_n := 0
var flash := 0.0 # hasar efekti süresi
var hp := MAX_HP
var max_hp := MAX_HP
var ch: Dictionary # seçilen karakter (characters.gd)
var sk: Dictionary # karakterin Q yeteneği
var skill_cd := 0.0
var buffs := {} # ad -> [değer, kalan süre]: süreli güçler ve olumsuz etkiler
var tick_t := 0.0
var regen_acc := 0.0
var land_wait := -1.0 # >= 0: sıçradı, yere inince alan etkisi tetiklenecek
var size_k := 1.0
var model: Node3D
var model_fx: StandardMaterial3D # modelin üstüne binen renk parlaması (hasar, güç)
var anim: AnimationPlayer
var cur_anim := ""
var b_arm := -1
var b_fore := -1
var b_head := -1
var quote_lbl: Label3D
var quote_t := 0.0
var still_t := 0.0 # yerinde durma süresi (sit_shield)
var cd := 0.0
var slot := 1 # 1 = bazuka, 2 = kalkan, 3 = duvar, 4 = kılıç
var wall_cd := 0.0
var shield_on := false
var shield_cd := 0.0
var shield_mesh: MeshInstance3D
var gun: Node3D
var air_jumps := 1
var dash_t := 0.0
var dash_cd := 0.0

var vis: Node3D
var look: Node3D # kafa / kamera pivotu (pitch)
var cam: Camera3D

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
var net_air := false


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


## Süreli etkinin değeri (yoksa d) ve kalan süresi.
func bv(k: String, d := 1.0) -> float:
	return buffs[k][0] if buffs.has(k) else d


func bt(k: String) -> float:
	return buffs[k][1] if buffs.has(k) else 0.0


func _world() -> Node:
	return get_parent().get_parent()


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
	sk = ch.sk
	max_hp = ch.get("hp", MAX_HP)
	hp = max_hp
	vis = Node3D.new()
	add_child(vis)
	look = Node3D.new()
	look.position.y = 1.7
	vis.add_child(look)
	_load_model()

	# Bazuka ve kılıç kafa pivotuna bağlı (bakışla birlikte döner); sağ kol onlara uzanır.
	gun = _prop("res://models/bazooka.glb", 0.95, Vector3(0, PI / 2, 0), Vector3(0.5, 0.5, 0.5))
	gun.position = Vector3(0.3, -0.33, -0.5)
	sword = _prop("res://models/sword.glb", 1.05, Vector3(-PI / 2, 0, 0), Vector3(0.5, 0.1, 0.5)) # kabzadan tut
	sword.position = Vector3(0.34, -0.36, -0.4)
	sword.rotation = Vector3(0.9, 0.2, 0) # dinlenme: ucu yukarıda, hafif içe dönük
	sword.visible = false

	if is_multiplayer_authority():
		cam = Camera3D.new()
		cam.fov = 80
		cam.near = 0.05
		look.add_child(cam)
		cam.current = true
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY # kendini görme, gölgen kalsın
		for mi in gun.find_children("*", "MeshInstance3D", true, false) + sword.find_children("*", "MeshInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		var col: Color = ch.color
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


## Karakterin iskeletli modelini yükler: ayaklar yerde, yüzü -Z'ye (ileri) dönük.
func _load_model() -> void:
	model = load("res://models/chars/%s.glb" % ch.model).instantiate()
	vis.add_child(model)
	model.scale = Vector3.ONE * MODEL_SCALE
	model.rotation.y = PI # modellerin önü +Z'ye bakıyor
	model_fx = StandardMaterial3D.new()
	model_fx.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	model_fx.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	model_fx.albedo_color = Color(1, 0.1, 0.1, 0)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = model_fx
	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	for n in ["Idle", "Run", "Walk"]: # dosyada döngü işareti yok
		if anim.has_animation(n):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	b_arm = skel.find_bone("UpperArm.R")
	b_fore = skel.find_bone("LowerArm.R")
	b_head = skel.find_bone("Head")
	var aim := ArmAim.new()
	aim.p = self
	skel.add_child(aim)


## Silah modeli: en uzun kenarı length olacak şekilde ölçekler, rot ile çevirir ve
## kutusunun anchor (0..1) noktasını tutucunun merkezine getirir.
func _prop(path: String, length: float, rot: Vector3, anchor: Vector3) -> Node3D:
	var holder := Node3D.new()
	look.add_child(holder)
	var scene: Node3D = load(path).instantiate()
	holder.add_child(scene)
	var box := AABB()
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var xf: Transform3D = mi.transform
		var n := mi.get_parent()
		while n != scene:
			xf = n.transform * xf
			n = n.get_parent()
		box = xf * mi.get_aabb() if box.size == Vector3.ZERO else box.merge(xf * mi.get_aabb())
	scene.rotation = rot
	scene.scale = Vector3.ONE * (length / box.get_longest_axis_size())
	scene.position = -(scene.basis * (box.position + box.size * anchor))
	return holder


## ArmAim çağırır (iskelet uzayı: +Z ön, +Y yukarı). Kemiklerin yerel +Y'si uzunluk yönüdür.
func _pose(s: Skeleton3D) -> void:
	if hp <= 0:
		return
	if b_head >= 0:
		var h := s.get_bone_global_pose(b_head)
		h.basis = Basis(Vector3.RIGHT, -look.rotation.x * 0.6) * h.basis
		s.set_bone_global_pose(b_head, h)
	if (slot == 1 or slot == 4) and b_arm >= 0 and b_fore >= 0:
		var grip: Vector3 = s.global_transform.affine_inverse() * (sword if slot == 4 else gun).global_position
		_aim_bone(s, b_arm, (grip - s.get_bone_global_pose(b_arm).origin).normalized() + Vector3.DOWN * 0.45)
		_aim_bone(s, b_fore, grip - s.get_bone_global_pose(b_fore).origin)


func _aim_bone(s: Skeleton3D, i: int, dir: Vector3) -> void:
	var g := s.get_bone_global_pose(i)
	g.basis = Basis(Quaternion(g.basis.y.normalized(), dir.normalized())) * g.basis
	s.set_bone_global_pose(i, g)


func _speed() -> float:
	return SPEED * ch.get("speed", 1.0) * bv("haste") * bv("slow")


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
	var active := alive and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and bt("stun") <= 0.0
	var can_act := active and bt("silence") <= 0.0
	var on_floor := is_on_floor()
	if not alive:
		_spectate(dt)
	if on_floor:
		air_jumps = ch.get("air_jumps", 1)
	cd -= dt
	dash_cd -= dt
	shield_cd -= dt
	wall_cd -= dt
	sword_cd -= dt
	skill_cd -= dt
	if alive:
		_tick(dt, on_floor)

	var dir := Vector3.ZERO
	if active:
		var iv := Input.get_vector("left", "right", "fwd", "back")
		if bt("confuse") > 0.0:
			iv = -iv # kafası karışık: yönler ters
		dir = (transform.basis * Vector3(iv.x, 0, iv.y)).normalized()
		if Input.is_action_just_pressed("jump"):
			if on_floor:
				velocity.y = JUMP * ch.get("jump", 1.0)
			elif air_jumps > 0: # çift zıplama
				air_jumps -= 1
				velocity.y = AIR_JUMP * ch.get("jump", 1.0)
		if Input.is_action_just_pressed("dash") and dash_cd <= 0.0: # yerde ve havada
			var d := dir if dir != Vector3.ZERO else -transform.basis.z
			velocity = d * DASH_SPEED
			dash_t = DASH_TIME
			dash_cd = DASH_CD
			Sfx.play2d(Sfx.whoosh, -2.0)
		for s in [1, 2, 3, 4]:
			if Input.is_action_just_pressed("slot%d" % s):
				_set_slot(s)
				if s == 2:
					_try_shield()
		if can_act and Input.is_action_just_pressed("skill") and skill_cd <= 0.0:
			_use_skill()

	if dash_t > 0.0:
		dash_t -= dt # dash sırasında yerçekimi/sürtünme yok
	else:
		if not on_floor:
			var g := GRAVITY * (FALL_MULT if velocity.y < 0.0 else 1.0) * (0.25 if bt("float") > 0.0 else 1.0)
			velocity.y = max(velocity.y - g * dt, -MAX_FALL)
		var a := AIR_ACCEL
		if on_floor:
			a = ACCEL if dir != Vector3.ZERO else FRICTION
		var hv := Vector2(velocity.x, velocity.z).move_toward(Vector2(dir.x, dir.z) * _speed(), a * dt)
		velocity.x = hv.x
		velocity.z = hv.y

	if can_act and Input.is_action_just_pressed("throw"):
		if slot == 2:
			_try_shield()
		elif slot == 3 and wall_cd <= 0.0:
			wall_cd = ch.get("wall_cd", WALL_CD)
			spawn_wall.rpc(_ground(global_position - transform.basis.z * WALL_DIST), rotation.y, 0)
		elif slot == 4 and sword_cd <= 0.0:
			sword_cd = SWORD_CD
			swing.rpc(global_position, -transform.basis.z)
	if can_act and slot == 1 and Input.is_action_pressed("throw") and cd <= 0.0:
		cd = THROW_CD * ch.get("fire_cd", 1.0) * bv("rapid")
		_shoot(int(bv("multi")), 0.07, false)

	move_and_slide()
	if global_position.y < -20.0:
		global_position = spawn_pos
		velocity = Vector3.ZERO
	sync_state.rpc(global_position, rotation.y, look.rotation.x, Vector2(velocity.x, velocity.z).length(), slot, not is_on_floor())


## Yalnızca sahibinde: can yenileme, yanma, durunca kalkan, sıçrayıştan iniş.
func _tick(dt: float, on_floor: bool) -> void:
	tick_t += dt
	if tick_t >= 1.0:
		tick_t -= 1.0
		regen_acc += ch.get("regen", 0.0) + bv("regen", 0.0)
		if regen_acc >= 1.0:
			gain(int(regen_acc))
			regen_acc -= int(regen_acc)
		if bt("burn") > 0.0:
			take_hit(int(bv("burn")), true)
	if ch.get("sit_shield", false):
		still_t = still_t + dt if Vector2(velocity.x, velocity.z).length() < 0.5 else minf(still_t, 0.0)
		if still_t >= SIT_TIME and not shield_on:
			still_t = -4.0 # sıradaki kalkan en erken 6 sn sonra
			set_shield.rpc(true)
	if land_wait >= 0.0:
		land_wait += dt
		if (land_wait > 0.25 and on_floor) or land_wait > 3.0:
			land_wait = -1.0
			skill_area.rpc(global_position, -transform.basis.z)


@rpc("authority", "unreliable_ordered")
func sync_state(p: Vector3, yaw: float, pitch: float, spd: float, s: int, air: bool) -> void:
	net_pos = p
	net_yaw = yaw
	net_pitch = pitch
	net_speed = spd
	net_air = air
	slot = s


func _set_slot(s: int) -> void:
	slot = s


func _player_rids() -> Array:
	return get_tree().get_nodes_in_group("players").map(func(p): return p.get_rid())


## Noktanın altındaki zemini bulur (oyuncuları saymaz).
func _ground(p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.0, p + Vector3.DOWN * 60.0)
	q.exclude = _player_rids()
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r:
		p.y = r.position.y
	return p


## Nişangâhın gösterdiği yöne n roket (yelpaze açısı: spread radyan).
func _shoot(n: int, spread: float, big: bool) -> void:
	var b := cam.global_basis
	var target := cam.global_position - b.z * 200.0
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, target)
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r:
		target = r.position
	var origin := cam.global_position + b.x * 0.3 - b.y * 0.33 - b.z * 1.05 # bazukanın namlusu
	var d := (target - origin).normalized()
	for i in n:
		rocket_n += 1
		fire_rocket.rpc(origin, d.rotated(Vector3.UP, spread * (i - (n - 1) * 0.5)), rocket_n, big)


## Oyuncu başına her numaradan tek duvar: yenisi eskisini siler.
@rpc("authority", "call_local", "reliable")
func spawn_wall(pos: Vector3, yaw: float, k: int) -> void:
	var world := _world()
	var wname := "W%d_%d" % [get_multiplayer_authority(), k]
	var old := world.get_node_or_null(wname)
	if old:
		world.remove_child(old) # isim hemen boşalsın
		old.queue_free()
	var w: Node3D = WallScript.new()
	w.name = wname
	w.position = pos
	w.rotation.y = yaw
	world.add_child(w)


# ---------- Q: karakter yeteneği (characters.gd'deki "sk" verisini yorumlar) ----------

func _nearest(max_d: float) -> Node3D:
	var best: Node3D = null
	for p in get_parent().get_children():
		var d := global_position.distance_to(p.global_position)
		if p != self and p.hp > 0 and d < max_d:
			best = p
			max_d = d
	return best


## Nişangâhın gösterdiği nokta (en çok max_d uzakta); boşluğa bakıyorsa altındaki zemin.
func _aim_point(max_d: float) -> Vector3:
	var from := cam.global_position
	var to := from - cam.global_basis.z * max_d
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return r.position if r else _ground(to)


## Karar yerel makinede verilir, etkiyi use_skill herkese yayar.
func _use_skill() -> void:
	var target_id := 0
	if sk.has("range"):
		var best := _nearest(sk.range)
		if best == null:
			return # hedef yok: bekleme süresi harcanmasın
		target_id = best.get_multiplayer_authority()
		if sk.has("backstab"): # hedefin arkasına geç, ona dön
			global_position = best.global_position + best.transform.basis.z * 1.6
			rotation.y = best.rotation.y
			velocity = Vector3.ZERO
	var aim := global_position
	if sk.has("area") and sk.area.get("at", "") == "aim":
		aim = _aim_point(sk.area.range)
	skill_cd = ch.cd
	use_skill.rpc(global_position, aim, -transform.basis.z, target_id)


@rpc("authority", "call_local", "reliable")
func use_skill(pos: Vector3, aim: Vector3, fwd: Vector3, target_id: int) -> void:
	say(ch.quote)
	Sfx.play3d(Sfx.whoosh, pos + Vector3.UP, 2.0)
	var s: Dictionary = sk.get("self", {})
	for k in TIMED:
		if s.has(k):
			buffs[k] = s[k].duplicate()
	for k in ["invis", "float"]:
		if s.has(k):
			buffs[k] = [1.0, s[k]]
	if not s.is_empty():
		_ring_fx(pos + Vector3.UP * 0.2, Color(ch.color, 0.85), 1.6, 0.4)
	var target: Node3D = get_parent().get_node_or_null(str(target_id)) if target_id != 0 else null
	if is_multiplayer_authority():
		_self_skill(s, fwd, target)
	if target and sk.has("swap") and target.is_multiplayer_authority(): # kurban benim yerime gelir
		target.global_position = pos
		target.velocity = Vector3.ZERO
	if target and sk.has("homing"):
		var h: Node3D = HomingScript.new()
		h.thrower = self
		h.h = sk.homing
		h.target = target
		h.dir = (-look.global_basis.z + Vector3.UP * 0.4).normalized() # önce havaya kalkar
		h.position = look.global_position + h.dir * 0.6
		_world().add_child(h)
	if sk.has("area") and not sk.area.get("land", false):
		_area(sk.area, aim if sk.area.get("at", "") == "aim" else pos, fwd)


## Yeteneğin atanı etkileyen kısmı; yalnızca atanın kendi makinesinde çalışır.
func _self_skill(s: Dictionary, fwd: Vector3, target: Node3D) -> void:
	var flat := Vector3(fwd.x, 0, fwd.z).normalized()
	var heal: int = s.get("heal", 0) + int((max_hp - hp) * s.get("heal_missing", 0.0))
	if heal > 0:
		gain(heal)
	if s.has("regen"):
		buffs["regen"] = s.regen.duplicate()
	if s.has("confuse"):
		buffs["confuse"] = [1.0, s.confuse]
	if s.get("shield", false) and not shield_on:
		set_shield.rpc(true)
	if s.has("leap"):
		velocity = flat * s.leap[0] + Vector3.UP * s.leap[1]
		if sk.has("area") and sk.area.get("land", false):
			land_wait = 0.0
	if s.has("blink"):
		var d: float = s.blink
		var from := global_position + Vector3.UP * 0.9
		var q := PhysicsRayQueryParameters3D.create(from, from + flat * d)
		q.exclude = _player_rids()
		var r := get_world_3d().direct_space_state.intersect_ray(q)
		if r:
			d = maxf(from.distance_to(r.position) - 0.6, 0.0) # duvarın içine girme
		global_position += flat * d
	if s.get("reset", false):
		cd = 0.0; shield_cd = 0.0; wall_cd = 0.0; dash_cd = 0.0; sword_cd = 0.0
	if sk.has("volley"):
		_shoot(sk.volley[0], sk.volley[1], sk.volley[2])
	if sk.has("walls"): # önüne ve iki yanına
		for i in sk.walls:
			var ang: float = [0.0, 1.15, -1.15][i % 3]
			spawn_wall.rpc(_ground(global_position + flat.rotated(Vector3.UP, ang) * WALL_DIST), rotation.y + ang, i + 1)
	if target and sk.has("swap"):
		global_position = target.global_position
		velocity = Vector3.ZERO


## Sıçrayışın inişi gibi sonradan tetiklenen alan etkisi.
@rpc("authority", "call_local", "reliable")
func skill_area(pos: Vector3, dir: Vector3) -> void:
	_area(sk.area, pos, dir)


## Alan etkisi: anlıksa hemen uygular; gecikmeli / kalıcı / kapansa zone.gd devralır.
func _area(a: Dictionary, at: Vector3, dir: Vector3) -> void:
	if a.has("delay") or a.has("linger") or a.has("mine"):
		var z: Node3D = ZoneScript.new()
		z.caster = self
		z.a = a
		z.position = at
		_world().add_child(z)
		return
	var col := Color(a.get("color", ch.color), 0.85)
	_ring_fx(at + Vector3.UP * 0.2, col, a.r, 0.35)
	if a.get("beam", false):
		_beam_fx(gun.global_position, at, col)
	if a.get("boom", false):
		boom_fx(at, 1.0)
	hit_local(a, at, dir)


## Bu makinedeki oyuncu (atan değilse) etki alanındaysa etkiyi ona uygular.
func hit_local(a: Dictionary, at: Vector3, dir: Vector3) -> void:
	var me := _local_player()
	if me == null or me == self or me.hp <= 0:
		return
	var c: Vector3 = me.global_position + Vector3.UP * 0.9
	if minf(c.distance_to(at), me.global_position.distance_to(at)) > a.r:
		return
	if a.has("cone"): # yalnızca önündeki yay
		var to: Vector3 = me.global_position - at
		to.y = 0.0
		if to.length() > 0.3 and dir.dot(to.normalized()) < a.cone:
			return
	if a.get("gaze", false) and (-me.look.global_basis.z).dot((at + Vector3.UP * 1.7 - me.look.global_position).normalized()) < 0.3:
		return # bakmıyor
	affect(me, a, at)


## Etkiyi kurbana uygular (kurbanın kendi makinesinde çağrılır). Kalkan bir etkiyi tümüyle emer.
func affect(me: Node, e: Dictionary, from: Vector3) -> void:
	if me.shield_on:
		me.set_shield.rpc(false)
		return
	var away: Vector3 = me.global_position - from
	away.y = 0.0
	var dist := away.length()
	away = away.normalized() if dist > 0.05 else -transform.basis.z
	if e.has("knock"):
		me.velocity += away * e.knock + Vector3.UP * e.get("up", 3.0)
	elif e.has("up"):
		me.velocity.y = e.up
	if e.has("pull"):
		me.velocity += -away * minf(dist * 2.0, e.pull) + Vector3.UP * 4.0
	if e.has("yank"): # atanın yanına
		var to: Vector3 = global_position - me.global_position
		me.velocity = to.normalized() * minf(to.length() * 2.2, e.yank) + Vector3.UP * 5.0
	for k in DEBUFFS:
		if e.has(k):
			me.buffs[k] = e[k].duplicate()
	for k in FLAGS:
		if e.has(k):
			me.buffs[k] = [1.0, e[k]]
	if e.has("drain"):
		gain.rpc_id(get_multiplayer_authority(), e.drain)
	if e.get("dmg", 0) > 0:
		me.take_hit(e.dmg)


## Can kazanma; başka makineler (can emme) sahibine bildirir.
@rpc("any_peer", "call_local", "reliable")
func gain(n: int) -> void:
	if is_multiplayer_authority() and hp > 0 and hp < max_hp:
		set_hp.rpc(mini(hp + n, max_hp))


## Kafa üstünde 2 sn replik balonu (herkes görür).
@rpc("any_peer", "call_local", "reliable")
func say(text: String) -> void:
	if quote_lbl == null:
		quote_lbl = Label3D.new()
		quote_lbl.position.y = 2.6
		quote_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		quote_lbl.pixel_size = 0.007
		quote_lbl.font_size = 40
		quote_lbl.outline_size = 14
		quote_lbl.modulate = Color(1.0, 0.95, 0.6)
		add_child(quote_lbl)
	quote_lbl.text = text
	quote_lbl.visible = true
	quote_t = 2.0


func _local_player() -> Node:
	return get_parent().get_node_or_null(str(multiplayer.get_unique_id()))


## Yere yatık halka efekti: fade sürede genişleyip söner ve silinir.
func _ring_fx(pos: Vector3, c: Color, r: float, fade: float) -> void:
	var t := TorusMesh.new()
	t.inner_radius = 0.92; t.outer_radius = 1.0
	var mi := _mesh(_world(), t, pos, c)
	_bar_mat(mi)
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * r, fade).from(Vector3.ONE * 0.2)
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, fade + 0.15)
	tw.chain().tween_callback(mi.queue_free)


## İki nokta arasında kısa süre görünen ışın (kurşun, kement, iğne).
func _beam_fx(from: Vector3, to: Vector3, c: Color) -> void:
	var d := to - from
	if d.length() < 0.1:
		return
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035; cyl.bottom_radius = 0.035; cyl.height = d.length()
	var mi := _mesh(_world(), cyl, (from + to) * 0.5, c)
	_bar_mat(mi)
	mi.basis = Basis(Quaternion(Vector3.UP, d.normalized()))
	var tw := mi.create_tween()
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(mi.queue_free)


func boom_fx(pos: Vector3, k: float) -> void:
	var fx: Node3D = ExplosionScript.new()
	fx.position = pos
	fx.scale = Vector3.ONE * k
	_world().add_child(fx)
	Sfx.play3d(Sfx.boom, pos, 4.0)


func _try_shield() -> void:
	if not shield_on and shield_cd <= 0.0:
		shield_cd = ch.get("shield_cd", 8.0)
		set_shield.rpc(true)


@rpc("authority", "call_local", "reliable")
func set_shield(on: bool) -> void:
	if on == shield_on:
		return
	shield_on = on
	var pos := global_position + Vector3.UP
	Sfx.play3d(Sfx.shield_up if on else Sfx.shield_break, pos, 0.0)


func _remote(dt: float) -> void:
	var k: float = min(1.0, dt * 18.0)
	if global_position.distance_to(net_pos) > 6.0:
		global_position = net_pos # ışınlanma (respawn, yer değiştirme)
	else:
		global_position = global_position.lerp(net_pos, k)
	rotation.y = lerp_angle(rotation.y, net_yaw, k)
	look.rotation.x = lerp(look.rotation.x, net_pitch, k)


func _animate(dt: float) -> void:
	var mine := is_multiplayer_authority()
	var spd: float = Vector2(velocity.x, velocity.z).length() if mine else net_speed
	var air: bool = not is_on_floor() if mine else net_air
	var want := "Idle"
	if hp <= 0:
		want = "Death"
	elif air:
		want = "Jump"
	elif spd > 0.5:
		want = "Run" if anim.has_animation("Run") else "Walk"
	if want != cur_anim:
		cur_anim = want
		anim.play(want, 0.15)
	anim.speed_scale = clampf(spd / SPEED, 0.7, 1.7) if want == "Run" or want == "Walk" else 1.0

	for k in buffs.keys(): # süreli etkiler
		buffs[k][1] -= dt
		if buffs[k][1] <= 0.0:
			buffs.erase(k)
	var hidden := bt("invis") > 0.0 and not mine and hp > 0 # görünmezlik: yalnızca başkalarına
	vis.visible = not hidden
	size_k = lerpf(size_k, bv("size"), 0.15)
	vis.scale = Vector3.ONE * size_k
	gun.visible = hp > 0 and slot == 1
	sword.visible = hp > 0 and slot == 4
	shield_mesh.visible = shield_on and not hidden
	flash = max(flash - dt, 0.0)
	if flash > 0.0:
		model_fx.albedo_color = Color(1, 0.1, 0.1, flash / 0.35 * 0.6)
	elif buffs.has("armor") and bv("armor") < 1.0:
		model_fx.albedo_color = Color(1.0, 0.85, 0.3, 0.35) # zırhlı
	elif bt("power") > 0.0:
		model_fx.albedo_color = Color(1.0, 0.45, 0.1, 0.3) # güçlü
	else:
		model_fx.albedo_color.a = 0.0

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
		name_lbl.visible = not hidden
		var f := clampf(float(hp) / max_hp, 0.0, 1.0)
		hp_fill.scale.x = maxf(f, 0.001)
		hp_fill.position.x = -0.4 * (1.0 - f) # sola yaslı
		(hp_fill.material_override as StandardMaterial3D).albedo_color = Color(0.95, 0.2, 0.15).lerp(Color(0.3, 0.9, 0.3), f)
		hp_bar.visible = hp > 0 and not hidden
		var c := get_viewport().get_camera_3d()
		if c:
			hp_bar.global_basis = c.global_basis # kameraya dön
	if quote_lbl and quote_lbl.visible:
		quote_t -= dt
		quote_lbl.visible = quote_t > 0.0


@rpc("authority", "call_local", "reliable")
func fire_rocket(origin: Vector3, dir: Vector3, n: int, big: bool) -> void:
	var r: Node3D = RocketScript.new()
	r.name = "%s%d_%d" % ["B" if big else "R", get_multiplayer_authority(), n] # B: gülle
	r.shooter = self
	r.dir = dir
	r.big = big
	r.position = origin
	_world().add_child(r)
	Sfx.play3d(Sfx.fire, origin, -2.0)


## Atanın makinesi çarpışmayı bulunca herkese yayınlar.
@rpc("authority", "call_local", "reliable")
func explode(rocket_name, pos: Vector3) -> void:
	var r := _world().get_node_or_null(NodePath(str(rocket_name)))
	if r:
		r.queue_free()
	var big := str(rocket_name).begins_with("B")
	boom_fx(pos, 1.8 if big else 1.0)
	if big:
		apply_blast(pos, BIG_RADIUS, BIG_DMG)
	else:
		apply_blast(pos, BLAST_RADIUS, int(bv("power", ch.get("rocket_dmg", DAMAGE))))


## Kılıç savurma: herkes animasyonu görür, her makine kendi oyuncusu vurulduysa hasarı uygular.
@rpc("authority", "call_local", "reliable")
func swing(from: Vector3, fwd: Vector3) -> void:
	swing_t = 0.25
	Sfx.play3d(Sfx.whoosh, from + Vector3.UP * 1.5, 0.0)
	var me := _local_player()
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
		me.take_hit(ch.get("sword_dmg", SWORD_DMG))


## Hasarı her makine yalnızca kendi oyuncusu için uygular (atan hariç).
func apply_blast(pos: Vector3, radius: float, dmg := DAMAGE) -> void:
	var me := _local_player()
	if me == null or me == self or me.hp <= 0:
		return
	var c: Vector3 = me.global_position + Vector3(0, 0.95, 0)
	if c.distance_to(pos) < radius:
		me.velocity += (c - pos).normalized() * 7.0 + Vector3.UP * 3.0 # sarsıntı / itme
		if me.shield_on:
			me.set_shield.rpc(false) # kalkan tek roketi emer
		else:
			me.take_hit(dmg)


## Hasar kurbanın kendi makinesinde uygulanır. sure: sıyrılma şansı yok (yanma).
func take_hit(dmg := DAMAGE, sure := false) -> void:
	if not sure and randf() < ch.get("dodge", 0.0):
		say.rpc("Iska!")
		return
	dmg = roundi(dmg * bv("armor") * bv("vuln"))
	if dmg <= 0:
		return # hasar almıyor (Demir Kafa)
	set_hp.rpc(hp - dmg)
	if hp <= 0:
		get_node("/root/Main").report_death.rpc_id(1, get_multiplayer_authority())


@rpc("authority", "call_local", "reliable")
func set_hp(v: int) -> void:
	if v < hp:
		flash = 0.35
		if is_multiplayer_authority():
			Sfx.play2d(Sfx.hurt)
		else:
			Sfx.play3d(Sfx.hurt, global_position + Vector3.UP)
	hp = max(v, 0)


func respawn() -> void:
	hp = max_hp
	skill_cd = 0.0
	buffs.clear()
	land_wait = -1.0
	still_t = 0.0
	shield_on = false
	shield_cd = 0.0
	dash_cd = 0.0
	wall_cd = 0.0
	sword_cd = 0.0
	velocity = Vector3.ZERO
	global_position = spawn_pos
	net_pos = spawn_pos
	dead_t = 0.0
	spec_target = null
	if cam:
		cam.current = true # izlemeden kendi gözüne dön
