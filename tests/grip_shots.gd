extends Node3D
## Kendi gözünden silah kavrayışı görüntüleri (her silah: dinlenme, ateş anı, sağdan ve soldan-alttan yakın çekim).
## xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 res://tests/grip_shots.tscn -- /tmp/grip/once
## Çıktı: <klasör>/<silah>_{fp,fire,right,left}.png

const GT := preload("res://tests/grip_test.gd")
const IDS := ["pistol", "smg", "shotgun", "sniper", "bazooka", "flame", "bow", "sword", "boomerang", "grenade", "item:potion", "build"]

var dir := "/tmp/grip"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		dir = args[0]
	DirAccess.make_dir_recursive_absolute(dir)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.65, 0.75)
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var vm: Node3D = load("res://viewmodel.gd").new()
	add_child(vm)
	vm.setup(Color(0.85, 0.65, 0.5), "res://models/chars/casual_male.glb")
	var side := SubViewport.new() # yardımcı kamera: yalnız viewmodel katmanı
	side.size = Vector2i(640, 480)
	side.transparent_bg = false
	side.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(side)
	var sc := Camera3D.new()
	sc.cull_mask = 2
	sc.fov = 40
	sc.near = 0.01
	side.add_child(sc)
	for id in IDS:
		if args.size() > 1 and id not in args.slice(1): # -- <klasör> smg bow: yalnız bunlar
			continue
		await GT.hold(vm, id)
		await _save(get_viewport(), id + "_fp")
		var c: Vector3 = vm.weapon.global_position if id != "build" else vm.hand_r.global_position
		for v in [["right", Vector3(0.45, 0.08, 0.05)], ["left", Vector3(-0.3, -0.3, -0.25)]]:
			sc.look_at_from_position(c + v[1], c + Vector3(0, -0.02, -0.08))
			await _save(side, id + "_" + v[0])
		var clip := "fire" if vm.ap.has_animation("fire") else ("swing1" if id == "sword" else "")
		if clip != "":
			vm.play(clip)
			vm.ap.advance(0.04)
			await _save(get_viewport(), id + "_fire")
	get_tree().quit()


func _save(v: Viewport, n: String) -> void:
	for i in 2:
		await RenderingServer.frame_post_draw
	v.get_texture().get_image().save_png(dir.path_join(n.replace(":", "_") + ".png"))
