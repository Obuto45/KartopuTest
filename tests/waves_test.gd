extends Node
## Dalga sistemi: zorluk, modifikatör, boss, sonsuz mod, düşme, özet.
## godot --headless --path . res://tests/waves_test.tscn   Son satır: WAVES_TEST: N/M

const Balance := preload("res://balance.gd")

var main: Node
var td: Node
var good := 0
var total := 0
var summary := {}


func _ok(title: String, cond: bool, note := "") -> void:
	total += 1
	good += int(cond)
	print("[%s] %s %s" % ["OK" if cond else "HATA", title, note])


func _until(cond: Callable, t: float) -> bool:
	var end := Time.get_ticks_msec() + int(t * 1000.0 / Engine.time_scale)
	while not cond.call():
		if Time.get_ticks_msec() > end:
			return false
		await get_tree().physics_frame
	return true


func _ready() -> void:
	preload("res://profile.gd").use_path("user://test_profile.cfg") # kalıcı profil kirlenmesin (tavuk, maç sonu)
	# Saf Balance denetimleri
	var b1 := Balance.wave(3, 1)
	var bh := Balance.wave(3, 1, "hard")
	_ok("zorluk çarpanları", is_equal_approx(bh.hp_mult, b1.hp_mult * Balance.DIFFS.hard.hp) and is_equal_approx(bh.dmg_mult, b1.dmg_mult * Balance.DIFFS.hard.dmg)
		and Balance.wave(3, 1, "easy").hp_mult < b1.hp_mult)
	var m1 := Balance.roll_mods(7, "normal", 123)
	_ok("roll_mods deterministik, dalga 1-2 boş", m1 == Balance.roll_mods(7, "normal", 123) and Balance.roll_mods(1, "normal", 5).is_empty()
		and Balance.roll_mods(2, "nightmare", 5).is_empty() and m1.size() == 1 and Balance.roll_mods(3, "nightmare", 5).size() == 2)
	var fast := Balance.wave(3, 1, "normal", ["fast"])
	var capped := true
	for t in Balance.ENEMIES:
		capped = capped and Balance.enemy_speed(t, fast) <= maxf(Balance.ENEMIES[t].speed, Balance.SPEED_CAP) + 0.001
	_ok("fast: hız <= 6,9", capped and is_equal_approx(Balance.enemy_speed("runner", fast), 6.9) and is_equal_approx(Balance.enemy_speed("grunt", fast), 3.84))
	var w15 := Balance.wave(15, 1)
	var mono := true
	for n in range(1, 20):
		mono = mono and Balance.wave(n + 1, 1).hp_mult > Balance.wave(n, 1).hp_mult
	_ok("sonsuz: wave(15) boss, hp monoton", w15.boss == "boss" and Balance.wave(11, 1).boss == "" and mono
		and Balance.roll_mods(15, "normal", 1).size() == 2)
	_ok("yaratıktan eşya düşmez (roll_drop / DROPS kalktı)", not Balance.new().has_method("roll_drop") and not Balance.new().get_script().get_script_constant_map().has("DROPS"))

	# Oyun içi
	main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(0.3).timeout
	Net.host_local()
	main.start_td([1])
	td = main.world.get_node("TD")
	td.summary_ready.connect(func(d): summary = d)
	Engine.time_scale = 8.0
	await get_tree().create_timer(0.5).timeout
	var me: Node = main.players.get_node("1")

	# Mola: seçilmemiş kart varken (tek kişilik) geri sayım durur, kartlar bitince akar; BREAK_TIME 40 sn
	_ok("mola süresi 40 sn", Balance.BREAK_TIME >= 40.0 and td.state == "break")
	me.cards = [{"type": "stat"}]
	td.time_left = 30.0
	await get_tree().create_timer(0.5).timeout
	_ok("kart açıkken mola süresi akmaz", is_equal_approx(td.time_left, 30.0), "kalan %.2f" % td.time_left)
	me.cards = []
	await get_tree().create_timer(0.5).timeout
	_ok("kart bitince mola süresi akar", td.time_left < 30.0, "kalan %.2f" % td.time_left)
	td.time_left = Balance.BREAK_TIME

	# Boss
	td.endless = true
	td.wave = 4
	td.ready_up()
	await _until(func(): return td.state == "fight", 6.0)
	var spawned: bool = await _until(func(): return td.boss_eid != 0, 40.0)
	var boss: Node = td._by_id.get(td.boss_eid)
	_ok("boss doğunca boss_eid != 0", spawned and boss != null and boss.type == "ogre")
	if boss:
		td.damage_enemy(boss.name, 999999, false)
	_ok("boss ölünce boss_eid = 0", td.boss_eid == 0)

	# Sonsuz: dalga 10'dan sonra 11
	td.wave = 9
	var guard := 0
	while td.wave < 11 and td.state != "lost" and guard < 400000:
		guard += 1
		if td.state == "break" and not td.is_ready(1):
			td.ready_up()
		for e in td.elist.duplicate():
			td.damage_enemy(e.name, 999999, false)
		await get_tree().physics_frame
	_ok("sonsuz: 10'dan sonra 11", td.wave == 11 and td.state == "fight" and td.endless, "dalga %d durum %s" % [td.wave, td.state])
	td.hurt_tower(999999)
	await get_tree().create_timer(0.5).timeout
	var sum := 0
	for p in summary.get("players", {}):
		sum += summary.players[p].kills
	_ok("kayıp + özet: kills toplamı", td.state == "lost" and summary.get("won") == false and summary.get("wave") == 11
		and sum == td.kills and td.kills > 0 and summary.mvp == 1, "kills %d özet %d" % [td.kills, sum])
	print("WAVES_TEST: %d/%d" % [good, total])
	Engine.time_scale = 1.0
	get_tree().quit()
