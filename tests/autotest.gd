extends Node
## Tek PC uçtan uca ağ testi (iki süreç): godot --headless res://tests/autotest.tscn -- host|join

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _ready() -> void:
	var role: String = OS.get_cmdline_user_args()[0]
	var main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _wait(0.3)
	if role == "host":
		Net.set_char(3) # Kahvehane Dayısı
		Net.host_local()
		while multiplayer.get_peers().is_empty():
			await _wait(0.2)
		await _wait(1.0)
		main._on_start()
		await _wait(1.0)
		var me = main.players.get_node("1")
		var other = main.players.get_children().filter(func(p): return p != me)[0]
		print("HOST players=", main.players.get_child_count(), " names=", Net.names, " label=", other.name_lbl.text)
		print("HOST chars me=", me.ch.name, " other=", other.ch.name, " (Kahvehane Dayısı / Terlikli Anne bekleniyor)")
		for i in 6:
			me.rocket_n += 1; me.fire_rocket.rpc(other.global_position + Vector3(0, 1.0, -3), Vector3(0, 0, 1), me.rocket_n, false)
			await _wait(0.4)
			if i == 0: print("HOST after1 other.hp=", other.hp, " shield=", other.shield_on, " (100, false: kalkan emdi)")
		await _wait(0.5)
		print("HOST other.hp=", other.hp, " (0) round_over=", main.round_over, " text=", main.center_lbl.text.replace("\n", " / "), " anim=", other.cur_anim, " (Death)")
		await _wait(3.5)
		print("HOST after restart other.hp=", other.hp, " (100) round_over=", main.round_over)
		me.spawn_wall.rpc(me.global_position + Vector3(0, 0, 3), 0.0, 0)
		await _wait(0.5)
		print("HOST wall=", main.world.has_node("W1_0"))
		me.swing.rpc(other.global_position - Vector3(0, 0, 1.5), Vector3(0, 0, 1)) # önünde: vurur
		await _wait(0.4)
		me.swing.rpc(other.global_position - Vector3(0, 0, 1.5), Vector3(0, 0, -1)) # arkası dönük: ıskalar
		await _wait(0.4)
		print("HOST sword other.hp=", other.hp, " (100 -> 80 bekleniyor)")
		me.use_skill.rpc(me.global_position, me.global_position, Vector3(0, 0, 1), other.get_multiplayer_authority())
		await _wait(3.0)
		print("HOST tile other.hp=", other.hp, " (80 -> 60 bekleniyor)")
		await _wait(3.0)
		print("HOST me.hp=", me.hp, " shield=", me.shield_on, " (dururken kalkan aldı, istemcinin terliği onu kırdı)")
		await _wait(1.0)
	else:
		Net.set_char(1) # Terlikli Anne
		Net.join_local()
		while main.players == null:
			await _wait(0.2)
		await _wait(0.3)
		var me = main.players.get_node(str(multiplayer.get_unique_id()))
		me._set_slot(2); me._try_shield()
		print("CLIENT shield=", me.shield_on)
		await _wait(3.6)
		print("CLIENT hp=", me.hp, " text=", main.center_lbl.text.replace("\n", " / "))
		await _wait(1.2)
		print("CLIENT spectating=", me.spec_target.name if me.spec_target else "yok", " spec_cam=", me.spec_cam != null and me.spec_cam.current, " hud=", main.spec_lbl.text.replace("\n", " / "))
		await _wait(2.3)
		print("CLIENT after restart hp=", me.hp, " pos=", me.global_position.round(), " own_cam=", me.cam.current)
		me._use_skill()
		print("CLIENT slipper skill_cd=", me.skill_cd, " (8 bekleniyor) quote=", me.quote_lbl.text)
		for i in 9:
			await _wait(1.0)
			print("CLIENT t+", i + 1, " hp=", me.hp, " hud=", main.hp_txt.text)
	get_tree().quit()
