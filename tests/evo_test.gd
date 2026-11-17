extends Node
## TD silah evrimleri testi, tek süreç, ağsız: godot --headless --path . res://tests/evo_test.tscn
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


func _ids() -> Array:
	return Weapons.pool(me).map(func(c): return c.id)


func _clear() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")
		e.queue_free()


## Silahı sahiplenir, evrim koşulunun tamamını (ya da eksiğini) kurar.
func _ready_for(id: String, full := true) -> void:
	_reset()
	me.inv[0] = {"kind": "weapon", "id": id, "count": 1, "lvl": 1}
	var ev: Dictionary = Weapons.EVOS[id]
	for u in ev.needs:
		me.ups["%s:%s" % [id, u]] = ev.needs[u]
	me.stats[ev.stat[0]] = ev.stat[1] if full else Weapons.stat_def(ev.stat[0]).base


func _evolve(id: String) -> void:
	Weapons.apply_card(me, {"id": "evo:" + id, "type": "evo"})


func _ready() -> void:
	InputMap.add_action("throw")
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
	Net.weapons[1] = 1
	me = _player(1, HOME)
	_enemy("E1", Vector3(0, 0, -6))
	_enemy("E2", Vector3(3, 0, -7))
	_enemy("E3", Vector3(0, 0, -8))
	await _wait(0.4)

	# --- havuz: koşul yok / kısmi / tam
	chk("10 silahın hepsinin evrimi var", Weapons.EVOS.size() == 10 and Weapons.LIST.all(func(w): return Weapons.EVOS.has(w.id)))
	_reset()
	chk("koşul yokken havuzda evo yok", not _ids().any(func(i): return i.begins_with("evo:")))
	var all_ok := true
	for w in Weapons.LIST:
		var id: String = w.id
		var ev: Dictionary = Weapons.EVOS[id]
		var first: String = ev.needs.keys()[0]
		_ready_for(id)
		var full := _ids().has("evo:" + id)
		_ready_for(id)
		me.ups["%s:%s" % [id, first]] = 0
		var part_up := _ids().has("evo:" + id) # yalnız bir yükseltme tamam
		_ready_for(id, false)
		var part_stat := _ids().has("evo:" + id) # yükseltmeler tamam, stat eksik
		_ready_for(id)
		me.inv[0] = {}
		var unowned := _ids().has("evo:" + id)
		if not (full and not part_up and not part_stat and not unowned):
			all_ok = false
			print("  evrim koşulu hatalı: ", id, [full, part_up, part_stat, unowned])
	chk("her evrim: tam koşulda var; kısmi, stat eksik ve sahipsizken yok", all_ok)
	_ready_for("pistol")
	var card: Dictionary = Weapons.pool(me).filter(func(c): return c.id == "evo:pistol")[0]
	chk("evo kartı Efsanevi, ağırlık ~40", card.rarity == "legendary" and card.type == "evo" and Weapons._weight(card) == 40.0, card)
	_evolve("pistol")
	var t := Weapons.tuned("pistol", me.ups)
	chk("apply_card sonrası tuned() evrim alanlarını döner", t.evo == "Altıpatlar Lordu" and t.crit_chain == 2 and t.color == Color(1.0, 0.35, 0.3), t.get("evo"))
	chk("envanter adı evrilmiş", Weapons.item_name(me.inv[0]) == "Altıpatlar Lordu", Weapons.item_name(me.inv[0]))
	chk("evrilince kart bir daha çıkmaz", not _ids().has("evo:pistol"))
	chk("evrilmemiş silahın tuned()'ında evrim yok", not Weapons.tuned("bazooka", me.ups).has("evo"))
	var tg := Weapons.tuned("shotgun", {"evo:shotgun": 1})
	chk("add evrimi: pompalı n 11, delme 1", tg.n == 11 and tg.pierce == 1, [tg.n, tg.pierce])

	# --- Tabanca: kritik vuruş zincire 2 sekme ekler
	_reset()
	me.stats.crit = 1.0
	var base: Array = await _fire("pistol", 0.2)
	me.ups = {"evo:pistol": 1} # yükseltmesiz: sekme yalnızca evrimden
	var evo_hits: Array = await _fire("pistol", 0.2)
	me.stats.crit = 0.0
	var nocrit: Array = await _fire("pistol", 0.2)
	chk("Altıpatlar: kritikte 3 isabet (1 + 2 sekme), taban 1, kritiksiz 1", base.size() == 1 and evo_hits.size() == 3 and nocrit.size() == 1, [base.size(), evo_hits.size(), nocrit.size()])

	# --- Bazuka: 3 mini patlama (halkada 3 ek yaratık)
	_clear()
	await _wait(0.1)
	_enemy("E1", Vector3(0, 0, -6))
	for i in 3:
		var a := TAU * i / 3.0
		_enemy("R%d" % i, Vector3(0, 0, -6) + Vector3(cos(a), 0, sin(a)) * 3.3)
	await _wait(0.1)
	_reset()
	var b0: Array = await _fire("bazooka", 1.3)
	var ring0 := _names(b0).filter(func(n): return n.begins_with("R")).size()
	me.ups = {"evo:bazooka": 1}
	var b1: Array = await _fire("bazooka", 1.3)
	var ring1 := _names(b1).filter(func(n): return n.begins_with("R")).size()
	chk("Kıyamet Bazukası: 3 mini patlama halkadakilere vurur (taban 0)", ring0 == 0 and ring1 == 3, [ring0, ring1])
	var main_dmg: int = b1.filter(func(h): return h[0] == "E1")[0][1]
	chk("mini hasar ana patlamanın %40'ı", b1.any(func(h): return h[0].begins_with("R") and h[1] == roundi(main_dmg * 0.4)), b1)

	# --- Alev: yanık 3 m'de yayılır
	_clear()
	await _wait(0.1)
	_enemy("E1", Vector3(0, 0, -6))
	_enemy("E2", Vector3(2.5, 0, -6))
	_enemy("E3", Vector3(0, 0, -12))
	await _wait(0.1)
	var e1: Node = get_tree().get_nodes_in_group("enemies").filter(func(e): return e.name == "E1")[0]
	_ready_for("flame", false)
	me.burns.clear()
	me.td_affect(e1, Weapons.tuned("flame", me.ups), Vector3.ZERO)
	me._tick(1.0, true)
	var n0: int = me.burns.size()
	_ready_for("flame")
	_evolve("flame")
	me.burns.clear()
	me.td_affect(e1, Weapons.tuned("flame", me.ups), Vector3.ZERO)
	me._tick(1.0, true)
	chk("Ejderha Nefesi: yanık 3 m içindekine geçer, uzaktakine geçmez (taban yayılmaz)", n0 == 1 and me.burns.size() == 2 and me.burns.has(&"E2") and not me.burns.has(&"E3"), [n0, me.burns.keys()])

	# --- Yay: yanarken ölen 4 m patlar
	_ready_for("bow")
	_evolve("bow")
	me.burns.clear()
	td.hits.clear()
	me.td_affect(e1, Weapons.tuned("bow", me.ups), Vector3.ZERO)
	td.hits.clear()
	e1.hp = 0
	me._tick(1.0, true)
	await _wait(0.2)
	chk("Avcı Yayı: yanan yaratık ölünce 4 m patlar (E2 vurulur, E3 uzak)", _names(td.hits) == ["E2"], td.hits)
	e1.hp = 100000

	# --- Sinerji: ateş + sekme -> yanık sekerken taşınır
	_ready_for("smg", false)
	me.ups["smg:burn"] = 2
	me.stats.bounce = 1.0
	me.stats.crit = 0.0
	me.burns.clear()
	me._td_shot(Weapons.tuned("smg", me.ups), Vector3(0, 1.2, 0), Vector3(0, 0, -1), true)
	chk("sinerji: sekilen yaratık da yanar (1,5 kat uzun)", me.burns.size() == 2 and me.burns.values().any(func(b): return b[2] > Weapons.BURN_T), me.burns.values().map(func(b): return b[2]))

	print("EVO_TEST: %d/%d" % [good, total])
	get_tree().quit()
