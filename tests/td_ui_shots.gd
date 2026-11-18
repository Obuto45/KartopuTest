extends Node
## TD arayüzünün yeni parçalarının ekran görüntüleri (user:// içine td_ui_*.png): rehber, boss barı + gece,
## modifikatör afişi, evrim kartı + yeniden çek / ele, maç sonu özeti. Gerçek td.gd üstünde, alanlar elle sürülür.
## xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 res://tests/td_ui_shots.tscn

const Profile := preload("res://profile.gd")


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir() + "/td_ui_" + n + ".png")


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _ready() -> void:
	Profile.use_path("user://shots_profile.cfg") # kalıcı profil kirlenmesin
	Profile.save_data({"gold": 300, "upgrades": {"reroll": 2, "banish": 1}, "stats": {"best_match_kills": 112}})
	get_window().size = Vector2i(1920, 1080)
	var main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _wait(1.0)
	Net.host_local()
	main._pick_mode("td")
	main._on_start()
	await _wait(1.2)
	var ui = main.td_ui
	var td = get_tree().get_first_node_in_group("td")
	var me = main.players.get_node("1")
	await _shot("tut1") # rehber 1. adım, ilk mola 90 sn
	ui.tut = 1
	ui._tut_next() # 3. adım: en uzun yazı
	await _wait(0.6)
	await _shot("tut3")
	td.set_physics_process(false) # durum elle sürülür
	td.mods = ["fast", "night"]
	td.difficulty = "hard"
	td.wave = 4
	td.state = "break"
	await _wait(0.3)
	await _shot("mods_break")
	# Boss dalgası: 10. dalga, Kara Şövalye, gece + hızlı
	td.wave = 10
	td._spawn(999, "boss", Vector3(0, 0, -12), 3000, 60, {"spd": 1.0, "armor": 0, "elite": false, "money": 1})
	td._by_id[999].hp = 1900
	td._by_id[999].set_physics_process(false)
	td.boss_eid = 999
	td.state = "fight"
	ui.tut = -1
	ui.tut_card.hide()
	await _wait(0.7)
	await _shot("boss")
	await _wait(2.4)
	await _shot("night")
	# Kartlar: evrim kartı + haklar
	me.cards = [{"id": "evo:bazooka", "title": "EVRİM: Kıyamet Topu", "desc": "Roketler 3 küçük bombaya bölünür, alan +%40.", "rarity": "legendary", "type": "evo"},
		{"id": "stat:hp:1", "title": "Can", "desc": "Can: 100 → 115", "rarity": "common", "type": "stat"},
		{"id": "up:bazooka:blast", "title": "Bazuka: Dev Patlama", "desc": "Patlama alanı +1 m.", "rarity": "epic", "type": "weapon_up"}]
	await _wait(0.9)
	await _shot("evo")
	ui._banish_toggle()
	await _wait(0.2)
	await _shot("banish")
	ui.banish_mode = false
	me.cards = []
	# Maç sonu özeti (3 oyuncu): zafer, sonra sonsuz kayıp
	Net.names[2] = "Sinan"
	Net.names[3] = "Ayşe"
	td.state = "won"
	td.kills = 412
	var d := {"won": true, "wave": 10, "difficulty": "hard", "endless": false, "mvp": 1, "players": {
		1: {"dmg": 18420, "kills": 190, "crits": 41, "builds": 6, "deaths": 0},
		2: {"dmg": 12011, "kills": 140, "crits": 52, "builds": 14, "deaths": 2},
		3: {"dmg": 9050, "kills": 82, "crits": 9, "builds": 3, "deaths": 1}}}
	ui._on_summary(d)
	await _wait(0.8)
	await _shot("summary_won")
	get_window().size = Vector2i(1280, 720)
	await _wait(0.5)
	await _shot("summary_720")
	ui.summary = {}
	ui.run_gold = -1
	d.won = false
	d.endless = true
	d.wave = 14
	d.players = {1: d.players[1]}
	ui._on_summary(d)
	await _wait(0.5)
	await _shot("summary_endless")
	print("TD_UI_SHOTS: bitti, gold %d" % Profile.gold())
	get_tree().quit()
