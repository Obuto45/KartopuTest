extends Node
## TD silah / stat / kart / envanter testi, tek süreç, ağsız: godot --headless res://tests/weapons_test.tscn
## main.gd ve td.gd'ye bağlı değil: kendi zeminini, sahte TD düğümünü ve sahte yaratıklarını kurar.

const Weapons := preload("res://weapons.gd")
const PlayerScript := preload("res://player.gd")


class FakeTD extends Node:
	var state := "break"
	var hits := [] # [yaratık adı, hasar, kritik]
	var placed := []
	var ok := true
	func damage_enemy(n: String, dmg: int, crit: bool) -> void:
		hits.append([n, dmg, crit])
	func can_place(_id: String, _pos: Vector3) -> bool:
		return ok
	func place(id: String, _pos: Vector3, _yaw: float) -> void:
		placed.append(id)


class FakeEnemy extends Node3D:
	var hp := 100000
	var radius := 0.5
	var height := 2.4


var good := 0
var total := 0
var td: FakeTD
var me: CharacterBody3D
const HOME := Vector3(0, 0.1, 0)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func chk(what: String, ok: bool, info = "") -> void:
	total += 1
	good += int(ok)
	print("[%s] %s %s" % ["OK" if ok else "HATA", what, info])


func _enemy(n: String, pos: Vector3) -> void:
	var e := FakeEnemy.new()
	e.name = n
	e.position = pos
	e.add_to_group("enemies")
	td.get_parent().add_child(e)


func _player(id: int, pos: Vector3) -> CharacterBody3D:
	var p: CharacterBody3D = PlayerScript.new()
	p.name = str(id)
	p.set_multiplayer_authority(id)
	p.spawn_pos = pos
	td.get_parent().get_node("Players").add_child(p)
	return p


## Slot 1'e silahı koyup bir kez ateş eder; t sn sonra kaydedilen isabetleri döndürür.
func _fire(id: String, t: float) -> Array:
	me.inv[0] = {"kind": "weapon", "id": id, "count": 1, "lvl": 1}
	me.slot = 1
	me.cd = 0.0
	me.burns.clear()
	td.hits.clear()
	me._td_use(true)
	await _wait(t)
	return td.hits.duplicate()


func _names(hits: Array) -> Array:
	var out := []
	for h in hits:
		if not out.has(h[0]):
			out.append(h[0])
	return out


func _reset() -> void:
	me.global_position = HOME
	me.velocity = Vector3.ZERO
	me.rotation.y = 0.0
	me.look.rotation.x = 0.0
	me.stats = Weapons.base_stats(me.ch)
	me.stats.crit = 0.0
	me.ups = {}
	me.buffs.clear()


func _ready() -> void:
	InputMap.add_action("throw") # main.gd yok: oyuncunun okuduğu tek eylem
	var world := Node3D.new()
	world.name = "World"
	get_tree().root.add_child.call_deferred(world)
	await _wait(0.1)
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	cs.shape = box
	floor_body.add_child(cs)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	var players := Node3D.new()
	players.name = "Players"
	world.add_child(players)
	td = FakeTD.new()
	td.name = "TD"
	td.add_to_group("td")
	world.add_child(td)
	Net.chars[1] = 9 # Manken: pasifsiz
	Net.chars[2] = 14 # Kasap: alan hasarı
	Net.weapons[1] = 1
	me = _player(1, HOME)
	var mate := _player(2, Vector3(6, 0.1, 0))
	_enemy("E1", Vector3(0, 0, -6))
	_enemy("E2", Vector3(3, 0, -7)) # yanda: sekme hedefi
	_enemy("E3", Vector3(0, 0, -8)) # arkada: delme ve patlama hedefi
	await _wait(0.4)

	chk("TD başlangıcı: yalnız seçilen silah slot 1'de", me.inv[0].get("id") == "pistol" and me.inv[1].is_empty() and me.inv[2].is_empty() and me.stats.size() == 9, me.inv)
	chk("TD başlangıç silahı dolu şarjörlü", me.inv[0].get("ammo") == 12, me.inv[0])
	chk("veri: 10 silah, 9 stat, her silaha >= 3 yükseltme", Weapons.LIST.size() == 10 and Weapons.STATS.size() == 9
		and Weapons.LIST.all(func(w): return Weapons.UPS[w.id].size() >= 3))

	# --- 10 silahın hepsi ateş eder ve yaratığa hasar yazar
	for w in Weapons.LIST:
		_reset()
		if w.kind == "melee":
			me.global_position = Vector3(0, 0.1, -4.2)
		var hits: Array = await _fire(w.id, 2.6 if w.kind == "homing" else 1.2)
		chk("silah %-16s E1'e hasar" % w.name, _names(hits).has("E1"), "isabet=%d hedef=%s ilk=%s" % [hits.size(), _names(hits), hits[0] if hits else "-"])
	_reset()
	await _wait(1.5)

	# --- statlar sonucu değiştirir
	var base: Array = await _fire("pistol", 0.2)
	chk("tabanca tek hedef, 9 hasar", base.size() == 1 and base[0] == ["E1", 9, false], base)
	me.stats.shot_power = 2.0
	var h: Array = await _fire("pistol", 0.2)
	chk("mermi gücü x2 -> 18", h.size() == 1 and h[0][1] == 18, h)
	_reset()
	me.stats.crit = 1.0
	h = await _fire("pistol", 0.2)
	chk("kritik -> x2 ve işaretli", h.size() == 1 and h[0][1] == 18 and h[0][2] == true, h)
	_reset()
	me.stats.bounce = 1.0
	h = await _fire("pistol", 0.2)
	chk("sekme 1 -> ikinci yaratığa zincir (x0,75)", h.size() == 2 and h[1][0] != "E1" and h[1][1] == 7, h)
	_reset()
	me.stats.attack = 2.0
	me.cd = 0.0
	me._td_use(true)
	chk("saldırı hızı x2 -> bekleme yarıya", is_equal_approx(me.cd, 0.125), me.cd)
	_reset()
	h = await _fire("sniper", 0.2)
	chk("keskin nişancı deler: E1 ve E3", _names(h) == ["E1", "E3"], h)
	h = await _fire("bazooka", 1.2)
	chk("patlama yarıçaptaki herkese: E1 ve E3", _names(h).has("E1") and _names(h).has("E3"), h)
	h = await _fire("flame", 2.4)
	chk("alev yakar: saniyede 4 hasarlık yanık", h.any(func(x): return x[1] == 4), h.size())
	me.stats.shot_speed = 2.0
	await _fire("bow", 0.0)
	var arrow = world.get_children().filter(func(n): return str(n.name).begins_with("T1_"))
	chk("mermi hızı x2 -> ok 84 m/sn", arrow.size() == 1 and absf(arrow[0].spd - 84.0) < 1.0, arrow.size())
	me.ups = {"shotgun:pellets": 2, "bazooka:blast": 1}
	chk("silah yükseltmesi veriye işler", Weapons.tuned("shotgun", me.ups).n == 11 and is_equal_approx(Weapons.tuned("bazooka", me.ups).blast, 3.1))
	_reset()
	await _wait(1.0)

	# --- kartlar
	var distinct := true
	for i in 200:
		var cs3 := Weapons.roll_cards(me)
		var ids := cs3.map(func(c): return c.id)
		if cs3.size() != 3 or ids[0] == ids[1] or ids[1] == ids[2] or ids[0] == ids[2] \
			or not cs3.all(func(c): return Weapons.RARITY.has(c.rarity) and c.type in ["stat", "char", "weapon", "weapon_up"] and c.title != "" and c.desc != ""):
			distinct = false
	chk("roll_cards: 3 farklı geçerli kart (200 çekiliş)", distinct)
	var pool := Weapons.pool(me)
	var types := {}
	for c in pool:
		types[c.type] = types.get(c.type, 0) + 1
	chk("havuzda dört kart türü de var", types.size() == 4, types)
	me.cards = [pool.filter(func(c): return c.id == "stat:speed:2")[0]]
	me.pending = 1
	me.choose_card(0)
	chk("stat kartı uygular (hız +2 adım)", is_equal_approx(me.stats.speed, 1.1) and me.cards.is_empty(), me.stats.speed)
	me.cards = [pool.filter(func(c): return c.id == "char:cd")[0]]
	me.choose_card(0)
	me.skill_cd = 0.0
	me._use_skill()
	chk("karakter kartı: yetenek bekleme -%15", me.ups.get("char:cd") == 1 and is_equal_approx(me.skill_cd, me.ch.cd * 0.85), me.skill_cd)
	me.inv[0] = {"kind": "weapon", "id": "pistol", "count": 1, "lvl": 1}
	me.cards = [pool.filter(func(c): return c.id == "weapon:sniper")[0]]
	me.choose_card(0)
	chk("silah kartı boş slota girer", me.inv[1].get("id") == "sniper" and me.inv[1].kind == "weapon", me.inv)
	me.cards = [Weapons.pool(me).filter(func(c): return c.id == "up:pistol:cal")[0]]
	me.choose_card(0)
	h = await _fire("pistol", 0.2)
	chk("silah yükseltme kartı: tabanca +3 hasar", me.ups.get("pistol:cal") == 1 and h[0][1] == 12, h)
	me.cards = [Weapons.pool(me).filter(func(c): return c.id == "equip:shield")[0]]
	me.choose_card(0)
	me.slot = 3
	me.shield_cd = 0.0
	me._td_use(true)
	chk("ekipman kartı: kalkan slot 3'te ve çalışıyor", me.inv[2].get("kind") == "equip" and me.shield_on, me.inv[2])
	me.td_hit(30)
	chk("kalkan yaratık darbesini emer", me.hp == me.max_hp and not me.shield_on)
	chk("slotlar doluyken yeni silah kartı çıkmaz", not Weapons.pool(me).any(func(c): return c.type == "weapon"))
	var lv: int = me.level
	me.cards = []
	me.pending = 0
	me.stat_points = 0
	me.level_up()
	me.level_up()
	var first: Array = me.cards
	chk("level_up: 3 kart + stat puanı, seviyeler birikir", first.size() == 3 and me.stat_points == 2 and me.level == lv + 2 and me.pending == 2)
	me.choose_card(1)
	var second_ok: bool = me.cards.size() == 3
	me.choose_card(0)
	chk("biriken seviyeler sırayla seçilir", second_ok and me.cards.is_empty() and me.pending == 0)

	# --- stat puanı yalnızca molada
	me.stat_points = 2
	td.state = "fight"
	var a0: float = me.stats.armor
	var r1: bool = me.spend_point("armor")
	td.state = "break"
	var r2: bool = me.spend_point("armor")
	chk("stat puanı yalnızca molada harcanır", not r1 and r2 and me.stat_points == 1 and is_equal_approx(me.stats.armor, a0 + 0.05), [r1, r2, me.stats.armor])
	var hp0: int = me.max_hp
	me.spend_point("hp")
	chk("can statı üst sınırı ve canı artırır", me.max_hp == hp0 + 15 and me.hp == me.max_hp, me.max_hp)
	chk("yanlış stat adı reddedilir", not me.spend_point("yok"))

	# --- envanter kuralları
	me.inv = [{}, {}, {}, {}, {}]
	var r := []
	for d in [{"kind": "weapon", "id": "bow"}, {"kind": "weapon", "id": "bow"}, {"kind": "equip", "id": "wall"}, {"kind": "weapon", "id": "smg"},
			{"kind": "weapon", "id": "flame"}, {"kind": "build", "id": "wall"}, {"kind": "build", "id": "wall"}, {"kind": "item", "id": "potion"},
			{"kind": "item", "id": "bomb"}, {"kind": "build", "id": "turret"}, {"kind": "saçma", "id": "x"}]:
		r.append(me.add_item(d))
	chk("envanter: silah 1-3, yapı/eşya 4-5, yığılır, doluysa false",
		r == [true, false, true, true, false, true, true, true, false, false, false]
		and me.inv[0].id == "bow" and me.inv[1].id == "wall" and me.inv[1].kind == "equip" and me.inv[2].id == "smg"
		and me.inv[3].kind == "build" and me.inv[3].count == 2 and me.inv[4].id == "potion", [r, me.inv])
	chk("eklenen silahlar dolu şarjörlü", me.inv[0].get("ammo") == 1 and me.inv[2].get("ammo") == 30 and not me.inv[3].has("ammo"), me.inv)
	chk("sahibi olmayan kopya yalnızca yer bildirir", mate.add_item({"kind": "item", "id": "bomb"}) and mate.inv[3].is_empty())

	# --- yapı yerleştirme ve eşyalar
	me.slot = 4
	td.ok = false
	me._td_use(true)
	var none: bool = td.placed.is_empty()
	me._td_ghost(true)
	td.ok = true
	me._td_use(true)
	chk("yapı: can_place yoksa kurmaz, varsa kurar ve bir adet düşer", none and td.placed == ["wall"] and me.inv[3].count == 1 and me.ghost != null, [td.placed, me.inv[3]])
	me.slot = 5
	me._td_use(true)
	var kept: bool = not me.inv[4].is_empty() # can doluyken iksir harcanmaz
	me.hp = 40
	me._td_use(true)
	chk("can iksiri: 50 can, tek kullanım", kept and me.hp == 90 and me.inv[4].is_empty(), me.hp)
	me.add_item({"kind": "item", "id": "bomb"})
	td.hits.clear()
	me._td_use(true)
	await _wait(1.5)
	chk("bomba: fırlatılır, alan hasarı 120", me.inv[4].is_empty() and td.hits.any(func(x): return x[1] >= 120), td.hits) # önceki rastgele kart saldırı statını yükseltmiş olabilir

	# --- zırh, ölüm, yeniden doğma
	_reset()
	me.max_hp = 100
	me.hp = 100
	me.stats.armor = 0.5
	me.td_hit(20)
	chk("td_hit zırhı uygular (20 -> 10)", me.hp == 90, me.hp)
	me.td_hit(5000)
	chk("ölüm: can 0, yeniden doğma sayacı Balance'tan", me.hp == 0 and me.respawn_t > 1.0, me.respawn_t)
	me.global_position = Vector3(9, 0.1, 9)
	me.respawn_t = 0.3
	await _wait(0.8)
	chk("yeniden doğar: can dolu, doğma noktasında", me.hp == me.max_hp and me.global_position.distance_to(HOME) < 1.0, me.global_position)

	# --- dost ateşi kapalı (uzak oyuncunun silahı ve yeteneği bize işlemez; bizimki ona işlemez)
	_reset()
	me.hp = me.max_hp
	mate.global_position = Vector3(0, 0.1, -3)
	mate.net_pos = mate.global_position
	await _wait(0.2)
	var to_me: Vector3 = (me.global_position + Vector3.UP - mate.look.global_position).normalized()
	for id in ["bazooka", "pistol", "sword", "flame", "grenade"]:
		mate.td_fire(id, mate.look.global_position, PackedVector3Array([to_me]), 1)
	mate.td_skill(mate.global_position, me.global_position, to_me, "")
	h = await _fire("bazooka", 1.0) # eşin içinden geçip E1'e varır
	chk("dost ateşi kapalı", me.hp == me.max_hp and mate.hp == mate.max_hp and _names(h).has("E1") and not _names(td.hits).has("2"), [me.hp, mate.hp])
	mate.global_position = Vector3(6, 0.1, 0)
	mate.net_pos = mate.global_position

	# --- karakter yeteneği yaratıklara işler
	_reset()
	me.ch = load("res://characters.gd").LIST[14] # Kasap: 3,5 m alan, 30 hasar
	me.sk = me.ch.sk
	me.global_position = Vector3(0, 0.1, -4)
	me.skill_cd = 0.0
	td.hits.clear()
	me.ups = {"char:power": 2}
	me._use_skill()
	await _wait(0.2)
	chk("alan yeteneği yaratığa hasar verir (ustalık +%50)", td.hits.any(func(x): return x[0] == "E1" and x[1] == 45), td.hits)
	me.ch = load("res://characters.gd").LIST[3] # Joker: seken kart
	me.sk = me.ch.sk
	me.ups = {}
	me.skill_cd = 0.0
	td.hits.clear()
	me._use_skill()
	await _wait(3.5)
	chk("güdümlü yetenek yaratıkları kovalar ve seker", _names(td.hits).size() == 3 and td.hits[0][1] == 20, td.hits)
	me.ch = load("res://characters.gd").LIST[12] # Pastacı: 5 roket
	me.sk = me.ch.sk
	me.global_position = HOME
	me.skill_cd = 0.0
	td.hits.clear()
	me._use_skill()
	await _wait(1.2)
	chk("yaylım roketleri yaratığa patlar", _names(td.hits).has("E1"), td.hits.size())

	for w in Weapons.LIST: # tools/weapon_models.gd çıktısı içe aktarılmış olmalı
		var m := Weapons.make_prop(w)
		chk("%s modeli var" % w.id, not m.find_children("*", "MeshInstance3D", true, false).is_empty())
		m.free()

	var p := Weapons.tuned("pistol", {})
	chk("tabanca şarjörü 12", Weapons.mag_of(p) == 12)
	chk("tabanca doldurma 1.3 / boş 1.6", is_equal_approx(Weapons.reload_time(p, 1.0, false), 1.3) and is_equal_approx(Weapons.reload_time(p, 1.0, true), 1.6))
	chk("saldırı hızı x2 doldurmayı yarılar", is_equal_approx(Weapons.reload_time(p, 2.0, false), 0.65))
	chk("bazuka hızlı dolum 2 seviye", is_equal_approx(Weapons.tuned("bazooka", {"bazooka:reload": 2}).reload, 2.0 * 0.85 * 0.85))
	chk("kılıç ve bumerang şarjörsüz", Weapons.mag_of(Weapons.tuned("sword", {})) == 0 and Weapons.mag_of(Weapons.tuned("boomerang", {})) == 0)
	chk("yeni silahın şarjörü dolu", Weapons.full_ammo("smg") == 30 and Weapons.full_ammo("sword") == 0)
	const PARTS := {"pistol": ["slide", "mag"], "shotgun": ["pump"], "smg": ["mag"], "sniper": ["bolt", "mag"], "bazooka": ["rocket"],
		"flame": ["tank"], "bow": ["string_top", "string_bot", "arrow"], "grenade": ["pin", "ring", "spoon"]}
	for w in Weapons.LIST:
		var m := Weapons.make_prop(w)
		var need: Array = ["body", "muzzle", "grip_l"] + PARTS.get(w.id, [])
		chk("%s parçaları" % w.id, need.all(func(n): return m.find_child(n, true, false) != null), need)
		m.free()

	Net.set_weapon(3)
	chk("Net.set_weapon", Net.my_weapon == 3 and Net.weapons.get(1) == 1)
	print("WEAPONS_TEST: %d/%d" % [good, total])
	get_tree().quit()
