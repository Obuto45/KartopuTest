extends Node
## İki süreçli Tower Defense ağ testi: godot --headless res://tests/td_net.tscn -- host|join
## İstemcinin ateşi, satın alması, yapı kurması ve seviye kartı host'a ulaşıyor mu, ona bakar.

var n_ok := 0
var n_all := 0

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _until(cond: Callable, t: float) -> bool:
	while t > 0.0 and not cond.call():
		await _wait(0.1)
		t -= 0.1
	return cond.call()

func _ok(role: String, title: String, cond: bool, note = "") -> void:
	n_all += 1
	n_ok += int(cond)
	print("%s %s %s  %s" % [role, "[OK]" if cond else "[HATA]", title, note])

func _ready() -> void:
	preload("res://profile.gd").use_path("user://test_profile.cfg") # kalıcı profil kirlenmesin (tavuk, maç sonu)
	var role: String = OS.get_cmdline_user_args()[0]
	var main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _wait(0.3)
	if role == "host":
		Net.set_weapon(0) # bazuka
		Net.host_local()
		while multiplayer.get_peers().is_empty():
			await _wait(0.2)
		await _wait(1.0)
		main._pick_mode("td")
		main._on_start()
		await _wait(1.5)
		var td = get_tree().get_first_node_in_group("td")
		var me = main.players.get_node("1")
		var other = main.players.get_children().filter(func(p): return p != me)[0]
		var oid: int = other.get_multiplayer_authority()
		_ok("HOST", "iki oyuncu, TD kuruldu", main.players.get_child_count() == 2 and td != null and td.state == "break")
		td.money = 200
		td.ready_up()
		_ok("HOST", "iki oy -> dalga başladı", await _until(func(): return td.state == "fight", 8.0), "oylar %s" % [td.ready_votes])
		_ok("HOST", "istemcinin silahı eşitlendi (tabanca)", await _until(func(): return not other.inv.is_empty() and other.inv[0].get("id", "") == "pistol", 5.0), other.inv)
		_ok("HOST", "istemci yaratığa hasar verdi", await _until(func(): return td.elist.any(func(e): return e.hp < e.max_hp) or td.kills > 0, 25.0))
		var ap_of := func() -> String: # istemcinin elindeki tabancanın parça klibi (bu makinede)
			var prop: Node3D = other.props.get("pistol")
			var ap: AnimationPlayer = prop.find_child("AnimationPlayer", true, false) if prop else null
			return ap.current_animation if ap else "-"
		_ok("HOST", "istemcinin doldurması host'ta oynuyor", await _until(func(): return ap_of.call() == "reload", 10.0), ap_of.call())
		_ok("HOST", "istemci duvar aldı: para düştü", await _until(func(): return td.money < 200, 10.0), "para %d" % td.money)
		_ok("HOST", "istemci yapıyı kurdu", await _until(func(): return td.builds.get_child_count() >= 1, 10.0))
		var lv: int = td.level
		for i in 80: # seviye atlayana dek yaratıkları öldür
			for e in td.elist.duplicate():
				td.damage_enemy(e.name, 999999, false)
			if td.level > lv:
				break
			await _wait(0.1)
		_ok("HOST", "takım seviye atladı", td.level > lv, "seviye %d" % td.level)
		_ok("HOST", "istemcinin seviyesi ve kart seçimi geri geldi", await _until(func(): return other.level > 1 and not (other.ups.is_empty() and other.stats == {}), 10.0), "sv %d ups %s" % [other.level, other.ups])
		await _wait(2.0)
		print("TD_NET HOST: %d/%d" % [n_ok, n_all])
	else:
		Net.set_weapon(1) # tabanca
		Net.join_local()
		_ok("CLIENT", "maça girdi", await _until(func(): return main.players != null and get_tree().get_first_node_in_group("td") != null, 20.0))
		await _wait(0.5)
		var td = get_tree().get_first_node_in_group("td")
		var me = main.players.get_node(str(multiplayer.get_unique_id()))
		_ok("CLIENT", "mod td, envanterde tabanca", main.mode == "td" and me.inv[0].get("id", "") == "pistol", me.inv)
		td.ready_up()
		_ok("CLIENT", "dalga başladı, yaratıklar geldi", await _until(func(): return td.state == "fight" and not td.elist.is_empty(), 15.0), "durum %s" % td.state)
		var hit := false
		for i in 60: # en yakın yaratığa nişan alıp gerçek ateş yolunu kullan
			if td.elist.is_empty():
				await _wait(0.2)
				continue
			var e: Node3D = td.elist[0]
			var d: Vector3 = e.global_position + Vector3.UP * e.height * 0.5 - me.look.global_position
			me.rotation.y = atan2(-d.x, -d.z)
			me.look.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
			me.slot = 1
			me.cd = 0.0
			await get_tree().physics_frame
			me._td_use(true)
			await _wait(0.3)
			if not is_instance_valid(e) or e.hp < e.max_hp:
				hit = true
				break
		_ok("CLIENT", "ateş etti, yaratığın canı bu makinede de düştü", hit)
		await _wait(0.5)
		me.inv[0]["ammo"] = 3
		me.busy = ""
		me.start_reload()
		_ok("CLIENT", "doldurma başladı", me.reloading)
		await _wait(1.6)
		var m0: int = td.money
		td.buy("wall")
		_ok("CLIENT", "duvar envantere geldi, para eşitlendi", await _until(func(): return me.inv[3].get("id", "") == "wall" and td.money < m0, 8.0), "%s para %d" % [me.inv[3], td.money])
		td.place("wall", Vector3(8, 0, 2), 0.0)
		me._take(3)
		_ok("CLIENT", "yapı bu makinede de göründü", await _until(func(): return td.builds.get_child_count() >= 1, 8.0))
		_ok("CLIENT", "seviye kartları geldi", await _until(func(): return not me.cards.is_empty(), 20.0), me.cards.map(func(c): return c.id))
		if not me.cards.is_empty():
			me.choose_card(0)
		_ok("CLIENT", "kart seçildi", me.cards.is_empty() or me.pending >= 0, "sv %d ups %s" % [me.level, me.ups])
		await _wait(1.5)
		print("TD_NET CLIENT: %d/%d" % [n_ok, n_all])
	get_tree().quit()
