extends Node
## Geçici: hareket hissi görsel kontrolü (motion_*.png)

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir() + "/motion_" + n + ".png")

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _dummy(main: Node, id: int, chr: int, pos: Vector3) -> CharacterBody3D:
	var d: CharacterBody3D = load("res://player.gd").new()
	d.name = str(id)
	d.set_multiplayer_authority(id)
	d.spawn_pos = pos
	Net.chars[id] = chr
	main.players.add_child(d)
	d.net_yaw = PI
	return d

var ds := []
var vels := []

func _physics_process(dt: float) -> void:
	for i in ds.size():
		ds[i].net_pos += vels[i] * dt

func _ready() -> void:
	var main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _wait(0.5)
	Net.host_local()
	main._on_start()
	await _wait(0.5)
	var me = main.players.get_node("1")
	me.rotation.y = 0.0
	me.look.rotation.x = -0.1
	var p: Vector3 = me.global_position
	# hepsi bize bakıyor (yaw PI): a bize koşar, b kendi soluna (bizim sağımıza) yan koşar, c geri geri gider, d durur
	for i in 4:
		ds.append(_dummy(main, 2 + i, [3, 40, 50, 34][i], p + Vector3(-3 + i * 2.0, 0, -7)))
		vels.append(Vector3.ZERO)
	await _wait(0.6)
	vels = [Vector3(0, 0, 3), Vector3(3, 0, 0), Vector3(0, 0, -3), Vector3.ZERO]
	for i in 3:
		ds[i].net_speed = 7.0
	await _wait(0.45)
	await _shot("run")
	vels = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	for d in ds:
		d.net_speed = 0.0
	ds[3].net_air = true
	ds[3].net_pos.y += 1.2
	await _wait(0.5)
	ds[3].net_pos.y -= 1.2
	await _wait(0.12)
	ds[3].net_air = false
	await _wait(0.07)
	await _shot("land")
	ds[0].set_hp(60)
	me.shake(p + Vector3(0, 0, -3), 1.0)
	me.kick = 1.0
	await _wait(0.05)
	print("shake_k=", me.shake_k, " camrot=", me.cam.rotation, " lean0=", ds[0].lean, " sq3=", ds[3].sq)
	await _shot("hit")
	await _wait(0.5)
	print("shake_k after 0.5s=", me.shake_k)
	ds[1].shake(p, 5.0)
	print("remote shake_k=", ds[1].shake_k)
	get_tree().quit()
