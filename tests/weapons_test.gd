extends Node
## TD silah / stat / kart / envanter testi, tek süreç, ağsız: godot --headless res://tests/weapons_test.tscn
## main.gd ve td.gd'ye bağlı değil: kendi zeminini, sahte TD düğümünü ve sahte yaratıklarını kurar.

const Weapons := preload("res://weapons.gd")
const PlayerScript := preload("res://player.gd")
const WA := preload("res://weapon_anims.gd")


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
	me._sync_held()
	me.busy = "" # yardımcı anında ateşler: çıkarma (draw) beklenmez
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
		var hits: Array = await _fire(w.id, 0.4 if w.id == "grenade" else 0.65 if w.id == "bow" else 2.6 if w.kind == "homing" else 1.2)
		if w.id in ["grenade", "bow"]: # basılı tut (pim / germe), bırakınca at
			me._release_throw()
			await _wait(3.0 if w.id == "grenade" else 1.2)
			hits = td.hits.duplicate()
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
	await _fire("bow", 0.65) # tam ger
	me._release_throw()
	await _wait(0.05)
	var arrow = world.get_children().filter(func(n): return str(n.name).begins_with("T1_"))
	chk("mermi hızı x2 -> ok 84 m/sn", arrow.size() == 1 and absf(arrow[0].spd - 84.0) < 1.0, arrow.size())
	me.ups = {"shotgun:pellets": 2, "bazooka:blast": 1}
	chk("silah yükseltmesi veriye işler", Weapons.tuned("shotgun", me.ups).n == 11 and is_equal_approx(Weapons.tuned("bazooka", me.ups).blast, 3.1))
	_reset()
	await _fire("pistol", 0.1)
	chk("atış şarjörden düşer", me.inv[0].ammo == 11, me.inv[0])
	me.inv[0].ammo = 0
	me.cd = 0.0
	td.hits.clear()
	me._td_use(true)
	chk("boş şarjör ateşlemez, doldurma başlar", td.hits.is_empty() and me.reloading)
	await _wait(2.0)
	chk("1.6 sn sonra dolu", me.inv[0].ammo == 12 and not me.reloading, me.inv[0])
	me.inv[0].ammo = 3
	me.start_reload()
	await _wait(0.5)
	me._set_slot(2)
	await _wait(0.1)
	me._set_slot(1)
	await _wait(1.5)
	chk("doldururken silah değişirse dolmaz", me.inv[0].ammo == 3, me.inv[0])
	me.inv[0] = {"kind": "weapon", "id": "shotgun", "count": 1, "lvl": 1, "ammo": 2}
	me.start_reload()
	await _wait(1.0)
	me.cd = 0.0
	me._td_use(true)
	chk("pompalı: fişek fişek dolar, ateş kesmez", me.inv[0].ammo >= 2 and not me.reloading, me.inv[0])
	me.stats.attack = 2.0
	me.inv[0] = {"kind": "weapon", "id": "smg", "count": 1, "lvl": 1, "ammo": 0}
	me.start_reload()
	await _wait(0.95)
	chk("saldırı x2: makineli 0.9 sn'de dolar", me.inv[0].ammo == 30, me.inv[0])
	me.stats.attack = 1.0
	var dry := 0
	me.inv[0].ammo = 0
	for i in 10:
		me.cd = 0.0
		me._td_use(i == 0)
		dry += int(me.busy == "reload")
	chk("boşken basılı tutmak tek doldurma başlatır", me.reloading and dry == 10)
	me.reloading = false
	me.busy = ""
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
	me.bag = Weapons.empty_bag().map(func(_d): return {"kind": "item", "id": "dummy", "count": 1}) # çanta da dolu
	chk("el ve çanta doluyken yeni silah kartı çıkmaz", not Weapons.pool(me).any(func(c): return c.type == "weapon"))
	me.bag = Weapons.empty_bag()
	var lv: int = me.level
	me.cards = []
	me.pending = 0
	me.level_up()
	me.level_up()
	var first: Array = me.cards
	chk("level_up: 3 kart, seviyeler birikir", first.size() == 3 and me.level == lv + 2 and me.pending == 2)
	me.choose_card(1)
	var second_ok: bool = me.cards.size() == 3
	me.choose_card(0)
	chk("biriken seviyeler sırayla seçilir", second_ok and me.cards.is_empty() and me.pending == 0)
	me.level_up()
	var g0: String = Weapons._group(me.cards[0])
	var b_ok: bool = me.banish_card(0)
	me.reroll_cards()
	chk("eleme: kart grubu bu maçta bir daha çıkmaz (yeniden çekince de)", b_ok and me.banished.has(g0) and me.cards.size() == 3
		and not me.cards.any(func(c): return Weapons._group(c) == g0), me.cards.map(func(c): return c.id))
	me.choose_card(0)
	me.banished.clear()

	# --- can statı: üst sınır canı da artırır
	var hp0: int = me.max_hp
	Weapons.stat_up(me.stats, "hp")
	me._td_changed()
	chk("can statı üst sınırı ve canı artırır", me.max_hp == hp0 + 15 and me.hp == me.max_hp, me.max_hp)

	# --- envanter kuralları
	me.inv = [{}, {}, {}, {}, {}]
	var r := []
	me.bag = Weapons.empty_bag().map(func(_d): return {"kind": "item", "id": "dummy", "count": 1}) # taşma çantaya gitmesin
	for d in [{"kind": "weapon", "id": "bow"}, {"kind": "weapon", "id": "bow"}, {"kind": "equip", "id": "wall"}, {"kind": "weapon", "id": "smg"},
			{"kind": "weapon", "id": "flame"}, {"kind": "build", "id": "wall"}, {"kind": "build", "id": "wall"}, {"kind": "item", "id": "potion"},
			{"kind": "item", "id": "bomb"}, {"kind": "build", "id": "turret"}, {"kind": "saçma", "id": "x"}]:
		r.append(me.add_item(d))
	chk("envanter: silah 1-3, yapı/eşya 4-5, yığılır, doluysa false",
		r == [true, false, true, true, false, true, true, true, false, false, false]
		and me.inv[0].id == "bow" and me.inv[1].id == "wall" and me.inv[1].kind == "equip" and me.inv[2].id == "smg"
		and me.inv[3].kind == "build" and me.inv[3].count == 2 and me.inv[4].id == "potion", [r, me.inv])
	me.bag = Weapons.empty_bag()
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
	me._sync_held()
	me.busy = ""
	me._td_use(true)
	await _wait(1.1) # içme klibi: can yudumda gelir
	chk("can iksiri: 50 can, tek kullanım", kept and me.hp >= 90 and me.hp <= 95 and me.inv[4].is_empty(), me.hp)
	me.add_item({"kind": "item", "id": "bomb"})
	td.hits.clear()
	me.busy = ""
	me._td_use(true)
	await _wait(0.4)
	me._release_throw()
	await _wait(3.2)
	chk("bomba: fırlatılır, alan hasarı 120", me.inv[4].is_empty() and td.hits.any(func(x): return x[1] >= 120), td.hits) # önceki rastgele kart saldırı statını yükseltmiş olabilir

	# --- el bombası: pim çek, beklet, at
	_reset()
	me.slot = 1
	me.inv[0] = {"kind": "weapon", "id": "grenade", "count": 1, "lvl": 1, "ammo": 1}
	me._sync_held()
	me.busy = ""
	td.hits.clear()
	me._td_use(true) # bas: pim
	await _wait(0.4)
	chk("basılı: pim çekildi, henüz atılmadı", me.busy == "prime" and me.fuse_left < 3.0 and me.fuse_left > 2.4, me.fuse_left)
	me._release_throw()
	await _wait(3.0)
	chk("bırakınca atılır, sigortayla patlar", _names(td.hits).has("E1"), td.hits)
	me.inv[0].ammo = 1
	me.busy = ""
	me.hp = me.max_hp
	me._td_use(true)
	await _wait(3.3)
	chk("elde patlarsa sahibine yarım hasar", me.hp == me.max_hp - int(Weapons.tuned("grenade", {}).dmg * 0.5), me.hp)
	me.inv[0].ammo = 1
	me.busy = ""
	me.hp = me.max_hp
	me._td_use(true)
	await _wait(0.5)
	me.td_hit(1000)
	await _wait(3.0)
	chk("pimliyken ölünce bomba yere düşüp patlar", me.fuse_left == 0.0 and get_tree().get_nodes_in_group("rockets").is_empty(), me.fuse_left)
	me.hp = me.max_hp

	# --- yay germe, dürbün, bumerang, kılıç serisi
	_reset()
	me.slot = 1
	me.inv[0] = {"kind": "weapon", "id": "bow", "count": 1, "lvl": 1, "ammo": 1}
	me._sync_held()
	me.busy = ""
	me._td_use(true)
	await _wait(0.3)
	td.hits.clear()
	me._release_throw()
	await _wait(0.6)
	var weak: Array = td.hits.duplicate()
	me.inv[0].ammo = 1
	me.busy = ""
	me.reloading = false
	me._td_use(true)
	await _wait(0.7)
	td.hits.clear()
	me._release_throw()
	await _wait(0.6)
	chk("yay: tam gerili güçlü, yarım gerili zayıf", weak.size() == 1 and td.hits.size() == 1 and td.hits[0][1] > weak[0][1], [weak, td.hits])
	me.inv[0] = {"kind": "weapon", "id": "sniper", "count": 1, "lvl": 1, "ammo": 5}
	me.scoped = true
	chk("dürbün yürümeyi yavaşlatır", is_equal_approx(me._speed(), me.SPEED * me.ch.get("speed", 1.0) * 0.65), me._speed())
	me.scoped = false
	await _fire("boomerang", 0.05)
	chk("bumerang havadayken yeniden atılmaz", me.thrown == 1 and not me._can_fire(), me.thrown)
	await _wait(6.0)
	chk("dönünce yakalanır", me.thrown == 0, me.thrown)
	me.inv[0] = {"kind": "weapon", "id": "sword", "count": 1, "lvl": 1}
	me.global_position = Vector3(0, 0.1, -4.2)
	me._sync_held()
	var dm := []
	for i in 3:
		me.cd = 0.0
		me.busy = ""
		td.hits.clear()
		me._td_use(true)
		await _wait(0.3)
		dm.append(td.hits[0][1] if td.hits else 0)
	chk("kılıç 3'lü seri, üçüncü daha güçlü", dm[2] > dm[0] and me.combo == 0, dm)
	_reset()

	# --- iksir içme, yapı yerleştirme
	_reset()
	me.inv[3] = {"kind": "item", "id": "potion", "count": 2, "lvl": 1}
	me.slot = 4
	me._sync_held()
	me.busy = ""
	me.max_hp = int(me.stats.hp) # _reset statları sıfırlar; can tavanı eşleşsin
	me.hp = 20
	me._td_use(true)
	await _wait(0.2)
	chk("iksir: hemen iyileştirmez, içiyor", me.hp == 20 and me.busy == "drink", [me.hp, me.busy])
	await _wait(0.95) # gulp 1.05'te
	chk("yudumda +50 ve bir şişe eksilir", me.hp >= mini(70, me.max_hp) and me.hp <= mini(75, me.max_hp) and me.inv[3].count == 1, [me.hp, me.max_hp, me.inv[3]])
	await _wait(0.65) # done 1.7'de
	chk("içme bitti", me.busy == "", me.busy)
	me._td_use(true) # son şişe: yudumda slot boşalır ama klip sonuna dek oynar
	await _wait(1.2)
	chk("son şişe: yudumdan sonra klip sürer", me.inv[3].is_empty() and me.busy == "drink" and me.held_id == "item:potion", [me.inv[3], me.busy, me.held_id])
	await _wait(0.65)
	chk("son şişe: klip bitince eller iner", me.busy == "" and me.held_id == "", [me.busy, me.held_id])
	me.inv[3] = {"kind": "build", "id": "wall", "count": 2, "lvl": 1}
	me._sync_held()
	chk("yapı slotunda eller boş (yerleştirme klibi var)", me.held_id == "build" and WA.has("build", "place"), me.held_id)
	me.hp = me.max_hp
	_reset()

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
	const Hands := preload("res://hands.gd")
	for left in [false, true]:
		var hd: Node3D = Hands.make(Color.RED, left)
		chk("el parçaları (sol=%s)" % left, ["palm", "thumb", "f0", "f3", "wrist"].all(func(n): return hd.find_child(n, true, false) != null))
		chk("parmak ve başparmak 3 boğum (f0/a/b)", range(4).all(func(i): return hd.find_child("f%d" % i, true, false).has_node("a/b")) and hd.find_child("thumb", true, false).has_node("a/b"))
		chk("pozlar: grip support open pinch bottle cork", ["grip", "support", "open", "pinch", "bottle", "cork"].all(func(n): return Hands.POSES.has(n)))
		var f1: Node3D = hd.find_child("f1", true, false)
		Hands.pose(hd, "grip")
		var fa := f1.rotation.x
		Hands.pose(hd, "open")
		chk("kavrama parmakları büker, açık düzeltir", fa < -0.8 and absf(f1.rotation.x) < 0.2, fa)
		Hands.pose(hd, "grip", true)
		chk("blend pozu anında değiştirmez", absf(f1.rotation.x) < 0.2, f1.rotation.x)
		Hands.update(hd, 0.5)
		chk("update(0.5) sonrası hedefte", absf(f1.rotation.x - fa) < 0.01, f1.rotation.x)
		chk("el gölge atmaz", hd.find_children("*", "MeshInstance3D", true, false).all(func(m): return m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
		hd.free()
	var ha: Node3D = Hands.make(Color.RED, false)
	var hb: Node3D = Hands.make(Color.BLUE, false)
	chk("el ağları paylaşılır", ha.find_child("f0", true, false).get_child(0).mesh == hb.find_child("f0", true, false).get_child(0).mesh)
	ha.free()
	hb.free()
	var pot: Node3D = load("res://potion.gd").make()
	chk("iksir çocukları", ["glass", "liquid", "cork", "muzzle", "twine", "glow"].all(func(n): return pot.get_node_or_null(n) != null) and pot.get_node("muzzle") is Marker3D)
	var lm := (pot.get_node("liquid") as MeshInstance3D).material_override as ShaderMaterial
	pot.set("fill", 0.3)
	chk("iksir fill -> shader", lm != null and is_equal_approx(float(lm.get_shader_parameter("fill")), 0.3))
	pot.free()
	for id in ["pistol", "shotgun", "smg", "sniper", "bazooka", "flame", "bow", "grenade", "boomerang", "sword", "item:potion", "item:bomb"]:
		chk("%s draw" % id, WA.has(id, "draw"))
	var an := WA.build("pistol", "reload")
	chk("tabanca reload süresi 1.3", is_equal_approx(an.length, 1.3), an.length)
	var ev := []
	for t in an.get_track_count():
		if an.track_get_type(t) == Animation.TYPE_METHOD:
			for k in an.track_get_key_count(t):
				var v: Dictionary = an.track_get_key_value(t, k)
				if v.method == "_ev":
					ev.append([an.track_get_key_time(t, k), v.args[0]])
	chk("mag_in %85'te", ev.any(func(e): return e[1] == "mag_in" and is_equal_approx(e[0], 1.3 * 0.85)), ev)
	chk("iksir gulp", WA.has("item:potion", "drink"))
	var dr: Dictionary = WA.clips("item:potion").drink
	var t_of := func(n: String) -> float: return dr.events.filter(func(e): return e[1] == n)[0][0]
	chk("içme: gulp < done, done sonda", t_of.call("gulp") < t_of.call("done") and is_equal_approx(t_of.call("done"), dr.len), dr.events)
	var da := WA.build("item:potion", "drink")
	var ft := da.find_track(NodePath("Rig/Weapon:fill"), Animation.TYPE_VALUE)
	chk("içme: Rig/Weapon:fill değer izi 1 -> 0.05", ft >= 0 and is_equal_approx(da.value_track_interpolate(ft, 0.0), 1.0) and da.value_track_interpolate(ft, dr.len) < 0.1)
	chk("içme: tıpa izi var", range(da.get_track_count()).any(func(t): return str(da.track_get_path(t)) == "Rig/Weapon/cork"))
	var dp := WA.build("item:potion", "drink", true)
	chk("içme parts_only: yalnız şişe parçaları (HandL, fill yok)", range(dp.get_track_count()).all(func(t): return not str(dp.track_get_path(t)).begins_with("HandL") and not str(dp.track_get_path(t)).begins_with("Rig")))
	chk("içme parts_only: modelsiz iksirde çözülemeyen tıpa izi yok", range(dp.get_track_count()).all(func(t): return not str(dp.track_get_path(t)).begins_with("cork")))
	var mt := da.find_track(NodePath("."), Animation.TYPE_METHOD)
	var calls := range(da.track_get_key_count(mt)).map(func(k): return da.method_track_get_params(mt, k))
	chk("aynı andaki el pozları ezilmez (sağ el bottle, sol el open)", calls.has(["R", "bottle"]) and calls.has(["L", "open"]), calls)
	var po := WA.build("pistol", "reload", true)
	chk("parts_only: yalnız parça izleri", range(po.get_track_count()).all(func(t): return po.track_get_type(t) == Animation.TYPE_METHOD or not str(po.track_get_path(t)).begins_with("HandL")))
	const NEED := {"pistol": ["fire", "dry", "reload", "reload_empty"], "smg": ["fire", "dry", "reload"], "sniper": ["fire", "dry", "reload"],
		"bazooka": ["fire", "dry", "reload"], "flame": ["fire", "dry", "reload"], "shotgun": ["fire", "dry", "reload_start", "shell", "reload_end"],
		"bow": ["draw_string", "release", "reload"], "grenade": ["prime", "throw", "reload"], "item:bomb": ["prime", "throw", "reload"],
		"boomerang": ["throw", "catch"], "sword": ["swing1", "swing2", "swing3"], "item:potion": ["drink"]}
	for id in NEED:
		chk("%s klipleri" % id, NEED[id].all(func(c): return WA.has(id, c) and WA.build(id, c).length > 0.0), NEED[id])

	var vm: Node3D = load("res://viewmodel.gd").new()
	add_child(vm)
	vm.setup(Color.BLUE)
	var got := []
	vm.event.connect(func(n): got.append(n))
	vm.equip("pistol")
	await _wait(0.5)
	chk("viewmodel çıkarma bitti -> ready", got.has("ready") and vm.current() == "pistol", got)
	chk("namlu ileride", vm.to_local(vm.muzzle()).z < -0.2, vm.to_local(vm.muzzle()))
	vm.equip("item:potion")
	vm.weapon.set("fill", 0.2)
	vm.weapon.get_node("cork").position.y = 0.3
	vm.equip("item:potion")
	chk("iksir yeniden kuşanılınca dolu, tıpa yerinde", is_equal_approx(float(vm.weapon.get("fill")), 1.0) and is_equal_approx(vm.weapon.get_node("cork").position.y, 0.085))
	chk("çıkarma başında sağ el pozu anında (bottle)", is_equal_approx(vm.hand_r.find_child("f0", true, false).rotation.x, Hands.POSES.bottle.f[0][0]))
	vm.queue_free()
	var va: Node3D = load("res://viewmodel.gd").new()
	add_child(va)
	va.setup(Color.BLUE, "res://models/chars/casual2_male.glb")
	va.equip("pistol")
	var sks := va.find_children("*", "Skeleton3D", true, false)
	chk("kollu viewmodel: Skeleton3D var", sks.size() == 1)
	if sks.size() == 1:
		var sk: Skeleton3D = sks[0]
		chk("kol ağları katman 2, gölgesiz", va.get_node("Arms").find_children("*", "MeshInstance3D", true, false).all(func(m): return m.layers == 2 and m.cast_shadow == 0))
		chk("Fist.L büzük (~0)", sk.get_bone_pose_scale(sk.find_bone("Fist.L")).x < 0.01)
	va.queue_free()
	chk("yerel oyuncuda viewmodel, 3. şahıs silahı gizli", me.vm != null and not me.gun.visible and me.cam.cull_mask & 2 == 0)

	Net.set_weapon(3)
	chk("Net.set_weapon", Net.my_weapon == 3 and Net.weapons.get(1) == 1)
	print("WEAPONS_TEST: %d/%d" % [good, total])
	get_tree().quit()
