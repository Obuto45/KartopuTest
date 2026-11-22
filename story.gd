extends Node
## Açık Dünya Hikaye Modu ("ORMANIN GÖLGESİ"): 150x150 m ormanda silahsız başlangıç, köy kampı,
## 4 etkileşimli NPC, 7 aşamalı mantıklı silah ilerlemesi (Kılıç -> Tabanca/Yay -> Pompalı/Kalkan -> Bazuka)
## ve 4 yaratık kampı + final boss (Orman Lordu).
## "td" grubundadır: player.gd ve enemy.gd savaş/envanter mekanikleri doğrudan çalışır.

signal story_updated
signal dialog_requested(speaker: String, role: String, lines: Array)
signal toast_requested(title: String, sub: String, color: Color)
signal story_won

const Balance := preload("res://balance.gd")
const EnemyScript := preload("res://enemy.gd")
const Fx := preload("res://explosion.gd")
const Weapons := preload("res://weapons.gd")

const VILLAGE := Vector3(0.0, 0.0, 48.0)
const PLAYER_START := Vector3(0.0, 1.0, 54.0)
const GOBLIN_CAMP := Vector3(-42.0, 0.0, 10.0)
const RUINS := Vector3(44.0, 0.0, 8.0)
const GROVE := Vector3(0.0, 0.0, -6.0)
const ALTAR := Vector3(0.0, 0.0, -52.0)
const LANDMARKS := [VILLAGE, GOBLIN_CAMP, RUINS, GROVE, ALTAR]

var is_story := true
var state := "fight" # enemy.gd ile uyumlu ("fight" | "won")
var stage := 0 # 0..7 hikaye aşaması
var kills := 0
var elapsed_t := 0.0
var boss_eid := 0

var enemies: Node3D
var props: Node3D
var npcs_node: Node3D
var elist: Array = []
var plist: Array = []
var _by_id := {}
var _eid := 0
var _plist_t := 0.0
var _npcs := {} # id -> {node, model, anim, pos, name, role, marker}
var _camp_left := {"goblin": 0, "ruins": 0, "grove": 0, "boss": 0}
var _camp_total := {"goblin": 5, "ruins": 5, "grove": 6, "boss": 4}
var _beacon: Node3D
var _crystal: MeshInstance3D
var _crystal_light: OmniLight3D
var _altar_light: OmniLight3D
var _fires := [] # [OmniLight3D, taban enerji, faz]
var _chests := [] # {id, pos, title, items, node, light, marker, opened}
var _orbs := [] # {node, pos} — elit düşmanlardan düşen can küreleri
var _camp_heal_t := 0.0
var _pending_action: Callable


func _ready() -> void:
	add_to_group("td")
	add_to_group("story")
	var world := get_parent()
	enemies = Node3D.new()
	enemies.name = "Enemies"
	props = Node3D.new()
	props.name = "StoryProps"
	npcs_node = Node3D.new()
	npcs_node.name = "NPCs"
	for n in [props, npcs_node, enemies]:
		world.add_child(n)
	_build_landmarks()
	_spawn_npcs()
	_spawn_chests()
	_build_beacon()
	_spawn_camp("goblin")
	_spawn_camp("ruins")
	_spawn_camp("grove")
	_refresh_markers()
	story_updated.emit()
	# Oyuncu doğduktan hemen sonra açılış mesajı
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if is_instance_valid(self):
			toast_requested.emit("BÖLÜM I — UYANIŞ", "Köy kampında Muhtar Arda ile konuş (E)", Color(1.0, 0.80, 0.32)))


func _physics_process(dt: float) -> void:
	if state == "fight":
		elapsed_t += dt
	_plist_t -= dt
	if _plist_t <= 0.0:
		_plist_t = 0.25
		var pl := get_parent().get_node_or_null("Players")
		plist = pl.get_children() if pl else []
	elist = elist.filter(func(e): return is_instance_valid(e) and e.hp > 0)
	_animate_world(dt)


func _animate_world(dt: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for f in _fires:
		var l: OmniLight3D = f[0]
		if is_instance_valid(l):
			l.light_energy = f[1] * (0.9 + 0.14 * sin(t * 7.5 + f[2]) + 0.08 * cos(t * 13.0))
	if is_instance_valid(_crystal):
		_crystal.rotate_y(dt * 0.9)
		_crystal.position.y = 2.3 + sin(t * 2.2) * 0.22
	if is_instance_valid(_beacon):
		var target := objective_pos()
		_beacon.visible = stage < 7 and target != Vector3.ZERO
		if _beacon.visible:
			_beacon.position = Vector3(target.x, 0.0, target.z)
			var gem: Node3D = _beacon.get_child(1)
			gem.position.y = 4.2 + sin(t * 3.0) * 0.35
			gem.rotate_y(dt * 1.8)
	var me := _player()
	if me:
		# Köy kamp ateşi sıcaklığı: yaralıyken ateşin yanında durmak yavaşça iyileştirir
		if me.hp > 0 and me.hp < me.max_hp and me.global_position.distance_to(VILLAGE) < 6.5:
			_camp_heal_t += dt
			if _camp_heal_t >= 1.0:
				_camp_heal_t -= 1.0
				me.set_hp(mini(me.hp + 6, me.max_hp))
		else:
			_camp_heal_t = 0.0
		# Yerdeki can küreleri: yaklaşınca otomatik toplanır
		for i in range(_orbs.size() - 1, -1, -1):
			var orb: Dictionary = _orbs[i]
			var nd: Node3D = orb.node
			if not is_instance_valid(nd):
				_orbs.remove_at(i)
				continue
			nd.rotate_y(dt * 2.5)
			nd.position.y = 0.65 + sin(t * 3.5 + i) * 0.14
			if me.hp > 0 and me.global_position.distance_to(orb.pos) < 2.2:
				me.set_hp(mini(me.hp + 35, me.max_hp))
				_aura_fx(me.global_position, Color(0.32, 0.96, 0.55))
				Sfx.play2d(Sfx.chime, -5.0)
				nd.queue_free()
				_orbs.remove_at(i)
		for id in _npcs:
			var n: Dictionary = _npcs[id]
			var nd: Node3D = n.node
			var to: Vector3 = me.global_position - nd.global_position
			to.y = 0.0
			if to.length() < 8.5 and to.length() > 0.2:
				nd.rotation.y = lerp_angle(nd.rotation.y, atan2(to.x, to.z), minf(1.0, dt * 5.0))


func _player() -> Node3D:
	var pl := get_parent().get_node_or_null("Players")
	return pl.get_node_or_null(str(multiplayer.get_unique_id())) if pl else null


# ---------- 3B Harita Bölgeleri ve Dekorlar ----------

func _mat(c: Color, rough := 0.85, emit := 0.0, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _mesh_box(sz: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO, collide := false) -> Node3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = sz
	mi.mesh = b
	mi.material_override = mat
	if collide:
		var sb := StaticBody3D.new()
		sb.position = pos
		sb.rotation = rot
		sb.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = sz
		cs.shape = sh
		sb.add_child(cs)
		props.add_child(sb)
		return sb
	mi.position = pos
	mi.rotation = rot
	props.add_child(mi)
	return mi


func _mesh_cyl(r0: float, r1: float, h: float, pos: Vector3, mat: Material, seg := 10, rot := Vector3.ZERO, collide := false) -> Node3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r0; c.bottom_radius = r1; c.height = h; c.radial_segments = seg
	mi.mesh = c
	mi.material_override = mat
	if collide:
		var sb := StaticBody3D.new()
		sb.position = pos
		sb.rotation = rot
		sb.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = maxf(r0, r1); sh.height = h
		cs.shape = sh
		sb.add_child(cs)
		props.add_child(sb)
		return sb
	mi.position = pos
	mi.rotation = rot
	props.add_child(mi)
	return mi


func _campfire(pos: Vector3, energy := 2.2) -> void:
	var stone := _mat(Color(0.36, 0.34, 0.32), 0.92)
	var wood := _mat(Color(0.28, 0.16, 0.08), 0.92)
	var ember := _mat(Color(1.0, 0.42, 0.08), 0.4, 3.2)
	for i in 10:
		var a := TAU * i / 10.0
		_mesh_cyl(0.22, 0.28, 0.24, pos + Vector3(cos(a) * 0.85, 0.12, sin(a) * 0.85), stone, 6)
	for i in 4:
		_mesh_cyl(0.08, 0.1, 1.1, pos + Vector3(0, 0.14, 0), wood, 6, Vector3(0.25, i * PI * 0.25, PI * 0.5))
	_mesh_cyl(0.35, 0.48, 0.18, pos + Vector3(0, 0.1, 0), ember, 8)
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0, 1.1, 0)
	l.light_color = Color(1.0, 0.62, 0.24)
	l.light_energy = energy
	l.omni_range = 14.0
	l.shadow_enabled = false
	props.add_child(l)
	_fires.append([l, energy, randf() * 10.0])
	# Yükselen alev kıvılcımları
	var p := CPUParticles3D.new()
	p.position = pos + Vector3(0, 0.35, 0)
	p.amount = 18
	p.lifetime = 1.4
	p.direction = Vector3.UP
	p.spread = 22.0
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = 0.7
	p.initial_velocity_max = 1.6
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.14
	var m := SphereMesh.new()
	m.radius = 0.5; m.height = 1.0; m.radial_segments = 6; m.rings = 3
	m.material = ember
	p.mesh = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	props.add_child(p)


func _build_landmarks() -> void:
	var wood := _mat(Color(0.36, 0.22, 0.12), 0.9)
	var plank := _mat(Color(0.46, 0.30, 0.16), 0.88)
	var iron := _mat(Color(0.26, 0.28, 0.32), 0.45, 0.0, 0.75)
	var cloth := _mat(Color(0.68, 0.20, 0.14), 0.9)
	var ruin_st := _mat(Color(0.45, 0.44, 0.40), 0.9)
	var dark_st := _mat(Color(0.18, 0.16, 0.22), 0.88)

	# 1. KÖY KAMPI (Güney): kamp ateşi, demirci ocağı, ahşap sundurma, erzak sandıkları, şifacı masası
	_campfire(VILLAGE, 2.4)
	# Demirci ocağı ve örsü (batı kenarı)
	_mesh_box(Vector3(1.1, 0.75, 0.65), VILLAGE + Vector3(-5.8, 0.38, -1.5), iron, Vector3(0, 0.3, 0), true)
	_mesh_box(Vector3(1.5, 0.28, 0.85), VILLAGE + Vector3(-5.8, 0.85, -1.5), iron, Vector3(0, 0.3, 0))
	_mesh_box(Vector3(1.4, 0.9, 1.4), VILLAGE + Vector3(-6.2, 0.45, -3.5), ruin_st, Vector3.ZERO, true)
	_mesh_cyl(0.45, 0.5, 0.18, VILLAGE + Vector3(-6.2, 0.96, -3.5), _mat(Color(1.0, 0.35, 0.05), 0.4, 2.6), 8)
	# Sundurma çatısı
	for x in [-7.6, -4.4]:
		for z in [-4.5, -0.5]:
			_mesh_cyl(0.12, 0.14, 3.0, VILLAGE + Vector3(x, 1.5, z), wood, 6, Vector3.ZERO, true)
	_mesh_box(Vector3(3.8, 0.18, 4.6), VILLAGE + Vector3(-6.0, 3.05, -2.5), cloth, Vector3(0, 0, -0.15))
	# Erzak sandıkları ve oturma kütükleri
	_mesh_box(Vector3(1.0, 1.0, 1.0), VILLAGE + Vector3(4.5, 0.5, 2.5), plank, Vector3(0, 0.4, 0), true)
	_mesh_box(Vector3(0.85, 0.85, 0.85), VILLAGE + Vector3(5.6, 0.42, 1.9), plank, Vector3(0, -0.2, 0), true)
	_mesh_cyl(0.24, 0.26, 2.4, VILLAGE + Vector3(0.0, 0.24, 3.2), wood, 8, Vector3(0, 0, PI * 0.5), true)
	_mesh_cyl(0.24, 0.26, 2.4, VILLAGE + Vector3(2.8, 0.24, -1.4), wood, 8, Vector3(PI * 0.5, 0.4, 0), true)
	# Şifacı masası ve parlayan iksir şişeleri (doğu kenarı)
	_mesh_box(Vector3(1.8, 0.85, 0.9), VILLAGE + Vector3(5.4, 0.42, -2.0), plank, Vector3(0, -0.35, 0), true)
	_mesh_cyl(0.10, 0.12, 0.32, VILLAGE + Vector3(5.1, 1.0, -2.0), _mat(Color(0.95, 0.18, 0.25), 0.2, 1.8), 8)
	_mesh_cyl(0.10, 0.12, 0.32, VILLAGE + Vector3(5.6, 1.0, -1.8), _mat(Color(0.22, 0.88, 0.45), 0.2, 1.8), 8)

	# 2. GOBLİN KAMPI (Batı): ateş, ahşap kazıklar, barikatlar
	_campfire(GOBLIN_CAMP, 1.8)
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var p := GOBLIN_CAMP + Vector3(cos(a) * 6.5, 0.0, sin(a) * 6.5)
		_mesh_box(Vector3(2.4, 1.1, 0.35), p + Vector3(0, 0.55, 0), wood, Vector3(0, -a + PI * 0.5, 0), true)

	# 3. ANTİK HARABELER (Doğu): yosunlu taş sütunlar ve kırık kemer
	for i in 6:
		var a := TAU * i / 6.0
		var h := 4.4 if i % 2 == 0 else 2.6
		_mesh_cyl(0.46, 0.54, h, RUINS + Vector3(cos(a) * 6.0, h * 0.5, sin(a) * 6.0), ruin_st, 10, Vector3.ZERO, true)
	_mesh_box(Vector3(5.2, 0.65, 0.9), RUINS + Vector3(0, 4.6, -5.2), ruin_st, Vector3(0, 0.0, 0.04))

	# 4. LANETLİ KORULUK (Orta): taş kaide ve havada dönen lanetli kristal
	_mesh_cyl(1.4, 1.8, 1.0, GROVE + Vector3(0, 0.5, 0), dark_st, 8, Vector3.ZERO, true)
	var cr_mesh := PrismMesh.new()
	cr_mesh.size = Vector3(1.1, 2.2, 1.1)
	_crystal = MeshInstance3D.new()
	_crystal.mesh = cr_mesh
	_crystal.position = GROVE + Vector3(0, 2.3, 0)
	_crystal.material_override = _mat(Color(0.65, 0.16, 0.95), 0.25, 2.6)
	props.add_child(_crystal)
	_crystal_light = OmniLight3D.new()
	_crystal_light.position = GROVE + Vector3(0, 2.6, 0)
	_crystal_light.light_color = Color(0.72, 0.28, 1.0)
	_crystal_light.light_energy = 2.8
	_crystal_light.omni_range = 18.0
	props.add_child(_crystal_light)

	# 5. KARANLIK SUNAK (Kuzey — Final Boss Alanı): 6 kara dikilitaş + mor sunak ışığı
	for i in 6:
		var a := TAU * i / 6.0
		_mesh_box(Vector3(1.2, 5.4, 1.2), ALTAR + Vector3(cos(a) * 8.5, 2.7, sin(a) * 8.5), dark_st, Vector3(0, -a, 0), true)
	_mesh_cyl(2.8, 3.2, 0.35, ALTAR + Vector3(0, 0.17, 0), dark_st, 12)
	_altar_light = OmniLight3D.new()
	_altar_light.position = ALTAR + Vector3(0, 3.2, 0)
	_altar_light.light_color = Color(0.75, 0.18, 0.95)
	_altar_light.light_energy = 3.2
	_altar_light.omni_range = 24.0
	props.add_child(_altar_light)


func _build_beacon() -> void:
	_beacon = Node3D.new()
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.14; cyl.bottom_radius = 0.24; cyl.height = 20.0; cyl.radial_segments = 10
	beam.mesh = cyl
	beam.position.y = 13.6
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color = Color(1.0, 0.84, 0.32, 0.13)
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.add_child(beam)
	var gem := MeshInstance3D.new()
	var pr := SphereMesh.new()
	pr.radius = 0.32; pr.height = 0.72; pr.radial_segments = 6; pr.rings = 2
	gem.mesh = pr
	gem.position.y = 4.2
	gem.material_override = _mat(Color(1.0, 0.85, 0.25), 0.2, 2.4)
	gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.add_child(gem)
	props.add_child(_beacon)


# ---------- Etkileşimli NPC'ler ----------

func _spawn_npcs() -> void:
	_make_npc("elder", "Muhtar Arda", "Köy Lideri", "oldclassy_male", VILLAGE + Vector3(0.0, 0.0, -3.2), 0.0)
	_make_npc("smith", "Demirci Kaya", "Silah Ustası", "worker_male", VILLAGE + Vector3(-4.2, 0.0, -1.2), 1.1)
	_make_npc("healer", "Şifacı Elif", "İksir Ustası", "doctor_female_young", VILLAGE + Vector3(4.2, 0.0, -1.6), -1.1)
	_make_npc("ranger", "Korucu Emre", "Orman İzci", "cowboy_male", RUINS + Vector3(0.0, 0.0, -2.5), 0.0)


func _make_npc(id: String, npc_name: String, role: String, model_name: String, pos: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.name = "NPC_" + id
	root.position = pos
	root.rotation.y = yaw
	var m: Node3D = load("res://models/chars/%s.glb" % model_name).instantiate()
	m.scale = Vector3.ONE * 0.74
	var rim := ShaderMaterial.new()
	rim.shader = preload("res://shaders/char_rim.gdshader")
	rim.set_shader_parameter("rim_color", Color(0.55, 0.95, 1.0, 0.35))
	var outline := ShaderMaterial.new()
	outline.shader = preload("res://shaders/outline.gdshader")
	rim.next_pass = outline
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = rim
	root.add_child(m)
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	if ap.has_animation("Idle"):
		ap.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
		ap.play("Idle")
	var tag := Label3D.new()
	tag.text = npc_name
	tag.position = Vector3(0, 2.75, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.font_size = 42
	tag.pixel_size = 0.0052
	tag.outline_size = 12
	tag.modulate = Color(0.95, 0.97, 1.0)
	root.add_child(tag)
	var marker := Label3D.new()
	marker.text = "!"
	marker.position = Vector3(0, 3.25, 0)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.font_size = 76
	marker.pixel_size = 0.007
	marker.outline_size = 16
	marker.modulate = Color(1.0, 0.85, 0.22)
	marker.visible = false
	root.add_child(marker)
	npcs_node.add_child(root)
	_npcs[id] = {"id": id, "node": root, "model": m, "anim": ap, "pos": pos, "name": npc_name, "role": role, "marker": marker}


## Keşif ödülleri: haritaya gizlenmiş 4 açılabilir hazine sandığı (models/chest.glb).
func _spawn_chests() -> void:
	var defs := [
		["camp", VILLAGE + Vector3(11.5, 0.0, 4.5), "Köy Erzak Sandığı", [["weapon", "grenade", 1], ["item", "potion", 1]]],
		["west", GOBLIN_CAMP + Vector3(-9.0, 0.0, -5.5), "Goblin Ganimet Sandığı", [["equip", "wall", 1], ["item", "potion", 1]]],
		["east", RUINS + Vector3(8.5, 0.0, -6.5), "Harabe Hazine Sandığı", [["weapon", "smg", 1], ["item", "potion", 1]]],
		["north", Vector3(-22.0, 0.0, -34.0), "Kuzey Sınır Sandığı", [["weapon", "flame", 1], ["item", "potion", 2]]],
	]
	var has_glb := ResourceLoader.exists("res://models/chest.glb")
	for d in defs:
		var root := Node3D.new()
		root.position = d[1]
		root.rotation.y = randf() * TAU
		if has_glb:
			var m: Node3D = load("res://models/chest.glb").instantiate()
			m.scale = Vector3.ONE * 0.85
			root.add_child(m)
		else:
			var bm := BoxMesh.new()
			bm.size = Vector3(1.1, 0.75, 0.75)
			var mi := MeshInstance3D.new()
			mi.mesh = bm
			mi.position.y = 0.38
			mi.material_override = _mat(Color(0.62, 0.42, 0.16), 0.5, 0.2, 0.4)
			root.add_child(mi)
		var l := OmniLight3D.new()
		l.position = Vector3(0, 1.0, 0)
		l.light_color = Color(0.4, 0.92, 1.0)
		l.light_energy = 1.6
		l.omni_range = 6.5
		root.add_child(l)
		var mk := Label3D.new()
		mk.text = "✦"
		mk.position = Vector3(0, 1.65, 0)
		mk.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mk.no_depth_test = true
		mk.font_size = 56
		mk.pixel_size = 0.006
		mk.outline_size = 12
		mk.modulate = Color(0.45, 0.95, 1.0)
		root.add_child(mk)
		props.add_child(root)
		_chests.append({"id": d[0], "pos": d[1], "title": d[2], "items": d[3], "node": root, "light": l, "marker": mk, "opened": false})


func nearby_chest(from_pos: Vector3, max_d := 3.8) -> Dictionary:
	var best: Dictionary = {}
	var bd := max_d
	for c in _chests:
		if c.opened:
			continue
		var d := from_pos.distance_to(c.pos)
		if d < bd:
			bd = d
			best = c
	return best


func open_chest(id: String) -> void:
	for c in _chests:
		if c.id == id and not c.opened:
			c.opened = true
			c.light.visible = false
			c.marker.visible = false
			var names := PackedStringArray()
			for it in c.items:
				_give_item(it[0], it[1], it[2])
				var w := Weapons.find(it[1]) if it[0] == "weapon" else {}
				var nm: String = str(w.get("name", Weapons.EQUIPS.get(it[1], Weapons.ITEMS.get(it[1], {})).get("name", it[1])))
				names.append(tr(nm))
			_aura_fx(c.pos, Color(0.45, 0.95, 1.0))
			Sfx.play2d(Sfx.chime, -2.0)
			toast_requested.emit(c.title.to_upper() + " AÇILDI!", "Kazanılanlar: " + ", ".join(names), Color(0.45, 0.95, 1.0))
			return


func _drop_heal_orb(at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at + Vector3.UP * 0.65
	var sm := SphereMesh.new()
	sm.radius = 0.24; sm.height = 0.48; sm.radial_segments = 10; sm.rings = 5
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = _mat(Color(0.25, 0.98, 0.52), 0.2, 2.4)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = Color(0.3, 1.0, 0.55)
	l.light_energy = 1.8
	l.omni_range = 5.0
	root.add_child(l)
	props.add_child(root)
	_orbs.append({"node": root, "pos": at})


## Oyuncunun yakınındaki etkileşimli NPC (yoksa boş sözlük).
func nearby_npc(from_pos: Vector3, max_d := 4.2) -> Dictionary:
	var best: Dictionary = {}
	var bd := max_d
	for id in _npcs:
		var n: Dictionary = _npcs[id]
		var d := from_pos.distance_to(n.pos)
		if d < bd:
			bd = d
			best = n
	return best


func _refresh_markers() -> void:
	for id in _npcs:
		_npcs[id].marker.visible = false
	match stage:
		0: _npcs["elder"].marker.visible = true
		1: _npcs["smith"].marker.visible = true
		3: _npcs["ranger"].marker.visible = (_camp_left.ruins <= 0)
		4: _npcs["healer"].marker.visible = (_camp_left.grove > 0) # iksir / görev için işaret
		5: _npcs["smith"].marker.visible = true
		7: _npcs["elder"].marker.visible = true


# ---------- Hikaye Diyalogları ve İlerleme ----------

func interact_npc(id: String) -> void:
	var n: Dictionary = _npcs.get(id, {})
	if n.is_empty():
		return
	var me := _player()
	if id == "healer" and me and me.hp < me.max_hp:
		me.set_hp(me.max_hp)
		_aura_fx(me.global_position, Color(0.32, 0.96, 0.55))
		toast_requested.emit("İYİLEŞTİN", "Şifacı Elif tüm canını yeniledi.", Color(0.35, 0.95, 0.55))

	if id == "elder":
		if stage == 0:
			_pending_action = func():
				stage = 1
				_refresh_markers()
				story_updated.emit()
				toast_requested.emit("YENİ GÖREV", "Demirci Kaya'dan ilk silahını al.", Color(1.0, 0.80, 0.32))
			dialog_requested.emit(n.name, n.role, [
				"Sonunda uyandın! Gece yarısı kuzeydeki Karanlık Sunak'tan garip bir sis çöktü.",
				"Goblin izcileri batı yolunu kesti, doğudaki Antik Harabeler'de Korucu Emre mahsur kaldı.",
				"Şu an elin boş — önce yanımızdaki Demirci Kaya'ya uğra, sana sağlam bir kılıç versin."
			])
		elif stage < 7:
			dialog_requested.emit(n.name, n.role, [
				"Dikkatli ol evlat. Yaralanırsan Şifacı Elif burada canını ücretsiz yeniler.",
				"Şu anki hedefin: " + objective_text()
			])
		else:
			dialog_requested.emit(n.name, n.role, [
				"Orman Lordu'nu devirdin! Kuşlar yeniden ötüyor, gökyüzü açıldı.",
				"Köyümüz sana minnettar. Ormanda dilediğin gibi gezebilirsin!"
			])

	elif id == "smith":
		if stage == 1:
			_pending_action = func():
				_give_item("weapon", "sword", 1)
				_give_item("item", "potion", 1)
				if me:
					me.slot = 1
				stage = 2
				_refresh_markers()
				story_updated.emit()
				toast_requested.emit("KILIÇ KAZANILDI", "1: Kılıç, 4: Can İksiri. Batıdaki Goblin Kampı'nı temizle!", Color(1.0, 0.82, 0.28))
			dialog_requested.emit(n.name, n.role, [
				"Muhtar seni gönderdi demek. Çıplak elle ormana çıkılmaz!",
				"Al şu bilenmiş çeliği ve bir can iksirini. Başlangıç için kılıç işini fazlasıyla görür.",
				"Batıdaki Goblin Kampı'nı temizle; geri geldiğinde sana daha ağır ekipmanlar açarım."
			])
		elif stage == 5:
			_pending_action = func():
				_give_item("weapon", "shotgun", 1)
				_give_item("weapon", "bazooka", 1)
				_give_item("equip", "shield", 1)
				_give_item("item", "potion", 2)
				if me:
					me.set_hp(me.max_hp)
				_spawn_camp("boss")
				stage = 6
				_refresh_markers()
				story_updated.emit()
				toast_requested.emit("AĞIR SİLAHLAR AÇILDI!", "Bazuka, Pompalı ve Kalkan eklendi! Kuzeydeki Orman Lordu'nu yen!", Color(1.0, 0.55, 0.18))
			dialog_requested.emit(n.name, n.role, [
				"Lanetli Koruluk'u temizledin ha?! Gerçek bir savaşçısın!",
				"Artık kilitli sandığı açma vakti geldi. İşte efsanevi BAZUKA, bir Pompalı ve Kalkan!",
				"Kuzeydeki Karanlık Sunak'ta Orman Lordu seni bekliyor. Bu işi bitir!"
			])
		else:
			dialog_requested.emit(n.name, n.role, [
				"Kılıcın keskin, nişanın sağlam olsun. Görevlerini tamamladıkça daha güçlü silahlar açılacak!"
			])

	elif id == "ranger":
		if stage == 3 and _camp_left.ruins <= 0:
			_pending_action = func():
				_give_item("weapon", "pistol", 1)
				_give_item("weapon", "bow", 1)
				_give_item("item", "potion", 1)
				stage = 4
				_refresh_markers()
				story_updated.emit()
				toast_requested.emit("TABANCA & YAY KAZANILDI", "Şifacı Elif'le konuş ya da doğrudan ortadaki Lanetli Koruluk'u arındır!", Color(0.45, 0.85, 1.0))
			dialog_requested.emit(n.name, n.role, [
				"Tam zamanında yetiştin! Harabelerdeki ölüler etrafımı sarmıştı.",
				"Al, yedek Tabancam ve Avcı Yayım artık senin — bundan sonra yaratıkları uzaktan avlayabilirsin!",
				"Ortadaki Lanetli Koruluk'ta mor bir kristal tüm yaratıkları besliyor. Köydeki Şifacı Elif seni hazırlayacaktır."
			])
		elif stage == 3:
			dialog_requested.emit(n.name, n.role, [
				"Önce harabelerdeki kalan %d yaratığı temizle, sonra konuşalım!" % _camp_left.ruins
			])
		else:
			dialog_requested.emit(n.name, n.role, [
				"Yay ve tabanca sende kalsın dostum. Harabeler artık güvende!"
			])

	elif id == "healer":
		if stage == 4:
			_pending_action = func():
				_give_item("item", "potion", 2)
				_npcs["healer"].marker.visible = false
				toast_requested.emit("İKİ CAN İKSİRİ ALDIN", "Ortadaki Lanetli Koruluk'taki yaratıkları temizle!", Color(0.42, 0.95, 0.58))
			dialog_requested.emit(n.name, n.role, [
				"Korucu Emre'yi kurtarmışsın! Canını tamamen tazeledim, yanına 2 Can İksiri daha veriyorum.",
				"Ortadaki Lanetli Koruluk'taki yaratıkları temizlediğinde mor kristal arınacak.",
				"Sonra Demirci Kaya'ya dön — Karanlık Sunak için en güçlü silahını sana verecek."
			])
		else:
			dialog_requested.emit(n.name, n.role, [
				"İhtiyacın olduğunda bana uğra; yaralarını her zaman iyileştiririm."
			])


func finish_dialog() -> void:
	if _pending_action.is_valid():
		var cb := _pending_action
		_pending_action = Callable()
		cb.call()


func _give_item(kind: String, id: String, count := 1) -> void:
	var me := _player()
	if me and me.has_method("add_item"):
		me.add_item({"kind": kind, "id": id, "count": count})
		_aura_fx(me.global_position, Color(1.0, 0.84, 0.30))
		Sfx.play2d(Sfx.chime, -3.0)


## İyileşme veya yeni silah kazanma efekti: oyuncunun etrafında yükselen parlak parçacık halesi.
func _aura_fx(at: Vector3, c: Color) -> void:
	var ring := Fx.ground(1.8, Color(c, 0.82), Vector4(0.15, 0.14, 0.06, 1.8))
	ring.position = at + Vector3.UP * 0.08
	props.add_child(ring)
	var tw := ring.create_tween().set_parallel()
	Fx.anim(tw, ring, "shape", Vector4(0.15, 0.14, 0.06, 1.8), Vector4(0.95, 0.03, 0.06, 1.8), 0.45).set_ease(Tween.EASE_OUT)
	Fx.anim(tw, ring, "col", Color(c, 0.82), Color(c, 0.0), 0.45).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(ring.queue_free)
	var p := Fx.parts(Fx.quad("glow", 0.22), 18, 0.8, 1.5, 4.2, [Color(c, 0.95), Color(1, 1, 1, 0.7), Color(c, 0.0)], 0.9, 0.2)
	p.position = at + Vector3.UP * 0.5
	p.direction = Vector3.UP
	p.spread = 45.0
	p.gravity = Vector3(0, 1.2, 0)
	p.finished.connect(p.queue_free)
	props.add_child(p)
	p.emitting = true


# ---------- Görev Bilgisi ve Hedefler ----------

func chapter_title() -> String:
	match stage:
		0: return "BÖLÜM I  •  UYANIŞ"
		1: return "BÖLÜM I  •  İLK SİLAH"
		2: return "BÖLÜM II  •  GOBLİN İZCİLERİ"
		3: return "BÖLÜM III  •  ANTİK HARABELER"
		4: return "BÖLÜM IV  •  LANETLİ KORULUK"
		5: return "BÖLÜM V  •  SON HAZIRLIK"
		6: return "FİNAL  •  ORMAN LORDU"
		_: return "ZAFER  •  ORMAN KURTULDU"


func objective_text() -> String:
	match stage:
		0: return "Köy Kampı'nda Muhtar Arda ile konuş (E)"
		1: return "Demirci Kaya'dan ilk silahını al (E)"
		2: return "Batı Goblin Kampı'nı temizle (%d / %d)" % [_camp_total.goblin - _camp_left.goblin, _camp_total.goblin]
		3:
			if _camp_left.ruins > 0:
				return "Doğu Antik Harabeleri'ndeki yaratıkları yen (%d / %d)" % [_camp_total.ruins - _camp_left.ruins, _camp_total.ruins]
			return "Harabelerdeki Korucu Emre ile konuş (E)"
		4: return "Ortadaki Lanetli Koruluk'u temizle (%d / %d)" % [_camp_total.grove - _camp_left.grove, _camp_total.grove]
		5: return "Köy Kampı'nda Demirci Kaya ile konuş (E)"
		6: return "Kuzey Karanlık Sunak'ta Orman Lordu'nu yen (%d düşman kaldı)" % _camp_left.boss
		_: return "Orman huzura kavuştu! Dilediğin gibi keşfet."


func objective_pos() -> Vector3:
	match stage:
		0: return _npcs["elder"].pos
		1: return _npcs["smith"].pos
		2: return GOBLIN_CAMP
		3: return RUINS if _camp_left.ruins > 0 else _npcs["ranger"].pos
		4: return GROVE
		5: return _npcs["smith"].pos
		6: return ALTAR
		_: return Vector3.ZERO


# ---------- Yaratık Kampları ve Savaş ----------

func _spawn_camp(camp: String) -> void:
	var defs := []
	match camp:
		"goblin":
			defs = [
				["runner", GOBLIN_CAMP + Vector3(-2.5, 0, -2.0), 34, 6, false],
				["runner", GOBLIN_CAMP + Vector3(2.8, 0, -1.5), 34, 6, false],
				["runner", GOBLIN_CAMP + Vector3(-1.0, 0, 3.0), 34, 6, false],
				["runner", GOBLIN_CAMP + Vector3(3.2, 0, 2.4), 38, 7, false],
				["grunt", GOBLIN_CAMP + Vector3(0.0, 0, -3.5), 48, 8, false],
			]
		"ruins":
			defs = [
				["grunt", RUINS + Vector3(-3.0, 0, 2.5), 55, 8, false],
				["grunt", RUINS + Vector3(3.0, 0, 2.5), 55, 8, false],
				["grunt", RUINS + Vector3(-3.2, 0, -2.5), 55, 8, false],
				["spitter", RUINS + Vector3(3.5, 0, -2.0), 48, 9, false],
				["knight", RUINS + Vector3(0.0, 0, 4.0), 110, 12, false],
			]
		"grove":
			defs = [
				["grunt", GROVE + Vector3(-4.0, 0, 3.0), 65, 9, false],
				["grunt", GROVE + Vector3(4.0, 0, 3.0), 65, 9, false],
				["spitter", GROVE + Vector3(-4.5, 0, -2.5), 58, 10, false],
				["spitter", GROVE + Vector3(4.5, 0, -2.5), 58, 10, false],
				["brute", GROVE + Vector3(-2.0, 0, -4.0), 135, 13, false],
				["ogre", GROVE + Vector3(2.0, 0, -4.0), 175, 15, true],
			]
		"boss":
			defs = [
				["boss", ALTAR + Vector3(0.0, 0, -1.5), 950, 22, true],
				["knight", ALTAR + Vector3(-4.5, 0, 3.0), 130, 13, false],
				["spitter", ALTAR + Vector3(4.5, 0, 3.0), 75, 11, false],
				["runner", ALTAR + Vector3(0.0, 0, 4.5), 80, 11, true],
			]
	_camp_total[camp] = defs.size()
	_camp_left[camp] = defs.size()
	for d in defs:
		_spawn_enemy(d[0], d[1], d[2], d[3], d[4], camp)


func _spawn_enemy(t: String, pos: Vector3, hp_: int, dmg_: int, elite_: bool, camp: String) -> void:
	_eid += 1
	var e := EnemyScript.new()
	e.name = "E%d" % _eid
	e.eid = _eid
	e.type = t
	e.hp = hp_
	e.dmg = dmg_
	e.elite = elite_
	e.money = 0
	e.td = self
	e.position = pos
	e.home_pos = pos
	e.camp_id = camp
	e.aggro_r = 18.0 if camp == "boss" else 14.5
	e.leash_r = 34.0
	enemies.add_child(e)
	_by_id[_eid] = e
	elist.append(e)
	if t == "boss":
		boss_eid = _eid


# ---------- player.gd / enemy.gd Sözleşmesi ----------

@rpc("any_peer", "call_local", "reliable")
func damage_enemy(enemy_name: String, amount: int, crit := false) -> void:
	var eid := enemy_name.trim_prefix("E").to_int()
	var e = _by_id.get(eid)
	if not is_instance_valid(e) or e.hp <= 0:
		return
	var eff := maxi(maxi(amount - e.armor, ceili(amount * 0.4)), 1)
	var nv := maxi(e.hp - eff, 0)
	e.apply_hit(nv, eff, crit)
	if nv <= 0:
		_on_enemy_killed(e)


func _on_enemy_killed(e: Node) -> void:
	_by_id.erase(e.eid)
	elist.erase(e)
	kills += 1
	if e.eid == boss_eid:
		boss_eid = 0
	if e.elite or e.type in ["knight", "brute", "ogre"]:
		_drop_heal_orb(e.global_position)
	var camp: String = str(e.get("camp_id"))
	if _camp_left.has(camp):
		_camp_left[camp] = maxi(_camp_left[camp] - 1, 0)
	_check_progression(camp)
	story_updated.emit()


func _check_progression(camp: String) -> void:
	if camp == "goblin" and _camp_left.goblin <= 0 and stage <= 2:
		stage = 3
		_refresh_markers()
		Sfx.play2d(Sfx.chime, -2.0)
		toast_requested.emit("GOBLİN KAMPI TEMİZLENDİ!", "Doğu Antik Harabeleri'ne gidip Korucu Emre'yi kurtar!", Color(0.42, 0.92, 0.55))
	elif camp == "ruins" and _camp_left.ruins <= 0 and stage == 3:
		_refresh_markers()
		Sfx.play2d(Sfx.chime, -2.0)
		toast_requested.emit("HARABELER GÜVENDE!", "Şimdi Korucu Emre ile konuş (E)", Color(0.45, 0.85, 1.0))
	elif camp == "grove" and _camp_left.grove <= 0 and stage <= 4:
		if is_instance_valid(_crystal):
			_crystal.material_override = _mat(Color(1.0, 0.84, 0.28), 0.2, 2.8)
		if is_instance_valid(_crystal_light):
			_crystal_light.light_color = Color(1.0, 0.86, 0.42)
		stage = 5
		_refresh_markers()
		Sfx.play2d(Sfx.chime, -2.0)
		toast_requested.emit("KORULUK ARINDI!", "Köy Kampı'nda Demirci Kaya'ya dön — Ağır silahlar seni bekliyor!", Color(1.0, 0.84, 0.30))
	elif camp == "boss" and _camp_left.boss <= 0 and stage == 6:
		state = "won"
		stage = 7
		if is_instance_valid(_altar_light):
			_altar_light.light_color = Color(1.0, 0.88, 0.48)
		_refresh_markers()
		Sfx.play2d(Sfx.chime, 0.0)
		story_won.emit()


@rpc("any_peer", "call_local", "reliable")
func effect_enemy(enemy_name: String, fx: Dictionary) -> void:
	var eid := enemy_name.trim_prefix("E").to_int()
	var e = _by_id.get(eid)
	if not is_instance_valid(e) or e.hp <= 0:
		return
	if fx.has("stun") and e.has_method("stun_fx"):
		e.stun_fx(minf(float(fx.stun), 5.0))
	if fx.has("stun"):
		e.slow_k = 0.0
		e.slow_t = minf(float(fx.stun), 5.0)
	elif fx.has("slow"):
		e.slow_k = clampf(float(fx.slow[0]), 0.0, 1.0)
		e.slow_t = minf(float(fx.slow[1]), 8.0)
	if fx.get("knock") is Vector3:
		e.move_and_collide((fx.knock as Vector3).limit_length(12.0) * Vector3(0.25, 0, 0.25))


@rpc("authority", "call_local", "unreliable")
func enemy_fx(eid: int, pos: Vector3) -> void:
	var e = _by_id.get(eid)
	if is_instance_valid(e):
		e.attack_fx(pos)


func hit_player(p: Node, dmg: int) -> void:
	if is_instance_valid(p) and p.has_method("td_hit"):
		p.td_hit(dmg)


func delayed_hit(p: Node, at: Vector3, dmg: int, delay: float) -> void:
	get_tree().create_timer(delay, false).timeout.connect(func() -> void:
		if is_instance_valid(p) and p.hp > 0 and p.global_position.distance_to(at) < 1.8:
			hit_player(p, dmg))


func explode(e: Node) -> void:
	if not is_instance_valid(e):
		return
	var pos: Vector3 = e.global_position
	var r: float = e.d.explode
	var fx: Node3D = Fx.new()
	fx.radius = r
	fx.position = pos
	get_parent().add_child(fx)
	for p in plist:
		if is_instance_valid(p) and p.hp > 0 and p.global_position.distance_to(pos) <= r:
			hit_player(p, e.dmg)
	damage_enemy(e.name, e.hp + 999, false)


func hurt_tower(_dmg: int) -> void:
	pass


func hurt_build(_b: Node, _dmg: int) -> void:
	pass
