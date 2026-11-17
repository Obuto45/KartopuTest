extends Node
## Görsel kontrol: menü, karakter seçimi, silahlar, modeller ve yetenek efektleri (user:// içine PNG).

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir() + "/" + n + ".png")

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _dummy(main: Node, id: int, chr: int, pos: Vector3) -> CharacterBody3D:
	var d: CharacterBody3D = load("res://player.gd").new()
	d.name = str(id)
	d.set_multiplayer_authority(id)
	d.spawn_pos = pos
	Net.chars[id] = chr
	main.players.add_child(d)
	d.net_yaw = PI # bize baksın
	return d

# A/B'nin parçaları eksikse arayüzü besleyen sahte düğümler: yalnız sözleşmedeki alanlar.
const FAKE_TD := """extends Node
signal changed
var wave := 0
var state := "break"
var time_left := 18.0
var money := 135
var level := 3
var xp := 40
var xp_next := 100
var tower_hp := 1500
var tower_max := 1500
var enemies_left := 0
var kills := 27
func is_ready(id): return id == 1
func can_place(_id, _p): return true
func _ready(): add_to_group("td")
func buy(_id): return true
func ready_up(): pass
"""
const FAKE_PLAYER := """extends Node
var hp := 100
var max_hp := 100
var dead_t := 0.0
var ch := {"name": "Parıltı", "skill_name": "KÖR EDİCİ PARILTI", "color": Color(0.8, 0.35, 0.75)}
var skill_cd := 4.2
var inv := []
var slot := 1
var stats := {}
var stat_points := 0
var level := 3
var cards := []
func choose_card(_i): cards = []
func spend_point(_id): pass
"""

func _fake(src: String) -> Node:
	var s := GDScript.new()
	s.source_code = src
	s.reload()
	return s.new()


## Kendi gözünden silah animasyonları: her kare klibin anlamlı anında.
func _fp_hold(me: Node, i: int, it: Dictionary) -> void:
	me.inv[i] = it
	me.slot = i + 1
	me._sync_held()
	await _wait(0.5) # çıkarma klibi
	me.busy = ""


func _fp_shots(me: Node) -> void:
	await _fp_hold(me, 1, {"kind": "weapon", "id": "pistol", "count": 1, "lvl": 1, "ammo": 3})
	me.start_reload()
	await _wait(0.6)
	await _shot("fp_reload")
	await _wait(1.0)
	await _fp_hold(me, 3, {"kind": "item", "id": "potion", "count": 2, "lvl": 1})
	me.hp = 40
	me._td_use(true)
	await _wait(0.55)
	await _shot("fp_potion")
	await _wait(0.6)
	await _fp_hold(me, 1, {"kind": "weapon", "id": "bow", "count": 1, "lvl": 1, "ammo": 1})
	me._td_use(true)
	await _wait(0.8)
	await _shot("fp_bow")
	me._release_throw()
	await _wait(0.8)
	await _fp_hold(me, 1, {"kind": "weapon", "id": "grenade", "count": 1, "lvl": 1, "ammo": 1})
	me._td_use(true)
	await _wait(0.35)
	await _shot("fp_grenade")
	me._release_throw()
	await _wait(1.0)
	await _fp_hold(me, 1, {"kind": "weapon", "id": "sniper", "count": 1, "lvl": 1, "ammo": 5})
	Input.action_press("aim")
	await _wait(0.4)
	await _shot("fp_scope")
	Input.action_release("aim")
	await _fp_hold(me, 1, {"kind": "weapon", "id": "shotgun", "count": 1, "lvl": 1, "ammo": 2})
	me.start_reload()
	await _wait(0.5)
	await _shot("fp_shotgun")
	await _wait(2.0)
	await _fp_hold(me, 1, {"kind": "weapon", "id": "smg", "count": 1, "lvl": 1, "ammo": 30})
	var box := MeshInstance3D.new() # burnumuzun dibinde duvar: silah içine girmemeli
	box.mesh = BoxMesh.new()
	box.mesh.size = Vector3(3, 3, 0.2)
	main_world(me).add_child(box)
	box.global_transform = me.look.global_transform.translated_local(Vector3(0, 0, -0.3))
	await _wait(0.3)
	await _shot("fp_wall")
	box.queue_free()
	me.inv[1] = {}
	me.inv[3] = {}
	me.slot = 1
	me.hp = me.max_hp


func main_world(me: Node) -> Node:
	return me.get_parent()


## Tower Defense ekranları: gerçek td.gd / player alanları varsa onlarla, yoksa sahtelerle.
func _td_shots(main: Node) -> void:
	main._pick_mode("td")
	main._on_start()
	await _wait(0.8)
	var ui = main.td_ui
	if ui.weapons.is_empty():
		ui.weapons = [{"id": "bazooka", "name": "Bazuka", "rarity": "rare"}, {"id": "pistol", "name": "Tabanca", "rarity": "common"}]
		ui.rarity = {"common": {"name": "Sıradan", "color": Color(0.75, 0.78, 0.82)}, "rare": {"name": "Nadir", "color": Color(0.3, 0.6, 1.0)},
			"epic": {"name": "Destansı", "color": Color(0.7, 0.35, 0.95)}, "legendary": {"name": "Efsanevi", "color": Color(1.0, 0.75, 0.2)}}
		ui.stat_defs = [{"id": "speed", "name": "Hız", "base": 1.0, "step": 0.05, "max": 1.5}, {"id": "hp", "name": "Can", "base": 100.0, "step": 15.0, "max": 400.0}]
	if ui.shop.is_empty():
		ui.shop = [{"id": "wall", "name": "Duvar", "desc": "Yolu keser.", "price": 25, "color": Color(0.62, 0.45, 0.28)},
			{"id": "turret", "name": "Taret", "desc": "Yaratıklara ateş eder.", "price": 190, "color": Color(0.35, 0.55, 0.75)}]
	var real_td := get_tree().get_first_node_in_group("td")
	if real_td:
		await _shot("td_real") # gerçek td.gd ile ilk mola
		await _fp_shots(main.players.get_node("1"))
		real_td.remove_from_group("td")
		real_td.queue_free()
	var td := _fake(FAKE_TD) # sahnelenen durumlar için alanları elle sürülen sahte TD
	main.world.add_child(td)
	ui.td = td
	var me = main.players.get_node("1")
	var pl = me
	if not ("cards" in me and "inv" in me and "stats" in me):
		pl = _fake(FAKE_PLAYER)
		add_child(pl)
		ui.player = pl
	print("TD shots: td=%s player=%s" % ["gerçek+sahte" if real_td else "sahte", "gerçek" if pl == me else "sahte"])
	pl.inv = [{"kind": "weapon", "id": "bazooka", "count": 1, "lvl": 3}, {"kind": "weapon", "id": "pistol", "count": 1, "lvl": 1}, {},
		{"kind": "build", "id": "wall", "count": 3, "lvl": 0}, {"kind": "build", "id": "turret", "count": 1, "lvl": 0}]
	pl.slot = 1
	var st := {}
	for d in ui.stat_defs:
		st[d.id] = d.base + d.step * (randi() % 4)
	pl.stats = st
	pl.stat_points = 2
	await _wait(0.6)
	await _shot("td_break")
	ui._open_shop()
	await _wait(0.4)
	ui._buy(ui.shop[-1], ui.shop_rows[-1].btn) # pahalı olan: "para yetmiyor"
	await _wait(0.6)
	await _shot("td_shop")
	ui.shop_wrap.hide()
	Input.action_press("stats")
	await _wait(0.5)
	await _shot("td_stats")
	Input.action_release("stats")
	td.state = "fight"
	td.wave = 3
	td.enemies_left = 14
	td.tower_hp = 380
	td.level = 4
	td.xp = 75
	pl.slot = 4
	pl.cards = [{"id": "a", "title": "Çelik Deri", "desc": "Zırh +%10. Yaratık hasarı azalır.", "rarity": "common", "type": "stat"},
		{"id": "b", "title": "Pompalı", "desc": "Yeni silah: 7 saçma birden, yakında ezer.", "rarity": "epic", "type": "weapon"},
		{"id": "c", "title": "Bazuka: Dev Patlama", "desc": "Patlama alanı +1 m, hasar +%20.", "rarity": "legendary", "type": "weapon_up"}]
	await _wait(0.9)
	await _shot("td_cards") # savaş: dalga afişi, düşük kule canı, kartlar
	var win := get_window()
	var full := win.size
	win.size = Vector2i(1280, 720) # küçük çözünürlükte taşma var mı
	await _wait(0.5)
	await _shot("td_720")
	win.size = full
	pl.cards = []
	pl.hp = 0
	pl.dead_t = 3.2
	await _wait(0.3)
	await _shot("td_dead")
	pl.hp = pl.max_hp
	td.state = "lost"
	await _wait(0.8)
	await _shot("td_end")
	ui.state = "fight"
	td.state = "won"
	td.wave = 10
	await _wait(0.8)
	await _shot("td_won")


func _ready() -> void:
	var main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _wait(1.5)
	await _shot("menu") # giriş ekranı
	main._show_page("main")
	await _wait(1.6)
	await _shot("menu_main")
	main._show_page("modes")
	await _wait(0.8)
	await _shot("menu_modes")
	main._show_page("lobby")
	await _wait(0.8)
	await _shot("menu_lobby")
	main._open_settings()
	await _wait(0.2)
	await _shot("settings")
	main._close_settings()
	main._open_chars()
	await _wait(0.4)
	await _shot("chars")
	main._show_char(40) # Ulu Büyücü
	await _wait(0.4)
	await _shot("chars2")
	main.char_wrap.hide()
	main._pick_mode("td") # TD lobisi ve silah seçimi
	await _wait(0.6)
	await _shot("menu_lobby_td")
	main._open_weapons()
	await _wait(0.3)
	await _shot("weapons")
	main.weapon_wrap.hide()
	main._pick_mode("arena")
	Net.host_local()
	main._on_start()
	await _wait(0.5)
	var me = main.players.get_node("1")
	me.rotation.y = PI * 0.75
	me.look.rotation.x = 0.05
	await _wait(0.3)
	await _shot("forest") # kendi gözünden bazuka
	me.rotation.y = 0.0
	me.look.rotation.x = -0.1
	var p: Vector3 = me.global_position
	Net.names[2] = "Sinan"
	var dayi := _dummy(main, 2, 3, p + Vector3(0, 0, -4.5))
	var wiz := _dummy(main, 3, 40, p + Vector3(-1.8, 0, -4.5))
	var cow := _dummy(main, 4, 50, p + Vector3(1.8, 0, -4.5))
	var knight := _dummy(main, 5, 34, p + Vector3(3.6, 0, -4.5))
	cow.slot = 4 # kılıçlı
	knight.slot = 2 # eli boş
	await _wait(0.7)
	dayi.hp = 60
	wiz.say("Gökten ne yağıyor?")
	await _wait(0.2)
	await _shot("looks")
	for d in [dayi, wiz, cow, knight]: # yandan: kol, silah ve koşu görünsün
		d.net_yaw = PI / 2
		d.net_speed = 7.0
	wiz.net_pitch = 0.5 # yukarı nişan
	await _wait(0.5)
	await _shot("side")
	for d in [dayi, wiz, cow, knight]:
		d.net_yaw = PI
		d.net_speed = 0.0
	wiz.net_pitch = 0.0
	wiz.use_skill(wiz.global_position, p + Vector3(0, 0, -9), Vector3(0, 0, -1), 0) # meteor arkaya düşer
	knight.use_skill(knight.global_position, knight.global_position, Vector3(0, 0, 1), 0) # Devleş
	cow.net_air = true # zıplama animasyonu
	await _wait(0.8)
	await _shot("skills")
	await _wait(0.35)
	await _shot("meteor")
	cow.net_air = false
	me.set_hp(25) # can barı: kritik seviye + beyaz iz
	me.buffs["slow"] = [0.5, 3.0]
	me.buffs["burn"] = [6, 4.0]
	me._set_slot(4)
	me.swing_t = 0.12
	await _wait(0.1)
	await _shot("hud") # kendi gözünden kılıç + durum yazıları
	me._set_slot(3)
	me.spawn_wall(me._ground(p + Vector3(0, 0, -2.5)), 0.0, 0)
	dayi.hp = 0 # ölüm animasyonu
	dayi.net_pos = p + Vector3(-3.5, 0, -3.0)
	await _wait(1.3)
	await _shot("wall")
	me.hp = 0
	me.dead_t = 2.0
	await _wait(0.6)
	await _shot("spectate")
	await _td_shots(main)
	get_tree().quit()
