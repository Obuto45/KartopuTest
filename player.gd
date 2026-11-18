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
const Weapons := preload("res://weapons.gd")
const WeaponAnims := preload("res://weapon_anims.gd")
const Profile := preload("res://profile.gd")
const Ragdoll := preload("res://ragdoll.gd")
const BUILD_DIST := 3.0 # TD: yapı önizlemesi önümüzde bu mesafede
const SIT_TIME := 2.0 # sit_shield pasifi: bu kadar durunca kalkan alır
const SPEED := 7.0
const ACCEL := 60.0 # yerde hızlanma (m/s²)
const FRICTION := 45.0 # yerde tuş yokken yavaşlama
const AIR_ACCEL := 16.0 # havada kontrol (momentum korunur)
const JUMP := 8.5 # ~1.4 m zıplama
const AIR_JUMP := 7.5 # çift zıplama
const COYOTE := 0.1 # kenardan düştükten sonra yerden zıplama payı (sn)
const JUMP_BUFFER := 0.12 # inişten önce basılan zıplama bu kadar beklenir (sn)
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
# Hareket hissi (yalnızca görsel, ağa gitmez)
const LEAN_MAX := 0.35 # gövdenin en çok yatışı (radyan)
const TWIST_MAX := 0.8 # yan koşuda gövdenin hareket yönüne dönüşü
const SQ_K := 220.0 # ez-uzat yayının sertliği
const SQ_DAMP := 16.0
const SWING_T := 0.3 # kılıç savurma süresi
const FOV := 80.0
const FOV_DASH := 9.0 # dash hızında eklenen görüş açısı
const SHAKE_R := 25.0 # patlama bu mesafeden uzaktaysa kamera sarsılmaz
const SHAKE_ANG := 0.015 # sarsıntı 1 iken kamera açısı (radyan)


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
var b_larm := -1
var b_lfore := -1
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
var coyote := 0.0
var hit_ms := -10000 # son isabetin zamanı (isabet işareti)
var hit_kill := false
var jump_buf := 0.0
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

# Hareket hissi durumu
var last_pos := Vector3.ZERO
var last_yaw := 0.0
var last_pitch := 0.0
var last_vy := 0.0
var was_air := false
var pose_vel := Vector3.ZERO # yumuşatılmış hız (uzaktakinde konum farkından)
var slow_vel := Vector3.ZERO # daha ağır yumuşatılmış: farkı ivmeyi verir
var lean := Vector2.ZERO # x: öne/arkaya, y: yana yatış
var twist := 0.0 # gövdenin hareket yönüne dönüşü
var back := false # geri geri yürüyor: koşu animasyonu tersten
var sq := 0.0 # ez-uzat yayı: + uzar, - ezilir
var sq_v := 0.0
var flinch := 0.0 # vurulunca geriye savrulma
var rag: PhysicalBoneSimulator3D # ölüyken ragdoll (ragdoll.gd)
var rag_off := false # ragdoll kapalı (kalite / sınır): ölüm animasyonu oynar
var kick := 0.0 # bazuka geri tepmesi
var sway := Vector2.ZERO # silahın bakışın gerisinde kalması
var bob_t := 0.0
var bob_k := 0.0
var shake_k := 0.0 # kamera sarsıntısı
var gun_p := Vector3.ZERO # silahların dinlenme konumu
var sword_p := Vector3.ZERO
var dust: CPUParticles3D # koşarken ayak tozu
# Tower Defense: yalnızca "td" grubunda düğüm varken dolar; arenada hepsi boş kalır (st() 1 döner).
var td: Node
var stats := {} # stat id -> değer (weapons.gd STATS)
var level := 1
var inv: Array = [{}, {}, {}, {}, {}] # 1–3 silah/ekipman, 4–5 yapı/eşya
var bag: Array = Weapons.empty_bag() # çanta: el slotu doluyken öğeler buraya düşer (E ile açılır)
var ups := {} # yükseltme seviyeleri: "<silah>:<id>" ve "char:<id>"
var cards: Array = [] # seçim bekleyen kartlar
var pending := 0 # kartı seçilmemiş seviye sayısı
var banished: Array = [] # bu maçta elenen kart grupları (bir daha çıkmaz)
var respawn_t := 0.0
var burns := {} # yaratık adı -> [yaratık, hasar/sn, kalan sn, etki sözlüğü (evrim alanları), son konum]
var _last_crit := false # son td_dmg kritik miydi (evrim: kritik zinciri)
var hand: Node3D # koddan üretilen silah modellerinin tutucusu
var vm: Node3D # kendi gözünden eller + silah (yalnız yerel oyuncuda; viewmodel.gd)
var held_id := "" # çıkarılmış silah; _held() değişince _switched
var busy := "" # ateşi kilitleyen animasyon: draw, reload, drink, prime, charge ("" = serbest)
var reloading := false
var reload_t := 0.0 # doldurmanın kalan süresi (HUD çubuğu)
var anim_gen := 0 # vm'siz oyuncuda zamanlanmış klip olaylarını geçersiz kılar
var flame_t := 0.0 # alev pilotu büyük kalsın
var fuse_left := 0.0 # pimi çekilmiş bombanın kalan sigortası
var pinned := false
var throw_q := false # pim çekilmeden bırakıldı: pim gelince at
var prime_id := "" # "grenade" ya da "item:bomb"
var draw_k := 0.0 # yay gerginliği 0..1
var scoped := false # keskin nişancı dürbünü (sağ tık)
var scope_block := false # atıştan sonra sürgü çekilene (chamber) dek dürbün kapalı
var thrown := 0 # havadaki bumerang
var combo := 0 # kılıç serisi: 0, 1, 2 (üçüncü güçlü)
var combo_t := 0.0
var swing_k := 0.0 # bekleyen kılıç vuruşunun gücü ("fired" olayında vurur)
const SCOPE_FOV := 20.0
var hand_p := Vector3.ZERO
var props := {} # silah id -> model
var hold: Node3D # elde görünen silah: sağ kol ona uzanır
var ghost: MeshInstance3D # yapı önizlemesi
var puff: CPUParticles3D # zıplama / iniş bulutu


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


## Stat değeri; arenada (stats boş) etkisiz varsayılan.
func st(k: String, d := 1.0) -> float:
	return stats.get(k, d)


func _ready() -> void:
	add_to_group("players")
	position = spawn_pos
	net_pos = spawn_pos
	last_pos = spawn_pos

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
	gun = _prop("res://models/bazooka.glb", 0.95, Vector3.ZERO, Vector3(0.5, 0.5, 0.5))
	gun.position = Vector3(0.3, -0.33, -0.5)
	sword = _prop("res://models/sword.glb", 1.05, Vector3.ZERO, Vector3(0.5, 0.5, 0.87)) # kabzadan tut
	sword.position = Vector3(0.34, -0.36, -0.4)
	sword.rotation = Vector3(0.9, 0.2, 0) # dinlenme: ucu yukarıda, hafif içe dönük
	sword.visible = false

	if is_multiplayer_authority():
		cam = Camera3D.new()
		cam.fov = FOV
		cam.near = 0.05
		look.add_child(cam)
		cam.current = true
		cam.cull_mask &= ~2 # katman 2 viewmodel'in, onu kendi görüntü alanı çizer
		vm = preload("res://viewmodel.gd").new()
		add_child(vm)
		vm.setup(ch.color, "res://models/chars/%s.glb" % ch.model)
		vm.event.connect(_on_vm_event)
		# Kendi gözünden: silahlar küçük ve uzakta, ekranın sağ altında dursun.
		gun.scale = Vector3.ONE * 0.45
		gun.position = Vector3(0.27, -0.26, -0.7)
		sword.scale = Vector3.ONE * 0.6
		sword.position = Vector3(0.3, -0.33, -0.5)
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY # kendini görme, gölgen kalsın
		for mi in gun.find_children("*", "MeshInstance3D", true, false) + sword.find_children("*", "MeshInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		var col: Color = ch.color
		name_lbl = Label3D.new()
		name_lbl.position.y = 2.9 # vis'e değil gövdeye bağlı: ölünce devrilmez
		name_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_lbl.pixel_size = 0.006 # dünya ölçeğinde: uzaklaştıkça oyuncuyla birlikte küçülür
		name_lbl.font_size = 36
		name_lbl.outline_size = 12
		name_lbl.modulate = col.lightened(0.35)
		name_lbl.text = Net.display_name(get_multiplayer_authority())
		add_child(name_lbl)
		# Can barı: ismin altında, her karede kameraya döner.
		hp_bar = Node3D.new()
		hp_bar.position.y = 2.72
		add_child(hp_bar)
		var bg := QuadMesh.new()
		bg.size = Vector2(0.84, 0.11)
		_bar_mat(_mesh(hp_bar, bg, Vector3.ZERO, Color(0, 0, 0, 0.6)))
		var fg := QuadMesh.new()
		fg.size = Vector2(0.8, 0.07)
		hp_fill = _mesh(hp_bar, fg, Vector3(0, 0, 0.005), Color(0.3, 0.9, 0.3))
		_bar_mat(hp_fill)

	gun_p = gun.position
	sword_p = sword.position
	dust = _dust(8, false)
	puff = _dust(14, true)

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


## Ayak dibinde toz: burst ise tek seferlik bulut, değilse koşarken sürekli. Parçacıklar dünyada kalır.
func _dust(n: int, burst: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position.y = 0.08
	p.amount = n
	p.lifetime = 0.5
	p.one_shot = burst
	p.explosiveness = 1.0 if burst else 0.0
	p.emitting = false
	p.direction = Vector3.UP
	p.spread = 85.0 if burst else 40.0
	p.initial_velocity_min = 0.8 if burst else 0.3
	p.initial_velocity_max = 2.2 if burst else 0.9
	p.gravity = Vector3(0, -1.5, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var g := Gradient.new()
	g.set_color(0, Color(0.9, 0.87, 0.8, 0.55))
	g.set_color(1, Color(0.9, 0.87, 0.8, 0.0))
	p.color_ramp = g
	var m := SphereMesh.new()
	m.radius = 0.09; m.height = 0.18; m.radial_segments = 6; m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	m.material = mat
	p.mesh = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


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
	var outline := ShaderMaterial.new() # koyu dış çizgi: karakter ormandan ayrışsın
	outline.shader = preload("res://shaders/outline.gdshader")
	model_fx.next_pass = outline
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = model_fx
	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	for n in ["Idle", "Run", "Walk"]: # dosyada döngü işareti yok
		if anim.has_animation(n):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	b_arm = skel.find_bone("UpperArm.R")
	b_fore = skel.find_bone("LowerArm.R")
	b_larm = skel.find_bone("UpperArm.L")
	b_lfore = skel.find_bone("LowerArm.L")
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
		h.basis = Basis(Vector3.UP, -twist) * Basis(Vector3.RIGHT, -look.rotation.x * 0.6) * h.basis # gövde yana dönse de kafa bakışta
		s.set_bone_global_pose(b_head, h)
	if hold and b_arm >= 0 and b_fore >= 0:
		var grip: Vector3 = s.global_transform.affine_inverse() * hold.global_position
		_aim_bone(s, b_arm, (grip - s.get_bone_global_pose(b_arm).origin).normalized() + Vector3.DOWN * 0.45)
		_aim_bone(s, b_fore, grip - s.get_bone_global_pose(b_fore).origin)
	var gl := hold.find_child("grip_l", true, false) as Node3D if hold and b_larm >= 0 and b_lfore >= 0 and _held() not in WeaponAnims.ONE_HAND else null
	if gl: # iki elli silah: sol el önden destekler
		var g2: Vector3 = s.global_transform.affine_inverse() * gl.global_position
		_aim_bone(s, b_larm, (g2 - s.get_bone_global_pose(b_larm).origin).normalized() + Vector3.DOWN * 0.45)
		_aim_bone(s, b_lfore, g2 - s.get_bone_global_pose(b_lfore).origin)


func _aim_bone(s: Skeleton3D, i: int, dir: Vector3) -> void:
	var g := s.get_bone_global_pose(i)
	g.basis = Basis(Quaternion(g.basis.y.normalized(), dir.normalized())) * g.basis
	s.set_bone_global_pose(i, g)


func _speed() -> float:
	return SPEED * ch.get("speed", 1.0) * bv("haste") * bv("slow") * st("speed") * (0.8 if busy == "charge" else 1.0) * (0.65 if scoped else 1.0)


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
	if td == null: # TD düğümü oyunculardan sonra eklenir
		td = get_tree().get_first_node_in_group("td")
		if td:
			_td_init()
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
		coyote = COYOTE
	else:
		coyote -= dt
	jump_buf -= dt
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
			jump_buf = JUMP_BUFFER
		if jump_buf > 0.0:
			if on_floor or coyote > 0.0: # kenardan yeni düştüysen ya da inişten hemen önce bastıysan da yerden zıplar
				velocity.y = JUMP * ch.get("jump", 1.0) * st("jump")
				jump_buf = 0.0
				coyote = 0.0
			elif Input.is_action_just_pressed("jump") and air_jumps > 0: # çift zıplama
				jump_buf = 0.0
				air_jumps -= 1
				velocity.y = AIR_JUMP * ch.get("jump", 1.0) * st("jump")
		if Input.is_action_just_pressed("dash") and dash_cd <= 0.0: # yerde ve havada
			var d := dir if dir != Vector3.ZERO else -transform.basis.z
			velocity = d * DASH_SPEED
			dash_t = DASH_TIME
			dash_cd = DASH_CD
			Sfx.play2d(Sfx.whoosh, -2.0)
		for s in [1, 2, 3, 4, 5] if td else [1, 2, 3, 4]:
			if td:
				# kart açıkken 1/2/3 kartı seçer, slotu değiştirmez
				if InputMap.has_action("slot%d" % s) and Input.is_action_just_pressed("slot%d" % s) and (cards.is_empty() or td.state != "break"):
					slot = s
			elif Input.is_action_just_pressed("slot%d" % s):
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

	if td:
		_td_local(dt, can_act, alive)
	elif can_act and Input.is_action_just_pressed("throw"):
		if slot == 2:
			_try_shield()
		elif slot == 3 and wall_cd <= 0.0:
			wall_cd = ch.get("wall_cd", WALL_CD)
			spawn_wall.rpc(_ground(global_position - transform.basis.z * WALL_DIST), rotation.y, 0)
		elif slot == 4 and sword_cd <= 0.0:
			sword_cd = SWORD_CD
			swing.rpc(global_position, -transform.basis.z)
			_anim("swing%d" % (combo + 1)) # Arena: aynı seri, hasar SWORD_DMG ile
			combo = (combo + 1) % 3
			combo_t = 0.6
	if td == null and can_act and slot == 1 and Input.is_action_pressed("throw") and cd <= 0.0:
		cd = THROW_CD * ch.get("fire_cd", 1.0) * bv("rapid")
		_shoot(int(bv("multi")), 0.07, false)
		_anim("fire")

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
		regen_acc += ch.get("regen", 0.0) + bv("regen", 0.0) + ups.get("char:regen", 0)
		if regen_acc >= 1.0:
			gain(int(regen_acc))
			regen_acc -= int(regen_acc)
		if bt("burn") > 0.0:
			take_hit(int(bv("burn")), true)
		for k in burns.keys(): # TD: yaktığımız yaratıklar
			var b: Array = burns[k]
			b[2] -= 1.0
			var dead: bool = not is_instance_valid(b[0]) or b[0].hp <= 0
			if dead or b[2] < 0.0:
				burns.erase(k)
				if dead and b[3].has("death_blast"): # evrim (Avcı Yayı): yanarken ölen patlar
					_evo_boom(b[4], b[3].death_blast[0], {"dmg": b[3].dmg * b[3].death_blast[1]})
			else:
				b[4] = b[0].global_position
				if b[3].get("ignite", 0.0) > 0.0: # evrim (Ejderha Nefesi): yanık komşuya geçer
					for e in Weapons.alive(get_tree()):
						if not burns.has(e.name) and Weapons.dist(e, b[4]) < b[3].ignite:
							burns[e.name] = [e, b[1], b[2], b[3], e.global_position]
				td_dmg(b[0], b[1], false)
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
	var b := look.global_basis # cam değil: kamera sarsıntısı nişanı oynatmasın
	var target := cam.global_position - b.z * 200.0
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, target)
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r:
		target = r.position
	var origin := gun.global_position - b.z * 0.45 * gun.scale.x # bazukanın namlusu
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
	var to := from - look.global_basis.z * max_d
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return r.position if r else _ground(to)


## Karar yerel makinede verilir, etkiyi use_skill herkese yayar.
func _use_skill() -> void:
	var target_id := 0
	var best: Node3D = null
	if sk.has("range"):
		best = Weapons.nearest(get_tree(), global_position, sk.range) if td else _nearest(sk.range)
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
	skill_cd = ch.cd * pow(0.85, ups.get("char:cd", 0))
	if td: # hedef yaratık: adıyla gider
		td_skill.rpc(global_position, aim, -transform.basis.z, str(best.name) if best else "")
	else:
		use_skill.rpc(global_position, aim, -transform.basis.z, target_id)


@rpc("authority", "call_local", "reliable")
func use_skill(pos: Vector3, aim: Vector3, fwd: Vector3, target_id: int) -> void:
	_skill(pos, aim, fwd, get_parent().get_node_or_null(str(target_id)) if target_id != 0 else null)


@rpc("authority", "call_local", "reliable")
func td_skill(pos: Vector3, aim: Vector3, fwd: Vector3, enemy: String) -> void:
	var t: Node3D = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if str(e.name) == enemy:
			t = e
	_skill(pos, aim, fwd, t)


func _skill(pos: Vector3, aim: Vector3, fwd: Vector3, target: Node3D) -> void:
	say(ch.quote)
	Sfx.play3d(Sfx.whoosh, pos + Vector3.UP, 2.0)
	var s: Dictionary = sk.get("self", {})
	for k in TIMED:
		if s.has(k):
			buffs[k] = s[k].duplicate()
			buffs[k][1] *= 1.0 + 0.3 * ups.get("char:dur", 0)
	for k in ["invis", "float"]:
		if s.has(k):
			buffs[k] = [1.0, s[k]]
	if not s.is_empty():
		_ring_fx(pos + Vector3.UP * 0.2, Color(ch.color, 0.85), 1.6, 0.4)
	if is_multiplayer_authority():
		_self_skill(s, fwd, target)
	if target and sk.has("swap") and target.is_multiplayer_authority(): # kurban benim yerime gelir
		target.global_position = pos
		target.velocity = Vector3.ZERO
	if target and sk.has("homing"):
		var h: Node3D = HomingScript.new()
		h.thrower = self
		h.h = sk.homing
		if td: # yaratığı kovalar; yükseltmeler hasara ve sekmeye eklenir
			h.td = true
			h.h = sk.homing.duplicate()
			h.h["dmg"] = h.h.get("dmg", 0) * _sk_k()
			h.h["bounces"] = h.h.get("bounces", 0) + ups.get("char:bounces", 0)
		h.target = target
		h.dir = (-look.global_basis.z + Vector3.UP * 0.4).normalized() # önce havaya kalkar
		h.position = look.global_position + h.dir * 0.6
		_world().add_child(h)
	if sk.has("area") and not sk.area.get("land", false):
		_area(sk.area, aim if sk.area.get("at", "") == "aim" else pos, fwd)


## Yeteneğin atanı etkileyen kısmı; yalnızca atanın kendi makinesinde çalışır.
func _self_skill(s: Dictionary, fwd: Vector3, target: Node3D) -> void:
	var flat := Vector3(fwd.x, 0, fwd.z).normalized()
	var heal: int = roundi((s.get("heal", 0) + int((max_hp - hp) * s.get("heal_missing", 0.0))) * _sk_k())
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
	if td: # yükseltmeler alanı ve hasarı büyütür
		a = a.duplicate()
		a.r *= 1.0 + 0.2 * ups.get("char:radius", 0)
		for k in ["dmg", "drain"]:
			if a.has(k):
				a[k] = roundi(a[k] * _sk_k())
		if a.erase("mine"): # shortcut: zone.gd kapanı yalnızca oyuncular tetikler; TD'de 1 sn gecikmeli patlama olur
			a["delay"] = 1.0
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
	if td: # dost ateşi yok: etki yaratıklara, atanın makinesinde
		if is_multiplayer_authority():
			for e in Weapons.alive(get_tree()):
				var et: Vector3 = e.global_position - at
				et.y = 0.0
				if Weapons.dist(e, at) <= a.r and not (a.has("cone") and et.length() > 0.3 and dir.dot(et.normalized()) < a.cone):
					td_affect(e, a, at)
		return
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
		quote_lbl.position.y = 3.2
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
	cyl.top_radius = 0.035; cyl.bottom_radius = 0.008; cyl.height = d.length() # namlu ucunda ince: kameraya yakın kalın görünmesin
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
	if hp <= 0 and rag == null and not rag_off: # ölünce fizikle yığıl (Düşük kalitede ölüm animasyonu)
		rag = Ragdoll.start(model, velocity * 0.4 + global_basis.z * 1.5)
		rag_off = rag == null
	elif hp > 0 and (rag or rag_off):
		Ragdoll.stop(rag)
		rag = null
		rag_off = false
	var want := "Idle"
	if hp <= 0:
		want = "Death"
	elif air:
		want = "Jump"
	elif spd > 0.5:
		want = "Run" if anim.has_animation("Run") else "Walk"
	if want != cur_anim:
		# Geçişe göre karışım: zıplama çabuk, koş-dur yumuşak, ölümden kalkış anında.
		anim.play(want, 0.0 if cur_anim == "Death" else 0.1 if want == "Jump" or cur_anim == "Jump" else 0.22)
		cur_anim = want
	# Adım hızı gerçek hıza ve boya uysun (ayak kaymasın); geri geri giderken tersten oynar.
	var run_k := clampf(spd / (SPEED * size_k) * (1.5 if want == "Walk" else 1.0), 0.5, 2.2) * (-1.0 if back else 1.0)
	anim.speed_scale = run_k if want == "Run" or want == "Walk" else 1.0

	for k in buffs.keys(): # süreli etkiler
		buffs[k][1] -= dt
		if buffs[k][1] <= 0.0:
			buffs.erase(k)
	var hidden := bt("invis") > 0.0 and not mine and hp > 0 # görünmezlik: yalnızca başkalarına
	vis.visible = not hidden
	size_k = lerpf(size_k, bv("size"), 0.15)
	vis.scale = Vector3.ONE * size_k
	combo_t -= dt
	if combo_t <= 0.0:
		combo = 0 # seri 0.6 sn'de bozulur
	var held := _held() if hp > 0 else ""
	gun.visible = held == "bazooka"
	sword.visible = held == "sword"
	hold = gun if gun.visible else sword if sword.visible else null
	if td: # diğer silahlar: koddan model, ilk gerektiğinde üretilir
		for k in props: # bumerang havadayken elde görünmez
			props[k].visible = k == held and not (k == "boomerang" and thrown > 0)
		if held != "" and hold == null:
			if not props.has(held):
				props[held] = Weapons.make_prop({"id": WeaponAnims.model_id(held)})
				var ap := AnimationPlayer.new() # td_anim parça kliplerini oynatır
				ap.name = "AnimationPlayer"
				props[held].add_child(ap)
				ap.root_node = NodePath("..")
				ap.add_animation_library("", AnimationLibrary.new())
				hand.add_child(props[held])
			hold = props[held]
	if vm: # kendi gözünde 3. şahıs silahı yerine viewmodel (kol IK'sı gölge için hold'u yine kullanır)
		gun.visible = false
		sword.visible = false
		for k in props:
			props[k].visible = false
	_sync_held()
	shield_mesh.visible = shield_on and not hidden
	flash = max(flash - dt, 0.0)
	if flash > 0.0:
		model_fx.albedo_color = Color(1, 0.1, 0.1, flash / 0.35 * 0.6)
	elif buffs.has("armor") and bv("armor") < 1.0:
		model_fx.albedo_color = Color(1.0, 0.85, 0.3, 0.15 + 0.08 * sin(Time.get_ticks_msec() * 0.01)) # zırhlı: hafif nabız
	elif bt("power") > 0.0:
		model_fx.albedo_color = Color(1.0, 0.45, 0.1, 0.15 + 0.08 * sin(Time.get_ticks_msec() * 0.01)) # güçlü
	else:
		model_fx.albedo_color.a = 0.0

	if swing_t > 0.0: # sağdan sola yatay savurma
		swing_t = maxf(swing_t - dt, 0.0)
		var k := 1.0 - swing_t / SWING_T
		# Ağırlık: önce geriye gerilir, hızla keser, sonunda bekler.
		var e := smoothstep(0.2, 0.7, k) - sin(minf(k / 0.2, 1.0) * PI) * 0.12
		sword.rotation = Vector3(0.25, lerpf(1.3, -1.2, e), -0.5 - e * 0.3)
	else:
		sword.rotation = sword.rotation.lerp(Vector3(0.9, 0.2, 0), 0.2)
	_feel(dt, mine, spd, air, hidden)
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


## Hareket hissi: gövde yatışı, ez-uzat, toz, silah salınımı, kamera. Hepsi görsel; nişanı (look) ellemez.
func _feel(dt: float, mine: bool, spd: float, air: bool, hidden: bool) -> void:
	# Uzaktakinin yönlü hızı ağdan gelmez: yumuşatılmış konum farkından çıkar.
	var v := velocity if mine else ((global_position - last_pos) / dt).limit_length(25.0)
	last_pos = global_position
	pose_vel = pose_vel.lerp(v, minf(1.0, dt * 10.0))
	slow_vel = slow_vel.lerp(v, minf(1.0, dt * 3.0))
	var inv := transform.basis.inverse()
	var lv := inv * pose_vel
	var acc := inv * (pose_vel - slow_vel)
	var hs := Vector2(lv.x, lv.z).length()
	var yr := angle_difference(last_yaw, rotation.y) / dt
	last_yaw = rotation.y

	# Gövde hareket yönüne döner; arkaya gidiyorsa yüzü önde kalır, koşu tersten oynar.
	var ang := atan2(-lv.x, -lv.z) if hs > 1.0 and hp > 0 else 0.0
	back = absf(ang) > 2.0
	if back:
		ang -= signf(ang) * PI
	twist = lerp_angle(twist, clampf(ang, -TWIST_MAX, TWIST_MAX), minf(1.0, dt * 10.0))
	flinch = maxf(flinch - dt * 4.0, 0.0)
	var tgt := Vector2(lv.z * 0.012 + acc.z * 0.03 + flinch * 0.25, -lv.x * 0.012 - acc.x * 0.03 + clampf(yr * 0.03, -0.12, 0.12) * minf(hs / SPEED, 1.0))
	lean = lean.lerp(tgt.limit_length(LEAN_MAX) if hp > 0 else Vector2.ZERO, minf(1.0, dt * 8.0))

	# Ez-uzat: zıplayınca uzar, inince ezilir. Yerelde dikey hız sıçramasından, uzaktakinde net_air'den.
	var vy := velocity.y if mine else pose_vel.y
	var seen := hp > 0 and not hidden # görünmezi toz ele vermesin
	if was_air and not air and last_vy < -3.0:
		sq_v -= clampf(-last_vy * 0.35, 1.5, 5.0)
		if seen:
			puff.restart()
	elif (vy > last_vy + 3.0 and vy > 2.0) if mine else (air and not was_air):
		sq_v += 3.5
		if seen and not was_air:
			puff.restart()
	was_air = air
	last_vy = vy
	sq_v += (-sq * SQ_K - sq_v * SQ_DAMP) * dt
	sq = clampf(sq + sq_v * dt, -0.3, 0.3)
	var st := (sq + clampf((hs - 12.0) * 0.02, 0.0, 0.16)) if hp > 0 else 0.0 # dash: boyuna uzar
	# vis'e değil modele: vis.scale size_k'nın, ayrıca kamera/silah vis'in altında (nişan oynamasın).
	model.basis = Basis(Vector3.RIGHT, lean.x) * Basis(Vector3.BACK, lean.y) * Basis(Vector3.UP, PI + twist) * Basis.from_scale(Vector3(1.0 - st * 0.5, 1.0 + st, 1.0 - st * 0.5) * MODEL_SCALE)
	dust.emitting = seen and not mine and ((not air and spd > 4.0) or hs > 12.0)

	# Silah: geri tepme herkeste; salınım, adım sallantısı ve iniş çöküşü yalnızca kendi gözünde.
	kick = lerpf(kick, 0.0, minf(1.0, dt * 9.0))
	var off := Vector3(0, 0, kick * 0.09)
	var tilt := Vector3(kick * 0.16, 0, 0)
	if mine:
		sway = sway.lerp(Vector2(yr, (look.rotation.x - last_pitch) / dt).limit_length(6.0) * 0.012, minf(1.0, dt * 10.0))
		last_pitch = look.rotation.x
		bob_k = lerpf(bob_k, 0.0 if air or hp <= 0 else minf(spd / SPEED, 1.3), minf(1.0, dt * 8.0))
		bob_t += dt * spd * 1.4
		var t := Time.get_ticks_msec() * 0.001
		off += Vector3(sway.x * 0.3 + cos(bob_t) * 0.01 * bob_k, -sway.y * 0.3 - absf(sin(bob_t)) * 0.012 * bob_k + sin(t * 1.8) * 0.003 + sq * 0.2, 0)
		tilt += Vector3(-sway.y + sq * 0.3, -sway.x, -sway.x * 0.5)
		# Kamera: sarsıntı ~0,4 sn'de söner, inişte hafif çöker, hızda görüş açısı genişler.
		shake_k *= maxf(1.0 - dt * 7.0, 0.0)
		var n := Vector3(sin(t * 53.0 + 1.0), sin(t * 71.0), sin(t * 61.0 + 2.0)) * shake_k * minf(shake_k, 1.0) * Settings.shake # karesel: küçük sarsıntı hafif, büyüğü sert
		cam.rotation = n * SHAKE_ANG
		cam.v_offset = minf(sq, 0.0) * 0.5
		var fov := SCOPE_FOV if scoped else FOV + clampf((spd - SPEED * 1.3) / (DASH_SPEED - SPEED * 1.3), 0.0, 1.0) * FOV_DASH
		cam.fov = lerpf(cam.fov, fov, minf(1.0, dt * (20.0 if scoped else 8.0)))
		if spec_cam: # yay kolu kameranın yerini kendi yönetir: yalnızca kaydır
			spec_cam.h_offset = n.y * 0.08
			spec_cam.v_offset = n.x * 0.08
	gun.position = gun_p + off
	gun.rotation = tilt
	if hand:
		hand.position = hand_p + off
		hand.rotation = tilt
	if vm:
		vm.sway_offset = off
		vm.sway_tilt = tilt
		flame_t = maxf(flame_t - dt, 0.0)
		var pilot := vm.weapon.find_child("pilot", true, false) as Node3D if vm.weapon and held_id == "flame" else null
		if pilot: # ateşlerken pilot alevi büyür, bırakınca söner
			pilot.scale = pilot.scale.lerp(Vector3.ONE * (1.8 if flame_t > 0.0 else 1.0), minf(1.0, dt * 12.0))
	sword.position = sword_p + off * 0.6 + Vector3(0, 0, -sin((1.0 - swing_t / SWING_T) * PI) * 0.12)


## Patlama kodu çağırır (call_group "players"): yalnızca bu makinenin oyuncusunun kamerası,
## uzaklıkla azalarak sarsılır. İzlerken izleme kamerasının yeri sayılır.
func shake(pos: Vector3, amount: float) -> void:
	if not is_multiplayer_authority():
		return
	var c := spec_cam if spec_cam and spec_cam.current else cam
	shake_k = clampf(amount * (1.0 - c.global_position.distance_to(pos) / SHAKE_R), shake_k, 2.0)


@rpc("authority", "call_local", "reliable")
func fire_rocket(origin: Vector3, dir: Vector3, n: int, big: bool) -> void:
	var r: Node3D = RocketScript.new()
	r.name = "%s%d_%d" % ["B" if big else "R", get_multiplayer_authority(), n] # B: gülle
	r.shooter = self
	r.dir = dir
	r.big = big
	if td: # yetenek roketi: yaratıklara çarpar
		r.w = Weapons.arena_rocket(big)
		r.w.dmg *= _pow(r.w)
	r.position = origin
	_world().add_child(r)
	Sfx.play3d(Sfx.fire, origin, -2.0)
	kick = 1.0
	shake(origin, 0.2)


## Atanın makinesi çarpışmayı bulunca herkese yayınlar.
@rpc("authority", "call_local", "reliable")
func explode(rocket_name, pos: Vector3) -> void:
	var r := _world().get_node_or_null(NodePath(str(rocket_name)))
	if r:
		r.queue_free()
	var big := str(rocket_name).begins_with("B")
	boom_fx(pos, 1.8 if big else 1.0)
	if is_multiplayer_authority(): # arena: patlama alanındaki tavuklar
		for c in get_tree().get_nodes_in_group("chickens"):
			if c.hp > 0 and c.global_position.distance_to(pos) < (BIG_RADIUS if big else BLAST_RADIUS):
				_hunt(c)
	if big:
		apply_blast(pos, BIG_RADIUS, BIG_DMG)
	else:
		apply_blast(pos, BLAST_RADIUS, int(bv("power", ch.get("rocket_dmg", DAMAGE))))


## Kılıç savurma: herkes animasyonu görür, her makine kendi oyuncusu vurulduysa hasarı uygular.
@rpc("authority", "call_local", "reliable")
func swing(from: Vector3, fwd: Vector3) -> void:
	swing_t = SWING_T
	shake(from, 0.15)
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
	if not sure and randf() < ch.get("dodge", 0.0) + 0.04 * ups.get("char:dodge", 0):
		say.rpc("Iska!")
		return
	dmg = roundi(dmg * bv("armor") * bv("vuln") * (1.0 - st("armor", 0.0)))
	if dmg <= 0:
		return # hasar almıyor (Demir Kafa)
	set_hp.rpc(hp - dmg)
	if hp <= 0:
		if td: # TD'de tur bitmez: süre dolunca kule dibinde doğar
			var bal: Script = load("res://balance.gd") if ResourceLoader.exists("res://balance.gd") else null
			respawn_t = bal.get_script_constant_map().get("RESPAWN_TIME", 8.0) if bal else 8.0
		else:
			get_node("/root/Main").report_death.rpc_id(1, get_multiplayer_authority())


@rpc("authority", "call_local", "reliable")
func set_hp(v: int) -> void:
	if v < hp:
		flash = 0.35
		flinch = 1.0
		sq_v -= 2.5
		if v > 0 and model:
			Ragdoll.flinch(model, global_position + Vector3.UP * 1.3, global_basis.z * 3.0)
		shake(global_position, 0.6)
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
	burns.clear()
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


# ---------- Tower Defense: envanter, silahlar, statlar, kartlar (veri ve saf mantık weapons.gd'de) ----------

func _td_init() -> void:
	if stats.is_empty():
		stats = Weapons.base_stats(ch)
		var wid: String = Weapons.get_weapon(Net.weapons.get(get_multiplayer_authority(), 0)).id
		inv[0] = {"kind": "weapon", "id": wid, "count": 1, "lvl": 1, "ammo": Weapons.full_ammo(wid)}
	slot = 1
	hand = Node3D.new()
	look.add_child(hand)
	var mine := is_multiplayer_authority()
	hand.position = Vector3(0.27, -0.24, -0.62) if mine else Vector3(0.3, -0.3, -0.45)
	hand.scale = Vector3.ONE * (0.6 if mine else 1.0)
	hand_p = hand.position


## Elde görünen silahın id'si ("" = yok). Arenada slot 1 bazuka, 4 kılıç.
func _held() -> String:
	if td == null:
		return "bazooka" if slot == 1 else "sword" if slot == 4 else ""
	var it: Dictionary = inv[clampi(slot, 1, 5) - 1]
	if it.get("kind", "") == "item" and it.id in ["potion", "bomb"]:
		return "item:" + it.id # elde şişe / bomba (viewmodel)
	if it.get("kind", "") == "build":
		return "build" # boş eller: yerleştirirken öne itiş
	return it.id if it.get("kind", "") == "weapon" else ""


func _sk_k() -> float:
	return 1.0 + 0.25 * ups.get("char:power", 0)


## Silah hasar çarpanı: mermi gücü statı + karakterin güç yeteneği ve hasar pasifi (arena tabanına oranla).
func _pow(w: Dictionary) -> float:
	var k: float = st("shot_power") * bv("power", Weapons.ARENA_DMG) / Weapons.ARENA_DMG
	return k * (float(ch.get("sword_dmg", SWORD_DMG)) / SWORD_DMG if w.kind == "melee" else float(ch.get("rocket_dmg", DAMAGE)) / DAMAGE)


## Mermilerin içinden geçtiği gövdeler: oyuncular (dost ateşi yok) ve yaratıklar (isabeti geometriyle buluruz).
func td_rids() -> Array:
	var out := _player_rids()
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is CollisionObject3D:
			out.append(e.get_rid())
	return out


## Host'taki TD işlevini çağırır: host'sak doğrudan, değilsek rpc ile.
func _host(m: String, args: Array) -> void:
	if multiplayer.is_server():
		td.callv(m, args)
	else:
		td.callv("rpc_id", [1, m] + args)


func _td_local(dt: float, can_act: bool, alive: bool) -> void:
	reload_t = maxf(reload_t - dt, 0.0)
	if busy == "charge": # yay: 0.6 sn'de tam gerilir
		draw_k = minf(1.0, draw_k + dt * st("attack") / Weapons.tuned("bow", ups).get("charge", 0.6))
	scoped = alive and held_id == "sniper" and busy == "" and not scope_block and InputMap.has_action("aim") and Input.is_action_pressed("aim")
	if vm:
		vm.visible = held_id != "" and not scoped # dürbünde silah ekrandan çekilir
	if pinned: # elde sigorta işler
		fuse_left -= dt
		if fuse_left <= 0.0:
			_cook_out()
	if can_act and InputMap.has_action("reload") and Input.is_action_just_pressed("reload"):
		start_reload()
	if Input.is_action_just_released("throw"):
		_release_throw()
	if can_act and Input.is_action_pressed("throw"):
		_td_use(Input.is_action_just_pressed("throw"))
	_td_ghost(alive)
	if not alive:
		respawn_t -= dt
		if respawn_t <= 0.0:
			td_respawn.rpc()


## Seçili slottakini kullanır (sol tık). just: tuşa bu karede basıldı (tek seferlik işler).
func _td_use(just: bool) -> void:
	var it: Dictionary = inv[slot - 1]
	match it.get("kind", ""):
		"weapon":
			_sync_held()
			var w := Weapons.tuned(it.id, ups)
			var mag := Weapons.mag_of(w)
			if reloading and w.get("per_shell", false) and int(it.get("ammo", 0)) > 0:
				reloading = false # pompalı: ateş doldurmayı keser, takılan fişekler kalır
				busy = ""
				reload_t = 0.0
			if busy != "":
				return
			if mag > 0 and int(it.get("ammo", mag)) <= 0:
				start_reload() # yedek sınırsız: boşken tetik doldurur
				return
			if it.id == "grenade": # bas: pim çek; bırakınca at (_release_throw)
				if just:
					_prime("grenade")
				return
			if it.id == "bow": # bas: ger; bırakınca ok (gerginlik güç ve hızı belirler)
				if just:
					_charge()
				return
			if _can_fire():
				cd = w.rate / st("attack") * ch.get("fire_cd", 1.0) * bv("rapid")
				if w.kind == "melee": # kılıç: 3'lü seri, vuruş klibin "fired" anında
					var c := combo
					combo = (combo + 1) % 3
					combo_t = 0.6
					swing_k = 1.5 if c == 2 else 1.0
					if c == 2:
						cd += 0.35 # seriden sonra toparlanma
					_anim("swing%d" % (c + 1), maxf(1.0, WeaponAnims.clips(it.id)["swing%d" % (c + 1)].len / cd))
					return
				if it.id == "sniper":
					scope_block = true
				if mag > 0:
					it["ammo"] = int(it.get("ammo", mag)) - 1
				if it.id == "flame":
					flame_t = 0.2
				_td_shoot(it.id, w)
				if w.kind == "homing":
					_anim("throw")
				elif WeaponAnims.has(it.id, "fire"):
					_anim("fire", maxf(1.0, WeaponAnims.clips(it.id).fire.len / cd))
		"equip":
			if just and it.id == "shield":
				_try_shield()
			elif just and it.id == "wall" and wall_cd <= 0.0:
				wall_cd = ch.get("wall_cd", WALL_CD)
				spawn_wall.rpc(_build_pos(), rotation.y, 0)
		"build":
			if just and td.can_place(it.id, _build_pos()):
				td.place(it.id, _build_pos(), rotation.y)
				_take(slot - 1)
				if busy == "":
					busy = "place"
					_anim("place")
		"item":
			var d: Dictionary = Weapons.ITEMS.get(it.id, {})
			if it.id == "bomb": # el bombasıyla aynı: pim, beklet, at
				if just:
					_prime("item:bomb")
				return
			if not just or d.is_empty() or (d.has("heal") and hp >= max_hp):
				return
			if d.has("heal"): # iç: can "gulp" olayında gelir
				_sync_held()
				if busy == "" or busy == "draw":
					busy = "drink"
					_anim("drink")
				return
			else:
				_td_shoot(it.id, Weapons.tuned(it.id, ups))
			_take(slot - 1)


## Şarjörü doldurur (R ya da boş tetik). Yalnız TD'de; dolu ya da şarjörsüzse bir şey yapmaz.
## Süre Weapons.reload_time; klip o süreye sığacak hızda oynar, mermi "mag_in" olayında dolar.
func start_reload() -> void:
	_sync_held()
	if td == null or held_id == "" or (busy != "" and busy != "draw"):
		return
	var w := Weapons.tuned(held_id, ups)
	var mag := Weapons.mag_of(w)
	var ammo: int = inv[slot - 1].get("ammo", mag)
	if mag == 0 or ammo >= mag:
		return
	reloading = true
	busy = "reload"
	var a := st("attack")
	if w.get("per_shell", false): # pompalı: başla, fişek fişek, bitir
		reload_t = Weapons.reload_time(w, a, false) * (mag - ammo) + 0.6 / a
		_anim("reload_start", a)
		return
	var empty := ammo <= 0 and WeaponAnims.has(held_id, "reload_empty")
	var clip := "reload_empty" if empty else "reload"
	reload_t = Weapons.reload_time(w, a, empty)
	_anim(clip, WeaponAnims.clips(held_id)[clip].len / reload_t)


## Klip olayları (vm'den ya da vm yoksa zamanlayıcıdan): oyun mantığı hep buradan geçer.
func _on_vm_event(n: String) -> void:
	match n:
		"mag_in":
			if reloading:
				inv[slot - 1]["ammo"] = Weapons.mag_of(Weapons.tuned(held_id, ups))
				reloading = false
		"shell":
			if reloading:
				var mag := Weapons.mag_of(Weapons.tuned(held_id, ups))
				inv[slot - 1]["ammo"] = mini(int(inv[slot - 1].get("ammo", 0)) + 1, mag)
				if inv[slot - 1].ammo >= mag:
					reloading = false
					_anim("reload_end", st("attack"))
				else:
					_anim("shell", st("attack"))
		"done":
			if reloading and busy == "reload": # pompalı: başlangıç bitti, fişeklere geç
				_anim("shell", st("attack"))
			else:
				busy = ""
				reload_t = 0.0
				var it: Dictionary = inv[slot - 1] if td else {}
				if it.get("kind", "") == "weapon" and int(it.get("ammo", 1)) <= 0:
					start_reload() # boşaldı: kendiliğinden doldur (yeni bomba, ok, roket)
		"ready":
			busy = ""
		"pin":
			if busy == "prime":
				pinned = true
				fuse_left = Weapons.tuned(prime_id.trim_prefix("item:"), ups).get("fuse", 3.0)
				if throw_q:
					_release_throw()
		"release":
			if busy == "throw":
				if held_id == "bow":
					_loose()
				else:
					_throw_now()
		"fired":
			if swing_k > 0.0: # kılıç vuruş anı
				var k := swing_k
				swing_k = 0.0
				_td_shoot("sword", Weapons.tuned("sword", ups), 0.0, k)
		"chamber":
			scope_block = false
		"gulp":
			if busy == "drink":
				var d: Dictionary = Weapons.ITEMS.potion
				gain(d.heal)
				_ring_fx(global_position + Vector3.UP * 0.2, Color(d.color, 0.85), 1.4, 0.4)
				_take(slot - 1)


## Elde tutulan silah değişti: süren doldurma iptal (şarjör dolmaz), çıkarma klibi baştan.
func _switched(id: String) -> void:
	if pinned and is_multiplayer_authority(): # pimli bombayla ölüm / silah değişimi: ayağa düşer
		rocket_n += 1
		td_fire.rpc(prime_id.trim_prefix("item:"), global_position + Vector3.UP * 0.6, PackedVector3Array([Vector3.DOWN]), rocket_n, fuse_left)
		_spent(prime_id)
	pinned = false
	throw_q = false
	fuse_left = 0.0
	draw_k = 0.0
	swing_k = 0.0
	scope_block = false
	held_id = id
	reloading = false
	reload_t = 0.0
	busy = "draw" if id != "" else ""
	anim_gen += 1
	if vm:
		vm.equip(id)
	elif id != "":
		_anim_timers(id, "draw", 1.0)


func _sync_held() -> void:
	var h := _held() if hp > 0 else ""
	if h != held_id and not (busy == "drink" and hp > 0): # son şişe yudumda biter: klip (iniş, done) sonuna dek oynasın
		_switched(h)


## Klip oynatır: kendi gözümüzde viewmodel, yoksa olaylar zamanlayıcıyla gelir. Diğer makineler parça klibini oynatır.
func _anim(clip: String, speed := 1.0) -> void:
	anim_gen += 1
	if is_multiplayer_authority():
		td_anim.rpc(clip)
	if vm:
		vm.play(clip, speed)
	else:
		_anim_timers(held_id, clip, speed)


func _anim_timers(id: String, clip: String, speed: float) -> void:
	if not WeaponAnims.has(id, clip):
		return
	var g := anim_gen
	for e in WeaponAnims.clips(id)[clip].get("events", []):
		get_tree().create_timer(e[0] / speed).timeout.connect(func():
			if g == anim_gen:
				_on_vm_event(e[1]))


## Bombayı hazırla: prime klibi, "pin" olayında sigorta başlar.
func _prime(id: String) -> void:
	_sync_held()
	if busy != "" and busy != "draw":
		return
	busy = "prime"
	prime_id = id
	pinned = false
	throw_q = false
	_anim("prime")


## Yayı germeye başla (draw_string); _td_local draw_k'yı artırır.
func _charge() -> void:
	_sync_held()
	if busy != "" and busy != "draw":
		return
	busy = "charge"
	draw_k = 0.0
	_anim("draw_string")


## Gerilmiş oku bırakır: güç ve hız gerginlikle %40 -> %100.
func _loose() -> void:
	var k := lerpf(0.4, 1.0, draw_k)
	draw_k = 0.0
	var it: Dictionary = inv[slot - 1]
	it["ammo"] = int(it.get("ammo", 1)) - 1
	_td_shoot("bow", Weapons.tuned("bow", ups), 0.0, k)


## Ateş edilebilir mi: animasyon serbest, bekleme bitti, şarjörde mermi var, bumerang elde.
func _can_fire() -> bool:
	var it: Dictionary = inv[slot - 1] if td else {}
	if busy != "" or cd > 0.0 or it.get("kind", "") != "weapon":
		return false
	var w := Weapons.tuned(it.id, ups)
	var mag := Weapons.mag_of(w)
	if mag > 0 and int(it.get("ammo", mag)) <= 0:
		return false
	return w.kind != "homing" or thrown < w.n + int(bv("multi")) - 1


## Bumerang döndü (slipper.gd çağırır).
func caught() -> void:
	thrown = maxi(thrown - 1, 0)
	if is_multiplayer_authority() and held_id == "boomerang" and busy == "":
		_anim("catch")


## Basılı tutulan atışı bırakır: yay, el bombası, bomba eşyası. Pim henüz çekilmediyse çekilince atar.
func _release_throw() -> void:
	if busy == "charge":
		busy = "throw"
		_anim("release")
		return
	if busy != "prime":
		return
	if not pinned:
		throw_q = true
		return
	busy = "throw"
	_anim("throw")


func _throw_now() -> void:
	var id := prime_id.trim_prefix("item:")
	pinned = false
	_td_shoot(id, Weapons.tuned(id, ups), maxf(fuse_left, 0.05))
	fuse_left = 0.0
	_spent(prime_id)


## Sigorta elde bitti: elde patlar; yaratıklara tam, sahibine yarım hasar.
func _cook_out() -> void:
	var id := prime_id.trim_prefix("item:")
	pinned = false
	fuse_left = 0.0
	rocket_n += 1
	td_fire.rpc(id, _muzzle(), PackedVector3Array([-look.global_basis.z]), rocket_n, 0.001)
	take_hit(int(Weapons.tuned(id, ups).dmg * 0.5), true)
	busy = ""
	_spent(prime_id)
	if prime_id == "grenade":
		start_reload()


## Atılan bomba elden çıktı: el bombasının şarjörü boşalır, bomba eşyası tükenir.
func _spent(id: String) -> void:
	if id == "item:bomb":
		var i := inv.find_custom(func(d): return d.get("id", "") == "bomb")
		if i >= 0:
			_take(i)
	else:
		var i := inv.find_custom(func(d): return d.get("id", "") == "grenade")
		if i >= 0:
			inv[i]["ammo"] = 0


## Diğer makinelerde elde tutulan modelin parça klibi (sürgü, şarjör, pim...); klip ilk kullanımda kurulur.
@rpc("authority", "call_remote", "unreliable_ordered")
func td_anim(clip: String) -> void:
	var id := _held()
	var ap := props[id].find_child("AnimationPlayer", false, false) as AnimationPlayer if props.has(id) else null
	if ap == null or not WeaponAnims.has(id, clip):
		return
	if not ap.has_animation(clip):
		ap.get_animation_library("").add_animation(clip, WeaponAnims.build(id, clip, true))
	ap.play(clip)
	ap.seek(0.0, true)


func _take(i: int) -> void:
	inv[i].count -= 1
	if inv[i].count <= 0:
		inv[i] = {}
	_td_changed()


func _build_pos() -> Vector3:
	return _ground(global_position - transform.basis.z * BUILD_DIST)


## Yapı slotu seçiliyken önümüzde yarı saydam önizleme: kurulabiliyorsa yeşil, değilse kırmızı.
func _td_ghost(alive: bool) -> void:
	var it: Dictionary = inv[slot - 1]
	var on: bool = alive and it.get("kind", "") == "build"
	if ghost == null:
		if not on:
			return
		var bm := BoxMesh.new()
		bm.size = Vector3(2.0, 1.6, 0.5)
		ghost = _mesh(_world(), bm, Vector3.ZERO, Color.WHITE)
		_bar_mat(ghost)
	ghost.visible = on
	if on:
		var p := _build_pos()
		ghost.global_position = p + Vector3.UP * 0.8
		ghost.rotation.y = rotation.y
		(ghost.material_override as StandardMaterial3D).albedo_color = Color(0.3, 1.0, 0.4, 0.45) if td.can_place(it.id, p) else Color(1.0, 0.25, 0.2, 0.45)


## Namlu ucu (dünyada). Kendi gözümüzde silah ayrı FOV'lu kamerada çizilir: o kameradaki ekran noktasını
## ana kameradan aynı derinliğe taşırız, böylece alev / iz ekranda tam silahın ucunda görünür.
func _muzzle() -> Vector3:
	if vm and vm.visible:
		var p: Vector3 = vm.muzzle()
		var c := get_viewport().get_camera_3d()
		if c and vm.vcam and not vm.vcam.is_position_behind(p):
			var depth := -(c.global_transform.affine_inverse() * p).z
			return c.project_position(vm.vcam.unproject_position(p), depth) # ikisi de aynı piksel boyutunda (vp.size = pencere)
		return p
	var m := hold.find_child("muzzle", true, false) as Node3D if hold and hold.visible else null
	if m: # başkasının elindeki silahın gerçek namlusu
		return m.global_position
	return look.global_position + look.global_basis * Vector3(0.25, -0.2, -0.8)


## Nişangâhın gösterdiği nokta: duvar, zemin ya da yaratık (oyuncuların içinden geçer).
func _td_aim(max_d: float) -> Vector3:
	var from := look.global_position
	var to := from - look.global_basis.z * max_d
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = _player_rids()
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r:
		to = r.position
	var hits := Weapons.ray(get_tree(), from, to)
	return hits[0][2] if not hits.is_empty() else to


## Atış kararı yerelde: yönleri (saçılma dahil) biz seçer, td_fire ile herkese yayarız.
func _td_shoot(id: String, w: Dictionary, fuse := 0.0, k := 1.0) -> void:
	var eye: bool = w.kind != "rocket" # anında isabet gözden çıkar: yakındaki hedefte namlu kayması olmasın
	var origin := look.global_position if eye else _muzzle()
	var to := _td_aim(200.0) - origin
	var n: int = w.n + int(bv("multi")) - 1
	var dirs := PackedVector3Array()
	for i in n:
		if w.kind == "homing":
			dirs.append(to) # nişan noktası: hedefi her makine oradan seçer
		elif w.kind == "shot":
			dirs.append((to.normalized() + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 2.0 * w.spread).normalized())
		else:
			dirs.append(to.normalized().rotated(Vector3.UP, w.spread * (i - (n - 1) * 0.5)))
	rocket_n += 1
	td_fire.rpc(id, origin, dirs, rocket_n, fuse, k)


## Her makinede görüntü ve mermi; yaratığa hasarı yalnızca atanın makinesi hesaplar.
@rpc("authority", "call_local", "reliable")
func td_fire(id: String, origin: Vector3, dirs: PackedVector3Array, n: int, fuse := 0.0, k := 1.0) -> void:
	var w := Weapons.tuned(id, ups)
	w["fuse"] = fuse # > 0: sigortalı bomba (çarpınca patlamaz)
	w.speed *= k # k: yay gerginliği / kılıç serisinin son vuruşu
	w.knock *= k
	if w.kind == "homing":
		thrown += dirs.size()
	var mine := is_multiplayer_authority()
	w.dmg *= _pow(w) * k
	kick = w.kick
	shake(origin, w.kick * 0.2)
	Sfx.play3d(Sfx.fire if w.kind in ["shot", "rocket"] else Sfx.whoosh, origin, -8.0 if w.rate < 0.2 else -2.0)
	if w.kind in ["shot", "rocket"] and dirs.size() > 0:
		_muzzle_fx(_muzzle(), dirs[0], w.kind == "shot")
	for i in dirs.size():
		var d := dirs[i]
		match w.kind:
			"shot":
				_td_shot(w, origin, d, mine)
			"rocket":
				var r: Node3D = RocketScript.new()
				r.name = "T%d_%d_%d" % [get_multiplayer_authority(), n, i]
				r.shooter = self
				r.dir = d
				r.w = w
				r.position = origin
				_world().add_child(r)
			"homing":
				var s: Node3D = HomingScript.new()
				s.thrower = self
				s.td = true
				s.h = w.duplicate()
				s.h.merge({"look": "boomerang", "speed": w.speed * st("shot_speed"), "turn": 5.0, "turn_gain": 4.0, "bounces": w.bounce + int(st("bounce", 0.0))}, true)
				s.target = Weapons.nearest(get_tree(), origin + d, 6.0)
				s.dir = (d.normalized().rotated(Vector3.UP, 0.6 * (i - (dirs.size() - 1) * 0.5)) + Vector3.UP * 0.25).normalized()
				s.position = origin + s.dir * 0.6
				_world().add_child(s)
			"cone":
				var p := ExplosionScript.parts(ExplosionScript.quad("glow", 0.6), 10, 0.35, w.range * 2.0, w.range * 2.8,
					[Color(1.0, 0.8, 0.3, 0.7), Color(1.0, 0.35, 0.05, 0.5), Color(0.4, 0.1, 0.0, 0.0)], 0.4, 1.6)
				p.direction = d
				p.spread = rad_to_deg(acos(clampf(w.cone, -1.0, 1.0))) * 0.6
				p.position = _muzzle()
				p.finished.connect(p.queue_free)
				_world().add_child(p)
				p.emitting = true
				if mine:
					_td_arc(w, origin, d)
			"melee":
				swing_t = SWING_T
				_slash_fx(origin, d, k)
				var fl := Vector3(d.x, 0, d.z).normalized()
				for e in Weapons.alive(get_tree()): # vuruş yönünde savrulma ve uzuv sarsıntısı (her makinede)
					var em := Weapons.e_mid(e)
					if em.distance_to(origin) < w.range + 1.0 and (em - origin).normalized().dot(fl) > 0.3:
						Ragdoll.poke(em, fl * 5.0 * k)
						Ragdoll.flinch(e.get("model"), em, fl * 5.0 * k)
				if mine:
					_td_arc(w, origin, d)


## Kılıç izi: oyuncunun önünde ince, parlak bir yay; uçlara doğru incelir, hızla söner. k > 1: serinin son vuruşu.
func _slash_fx(at: Vector3, d: Vector3, k: float) -> void:
	var m := ImmediateMesh.new()
	m.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := 16
	for i in n + 1:
		var f := float(i) / n
		var a := lerpf(-1.1, 1.1, f)
		var w := sin(f * PI) * 0.12 * k
		var c := Color(1.0, 0.95, 0.8, sin(f * PI) * 0.8)
		var dir := Vector3(sin(a), 0, -cos(a))
		m.surface_set_color(c)
		m.surface_add_vertex(dir * (1.3 - w))
		m.surface_set_color(c)
		m.surface_add_vertex(dir * (1.3 + w))
	m.surface_end()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world().add_child(mi)
	var flat := Vector3(d.x, 0, d.z)
	mi.global_position = at + Vector3.DOWN * 0.3
	if flat.length_squared() > 0.001:
		mi.look_at(mi.global_position + flat)
	mi.rotate_object_local(Vector3.FORWARD, 0.35) # hafif çapraz savuruş
	var tw := mi.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.18)
	tw.tween_callback(mi.queue_free)


## Namlu ateşi: parlak alev çiçeği + kısa ışık; mermili silahta sağa sekip düşen pirinç kovan.
func _muzzle_fx(at: Vector3, d: Vector3, casing: bool) -> void:
	var fp := vm != null and vm.visible # kendi gözümüzde alev küçük: ekranı kapatmasın
	var p := ExplosionScript.parts(ExplosionScript.quad("glow", 0.15 if fp else 0.35), 6, 0.06 if fp else 0.08, 0.5 if fp else 1.0, 2.0 if fp else 4.0,
		[Color(1.0, 0.9, 0.5, 0.9), Color(1.0, 0.5, 0.1, 0.0)], 1.0, 0.3)
	p.direction = d
	p.spread = 25.0
	p.position = at
	p.finished.connect(p.queue_free)
	_world().add_child(p)
	p.emitting = true
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.4)
	l.light_energy = 3.0
	l.omni_range = 4.0
	l.position = at
	_world().add_child(l)
	l.create_tween().tween_property(l, "light_energy", 0.0, 0.06)
	l.create_tween().tween_callback(l.queue_free).set_delay(0.08)
	if casing:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.012, 0.012, 0.03)
		bm.material = ExplosionScript.mat("chunk")
		var c := ExplosionScript.parts(bm, 1, 0.6, 1.5, 2.2, [Color(0.85, 0.65, 0.2), Color(0.7, 0.5, 0.15)], 1.0, 1.0)
		c.direction = (d.cross(Vector3.UP).normalized() + Vector3.UP).normalized() # sağa-yukarı
		c.spread = 15.0
		c.gravity = Vector3(0, -9.8, 0)
		c.angular_velocity_min = 360.0
		c.angular_velocity_max = 720.0
		c.position = at - d * 0.25
		c.finished.connect(c.queue_free)
		_world().add_child(c)
		c.emitting = true


## İsabet: duvarda kıvılcım + toz + birkaç saniye kalan kurşun deliği; yaratıkta yeşilimsi sıçrama.
func _impact_fx(at: Vector3, n: Vector3, flesh: bool) -> void:
	var q: int = Settings.quality
	if flesh:
		var b := ExplosionScript.parts(enemy_splash_mesh(), 4 + q * 3, 0.45, 1.5, 3.5,
			[Color(0.55, 0.9, 0.25), Color(0.3, 0.55, 0.1, 0.0)], 1.0, 0.4)
		b.direction = n
		b.spread = 50.0
		b.gravity = Vector3(0, -12, 0)
		b.position = at
		b.finished.connect(b.queue_free)
		_world().add_child(b)
		b.emitting = true
		return
	var sp := ExplosionScript.parts(ExplosionScript.quad("glow", 0.06), 3 + q * 3, 0.25, 2.0, 6.0,
		[Color(1.0, 0.85, 0.4), Color(1.0, 0.4, 0.1, 0.0)], 1.0, 0.2)
	sp.direction = n
	sp.spread = 40.0
	sp.gravity = Vector3(0, -9.8, 0)
	sp.position = at + n * 0.02
	sp.finished.connect(sp.queue_free)
	_world().add_child(sp)
	sp.emitting = true
	if q > 0:
		var du := ExplosionScript.parts(ExplosionScript.quad("puff", 0.35), 3, 0.7, 0.2, 0.8,
			[Color(0.55, 0.5, 0.45, 0.45), Color(0.6, 0.58, 0.55, 0.0)], 0.5, 1.6)
		du.direction = n
		du.spread = 30.0
		du.position = at + n * 0.05
		du.finished.connect(du.queue_free)
		_world().add_child(du)
		du.emitting = true
		var dc := Decal.new()
		dc.size = Vector3(0.12, 0.2, 0.12)
		dc.texture_albedo = bullet_hole()
		dc.modulate = Color(1, 1, 1, 0.9)
		_world().add_child(dc)
		dc.global_position = at
		dc.global_basis = Basis(Quaternion(Vector3.UP, n)) # Decal'ın -Y'si yüzeye yansır
		var tw := dc.create_tween()
		tw.tween_interval(4.0)
		tw.tween_property(dc, "modulate:a", 0.0, 1.5)
		tw.tween_callback(dc.queue_free)


static var _hole: Texture2D
static var _splash: Mesh


## Kurşun deliği dokusu: koyu merkez, yumuşak kenar (koddan, bir kez).
static func bullet_hole() -> Texture2D:
	if _hole == null:
		var g := Gradient.new()
		g.set_color(0, Color(0.02, 0.02, 0.02, 1.0))
		g.set_color(1, Color(0.15, 0.13, 0.12, 0.0))
		g.add_point(0.35, Color(0.05, 0.05, 0.05, 0.95))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_hole = t
	return _hole


static func enemy_splash_mesh() -> Mesh:
	if _splash == null:
		var s := SphereMesh.new()
		s.radius = 0.035; s.height = 0.07
		s.radial_segments = 6; s.rings = 3
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.3
		s.material = m
		_splash = s
	return _splash


## Anında isabet: yol üstündeki yaratıkları (pierce + 1 tane) vurur, sonra yakındakilere seker.
func _td_shot(w: Dictionary, from: Vector3, d: Vector3, mine: bool) -> void:
	var to: Vector3 = from + d * w.range
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = td_rids()
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r:
		to = r.position
	var seen := []
	var extra := 0 # evrim (Altıpatlar Lordu): kritik vuruş ek sekme
	for h in Weapons.ray(get_tree(), from, to).slice(0, w.pierce + 1):
		seen.append(h[1])
		Ragdoll.poke(h[2], d * (2.0 + w.knock)) # ölürse bu yöne savrulur
		Ragdoll.flinch(h[1].get("model"), h[2], d * (2.0 + w.knock))
		_impact_fx(h[2], -d, true)
		if mine:
			td_affect(h[1], w, from)
			if _last_crit:
				extra = w.get("crit_chain", 0)
		if seen.size() > w.pierce:
			to = h[2] # son yaratıkta durdu
	_beam_fx(_muzzle(), to, w.color)
	if r and seen.size() <= w.pierce: # duvar / zemin: kıvılcım, toz, kısa süren delik
		_impact_fx(r.position, r.normal, false)
	if seen.is_empty():
		return
	for i in w.bounce + int(st("bounce", 0.0)) + extra:
		var nx := Weapons.nearest(get_tree(), to, Weapons.CHAIN_R, seen)
		if nx == null:
			return
		w = w.duplicate()
		w.dmg *= Weapons.CHAIN_K
		if w.has("burn"): # sinerji ateş + sekme: sekerken yanığı da taşır, üstüne 1,5 kat uzun yanar
			w.burn = [w.fire, Weapons.BURN_T * 1.5]
		_beam_fx(to, Weapons.e_mid(nx), w.color)
		if mine:
			td_affect(nx, w, to)
		seen.append(nx)
		to = Weapons.e_mid(nx)


## Önümüzdeki yay (alev, kılıç): menzil ve açı içindeki bütün yaratıklar.
## shortcut: duvar arkasındakini de vurur; sorun olursa yaratığa ışın at.
func _td_arc(w: Dictionary, from: Vector3, d: Vector3) -> void:
	d.y = 0.0
	for e in Weapons.alive(get_tree()):
		var to: Vector3 = e.global_position - from
		to.y = 0.0
		if Weapons.dist(e, from) < w.range and (to.length() < 0.3 + Weapons.e_r(e) or d.normalized().dot(to.normalized()) >= w.cone):
			td_affect(e, w, from)


## Atanın roketi çarpınca yayınlar: patlama (alan hasarı) ya da küçük isabet izi; last ise roket silinir.
@rpc("authority", "call_local", "reliable")
func td_explode(rocket_name: String, pos: Vector3, blast: float, last: bool) -> void:
	var r := _world().get_node_or_null(NodePath(rocket_name))
	if blast > 0.0:
		boom_fx(pos, blast / BLAST_RADIUS)
		if r and is_multiplayer_authority():
			for e in Weapons.alive(get_tree()):
				if Weapons.dist(e, pos) < blast:
					td_affect(e, r.w, pos)
			if r.w.has("mini"): # evrim (Kıyamet Bazukası): ana patlamanın çevresinde mini patlamalar
				var mw: Dictionary = r.w.duplicate()
				mw.dmg *= r.w.mini[1]
				mw.knock = 0.0
				for i in int(r.w.mini[0]):
					_evo_boom(pos + Vector3.RIGHT.rotated(Vector3.UP, TAU * i / r.w.mini[0]) * blast * 0.8, r.w.mini[2], mw)
	else:
		_ring_fx(pos, Color(1.0, 0.9, 0.6, 0.8), 0.35, 0.15)
	if r and last:
		r.queue_free()


## Evrim patlaması: görüntü herkese (roketsiz td_explode), hasar yalnızca bizde.
func _evo_boom(pos: Vector3, radius: float, eff: Dictionary) -> void:
	td_explode.rpc("evo", pos, radius, false)
	for e in Weapons.alive(get_tree()):
		if Weapons.dist(e, pos) < radius:
			td_affect(e, eff, pos)


## Etkiyi yaratığa uygular (yalnızca atanın makinesinde çağrılır): hasar ve yanık burada hesaplanır,
## yavaşlatma / sersemletme / itme yaratığın kancasına gider (td.effect_enemy ya da enemy.apply_effect varsa).
func td_affect(e: Node, eff: Dictionary, from: Vector3) -> void:
	if eff.get("dmg", 0) > 0:
		td_dmg(e, eff.dmg)
	if eff.has("burn"):
		burns[e.name] = [e, eff.burn[0], eff.burn[1], eff, e.global_position]
	if eff.has("drain"):
		gain(eff.drain)
	var fx := Weapons.enemy_fx(eff, from, e.global_position, global_position)
	if fx.is_empty():
		return
	if td.has_method("effect_enemy"):
		_host("effect_enemy", [str(e.name), fx])
	elif multiplayer.is_server() and e.has_method("apply_effect"):
		e.apply_effect(fx)
	elif multiplayer.is_server() and e.get("slow_t") != null and (fx.has("slow") or fx.has("stun")):
		# shortcut: kanca yokken yalnızca host oyuncusu, enemy.gd'nin yavaşlatma alanlarını doğrudan yazar (sersemletme = hız 0)
		e.slow_k = 0.0 if fx.has("stun") else fx.slow[0]
		e.slow_t = fx.get("stun", 0.0) if fx.has("stun") else fx.slow[1]


## Kritik burada atılır (x2); sonucu host'a bildirir.
func td_dmg(e: Node, dmg: float, can_crit := true) -> void:
	_last_crit = false
	if e.is_in_group("chickens"):
		_hunt(e)
		return
	var crit := can_crit and randf() < st("crit", 0.0)
	_last_crit = crit
	var n := maxi(roundi(dmg * (2.0 if crit else 1.0)), 1)
	# isabet işareti ve tık hemen, host'un cevabını beklemeden (öldürme tahmini: istemcinin bildiği son can)
	hit_ms = Time.get_ticks_msec()
	hit_kill = "hp" in e and "armor" in e and e.hp > 0 and maxi(n - e.armor, ceili(n * 0.4)) >= e.hp
	Sfx.play2d(Sfx.tick, -6.0 if hit_kill else -12.0)
	_host("damage_enemy", [str(e.name), n, crit])


## Tavuğu vuran makine: ölümü herkese yayar, ödülü alır (TD'de can iksiri, yer yoksa ya da arenada 25 can).
## shortcut: tavukların konumu ağda eşit değil; başka oyuncular kendi ekranlarındaki kopyanın öldüğünü görür.
func _hunt(c: Node) -> void:
	chicken_die.rpc(str(c.name))
	Profile.stat_add("chickens")
	if not (td and add_item({"kind": "item", "id": "potion"})):
		gain(25)


@rpc("authority", "call_local", "reliable")
func chicken_die(cname: String) -> void:
	for c in get_tree().get_nodes_in_group("chickens"):
		if str(c.name) == cname and c.hp > 0:
			c.die()


## Yaratık hasarı (host çağırır); zırh statı take_hit içinde uygulanır, kalkan bir darbeyi emer.
@rpc("any_peer", "call_local", "reliable")
func td_hit(dmg: int) -> void:
	if not is_multiplayer_authority() or hp <= 0:
		return
	if shield_on:
		set_shield.rpc(false)
	else:
		take_hit(dmg)


@rpc("authority", "call_local", "reliable")
func td_respawn() -> void:
	respawn()


## Envantere öğe ekler: {"kind": "weapon"|"equip"|"build"|"item", "id", ["count"]}. Yer yoksa false.
## Sahibi olmayan kopyada yalnızca "yer var mı" cevabını verir (host satın almadan önce sorabilir).
@rpc("any_peer", "call_local", "reliable")
func add_item(d: Dictionary) -> bool:
	var arr := inv
	var i := Weapons.find_slot(inv, d) if td else -1
	if i < 0 and td:
		arr = bag
		i = Weapons.bag_slot(inv, bag, d)
	if i < 0:
		return false
	if is_multiplayer_authority() and multiplayer.get_remote_sender_id() <= 1:
		if arr[i].is_empty():
			arr[i] = {"kind": d.kind, "id": d.id, "count": d.get("count", 1), "lvl": 1}
			if d.kind == "weapon":
				arr[i]["ammo"] = Weapons.full_ammo(d.id)
		else:
			arr[i].count += d.get("count", 1)
		_td_changed()
	return true


## Envanter paneli: birleşik indeks a'daki öğeyi b'ye taşır (0–4 el, 5.. çanta). Tür kuralları Weapons.move_item'de.
func move_item(a: int, b: int) -> bool:
	if td == null or not Weapons.move_item(inv, bag, a, b):
		return false
	reloading = false # el slotunun içeriği değişti: yarım doldurma iptal
	_sync_held()
	_td_changed()
	return true


## Takım seviye atlayınca host her oyuncuda çağırır: 3 kart (birikirse sırayla).
@rpc("any_peer", "call_local", "reliable")
func level_up() -> void:
	if td == null or not is_multiplayer_authority() or multiplayer.get_remote_sender_id() > 1:
		return
	level += 1
	pending += 1
	if cards.is_empty():
		cards = _roll()
	_td_changed()


func choose_card(i: int) -> void:
	if i < 0 or i >= cards.size():
		return
	if cards[i].type == "evo":
		Profile.achieve("ACH_EVOLVED")
	Weapons.apply_card(self, cards[i])
	pending -= 1
	cards = _roll() if pending > 0 else []
	_td_changed()


## 3 kart; elenen gruplar atlanır (fazladan çekip süzer).
func _roll() -> Array:
	return Weapons.roll_cards(self, 3 + banished.size()).filter(func(c): return not banished.has(Weapons._group(c))).slice(0, 3)


## Yeniden çekme hakkı (sayacı td_ui tutar): eldeki kartlar yenilenir.
func reroll_cards() -> void:
	if not cards.is_empty():
		cards = _roll()


## Eleme: kart bu maçta bir daha çıkmaz, yerine yenisi gelir (yeni yoksa düşer; son kart elenmez). Olduysa true.
func banish_card(i: int) -> bool:
	if i < 0 or i >= cards.size():
		return false
	var keep := cards.map(func(c): return Weapons._group(c))
	var fresh := _roll().filter(func(c): return not keep.has(Weapons._group(c)))
	if fresh.is_empty() and cards.size() == 1:
		return false
	banished.append(Weapons._group(cards[i]))
	if fresh.is_empty():
		cards.remove_at(i)
	else:
		cards[i] = fresh[0]
	return true


## Sahibinde stat / envanter / yükseltme değişti: diğer makinelere yay (silah modeli, can barı, mermi sayısı).
func _td_changed() -> void:
	var d := int(stats.hp) - max_hp
	max_hp = int(stats.hp)
	td_sync.rpc(inv, stats, ups, level, bag)
	if d != 0 and hp > 0:
		set_hp.rpc(hp + d)


@rpc("authority", "call_remote", "reliable")
func td_sync(i: Array, s: Dictionary, u: Dictionary, l: int, b: Array) -> void:
	inv = i
	bag = b
	stats = s
	ups = u
	level = l
	max_hp = int(stats.hp)
