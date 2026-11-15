extends Node
## Görsel kontrol: menü, ayarlar, duvar ve yıldırım ekran görüntüleri (user:// içine).

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir() + "/" + n + ".png")

func _ready() -> void:
	var main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(0.5).timeout
	await _shot("menu")
	main._open_settings()
	await get_tree().create_timer(0.2).timeout
	await _shot("settings")
	main._close_settings()
	Net.host_local()
	main._on_start()
	await get_tree().create_timer(0.5).timeout
	var me = main.players.get_node("1")
	me.rotation.y = PI * 0.75
	me.look.rotation.x = 0.05
	await get_tree().create_timer(0.3).timeout
	await _shot("forest")
	me.look.rotation.x = -0.2
	me._set_slot(4)
	me._place_wall()
	await get_tree().create_timer(0.4).timeout
	me.rotation.y += 0.6
	me._set_slot(3)
	me._cast_lightning()
	await get_tree().create_timer(0.42).timeout
	await _shot("lightning")
	get_tree().quit()