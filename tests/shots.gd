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

func _ready() -> void:
	var main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _wait(0.5)
	await _shot("menu")
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
	get_tree().quit()
