extends Node
## Tek PC uçtan uca test: godot --headless res://tests/autotest.tscn -- host|join

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _ready() -> void:
	var role: String = OS.get_cmdline_user_args()[0]
	var main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _wait(0.3)
	if role == "host":
		Net.set_char(3) # Kaptan Dron (120 can)
		Net.host_local()
		while multiplayer.get_peers().is_empty():
			await _wait(0.2)
		await _wait(1.0)
		main._on_start()
		await _wait(1.0)
		var me = main.players.get_node("1")
		var other = main.players.get_children().filter(func(p): return p != me)[0]
		print("HOST players=", main.players.get_child_count(), " names=", Net.names, " label=", other.name_lbl.text)
		print("HOST chars me=", me.ch.name, " max_hp=", me.max_hp, " other=", other.ch.name, " (Kaptan Dron 120 / Terlikli Anne bekleniyor)")
		for i in 6:
			me.rocket_n += 1; me.fire_rocket.rpc(other.global_position + Vector3(0, 1.0, -3), Vector3(0, 0, 1), me.rocket_n)
			await _wait(0.4)
			if i == 0: print("HOST after1 other.hp=", other.hp, " shield=", other.shield_on)
		await _wait(0.5)
		print("HOST other.hp=", other.hp, " round_over=", main.round_over, " text=", main.center_lbl.text.replace("\n", " / "))
		await _wait(3.5)
		print("HOST after restart other.hp=", other.hp, " round_over=", main.round_over)
		me.cast_lightning.rpc(other.global_position)
		await _wait(1.0)
		print("HOST lightning other.hp=", other.hp)
		me.spawn_wall.rpc(me.global_position + Vector3(0, 0, 3), 0.0)
		await _wait(0.5)
		print("HOST wall=", main.world.has_node("W1"))
		me.swing.rpc(other.global_position - Vector3(0, 0, 1.5), Vector3(0, 0, 1)) # önünde: vurur
		await _wait(0.4)
		me.swing.rpc(other.global_position - Vector3(0, 0, 1.5), Vector3(0, 0, -1)) # arkası dönük: ıskalar
		await _wait(0.4)
		print("HOST sword other.hp=", other.hp, " (60 -> 40 bekleniyor)")
		me.use_skill.rpc("pull", other.global_position - Vector3(0, 0, 2)) # 2 m yanında "gel abla gel"
		await _wait(0.6)
		print("HOST pull other.hp=", other.hp, " (40 -> 30 bekleniyor)")
		print("HOST slipper dist=", me.global_position.distance_to(other.global_position))
		me.throw_slipper.rpc(other.get_multiplayer_authority())
		await _wait(4.0)
		print("HOST slipper other.hp=", other.hp, " (30 -> 0 bekleniyor) me.hp=", me.hp, " (istemcinin terliği: 120 -> 90 bekleniyor)")
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
		print("CLIENT slipper skill_cd=", me.skill_cd, " (8 bekleniyor) quote=", me.quote_lbl.text, " rocket_speed=", 30.0 * me.ch.throw_mult, " (37.5 bekleniyor)")
		await _wait(1.5)
		print("CLIENT after lightning hp=", me.hp)
		await _wait(1.5)
		print("CLIENT after sword hp=", me.hp)
		await _wait(4.8)
		print("CLIENT after skills hp=", me.hp, " hud=", main.hp_txt.text)
		await _wait(1.0)
	get_tree().quit()
