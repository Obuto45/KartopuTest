extends Node3D
func _ready() -> void:
	var f = load("res://forest.gd").new()
	f.spawns = [Vector3(-14, 1, -14), Vector3(14, 1, 14), Vector3(-14, 1, 14), Vector3(14, 1, -14)]
	add_child(f)
	var cam := Camera3D.new()
	cam.fov = 80
	add_child(cam)
	var views := [[Vector3(-15.8, 3.2, -14.5), Vector3(-15.8, 1.5, -19)], [Vector3(0, 40, 48), Vector3(0, 0, 4)],
		[Vector3(0, 1.7, 0), Vector3(10, 1.7, -3)], [Vector3(0, 1.7, 0), Vector3(-10, 2.5, 6)], [Vector3(20, 1.7, -20), Vector3(30, 2.2, -24)],
		[Vector3(-15.8, 3.2, -14.5), Vector3(-15.8, 9, -19)]]
	for i in views.size():
		cam.look_at_from_position(views[i][0], views[i][1])
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir() + "/tmp%d.png" % i)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	cam.look_at_from_position(Vector3(-14, 1.7, -14), Vector3(0, 1.7, 0))
	var env: Environment = null
	for c in f.get_children():
		if c is WorldEnvironment:
			env = c.environment
	var sun: DirectionalLight3D = null
	for c in f.get_children():
		if c is DirectionalLight3D and c.shadow_enabled:
			sun = c
	for mode in [0, 1, 2, 3, 4, 5, 0]:
		env.volumetric_fog_enabled = mode != 1
		env.ssao_enabled = mode != 2
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED if mode == 3 else Viewport.MSAA_2X
		sun.shadow_enabled = mode != 4
		for c in f.get_children():
			if c is MultiMeshInstance3D and c.multimesh.instance_count > 5000:
				c.visible = mode != 5
		await get_tree().create_timer(3.0).timeout
		print("FPS mode ", mode, " ", Engine.get_frames_per_second())
	print("draws ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " prims ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	get_tree().quit()
