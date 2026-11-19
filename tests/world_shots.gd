extends Node
## Görsel kontrol: her biyomdan bir kare (user://world_<biyom>.png). Pencereli çalıştır:
## godot --path . --rendering-driver opengl3 res://tests/world_shots.tscn

const WorldScript := preload("res://world.gd")


func _ready() -> void:
	Settings.quality = 1 # Orta: fps hedefi bu kalitede
	Settings.apply_quality()
	var w: Node3D = WorldScript.new()
	var marker := Node3D.new()
	var players := Node3D.new()
	players.add_child(marker)
	add_child(players)
	w.players = players
	add_child(w)
	var cam := Camera3D.new()
	cam.far = 600.0
	add_child(cam)
	cam.current = true
	for b in 4: # her biyomun merkeze en yakın, içinde iyice kalmış noktası
		var spot := Vector2.ZERO
		for r in range(60, 480, 20):
			for a in 16:
				var p := Vector2(r, 0).rotated(TAU * a / 16.0)
				if spot == Vector2.ZERO and w.weights(p.x, p.y)[b] > 0.97:
					spot = p
		marker.position = Vector3(spot.x, 0, spot.y)
		var h: float = w.height(spot.x, spot.y)
		cam.position = Vector3(spot.x, h + 3.0, spot.y)
		cam.look_at(Vector3(spot.x + 30, w.height(spot.x + 30, spot.y + 30) + 2.0, spot.y + 30))
		w._update_env(100.0)
		for i in 150:
			await get_tree().process_frame
		w._update_env(100.0)
		await RenderingServer.frame_post_draw
		var f: String = OS.get_user_data_dir() + "/world_" + WorldScript.NAMES[b] + ".png"
		get_viewport().get_texture().get_image().save_png(f)
		print("SHOT ", f, " fps=", Engine.get_frames_per_second(), " chunk_ms=", w.build_ms)
	# Karşılaştırma: kule savunması haritası (forest.gd), aynı kamera yüksekliğinden.
	w.free()
	var td: Node3D = load("res://forest.gd").new()
	td.spawns = [Vector3(-20, 0, -20), Vector3(20, 0, 20)]
	add_child(td)
	cam.position = Vector3(-20, 3.0, -20)
	cam.look_at(Vector3(10, 2.0, 10))
	for i in 150:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var tf: String = OS.get_user_data_dir() + "/world_td_reference.png"
	get_viewport().get_texture().get_image().save_png(tf)
	print("SHOT ", tf)
	get_tree().quit()
