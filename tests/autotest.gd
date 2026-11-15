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
		Net.host_local()
		while multiplayer.get_peers().is_empty():
			await _wait(0.2)
		await _wait(1.0)
		main._on_start()
		await _wait(1.0)
		var me = main.players.get_node("1")
		var other = main.players.get_children().filter(func(p): return p != me)[0]
		print("HOST players=", main.players.get_child_count(), " names=", Net.names)
		for i in 6:
			me.rocket_n += 1; me.fire_rocket.rpc(other.global_position + Vector3(0, 1.0, -3), Vector3(0, 0, 1), me.rocket_n)
			await _wait(0.4)
			if i == 0: print("HOST after1 other.hp=", other.hp, " shield=", other.shield_on)
		await _wait(0.5)
		print("HOST other.hp=", other.hp, " round_over=", main.round_over, " text=", main.center_lbl.text.replace("\n", " / "))
		await _wait(3.5)
		print("HOST after restart other.hp=", other.hp, " round_over=", main.round_over)
		await _wait(1.0)
	else:
		Net.join_local()
		while main.players == null:
			await _wait(0.2)
		await _wait(0.3)
		var me = main.players.get_node(str(multiplayer.get_unique_id()))
		me._set_slot(2); me._try_shield()
		print("CLIENT shield=", me.shield_on)
		await _wait(3.6)
		print("CLIENT hp=", me.hp, " text=", main.center_lbl.text.replace("\n", " / "))
		await _wait(3.5)
		print("CLIENT after restart hp=", me.hp, " pos=", me.global_position.round())
	get_tree().quit()
