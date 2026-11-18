extends Node
## Tavukların görüntü denetimi: ormanı kurar, bir civcivli tavuğa bakan kareyi user://chickens.png'ye yazar.
func _ready() -> void:
	var f: Node3D = load("res://forest.gd").new()
	add_child(f)
	await get_tree().create_timer(1.0).timeout
	var hens := get_tree().get_nodes_in_group("chickens")
	var c: Node3D = hens.filter(func(h): return h.chick)[0]
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 50
	cam.look_at_from_position(c.position + Vector3(2.2, 1.0, 2.6), c.position + Vector3(0, 0.25, 0))
	cam.current = true
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("user://chickens.png")
	print("CHICKENS: ", hens.size())
	get_tree().quit()
