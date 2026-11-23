extends Node
## Açık Dünya Modu: 180x180 m geniş orman, 8 girilebilir ev ve içlerinde ganimet kutuları,
## 48 rastgele karakter muhafızı (kendi Q yeteneklerini kullanan), 30 yaratık, dinamik gece/gündüz,
## XP / seviye kartları (evrim dahil) ve tam 5+15 envanter sistemi.

signal toast(text: String, color: Color)

const EnemyScript := preload("res://enemy.gd")
const RivalScript := preload("res://rival.gd")
const Balance := preload("res://balance.gd")
const Weapons := preload("res://weapons.gd")
const Chars := preload("res://characters.gd")
const Fx := preload("res://explosion.gd")

const PLAYER_START := Vector3(0, 1, 0)
const DAY_LEN := 180.0 # tam gece-gündüz döngüsü (sn)

## 8 girilebilir ev (konum, ön kapı yönü yaw, duvar/çatı rengi).
const HOUSES := [
	{"id": "h0", "name": "Orman Kulübesi", "pos": Vector3(0, 0, -24), "yaw": 0.0, "wall": Color(0.55, 0.40, 0.25), "roof": Color(0.45, 0.17, 0.12)},
	{"id": "h1", "name": "Avcı Evi", "pos": Vector3(-38, 0, -28), "yaw": 0.45, "wall": Color(0.49, 0.36, 0.23), "roof": Color(0.22, 0.34, 0.20)},
	{"id": "h2", "name": "Değirmen Konağı", "pos": Vector3(42, 0, -34), "yaw": -0.5, "wall": Color(0.58, 0.48, 0.34), "roof": Color(0.48, 0.22, 0.14)},
	{"id": "h3", "name": "Batı Karakolu", "pos": Vector3(-56, 0, 14), "yaw": 1.4, "wall": Color(0.47, 0.45, 0.41), "roof": Color(0.22, 0.27, 0.36)},
	{"id": "h4", "name": "Doğu Çiftliği", "pos": Vector3(54, 0, 18), "yaw": -1.5, "wall": Color(0.56, 0.42, 0.26), "roof": Color(0.50, 0.18, 0.14)},
	{"id": "h5", "name": "Güney Hanı", "pos": Vector3(-28, 0, 52), "yaw": 2.7, "wall": Color(0.53, 0.37, 0.24), "roof": Color(0.38, 0.16, 0.22)},
	{"id": "h6", "name": "Göl Kıyısı Evi", "pos": Vector3(34, 0, 56), "yaw": -2.6, "wall": Color(0.48, 0.40, 0.30), "roof": Color(0.19, 0.35, 0.38)},
	{"id": "h7", "name": "Kuzey Kalesi", "pos": Vector3(0, 0, -68), "yaw": 0.0, "wall": Color(0.45, 0.43, 0.47), "roof": Color(0.28, 0.16, 0.36)},
]

## 5 yaratık kampı (orman açıklıkları).
const CAMPS := [
	{"id": "c0", "pos": Vector3(-26, 0, 14), "types": ["grunt", "grunt", "runner", "runner", "spitter", "knight"]},
	{"id": "c1", "pos": Vector3(28, 0, 12), "types": ["grunt", "runner", "spitter", "bomber", "brute", "grunt"]},
	{"id": "c2", "pos": Vector3(-54, 0, -56), "types": ["runner", "spitter", "bomber", "knight", "brute", "ogre"]},
	{"id": "c3", "pos": Vector3(56, 0, -58), "types": ["grunt", "bomber", "knight", "brute", "ogre", "spitter"]},
	{"id": "c4", "pos": Vector3(0, 0, 68), "types": ["grunt", "runner", "knight", "brute", "ogre", "boss"]},
]

## 4 ek karakter devriye noktası (ev dışı 16 karakter muhafızı -> toplam 48 eşsiz karakter).
const OUTPOSTS := [
	{"id": "o0", "pos": Vector3(-24, 0, -54)},
	{"id": "o1", "pos": Vector3(26, 0, -54)},
	{"id": "o2", "pos": Vector3(-56, 0, 48)},
	{"id": "o3", "pos": Vector3(56, 0, 48)},
]

## Forest.spawns için ağaçsız bırakılacak tüm noktalar.
const LANDMARKS := [
	Vector3(0, 0, 0),
	Vector3(0, 0, -24), Vector3(-38, 0, -28), Vector3(42, 0, -34), Vector3(-56, 0, 14),
	Vector3(54, 0, 18), Vector3(-28, 0, 52), Vector3(34, 0, 56), Vector3(0, 0, -68),
	Vector3(-26, 0, 14), Vector3(28, 0, 12), Vector3(-54, 0, -56), Vector3(56, 0, -58), Vector3(0, 0, 68),
	Vector3(-24, 0, -54), Vector3(26, 0, -54), Vector3(-56, 0, 48), Vector3(56, 0, 48),
]

## Silah/eşya kutu ganimet havuzu (sıra dışı çeşitlilik için kademeli).
const EARLY_WEAPONS := ["pistol", "shotgun", "smg", "bow"]
const LATE_WEAPONS := ["sniper", "boomerang", "flame", "bazooka", "grenade"]

var is_open_world := true # player.gd bunu okuyup yalnız Kılıç ile başlatır
var state := "fight"
var wave := 1
var money := 0
var xp := 0
var xp_next := 55
var level := 1
var kills := 0
var rivals_killed := 0
var rivals_total := 0
var monsters_killed := 0
var monsters_total := 0
var crates_opened := 0
var crates_total := 0
var elapsed := 0.0

## Gece / gündüz durumu (0.0 şafak, 0.25 öğle, 0.55 gün batımı, 0.78 gece yarısı).
var day_t := 0.16
var is_night := false

var elist: Array = []
var plist: Array = []
var _by_id := {} # "E12" -> Enemy veya Rival
var _eid := 0

var houses_data: Array = [] # minimap için: {id, name, pos, yaw}
var crates: Array = [] # {id, pos, node, opened, tier, house_name, glow}
var nearby_crate: Dictionary = {}
var _orbs: Array = [] # {node, pos, t, heal}
var _house_lights: Array = []
var _win_mats: Array = []
var _sun: DirectionalLight3D
var _env: Environment
var _base_env := {}
var _camp_light: OmniLight3D
var _respawn_t := 0.0
var _loot_rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("td")
	add_to_group("open_world")
	_loot_rng.seed = int(Time.get_ticks_msec()) ^ 0x51A7E
	_find_lighting()
	_build_spawn_camp()
	_build_houses_and_crates()
	_spawn_rivals()
	_spawn_monsters()
	call_deferred("_welcome")


func _welcome() -> void:
	toast.emit("Açık Dünyaya Hoş Geldin! Evlerdeki kutuları [E] ile aç, 48 karakter muhafızı ve yaratıklarla savaş!", Color(0.55, 0.95, 0.65))


func _find_lighting() -> void:
	var w := get_parent()
	if w == null:
		return
	var suns := w.find_children("*", "DirectionalLight3D", true, false)
	if not suns.is_empty():
		_sun = suns[0] as DirectionalLight3D
		_base_env["sun_e"] = _sun.light_energy
		_base_env["sun_c"] = _sun.light_color
		_base_env["sun_rot"] = _sun.rotation_degrees
	var wes := w.find_children("*", "WorldEnvironment", true, false)
	if not wes.is_empty():
		_env = (wes[0] as WorldEnvironment).environment
		if _env:
			_base_env["amb_e"] = _env.ambient_light_energy
			_base_env["amb_c"] = _env.ambient_light_color
			_base_env["fog_c"] = _env.fog_light_color
			_base_env["fog_e"] = _env.fog_light_energy
			_base_env["vfog_c"] = _env.volumetric_fog_albedo
			_base_env["vfog_d"] = _env.volumetric_fog_density
			_base_env["exp"] = _env.tonemap_exposure


# ---------- Başlangıç kampı ve 8 girilebilir ev + kutular ----------

func _mat(c: Color, rough := 0.85, metal := 0.0, emit := Color.BLACK, emit_e := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit_e > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = emit_e
	return m


func _solid_box(parent: Node3D, pos: Vector3, sz: Vector3, mat: Material, rot := Vector3.ZERO) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	b.rotation = rot
	b.collision_layer = 1
	b.collision_mask = 0
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = mat
	b.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = sz
	cs.shape = sh
	b.add_child(cs)
	parent.add_child(b)
	return b


func _vis_box(parent: Node3D, pos: Vector3, sz: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _build_spawn_camp() -> void:
	var root := Node3D.new()
	root.name = "SpawnCamp"
	get_parent().add_child(root)
	var stone := _mat(Color(0.45, 0.44, 0.42), 0.92)
	var wood := _mat(Color(0.38, 0.24, 0.14), 0.9)
	# Başlangıç kamp ateşi: oyuncunun ön-solunda sıcak referans noktası
	var fire_pos := Vector3(-4.2, 0.0, -5.2)
	for i in 8:
		var ang := i * TAU / 8.0
		_vis_box(root, fire_pos + Vector3(cos(ang) * 0.72, 0.14, sin(ang) * 0.72), Vector3(0.34, 0.28, 0.34), stone, Vector3(0, ang, 0))
	for a in [0.3, -0.6, 1.1]:
		_vis_box(root, fire_pos + Vector3(0, 0.12, 0), Vector3(0.18, 0.16, 1.1), wood, Vector3(0.12, a, 0))
	var flame := _vis_box(root, fire_pos + Vector3(0, 0.42, 0), Vector3(0.32, 0.56, 0.32),
		_mat(Color(1.0, 0.55, 0.15), 0.4, 0.0, Color(1.0, 0.52, 0.12), 2.8), Vector3(0, 0.4, 0))
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_camp_light = OmniLight3D.new()
	_camp_light.position = fire_pos + Vector3(0, 1.25, 0)
	_camp_light.light_color = Color(1.0, 0.62, 0.25)
	_camp_light.light_energy = 1.6
	_camp_light.omni_range = 14.0
	_camp_light.shadow_enabled = false
	root.add_child(_camp_light)
	# Başlangıçta 1 adet yakın ikmal kutusu (oyuncu hemen ilk silahını alabilsin!)
	_spawn_crate(Vector3(4.2, 0.0, -6.2), 0, "Başlangıç Kampı")


func _build_houses_and_crates() -> void:
	var root := Node3D.new()
	root.name = "Houses"
	get_parent().add_child(root)
	for i in HOUSES.size():
		var h: Dictionary = HOUSES[i]
		houses_data.append({"id": h.id, "name": h.name, "pos": h.pos, "yaw": h.yaw})
		_build_house(root, h, i)
	crates_total = crates.size()


func _build_house(root: Node3D, h: Dictionary, idx: int) -> void:
	var node := Node3D.new()
	node.name = "House_" + h.id
	node.position = h.pos
	node.rotation.y = h.yaw
	root.add_child(node)

	var w := 8.2 # genişlik (X)
	var d := 7.0 # derinlik (Z)
	var wh := 3.4 # duvar yüksekliği
	var t := 0.32 # duvar kalınlığı
	var door_w := 2.4 # rahat girilebilir geniş kapı
	var door_h := 2.65

	var wall_m := _mat(h.wall, 0.88)
	var trim_m := _mat(Color(0.28, 0.19, 0.12), 0.86)
	var floor_m := _mat(Color(0.36, 0.25, 0.16), 0.82)
	var roof_m := _mat(h.roof, 0.78)
	var stone_m := _mat(Color(0.46, 0.44, 0.42), 0.92)
	var rug_m := _mat(h.roof.lightened(0.18), 0.95)
	var win_m := _mat(Color(0.95, 0.82, 0.50), 0.25, 0.0, Color(1.0, 0.76, 0.32), 0.45)
	_win_mats.append(win_m)

	# Ahşap zemin + ön basamak (alçak eşik -> oyuncu takılmadan yürüyüp girer)
	_solid_box(node, Vector3(0, 0.07, 0), Vector3(w + 0.3, 0.14, d + 0.3), floor_m)
	_solid_box(node, Vector3(0, 0.04, d * 0.5 + 0.55), Vector3(door_w + 0.8, 0.08, 0.9), stone_m)
	_vis_box(node, Vector3(0, 0.155, 0.2), Vector3(3.6, 0.02, 2.8), rug_m)

	# Arka, sol ve sağ duvarlar (katı)
	_solid_box(node, Vector3(0, wh * 0.5, -d * 0.5), Vector3(w, wh, t), wall_m)
	_solid_box(node, Vector3(-w * 0.5, wh * 0.5, 0), Vector3(t, wh, d), wall_m)
	_solid_box(node, Vector3(w * 0.5, wh * 0.5, 0), Vector3(t, wh, d), wall_m)

	# Ön duvar: ortada açık kapı boşluğu (sol + sağ kanat + üst lento)
	var side_w := (w - door_w) * 0.5
	_solid_box(node, Vector3(-(door_w * 0.5 + side_w * 0.5), wh * 0.5, d * 0.5), Vector3(side_w, wh, t), wall_m)
	_solid_box(node, Vector3(door_w * 0.5 + side_w * 0.5, wh * 0.5, d * 0.5), Vector3(side_w, wh, t), wall_m)
	var lintel_h := wh - door_h
	_solid_box(node, Vector3(0, door_h + lintel_h * 0.5, d * 0.5), Vector3(door_w + 0.2, lintel_h, t), trim_m)
	# Kapı çerçevesi direkleri
	_vis_box(node, Vector3(-door_w * 0.5, door_h * 0.5, d * 0.5 + 0.05), Vector3(0.18, door_h, 0.38), trim_m)
	_vis_box(node, Vector3(door_w * 0.5, door_h * 0.5, d * 0.5 + 0.05), Vector3(0.18, door_h, 0.38), trim_m)

	# 4 köşe ahşap sütun
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_vis_box(node, Vector3(sx * w * 0.5, wh * 0.5, sz * d * 0.5), Vector3(0.42, wh + 0.1, 0.42), trim_m)

	# Beşik çatı (iki eğimli kanat + üst mahya + ön/arka alınlık + baca)
	var slope := 0.46
	var half_span := w * 0.58
	_solid_box(node, Vector3(-w * 0.26, wh + 0.85, 0), Vector3(half_span, 0.24, d + 1.1), roof_m, Vector3(0, 0, slope))
	_solid_box(node, Vector3(w * 0.26, wh + 0.85, 0), Vector3(half_span, 0.24, d + 1.1), roof_m, Vector3(0, 0, -slope))
	_vis_box(node, Vector3(0, wh + 1.88, 0), Vector3(0.36, 0.36, d + 1.15), trim_m)
	# Alınlık dolgu kirişleri
	for sz in [-d * 0.5, d * 0.5]:
		_vis_box(node, Vector3(0, wh + 0.42, sz), Vector3(w * 0.72, 0.82, 0.24), wall_m)
		_vis_box(node, Vector3(0, wh + 1.10, sz), Vector3(w * 0.36, 0.65, 0.24), wall_m)
	# Taş baca
	_vis_box(node, Vector3(w * 0.26, wh + 1.9, -d * 0.25), Vector3(0.85, 2.2, 0.85), stone_m)

	# Parlayan pencereler (ön iki yan + sol/sağ cephe; gece parlaklaşır)
	for wx in [-2.65, 2.65]:
		_vis_box(node, Vector3(wx, 1.85, d * 0.5 + 0.14), Vector3(1.15, 1.05, 0.08), trim_m)
		_vis_box(node, Vector3(wx, 1.85, d * 0.5 + 0.17), Vector3(0.95, 0.85, 0.06), win_m)
	for sx in [-1.0, 1.0]:
		_vis_box(node, Vector3(sx * (w * 0.5 + 0.14), 1.85, 0.0), Vector3(0.08, 1.05, 1.5), trim_m)
		_vis_box(node, Vector3(sx * (w * 0.5 + 0.17), 1.85, 0.0), Vector3(0.06, 0.85, 1.28), win_m)

	# İç mekan dekoru: arka duvarda ahşap masa + tavan feneri + kapı üstü fener
	_vis_box(node, Vector3(0, 0.82, -d * 0.5 + 0.85), Vector3(2.2, 0.12, 0.9), trim_m)
	for lx in [-0.95, 0.95]:
		_vis_box(node, Vector3(lx, 0.42, -d * 0.5 + 0.85), Vector3(0.12, 0.76, 0.72), trim_m)
	_vis_box(node, Vector3(0, 3.05, d * 0.5 + 0.36), Vector3(0.26, 0.36, 0.26), win_m)

	# Sıcak iç/veranda ışığı (geceleri parlar; gölgesiz = çok hızlı performans)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.65, 0.6)
	light.light_color = Color(1.0, 0.72, 0.34)
	light.light_energy = 0.55
	light.omni_range = 15.0
	light.shadow_enabled = false
	node.add_child(light)
	_house_lights.append(light)

	# Ev tabelası (kapı fenerinin üstünde net okunur)
	var sign_lbl := Label3D.new()
	sign_lbl.text = h.name
	sign_lbl.position = Vector3(0, 3.85, d * 0.5 + 0.35)
	sign_lbl.font_size = 34
	sign_lbl.outline_size = 10
	sign_lbl.modulate = Color(1.0, 0.94, 0.76)
	sign_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_lbl.no_depth_test = false
	node.add_child(sign_lbl)

	# Evin İÇİNDE 2–3 adet ganimet kutusu yerleştir (biri kapıdan içeri bakınca görünür!)
	var tier := 0 if idx < 3 else (1 if idx < 6 else 2)
	var local_spots := [
		Vector3(-2.4, 0.14, -1.7),
		Vector3(0.95, 0.14, -1.6),
	]
	if idx in [0, 2, 5, 7]: # büyük/önemli evlerde 3. bonus kutu!
		local_spots.append(Vector3(2.4, 0.14, 1.3))
	var xf := Transform3D(Basis(Vector3.UP, h.yaw), h.pos)
	for lp in local_spots:
		_spawn_crate(xf * lp, tier, h.name)


func _spawn_crate(pos: Vector3, tier: int, house_name: String) -> void:
	var cid := crates.size()
	var root := Node3D.new()
	root.name = "Crate_%d" % cid
	root.position = pos
	get_parent().add_child(root)

	var wood_c := Color(0.54, 0.36, 0.18) if tier == 0 else (Color(0.42, 0.32, 0.24) if tier == 1 else Color(0.32, 0.22, 0.38))
	var accent := Color(0.35, 0.90, 1.0) if tier == 0 else (Color(1.0, 0.78, 0.22) if tier == 1 else Color(0.95, 0.42, 1.0))
	var body_m := _mat(wood_c, 0.75, 0.08)
	var iron_m := _mat(Color(0.24, 0.26, 0.30), 0.42, 0.72)
	var glow_m := _mat(accent, 0.2, 0.1, accent, 2.2)

	# Sandık gövdesi + demir kuşaklar + parlayan kilit + üst işaretçi
	_vis_box(root, Vector3(0, 0.42, 0), Vector3(0.96, 0.84, 0.96), body_m)
	_vis_box(root, Vector3(0, 0.84, 0), Vector3(1.04, 0.10, 1.04), iron_m)
	_vis_box(root, Vector3(0, 0.42, 0), Vector3(1.02, 0.12, 1.02), iron_m)
	_vis_box(root, Vector3(0, 0.48, 0.49), Vector3(0.22, 0.26, 0.08), glow_m)
	var beacon := _vis_box(root, Vector3(0, 1.28, 0), Vector3(0.18, 0.18, 0.18), glow_m, Vector3(0.6, 0.8, 0.6))
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	crates.append({
		"id": cid, "pos": pos, "node": root, "beacon": beacon,
		"opened": false, "tier": tier, "house": house_name, "accent": accent,
	})


# ---------- 48 Rastgele Karakter Muhafızı & 30 Yaratık ----------

func _spawn_rivals() -> void:
	var pool: Array[int] = []
	for i in Chars.LIST.size():
		if i != Net.my_char:
			pool.append(i)
	# Fisher-Yates karıştırma (her maçta farklı 48 rastgele karakter!)
	for i in range(pool.size() - 1, 0, -1):
		var j := _loot_rng.randi_range(0, i)
		var tmp := pool[i]; pool[i] = pool[j]; pool[j] = tmp

	var cursor := 0
	# 8 ev x 4 karakter muhafızı = 32 ev muhafızı (her evin 1 lideri elit!)
	for h in HOUSES:
		var xf := Transform3D(Basis(Vector3.UP, h.yaw), h.pos)
		var offsets := [
			Vector3(0.0, 0, 6.2),   # ön kapı lideri (elit)
			Vector3(-6.2, 0, 2.2),  # sol yan
			Vector3(6.2, 0, 2.2),   # sağ yan
			Vector3(0.0, 0, -6.2),  # arka bahçe
		]
		for k in offsets.size():
			if cursor >= pool.size():
				break
			var wp: Vector3 = xf * offsets[k]
			_add_rival(pool[cursor], wp, h.id, k == 0, 14.5 if h.id == "h0" else 16.0)
			cursor += 1

	# 4 orman devriye noktası x 4 karakter muhafızı = 16 devriye muhafızı -> TOPLAM 48 karakter!
	for op in OUTPOSTS:
		for k in 4:
			if cursor >= pool.size():
				break
			var ang := k * TAU / 4.0 + 0.35
			var wp: Vector3 = op.pos + Vector3(cos(ang), 0, sin(ang)) * 5.2
			_add_rival(pool[cursor], wp, op.id, k == 0, 16.5)
			cursor += 1
	rivals_total = cursor


func _add_rival(cidx: int, pos: Vector3, camp: String, is_elite: bool, aggro_dist: float) -> void:
	_eid += 1
	var r: CharacterBody3D = RivalScript.new()
	r.name = "E%d" % _eid
	r.eid = _eid
	r.char_idx = cidx
	r.elite = is_elite
	r.td = self
	r.home_pos = Vector3(pos.x, 0.0, pos.z)
	r.position = Vector3(pos.x, 0.1, pos.z)
	r.aggro_r = aggro_dist
	r.leash_r = 40.0
	r.camp_id = camp
	get_parent().add_child(r)
	_by_id[r.name] = r
	elist.append(r)


func _spawn_monsters() -> void:
	var count := 0
	for camp in CAMPS:
		var types: Array = camp.types
		for k in types.size():
			var ang := k * TAU / maxf(types.size(), 1)
			var dist := 0.0 if types[k] == "boss" else randf_range(3.5, 8.5)
			var pos: Vector3 = camp.pos + Vector3(cos(ang), 0, sin(ang)) * dist
			_add_monster(str(types[k]), pos, camp.id)
			count += 1
	monsters_total = count


func _add_monster(kind: String, pos: Vector3, camp: String) -> void:
	_eid += 1
	var ed: Dictionary = Balance.ENEMIES[kind]
	var e: CharacterBody3D = EnemyScript.new()
	e.name = "E%d" % _eid
	e.eid = _eid
	e.type = kind
	e.hp = roundi(float(ed.hp) * (2.6 if kind == "boss" else 1.15))
	e.dmg = roundi(float(ed.dmg) * (1.3 if kind == "boss" else 1.0))
	e.td = self
	e.home_pos = Vector3(pos.x, 0.0, pos.z)
	e.position = Vector3(pos.x, 0.1, pos.z)
	e.aggro_r = 22.0 if kind == "boss" else 16.5
	e.leash_r = 48.0 if kind == "boss" else 42.0
	e.camp_id = camp
	get_parent().add_child(e)
	_by_id[e.name] = e
	elist.append(e)


# ---------- Her kare: Gece/Gündüz, Kutular, Küreler ve Yeniden Doğuş ----------

func _process(dt: float) -> void:
	elapsed += dt
	_sync_lists()
	_update_day_night(dt)
	_update_crates(dt)
	_update_orbs(dt)
	_update_respawn(dt)


func _sync_lists() -> void:
	var ps := get_parent().get_node_or_null("Players")
	plist = ps.get_children() if ps else []
	elist = elist.filter(func(e): return is_instance_valid(e) and e.hp > 0)


func _player() -> Node3D:
	for p in plist:
		if is_instance_valid(p):
			return p as Node3D
	return null


func _update_day_night(dt: float) -> void:
	day_t = fmod(day_t + dt / DAY_LEN, 1.0)
	# daylight: 1.0 gündüz (day_t ~0.25), 0.0 gece yarısı (day_t ~0.75)
	var sun_sin := sin(day_t * TAU) # > 0 gündüz, < 0 gece
	var day_k := clampf((sun_sin + 0.18) / 0.55, 0.0, 1.0)
	var dusk_k := clampf(1.0 - absf(sun_sin) * 3.8, 0.0, 1.0) # şafak / gün batımı sıcak turuncu

	var now_night := day_k < 0.35
	if now_night != is_night:
		is_night = now_night
		if is_night:
			toast.emit("☾ GECE ÇÖKTÜ — Ev ışıkları yandı! Düşmanlar daha güçlü, +%50 XP!", Color(0.65, 0.78, 1.0))
		else:
			toast.emit("☀ ŞAFAK SÖKTÜ — Orman aydınlandı.", Color(1.0, 0.86, 0.45))

	if _sun and _base_env.has("sun_e"):
		var pitch := lerpf(-18.0, -52.0, day_k) if sun_sin >= -0.05 else lerpf(-22.0, -45.0, 1.0 - day_k)
		var yaw := lerpf(-48.0, 48.0, fmod(day_t + 0.25, 1.0))
		_sun.rotation_degrees = Vector3(pitch, yaw, 0.0)
		var day_col: Color = _base_env["sun_c"]
		var dusk_col := Color(1.0, 0.56, 0.28)
		var moon_col := Color(0.55, 0.68, 0.98)
		var c := moon_col.lerp(day_col, day_k).lerp(dusk_col, dusk_k * 0.65)
		_sun.light_color = c
		_sun.light_energy = lerpf(0.38, float(_base_env["sun_e"]), day_k)

	if _env and _base_env.has("amb_e"):
		_env.ambient_light_energy = lerpf(0.24, float(_base_env["amb_e"]), day_k)
		_env.ambient_light_color = Color(0.16, 0.22, 0.38).lerp(_base_env["amb_c"], day_k)
		_env.fog_light_color = Color(0.10, 0.14, 0.26).lerp(_base_env["fog_c"], day_k).lerp(Color(0.85, 0.45, 0.25), dusk_k * 0.4)
		_env.fog_light_energy = lerpf(0.45, float(_base_env["fog_e"]), day_k)
		_env.volumetric_fog_albedo = Color(0.22, 0.30, 0.52).lerp(_base_env["vfog_c"], day_k)
		_env.volumetric_fog_density = lerpf(0.0085, float(_base_env["vfog_d"]), day_k)
		_env.tonemap_exposure = lerpf(0.76, float(_base_env["exp"]), day_k)

	var night_k := 1.0 - day_k
	for l: OmniLight3D in _house_lights:
		if is_instance_valid(l):
			l.light_energy = lerpf(0.35, 3.0, night_k)
	for wm: StandardMaterial3D in _win_mats:
		wm.emission_energy_multiplier = lerpf(0.3, 2.4, night_k)
	if _camp_light and is_instance_valid(_camp_light):
		_camp_light.light_energy = lerpf(1.4, 3.4, night_k) + sin(elapsed * 9.0) * 0.22


func _update_crates(dt: float) -> void:
	var p := _player()
	var best := {}
	var best_d := 3.8
	for c in crates:
		if c.opened:
			continue
		var bc: Node3D = c.beacon
		if is_instance_valid(bc):
			bc.rotation.y += dt * 2.2
			bc.position.y = 1.25 + sin(elapsed * 3.0 + float(c.id)) * 0.12
		if p and p.hp > 0:
			var d := p.global_position.distance_to(c.pos)
			if d < best_d:
				best_d = d
				best = c
	nearby_crate = best


## Yakındaki ganimet kutusunu açar (open_world_ui.gd E tuşuyla çağırır). Açarsa true döner.
func try_open_nearby_crate() -> bool:
	if nearby_crate.is_empty() or nearby_crate.opened:
		return false
	var p := _player()
	if p == null or p.hp <= 0:
		return false
	_open_crate(nearby_crate, p)
	return true


func _open_crate(c: Dictionary, p: Node) -> void:
	c.opened = true
	crates_opened += 1
	nearby_crate = {}
	var pos: Vector3 = c.pos
	if is_instance_valid(c.node):
		c.node.queue_free()
	Sfx.play3d(Sfx.chime, pos, -2.0)
	var fx: Node3D = Fx.new()
	fx.position = pos + Vector3.UP * 0.5
	fx.scale = Vector3.ONE * 0.55
	get_parent().add_child(fx)

	# Oyuncunun henüz sahip olmadığı silahları belirle (böylece evleri gezdikçe tüm cephanelik açılır!)
	var owned := _owned_ids(p)
	var pool: Array[String] = []
	var primary_pool: Array = EARLY_WEAPONS if c.tier == 0 else (EARLY_WEAPONS + LATE_WEAPONS if c.tier == 1 else LATE_WEAPONS + EARLY_WEAPONS)
	for wid in primary_pool:
		if wid not in owned:
			pool.append(wid)
	var msgs := PackedStringArray()
	if not pool.is_empty():
		var pick := pool[_loot_rng.randi_range(0, pool.size() - 1)]
		if p.add_item({"kind": "weapon", "id": pick}):
			msgs.append(_weapon_label(pick))
	else:
		# Tüm silahlar varsa: ekipman (kalkan/duvar) veya mevcut bir silahı güçlendir!
		var eq := "shield" if "shield" not in owned else ("wall" if "wall" not in owned else "")
		if eq != "" and p.add_item({"kind": "equip", "id": eq}):
			msgs.append(tr(str(Weapons.EQUIPS[eq].name)))
		else:
			if p.add_item({"kind": "item", "id": "bomb", "count": 2}):
				msgs.append("El Bombası x2")
	# Her kutu ek olarak 1 adet Can İksiri veya Bomba bırakır
	var bonus_id := "potion" if _loot_rng.randf() < 0.68 else "bomb"
	if p.add_item({"kind": "item", "id": bonus_id, "count": 1}):
		msgs.append(tr(str(Weapons.ITEMS[bonus_id].name)))

	var gained_xp := _grant_xp(30)
	var loot_txt := " + ".join(msgs) if not msgs.is_empty() else "Çanta Dolu"
	toast.emit("✦ Kutu Açıldı (%s): %s  (+%d XP)" % [c.house, loot_txt, gained_xp], c.accent)


func _owned_ids(p: Node) -> Array[String]:
	var out: Array[String] = []
	for arr in [p.inv, p.bag]:
		for slot in arr:
			if slot is Dictionary and not slot.is_empty():
				out.append(str(slot.get("id", "")))
	return out


func _weapon_label(wid: String) -> String:
	for w in Weapons.LIST:
		if w.id == wid:
			return tr(str(w.name))
	return wid.capitalize()


# ---------- Can Küreleri ve Yeniden Doğuş ----------

func _drop_orb(pos: Vector3, heal: int) -> void:
	var n := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28; sm.height = 0.56
	n.mesh = sm
	n.material_override = _mat(Color(0.25, 1.0, 0.55), 0.2, 0.0, Color(0.25, 1.0, 0.55), 2.5)
	n.position = Vector3(pos.x, 0.55, pos.z)
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(n)
	_orbs.append({"node": n, "pos": n.position, "t": 0.0, "heal": heal})


func _update_orbs(dt: float) -> void:
	var p := _player()
	var keep := []
	for o in _orbs:
		if not is_instance_valid(o.node):
			continue
		o.t += dt
		if o.t > 24.0:
			o.node.queue_free()
			continue
		var n: Node3D = o.node
		n.position.y = 0.55 + sin(o.t * 4.2) * 0.14
		if p and p.hp > 0:
			var d := p.global_position.distance_to(n.position)
			if d < 5.5:
				n.position = n.position.lerp(p.global_position + Vector3.UP * 0.9, minf(1.0, dt * 8.0))
			if d < 1.6:
				p.gain(int(o.heal))
				Sfx.play2d(Sfx.chime, -10.0)
				n.queue_free()
				continue
		keep.append(o)
	_orbs = keep


func _update_respawn(dt: float) -> void:
	var p := _player()
	if p == null:
		return
	if p.hp <= 0:
		if _respawn_t <= 0.0:
			_respawn_t = 3.5
		else:
			_respawn_t -= dt
			if _respawn_t <= 0.0:
				p.respawn()
				toast.emit("Başlangıç kampında yeniden doğdun — eşyaların ve seviyen korundu!", Color(0.6, 0.95, 0.7))
	else:
		_respawn_t = 0.0


# ---------- XP ve Seviye Atlama ----------

func _grant_xp(base_amount: int) -> int:
	var amount := roundi(float(base_amount) * (1.5 if is_night else 1.0))
	xp += amount
	var p := _player()
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = roundi(55.0 * pow(1.26, level - 1))
		if p and p.has_method("level_up"):
			p.level_up()
		Sfx.play2d(Sfx.chime, -3.0)
		toast.emit("★ SEVİYE %d! Bir yükseltme kartı seç!" % level, Color(1.0, 0.85, 0.25))
	return amount


# ---------- TD / Savaş Sözleşmesi (player.gd, enemy.gd, rival.gd ile tam uyumlu) ----------

@rpc("any_peer", "call_local", "reliable")
func damage_enemy(enemy_name: String, amount: int, crit := false) -> void:
	var e = _by_id.get(enemy_name)
	if e == null or not is_instance_valid(e) or e.hp <= 0:
		return
	var arm: int = int(e.get("armor"))
	var n := maxi(maxi(amount - arm, ceili(amount * 0.4)), 1)
	var new_hp := maxi(int(e.hp) - n, 0)
	e.apply_hit(new_hp, n, crit)
	if e.hp <= 0:
		_on_killed(e)


@rpc("any_peer", "call_local", "reliable")
func effect_enemy(enemy_name: String, fx: Dictionary) -> void:
	var e = _by_id.get(enemy_name)
	if e == null or not is_instance_valid(e) or e.hp <= 0:
		return
	if fx.has("stun"):
		var t := float(fx.stun)
		e.slow_k = 0.0
		e.slow_t = maxf(float(e.slow_t), t)
		if e.has_method("stun_fx"):
			e.stun_fx(t)
	elif fx.has("slow"):
		var s: Array = fx.slow
		e.slow_k = minf(float(e.slow_k), float(s[0])) if float(e.slow_t) > 0.0 else float(s[0])
		e.slow_t = maxf(float(e.slow_t), float(s[1]))
	if fx.has("knock") and e is CharacterBody3D:
		var push: Vector3 = fx.knock
		e.global_position += Vector3(push.x, 0.0, push.z) * 0.14


func _on_killed(e: Node) -> void:
	_by_id.erase(e.name)
	kills += 1
	var pos: Vector3 = e.global_position
	var is_rival := str(e.get("type")) == "rival"
	if is_rival:
		rivals_killed += 1
		var is_elite := bool(e.get("elite"))
		var gained := _grant_xp(70 if is_elite else 38)
		_drop_orb(pos, 40 if is_elite else 28)
		if is_elite:
			var p := _player()
			if p and p.add_item({"kind": "item", "id": "potion"}):
				toast.emit("♛ Elit Muhafız Yenildi (%s)! +%d XP + Can İksiri" % [tr(str(e.ch.name)), gained], Color(1.0, 0.82, 0.30))
			else:
				toast.emit("♛ Elit Muhafız Yenildi (%s)! +%d XP" % [tr(str(e.ch.name)), gained], Color(1.0, 0.82, 0.30))
		if rivals_killed >= rivals_total and rivals_total > 0:
			toast.emit("🏆 TÜM 48 KARAKTER MUHAFIZI YENİLDİ! Açık dünyanın hakimi sensin!", Color(1.0, 0.86, 0.25))
	else:
		monsters_killed += 1
		var t := str(e.get("type"))
		var base_xp := 150 if t == "boss" else (48 if t in ["ogre", "brute"] else (28 if t in ["knight", "bomber"] else 18))
		var gained := _grant_xp(base_xp)
		if t == "boss" or _loot_rng.randf() < 0.45:
			_drop_orb(pos, 60 if t == "boss" else 22)
		if t == "boss":
			toast.emit("👑 GÜNEY BOSSU YENİLDİ! +%d XP!" % gained, Color(0.88, 0.52, 1.0))


@rpc("authority", "call_local", "unreliable")
func enemy_fx(eid: int, goal: Vector3) -> void:
	var e = _by_id.get("E%d" % eid)
	if e and is_instance_valid(e) and e.has_method("attack_fx"):
		e.attack_fx(goal)


func hit_player(tgt: Node, dmg: int) -> void:
	if tgt and is_instance_valid(tgt) and tgt.has_method("td_hit"):
		var mult := 1.15 if is_night else 1.0
		tgt.td_hit.rpc(maxi(roundi(float(dmg) * mult), 1))


func delayed_hit(tgt: Node, goal: Vector3, dmg: int, delay: float) -> void:
	var t := get_tree().create_timer(delay)
	t.timeout.connect(func():
		if is_instance_valid(tgt) and tgt.hp > 0 and tgt.global_position.distance_to(goal) < 2.2:
			hit_player(tgt, dmg))


func explode(e: Node) -> void:
	if not is_instance_valid(e) or e.hp <= 0:
		return
	var pos: Vector3 = e.global_position
	var fx: Node3D = Fx.new()
	fx.position = pos + Vector3.UP * 0.6
	fx.scale = Vector3.ONE * 1.1
	get_parent().add_child(fx)
	Sfx.play3d(Sfx.boom, pos, -2.0)
	for p in plist:
		if is_instance_valid(p) and p.hp > 0 and p.global_position.distance_to(pos) < 4.5:
			hit_player(p, int(e.get("dmg")) * 2)
	_by_id.erase(e.name)
	elist.erase(e)
	e.apply_hit(0, -1, false)


func hurt_tower(_dmg: int) -> void:
	pass


func hurt_build(_tgt: Node, _dmg: int) -> void:
	pass


func can_place(_id: String, _pos: Vector3) -> bool:
	return false
