extends Node
## Tower Defense çekirdeğini tek süreçte dener: godot --headless --path . res://tests/td_test.tscn
## Dalga akışı, doğma, kule hasarı, ödül / seviye, satın alma / kurma, taret, duvar, kazanma, kaybetme.
## Son satır: TD_TEST: N/M

const Balance := preload("res://balance.gd")

var main: Node
var td: Node
var me: Node
var good := 0
var total := 0
var ev := {"wave": 0, "level": 0, "won": 0, "lost": 0, "changed": 0}


func _ok(title: String, cond: bool, note := "") -> void:
	total += 1
	good += int(cond)
	print("[%s] %s %s" % ["OK" if cond else "HATA", title, note])


## cond doğru olana dek (en çok t oyun saniyesi) bekler.
func _until(cond: Callable, t: float) -> bool:
	var end := Time.get_ticks_msec() + int(t * 1000.0 / Engine.time_scale)
	while not cond.call():
		if Time.get_ticks_msec() > end:
			return false
		await get_tree().physics_frame
	return true


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _start() -> void:
	if main.has_method("start_td"):
		main.start_td([1])
	else: # C'nin başlatıcısı yoksa dünyayı kendimiz kur
		main._clear_world()
		main._set_menu_bg(false)
		main._build_world()
		var p: CharacterBody3D = load("res://player.gd").new()
		p.name = "1"
		p.spawn_pos = Vector3(5, 1, 0)
		main.players.add_child(p)
	if main.world.get_node_or_null("TD") == null:
		var t: Node = load("res://td.gd").new()
		t.name = "TD"
		main.world.add_child(t)
	td = main.world.get_node("TD")
	me = main.players.get_node("1")
	td.wave_started.connect(func(_w): ev.wave += 1)
	td.leveled.connect(func(_l): ev.level += 1)
	td.run_ended.connect(func(won): ev["won" if won else "lost"] += 1)
	td.changed.connect(func(): ev.changed += 1)


func _kill_all() -> void:
	for e in td.elist.duplicate():
		td.damage_enemy(e.name, 999999, false)


func _ready() -> void:
	main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _wait(0.3)
	Net.host_local()
	_start()
	Engine.time_scale = 8.0
	await _wait(0.5)

	# 1) Kurulum
	var w: Node = main.world
	_ok("kurulum", td.is_in_group("td") and w.get_node_or_null("Tower") != null and w.get_node_or_null("Enemies") != null
		and w.get_node_or_null("Builds") != null and td.state == "break" and td.tower_hp == Balance.TOWER_HP and td.xp_next == Balance.xp_for(1, 1))
	_ok("denge tablosu", Balance.ENEMIES.size() >= 6 and Balance.wave(10, 1).boss == "boss" and Balance.wave(5, 4).boss == "ogre"
		and Balance.wave(3, 4).groups[0].count > Balance.wave(3, 1).groups[0].count and Balance.SPAWN_POINTS.size() == 8)

	# 2) Hazır oyu -> dalga 1
	td.ready_up()
	await _until(func(): return td.state == "fight", 6.0)
	_ok("hazır -> dalga başlar", td.state == "fight" and td.wave == 1 and ev.wave == 1, "olay %d" % ev.wave)

	# 3) Doğma, kuleye hasar, oyuncuya hasar
	await _until(func(): return td.elist.size() >= 3, 12.0)
	_ok("yaratıklar doğdu", td.elist.size() >= 3 and td.enemies_left > 0, "canlı %d kalan %d" % [td.elist.size(), td.enemies_left])
	var hp0: int = me.hp
	await _until(func(): return td.tower_hp < td.tower_max, 40.0)
	_ok("kuleye ulaşıp vurdular", td.tower_hp < td.tower_max, "kule %d/%d" % [td.tower_hp, td.tower_max])
	await _until(func(): return me.hp < hp0, 25.0)
	_ok("avcı oyuncuya vurdu", me.hp < hp0, "can %d -> %d (td_hit %s)" % [hp0, me.hp, "var" if me.has_method("td_hit") else "YOK: take_hit"])

	# 4) damage_enemy -> para + XP, seviye
	await _until(func(): return not td.elist.is_empty(), 10.0)
	var m0: int = td.money
	var k0: int = td.kills
	var e0: Node = td.elist[0]
	var xp0: int = td.xp + (td.level - 1) * 1000
	td.damage_enemy(e0.name, 5, false)
	var part: bool = e0.hp == e0.max_hp - 5 and e0.bar.visible
	td.damage_enemy(e0.name, 99999, true)
	_ok("damage_enemy: can düşer, ölüm para+XP verir", part and e0.hp == 0 and td.money == m0 + e0.d.money and td.kills == k0 + 1
		and td.xp + (td.level - 1) * 1000 > xp0 and not td.elist.has(e0))
	while td.state == "fight":
		_kill_all()
		await get_tree().physics_frame
	await _wait(0.3)
	_ok("seviye atlandı", td.level >= 2 and ev.level >= 1, "seviye %d xp %d/%d" % [td.level, td.xp, td.xp_next])
	_ok("dalga bitti -> mola + bonus", td.state == "break" and td.time_left > 20.0 and td.money >= m0 + Balance.wave_bonus(1), "para %d" % td.money)

	# 5) Satın alma ve kurma
	td.money = 500
	var m1: int = td.money
	var bought: bool = td.buy("turret")
	await _wait(0.3)
	if me.has_method("add_item"):
		_ok("buy: para düştü, envantere girdi", bought and td.money == m1 - Balance.shop("turret").price
			and str(me.get("inv")).contains("turret"), "inv %s" % str(me.get("inv")))
	else:
		_ok("buy: add_item yokken para düşmez", not bought and td.money == m1, "(B'nin add_item'ı henüz yok)")
	td.money = 0
	_ok("buy: para yetmezse olmaz", not td.buy("wall") and td.money == 0)
	_ok("can_place kuralları", td.can_place("wall", Vector3(8, 0, 0)) and not td.can_place("wall", Vector3(2, 0, 0))
		and not td.can_place("wall", Vector3(40, 0, 0)) and not td.can_place("yok", Vector3(8, 0, 0)))
	td.place("wall", Vector3(8, 0, 0), PI / 2) # +X yolunu kesen duvar
	td.place("wall", Vector3(8.5, 0, 0.5), 0.0) # çok yakın: reddedilmeli
	td.place("trap", Vector3(-8, 0, 0), 0.0)
	td.place("spike", Vector3(0, 0, -9), 0.0)
	td.place("frost", Vector3(0, 0, 9), 0.0)
	await _wait(0.5)
	var wall: Node = td.builds.get_child(0)
	_ok("place: yapılar kuruldu", td.builds.get_child_count() == 4 and wall.id == "wall" and wall.is_in_group("builds")
		and wall is StaticBody3D and not td.can_place("turret", Vector3(8.5, 0, 0.5)), "%d yapı" % td.builds.get_child_count())

	# 6) Duvar yolu keser ve saldırıya uğrar (dalga 2'nin kendi sırası boşaltılır, yaratıklar elle konur)
	td.ready_up()
	await _until(func(): return td.state == "fight", 6.0)
	td._queue.clear()
	td._to_spawn = 0
	td._spawn_now("grunt", Vector3(13, 0, 0))
	var g: Node = td.elist[0]
	await _until(func(): return wall.hp < wall.max_hp, 20.0)
	_ok("duvar yolu kesti ve saldırıldı", wall.hp < wall.max_hp and g.global_position.x > 8.0 and td.tower_hp == td.tower_max,
		"duvar %d/%d, yaratık x=%.1f" % [wall.hp, wall.max_hp, g.global_position.x])
	# Tuzak ve dikenli duvar
	td._spawn_now("grunt", Vector3(-13, 0, 0))
	var g2: Node = td.elist[1]
	td._spawn_now("grunt", Vector3(0, 0, -13))
	var g3: Node = td.elist[2]
	var trap: Node = td.builds.get_child(1)
	await _until(func(): return trap.hp < trap.max_hp and g3.hp < g3.max_hp, 20.0)
	_ok("tuzak ve diken hasar verdi", trap.hp < trap.max_hp and g2.hp < g2.max_hp and g3.hp < g3.max_hp,
		"tuzak şarj %d, g2 %d/%d, g3 %d/%d" % [trap.hp, g2.hp, g2.max_hp, g3.hp, g3.max_hp])
	# Taret
	_kill_all()
	td.place("turret", Vector3(6, 0, 6), 0.0)
	await _wait(0.3)
	var k1: int = td.kills
	td._spawn_now("runner", Vector3(14, 0, 8))
	await _until(func(): return td.kills > k1, 20.0)
	_ok("taret yaratık öldürdü", td.kills > k1)

	# 7) Dalga 10'a kadar: her şeyi öldürerek kazan
	var guard := 0
	while td.state != "won" and td.state != "lost" and guard < 400000:
		guard += 1
		if td.state == "break" and not td.is_ready(1):
			td.ready_up()
		_kill_all()
		await get_tree().physics_frame
	await _wait(0.3)
	_ok("dalga 10 sonrası kazanıldı", td.state == "won" and td.wave == Balance.WAVE_COUNT and ev.won == 1 and ev.lost == 0,
		"dalga %d seviye %d öldürme %d para %d" % [td.wave, td.level, td.kills, td.money])

	# 8) Yeni koşu: kule canı bitince kayıp; ayrılan oyuncu hata vermez
	_start()
	await _wait(0.5)
	td._on_peer_left(7)
	td.ready_up()
	await _until(func(): return td.state == "fight", 6.0)
	td.hurt_tower(td.tower_max - 100)
	await _wait(0.3)
	var cracked: bool = td.state == "fight" and td.tower.smoke.emitting
	td.hurt_tower(999)
	await _wait(0.5)
	_ok("kule yıkılınca kayıp", cracked and td.state == "lost" and td.tower_hp == 0 and ev.lost == 1 and td.tower.fallen)
	print("TD_TEST: %d/%d" % [good, total])
	Engine.time_scale = 1.0
	get_tree().quit()
