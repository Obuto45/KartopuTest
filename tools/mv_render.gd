extends SceneTree
## Hunyuan3D-2mv girdisi: modeli ortografik kamerayla ön / sol / arka / sağdan, beyaz zeminde 1024x1024 çizer.
func _initialize():
	var args := OS.get_cmdline_user_args()
	var path: String = args[0]
	var out: String = args[1]
	var vp := SubViewport.new()
	vp.size = Vector2i(1024, 1024)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.WHITE
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 1.0
	vp.add_child(key)
	var m: Node3D = (load(path) as PackedScene).instantiate()
	vp.add_child(m)
	var aabb := AABB()
	var first := true
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb()
		aabb = b if first else aabb.merge(b)
		first = false
	m.position -= aabb.get_center()
	print("AABB size=", aabb.size, " center=", aabb.get_center())
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z)) * 1.12 # en uzun kenar çerçeveyi doldursun
	vp.add_child(cam)
	cam.current = true
	var d := aabb.size.length() * 2.0
	# Model +Z'ye bakar varsayımı (Godot glTF): ön = +Z'den bakış. Hunyuan: front, left, back, right.
	var views := {"front": Vector3(0, 0, 1), "left": Vector3(-1, 0, 0), "back": Vector3(0, 0, -1), "right": Vector3(1, 0, 0)}
	for k in views:
		cam.position = views[k] * d
		cam.look_at(Vector3.ZERO, Vector3.UP)
		key.global_transform = cam.global_transform.rotated_local(Vector3.UP, 0.5).rotated_local(Vector3.RIGHT, -0.5)
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(out + "/" + k + ".png")
	quit()
