extends Node
## Yeni menü sayfalarının görüntüsü (user:// içine PNG): modes, lobi (TD), lobi bul, gelişim, silahlar.

func _shot(n: String) -> void:
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir() + "/" + n + ".png")

func _ready() -> void:
	var main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(0.5).timeout
	main._show_page("modes")
	await _shot("ms_modes0")
	main._show_page("modes")
	await _shot("ms_modes")
	var pm: Control = main.pages["modes"]
	for c in pm.get_child(0).get_children():
		print("MODES ", c.get_class(), " ", c.size, " min=", c.get_combined_minimum_size())
	main._pick_mode("td")
	await _shot("ms_lobby_td")
	main._open_find()
	await _shot("ms_find")
	main._on_lobbies([{"id": 1, "name": "Ayşe lobisi", "mode": "td", "diff": "hard", "n": 2}])
	await _shot("ms_find2")
	main._open_growth()
	await _shot("ms_growth")
	main._show_page("lobby")
	main._open_weapons()
	await _shot("ms_weapons")
	get_tree().quit()
