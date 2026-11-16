extends Node
var me
func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir() + "/fx_" + n + ".png")

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _seq(tag: String, times: Array) -> void:
	var prev := 0.0
	for t in times:
		await _wait(t - prev)
		prev = t
		await _shot("%s_%03d" % [tag, int(t * 100)])

func _ready() -> void:
	var main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _wait(0.4)
	Net.host_local()
	main._on_start()
	await _wait(0.6)
	me = main.players.get_node("1")
	me.rotation.y = 0.0
	me.look.rotation.x = -0.12
	var p: Vector3 = me.global_position
	var what := OS.get_cmdline_user_args()
	if what.is_empty() or "boom" in what:
		me.boom_fx(me._ground(p + Vector3(0, 0, -7)) + Vector3(0, 0.1, 0), 1.0)
		await _seq("boom", [0.04, 0.12, 0.25, 0.45, 0.8, 1.4, 2.5])
		await _wait(1.8)
		me.boom_fx(p + Vector3(-3, 3.0, -9), 1.0)
		me.boom_fx(me._ground(p + Vector3(3, 0, -10)), 1.8)
		await _seq("big", [0.08, 0.3, 0.9])
		await _wait(3.5)
	if what.is_empty() or "rocket" in what:
		me.rocket_n += 1
		me.fire_rocket.rpc(p + Vector3(-9, 1.6, -6), Vector3(1, 0, 0), me.rocket_n, false)
		await _seq("rocket", [0.25, 0.45])
		me.rocket_n += 1
		me.fire_rocket.rpc(me.cam.global_position + Vector3(0.3, -0.2, -0.6), -me.cam.global_basis.z, me.rocket_n, false)
		await _seq("fpv", [0.05, 0.2])
		me.rocket_n += 1
		me.fire_rocket.rpc(p + Vector3(-9, 1.6, -6), Vector3(1, 0, 0), me.rocket_n, true)
		await _seq("ball", [0.3])
		await _wait(2.0)
	if what.is_empty() or "wall" in what:
		me.spawn_wall(me._ground(p + Vector3(0, 0, -4)), 0.3, 0)
		await _seq("wall", [0.15, 0.4, 0.8])
		await _wait(7.4)
		await _seq("wallend", [0.2, 0.5])
	if what.is_empty() or "zone" in what:
		me._area({"r": 3.0, "delay": 1.2, "boom": true, "dmg": 1, "color": Color(1, 0.4, 0.1)}, me._ground(p + Vector3(0, 0, -8)), Vector3.FORWARD)
		me._area({"r": 2.0, "linger": 3.0, "dmg": 1, "color": Color(0.3, 0.8, 1.0)}, me._ground(p + Vector3(-4, 0, -6)), Vector3.FORWARD)
		await _seq("zone", [0.3, 0.9, 1.05, 1.15, 1.3])
		var d: CharacterBody3D = load("res://player.gd").new()
		d.name = "2"
		d.set_multiplayer_authority(2)
		d.spawn_pos = p + Vector3(8, 0, -14)
		Net.chars[2] = 3
		main.players.add_child(d)
		var i := 0
		for look in ["card", "ball", "boomerang"]:
			var h: Node3D = load("res://slipper.gd").new()
			h.thrower = me
			h.h = {"look": look, "speed": 4.0, "turn": 3.0, "dmg": 1}
			h.target = d
			h.dir = Vector3(0.3, 0.2, -1).normalized()
			h.position = p + Vector3(-1.2 + i * 1.0, 1.4, -1.6)
			main.world.add_child(h)
			i += 1
		await _seq("homing", [0.3, 0.6])
	get_tree().quit()
