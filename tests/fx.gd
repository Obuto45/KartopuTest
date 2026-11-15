extends Node
func _ready() -> void:
	var main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(0.3).timeout
	Net.host_local()
	main._on_start()
	await get_tree().create_timer(0.5).timeout
	var me = main.players.get_node("1")
	me.look.rotation.x = -0.25
	me._set_slot(2); me._try_shield()
	me.rocket_n += 1
	me.fire_rocket.rpc(me.cam.global_position + Vector3(0, 0, -0.6), (-me.cam.global_basis.z), me.rocket_n)
	await get_tree().create_timer(0.12).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir() + "/fx1.png")
	await get_tree().create_timer(0.25).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir() + "/fx2.png")
	print("DIR=", OS.get_user_data_dir())
	get_tree().quit()