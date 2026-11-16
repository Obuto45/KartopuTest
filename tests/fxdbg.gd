extends Node
func _ready() -> void:
	var main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(0.4).timeout
	Net.host_local()
	main._on_start()
	await get_tree().create_timer(0.6).timeout
	var me = main.players.get_node("1")
	me.spawn_wall(me._ground(me.global_position + Vector3(0, 0, -4)), 0.3, 0)
	await get_tree().create_timer(0.15).timeout
	var w = main.world.get_node("W1_0")
	print("wall ", w.global_position)
	for c in w.get_children():
		if c is CPUParticles3D:
			print(c.global_position, " emit=", c.emitting, " vis=", c.is_visible_in_tree(), " top=", c.top_level, " scale=", c.global_basis.get_scale())
	get_tree().quit()
