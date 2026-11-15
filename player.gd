extends CharacterBody3D
## Silindir gövde + yuvarlak kafa. Her oyuncu kendi hareketinin sahibi (client-authoritative):
## pozisyon 60 Hz unreliable gider, diğer tarafta yumuşatılır -> girişte gecikme hissi yok.

const RocketScript := preload("res://rocket.gd")
const ExplosionScript := preload("res://explosion.gd")
const LightningScript := preload("res://lightning.gd")
const WallScript := preload("res://wall.gd")
const Chars := preload("res://characters.gd")
const Rig := preload("res://rig.gd")
const SlipperScript := preload("res://slipper.gd")
const FLASH_R := 8.0
const FLASH_TIME := 1.5
const SLIPPER_RANGE := 40.0
const PULL_R := 8.0
const PULL_DMG := 10
const SHOUT_TIME := 4.0
const SHOUT_DMG := 30
const TILE_RANGE := 30.0
const SIT_TIME := 2.0 # Kahvehane Dayısı bu kadar durunca kalkan alır
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
var shout_t := 0.0 # > 0 iken Pazarcı Abi'nin ateş topları güçlü
var blind_t := 0.0 # > 0 iken ekran beyaz (Keloğlan'ın flaşı; yalnızca yerel oyuncu)
var head_mat: StandardMaterial3D
var model: Node3D # karakterin 3D modeli (varsa)
var model_fx: StandardMaterial3D # modelin üstüne binen kırmızı hasar parlaması
var skel: Skeleton3D # modele kodla takılan iskelet (rig.gd)
var arm_down := [Quaternion(), Quaternion()] # [sağ, sol] kolu aşağı sarkıtan dönüş
var arm_straight := [Quaternion(), Quaternion()] # ön kolu üst kolla hizalayan dönüş
var arm_dir := Vector3.DOWN # sağ üst kolun modeldeki duruş yönü
var quote_lbl: Label3D
var quote_t := 0.0
var still_t := 0.0 # yerinde durma süresi (Kahvehane Dayısı pasifi)
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
	head_mat = _mesh(look, head, Vector3.ZERO, Color(1.0, 0.85, 0.7)).material_override
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
	if ch.has("model"):
		_load_model()

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
	var staff: String = ch.get("staff", "")
	var pole := CylinderMesh.new()
	pole.top_radius = 0.022; pole.bottom_radius = 0.035; pole.height = 1.0
	var pole_col := Color(0.4, 0.24, 0.12)
	match staff:
		"oklava":
			pole.top_radius = 0.026; pole.bottom_radius = 0.026
			pole_col = Color(0.87, 0.72, 0.47)
		"leek":
			pole.top_radius = 0.03; pole.bottom_radius = 0.024
			pole_col = Color(0.96, 0.96, 0.88)
		"cane":
			pole.top_radius = 0.022; pole.bottom_radius = 0.022
			pole_col = Color(0.2, 0.13, 0.08)
	gun = _mesh(look, pole, Vector3(0.3, -0.35, -0.45), pole_col)
	gun.rotation.x = -PI / 2 + 0.45 # ucu hafif yukarı bakar, kristal görünsün
	_staff_parts(staff)
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
	if skel and not is_multiplayer_authority():
		_weapons_to_hand() # kendi gözünden bakarken silah ekranın önünde kalır
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


## Basit şekilleri gizler, yerine karakterin 3D modelini 1,9 m boyunda ve ayakları yerde koyar.
func _load_model() -> void:
	for mi in vis.find_children("*", "MeshInstance3D", true, false):
		mi.visible = false
	var scene: Node3D = load(ch.model).instantiate()
	model = Node3D.new()
	vis.add_child(model)
	model.add_child(scene)
	model_fx = StandardMaterial3D.new()
	model_fx.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	model_fx.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	model_fx.albedo_color = Color(1, 0.1, 0.1, 0)
	var box := AABB()
	var inv := model.global_transform.affine_inverse()
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = inv * mi.global_transform * mi.get_aabb()
		box = b if box.size == Vector3.ZERO else box.merge(b)
		mi.material_overlay = model_fx
	var c := box.get_center()
	scene.position = Vector3(-c.x, -box.position.y, -c.z)
	model.scale = Vector3.ONE * (1.9 / box.size.y)
	model.rotation.y = ch.get("model_yaw", 0.0)
	if ch.has("rig"):
		var skin_mi: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
		skel = Rig.build(skin_mi, ch.rig, ch.model)
		var segs := Rig.segments(ch.rig)
		arm_dir = (segs[Rig.ARM_R][1] - segs[Rig.ARM_R][0]).normalized()
		for k in 2: # 0 sağ (+Z), 1 sol (-Z)
			var up_i: int = Rig.ARM_R + k * 2
			var u: Vector3 = (segs[up_i][1] - segs[up_i][0]).normalized()
			var f: Vector3 = (segs[up_i + 1][1] - segs[up_i + 1][0]).normalized()
			arm_down[k] = Quaternion(u, Vector3(0, -1, 0.12 if k == 0 else -0.12).normalized())
			arm_straight[k] = Quaternion(f, u)


## Asayı ve kılıcı kafa pivotundan alıp sağ ele bağlar (yalnızca iskeletli modelde, başkalarının gözünde).
func _weapons_to_hand() -> void:
	var segs := Rig.segments(ch.rig)
	var hand := BoneAttachment3D.new()
	skel.add_child(hand)
	hand.bone_name = "fore_r"
	var holder := Node3D.new()
	hand.add_child(holder)
	# Kol nişan alırken (pitch 0) tutucunun -Z'si karakterin önüne (+X), Y'si yukarı baksın.
	var aim: Quaternion = Quaternion(arm_dir, _aim_dir(0.0)) * arm_straight[0]
	holder.basis = Basis(aim.inverse()) * Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
	holder.scale = Vector3.ONE / model.scale.x # model büyütülmüş; silah gerçek boyunda kalsın
	holder.position = (segs[Rig.FORE_R][1] - segs[Rig.FORE_R][0]) * 0.85 # avuç içi
	gun.reparent(holder, false)
	gun.position = gun.basis.y * 0.25 # sapın alt üçte birinden tut
	sword.reparent(holder, false)
	sword.position = Vector3.ZERO


## Sağ kolun nişan yönü (model uzayında): ileri, bakış açısı kadar yukarı/aşağı, hafif dışa ve aşağı.
func _aim_dir(pitch: float) -> Vector3:
	return Vector3(cos(pitch), sin(pitch) - 0.18, 0.22).normalized()


## Ateş asasının karaktere özel süsleri. Asanın yerel +Y'si uç tarafıdır (kristal 0.6'da).
func _staff_parts(staff: String) -> void:
	var gold := Color(0.95, 0.75, 0.2)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.04; ring.outer_radius = 0.065
	match staff:
		"crook": # çoban değneği: uçta kıvrık kanca, sapta ip sargısı
			_mesh(gun, ring, Vector3(0, 0.44, 0.06), Color(0.4, 0.24, 0.12)).rotation.z = PI / 2
			var wrap := CylinderMesh.new()
			wrap.top_radius = 0.034; wrap.bottom_radius = 0.036; wrap.height = 0.12
			_mesh(gun, wrap, Vector3(0, -0.2, 0), Color(0.8, 0.7, 0.45))
		"oklava": # oklava: iki ucu koyu, ortası açık renk tahta
			var cap := CylinderMesh.new()
			cap.top_radius = 0.03; cap.bottom_radius = 0.03; cap.height = 0.07
			for y in [-0.46, 0.4]:
				_mesh(gun, cap, Vector3(0, y, 0), Color(0.6, 0.42, 0.22))
		"leek": # pırasa: beyaz sap, yeşil üst, yapraklar
			var green := CylinderMesh.new()
			green.top_radius = 0.04; green.bottom_radius = 0.031; green.height = 0.45
			_mesh(gun, green, Vector3(0, 0.25, 0), Color(0.3, 0.62, 0.22))
			var leaf := PrismMesh.new()
			leaf.size = Vector3(0.07, 0.22, 0.02)
			for i in 3:
				var a := TAU * i / 3.0
				var l := _mesh(gun, leaf, Vector3(cos(a) * 0.05, 0.5, sin(a) * 0.05), Color(0.2, 0.5, 0.18))
				l.basis = Basis(Vector3(-sin(a), 0, cos(a)), -0.5)
		"cane": # baston: tutma yerinde kıvrık sap, uçta pirinç halka
			_mesh(gun, ring, Vector3(0, -0.5, 0.06), Color(0.2, 0.13, 0.08)).rotation.z = PI / 2
			var gm := _mesh(gun, ring, Vector3(0, 0.44, 0), gold).material_override as StandardMaterial3D
			gm.metallic = 1.0; gm.roughness = 0.3
		_: # büyücü asası: altın halkalar ve kristali tutan pençeler
			for y in [0.3, 0.44]:
				var gm := _mesh(gun, ring, Vector3(0, y, 0), gold).material_override as StandardMaterial3D
				gm.metallic = 1.0; gm.roughness = 0.3
			var claw := CylinderMesh.new()
			claw.top_radius = 0.008; claw.bottom_radius = 0.015; claw.height = 0.16
			for i in 3:
				var a := TAU * i / 3.0
				var c := _mesh(gun, claw, Vector3(cos(a) * 0.05, 0.53, sin(a) * 0.05), gold)
				c.basis = Basis(Vector3(-sin(a), 0, cos(a)), -0.35) # uçları dışa açık


## Karakteri tanıtan kafa süsü. Kafa pivotuna bağlı; yerel oyuncu kendininkini görmez.
func _accessory(kind: String, col: Color) -> void:
	match kind:
		"bald": # parlak kel kafa + yamalı yelek
			head_mat.roughness = 0.12
			head_mat.metallic_specular = 1.0
			var glint := SphereMesh.new()
			glint.radius = 0.045; glint.height = 0.09
			var g: StandardMaterial3D = _mesh(look, glint, Vector3(0.09, 0.22, -0.14), Color.WHITE).material_override
			g.emission_enabled = true
			g.emission = Color.WHITE
			var patch := BoxMesh.new()
			patch.size = Vector3(0.15, 0.15, 0.03)
			_mesh(vis, patch, Vector3(-0.15, 1.2, -0.37), Color(0.85, 0.7, 0.25)).rotation.z = 0.3
			_mesh(vis, patch, Vector3(0.14, 0.9, -0.37), Color(0.3, 0.45, 0.75)).rotation.z = -0.2
		"curlers": # bigudiler + önlük
			var cur := CylinderMesh.new()
			cur.top_radius = 0.055; cur.bottom_radius = 0.055; cur.height = 0.16
			for i in 5:
				var a := PI * (0.15 + 0.7 * i / 4.0)
				var cc := Color(1.0, 0.75, 0.85) if i % 2 == 0 else Color(0.6, 0.85, 1.0)
				_mesh(look, cur, Vector3(cos(a) * 0.2, 0.22 + sin(a) * 0.04, 0.08 - sin(a) * 0.08), cc).rotation.z = PI / 2
			var apron := BoxMesh.new()
			apron.size = Vector3(0.5, 0.62, 0.03)
			_mesh(vis, apron, Vector3(0, 0.98, -0.37), Color(0.97, 0.95, 0.9))
		"cap": # kasket + bıyık + omuzda domates kasası
			var top := CylinderMesh.new()
			top.top_radius = 0.33; top.bottom_radius = 0.31; top.height = 0.1
			_mesh(look, top, Vector3(0, 0.2, 0.02), Color(0.35, 0.3, 0.25))
			var brim := BoxMesh.new()
			brim.size = Vector3(0.34, 0.03, 0.2)
			_mesh(look, brim, Vector3(0, 0.16, -0.3), Color(0.3, 0.25, 0.2))
			var stache := BoxMesh.new()
			stache.size = Vector3(0.22, 0.05, 0.05)
			_mesh(look, stache, Vector3(0, -0.07, -0.28), Color(0.15, 0.1, 0.07))
			var crate := BoxMesh.new()
			crate.size = Vector3(0.32, 0.14, 0.24)
			_mesh(vis, crate, Vector3(-0.45, 1.58, 0.05), Color(0.6, 0.42, 0.22))
			var tom := SphereMesh.new()
			tom.radius = 0.07; tom.height = 0.13
			for x in [-0.55, -0.45, -0.35]:
				_mesh(vis, tom, Vector3(x, 1.69, 0.05), Color(0.9, 0.12, 0.08))
		"dayi": # kasket + gür kır bıyık + koyu yelek
			var top := CylinderMesh.new()
			top.top_radius = 0.33; top.bottom_radius = 0.31; top.height = 0.09
			_mesh(look, top, Vector3(0, 0.2, 0.02), Color(0.45, 0.45, 0.5))
			var brim := BoxMesh.new()
			brim.size = Vector3(0.34, 0.03, 0.2)
			_mesh(look, brim, Vector3(0, 0.16, -0.3), Color(0.38, 0.38, 0.43))
			var stache := BoxMesh.new()
			stache.size = Vector3(0.3, 0.08, 0.06)
			_mesh(look, stache, Vector3(0, -0.08, -0.28), Color(0.8, 0.8, 0.8))
			var vest := BoxMesh.new()
			vest.size = Vector3(0.2, 0.7, 0.03)
			for x in [-0.2, 0.2]:
				_mesh(vis, vest, Vector3(x, 1.05, -0.37), Color(0.2, 0.18, 0.22))


func _speed() -> float:
	return SPEED * ch.speed


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
	if alive and ch.get("sit_shield", false): # Kahvehane Dayısı: oturan (duran) adam kalkan alır
		still_t = still_t + dt if Vector2(velocity.x, velocity.z).length() < 0.5 else minf(still_t, 0.0)
		if still_t >= SIT_TIME and not shield_on:
			still_t = -4.0 # sıradaki kalkan en erken 6 sn sonra
			set_shield.rpc(true)

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
		cd = THROW_CD
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
		"slipper", "tile":
			var best: Node3D = null
			var bd := SLIPPER_RANGE if ch.skill == "slipper" else TILE_RANGE
			for p in get_parent().get_children():
				var d := global_position.distance_to(p.global_position)
				if p != self and p.hp > 0 and d < bd:
					best = p
					bd = d
			if best == null:
				return # kovalanacak kimse yok: bekleme süresi harcanmasın
			throw_slipper.rpc(best.get_multiplayer_authority(), ch.skill)
		_:
			use_skill.rpc(ch.skill, global_position)
	skill_cd = ch.cd


@rpc("authority", "call_local", "reliable")
func use_skill(kind: String, pos: Vector3) -> void:
	say(ch.quote)
	match kind:
		"flash":
			_ring_fx(pos + Vector3.UP * 1.7, Color(1, 1, 0.85, 0.9), FLASH_R, 0.35)
			Sfx.play3d(Sfx.shield_up, pos + Vector3.UP, 4.0)
			var me := _local_player()
			if me and me != self and me.hp > 0:
				var eye: Vector3 = me.look.global_position
				var to := pos + Vector3.UP * 1.7 - eye
				if to.length() < FLASH_R and (-me.look.global_basis.z).dot(to.normalized()) > 0.3: # bakıyorsa
					me.blind_t = FLASH_TIME
		"pull":
			shout_t = SHOUT_TIME
			var ring := _ring_fx(pos + Vector3.UP * 0.2, Color(0.95, 0.3, 0.15, 0.8), PULL_R, 0.0)
			var tw := ring.create_tween() # dışarıdan içe daralır: çekiliyorsun
			tw.tween_property(ring, "scale", Vector3.ONE * 0.3, 0.4)
			tw.tween_callback(ring.queue_free)
			Sfx.play3d(Sfx.whoosh, pos + Vector3.UP, 4.0)
			var me := _local_player()
			if me and me != self and me.hp > 0:
				var to: Vector3 = pos - me.global_position
				to.y = 0.0
				if to.length() < PULL_R:
					me.velocity += to.normalized() * minf(to.length() * 2.0, 14.0) + Vector3.UP * 4.0
					if me.shield_on:
						me.set_shield.rpc(false)
					else:
						me.take_hit(PULL_DMG)


@rpc("authority", "call_local", "reliable")
func throw_slipper(target_id: int, kind := "slipper") -> void:
	say(ch.quote)
	var target := get_parent().get_node_or_null(str(target_id))
	if target == null:
		return
	var s: Node3D = SlipperScript.new()
	s.thrower = self
	s.kind = kind
	s.target = target
	s.dir = (-look.global_basis.z + Vector3.UP * 0.4).normalized() # önce havaya kalkar
	s.position = look.global_position + s.dir * 0.6
	get_parent().get_parent().add_child(s)
	Sfx.play3d(Sfx.whoosh, s.position, 2.0)


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
	if model:
		model.position.y = absf(sin(walk_t)) * 0.07 * amp
		model_fx.albedo_color.a = flash / 0.35 * 0.6
		if skel:
			_pose(sin(walk_t) * amp / 0.7)
		else: # iskeleti yok: yürürken yalnızca sallanır
			model.rotation.x = sin(walk_t) * 0.06 * amp
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
	shout_t = maxf(shout_t - dt, 0.0)
	blind_t = maxf(blind_t - dt, 0.0)
	if quote_lbl and quote_lbl.visible:
		quote_t -= dt
		quote_lbl.visible = quote_t > 0.0
	body_mat.albedo_color = base_col.lerp(Color(1, 0.1, 0.1), flash / 0.35)
	body_mat.emission_enabled = flash > 0.0 or shout_t > 0.0
	body_mat.emission = Color(1, 0, 0) * (flash / 0.35) if flash > 0.0 else Color(1.0, 0.5, 0.1) * 0.6 # turuncu: bağırdı, güçlü


## İskelet duruşu. s: -1..1 adım salınımı. Model uzayı: +X ön, +Z sağ; Z ekseninde + dönüş uzvu öne atar.
func _pose(s: float) -> void:
	var z := Vector3(0, 0, 1)
	_bone(Rig.LEG_R, Quaternion(z, s * 0.6))
	_bone(Rig.SHIN_R, Quaternion(z, -maxf(-s, 0.0) * 0.8)) # arkada kalan bacak dizden bükülür
	_bone(Rig.LEG_L, Quaternion(z, -s * 0.6))
	_bone(Rig.SHIN_L, Quaternion(z, -maxf(s, 0.0) * 0.8))
	_bone(Rig.HEAD, Quaternion(z, look.rotation.x * 0.6))
	_bone(Rig.ARM_L, Quaternion(z, s * 0.5) * arm_down[1])
	_bone(Rig.FORE_L, arm_straight[1])
	_bone(Rig.FORE_R, arm_straight[0])
	if slot == 2 or hp <= 0: # elinde bir şey yok: kol sarkar ve sallanır
		_bone(Rig.ARM_R, Quaternion(z, -s * 0.5) * arm_down[0])
	else: # silah elde: kol baktığı yere uzanır
		_bone(Rig.ARM_R, Quaternion(arm_dir, _aim_dir(look.rotation.x)))


func _bone(i: int, q: Quaternion) -> void:
	skel.set_bone_pose_rotation(i, skel.get_bone_pose_rotation(i).slerp(q, 0.3)) # yumuşak geçiş


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
	apply_blast(pos, BLAST_RADIUS, SHOUT_DMG if shout_t > 0.0 else DAMAGE) # Pazarcı pasifi


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
	if randf() < ch.get("dodge", 0.0): # Keloğlan pasifi
		say.rpc("Kafadan sekti!")
		return
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
	shout_t = 0.0
	blind_t = 0.0
	still_t = 0.0
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
