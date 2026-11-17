## Kendi gözünden eller + silah. Ana dünyada kameranın önünde durur ama yalnız kendi SubViewport'unda
## (katman 2) çizilir; o görüntü tam ekran TextureRect olarak ana görüntünün üstüne biner (duvara girmez,
## görüş açısı koşarken genişlemez). Klipler weapon_anims.gd'den; kök "Base", yollar "Rig", "HandL"...
extends Node3D

signal event(name: String)

const Hands := preload("res://hands.gd")
const Potion := preload("res://potion.gd")
const WA := preload("res://weapon_anims.gd")
const Weapons := preload("res://weapons.gd")
const LAYER := 2
const FOV := 62.0
const ARM_SCALE := 0.72 # oyuncu modeliyle aynı (player.MODEL_SCALE): kol ~0,68 m, yay tutuşuna da yeter
const SHOULDER_WIDEN := 0.15 # model biriminde, her omuz dışa
const SHOULDERS := Vector3(0, -0.3, 0.0) # iki omuz ortası, kamera uzayında: göz hizasının altında, ekran dışında
const ITEM_VIEW := {"build": [Vector3(0.1, -0.24, -0.3), Vector3.ZERO], "item:potion": [Vector3(0.15, -0.17, -0.34), Vector3.ZERO], "item:bomb": [Vector3(0.16, -0.17, -0.3), Vector3.ZERO]}

var sway_offset := Vector3.ZERO # _feel yazar: salınım, adım, geri tepme
var sway_tilt := Vector3.ZERO
var base: Node3D # silah duruşu (view) + salınım; animasyon kökü
var rig: Node3D
var weapon: Node3D
var hand_r: Node3D
var hand_l: Node3D
var ap: AnimationPlayer
var vp: SubViewport
var vcam: Camera3D
var id := ""
var view: Array = [Vector3.ZERO, Vector3.ZERO]


## model_path: karakter glb'si; verilirse kendi kolları ellere uzanır ("" = yalnız eller).
func setup(color: Color, model_path := "") -> void:
	top_level = true
	base = Node3D.new()
	base.name = "Base"
	add_child(base)
	rig = Node3D.new()
	rig.name = "Rig"
	base.add_child(rig)
	hand_r = Hands.make(color, false)
	hand_r.name = "HandR"
	rig.add_child(hand_r)
	hand_l = Hands.make(color, true)
	hand_l.name = "HandL"
	base.add_child(hand_l)
	ap = AnimationPlayer.new()
	base.add_child(ap)
	ap.root_node = NodePath("..")
	ap.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE # olay klip hâlâ "oynarken" gelsin
	vp = SubViewport.new()
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	vcam = Camera3D.new()
	vcam.fov = FOV
	vcam.near = 0.01
	vcam.cull_mask = 1 << (LAYER - 1)
	vp.add_child(vcam)
	var key := DirectionalLight3D.new() # güneşe karşı bakınca silah kapkara kalmasın: yalnız katman 2'yi aydınlatır
	key.light_cull_mask = 1 << (LAYER - 1)
	key.light_energy = 0.6
	key.rotation = Vector3(-0.6, 0.5, 0)
	key.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(key)
	var cl := CanvasLayer.new()
	cl.layer = -1
	add_child(cl)
	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture = vp.get_texture()
	cl.add_child(tr)
	if model_path != "":
		_arms(model_path)
	visible = false


## Karakter modelinin kopyası kamera uzayında; omuzlar kameranın arkasında-altında, yalnız kollar görünür.
## Kafa/boyun/bacak/yumruk kemikleri sıfıra büzülür; iki TwoBoneIK3D kolları el bileklerine uzatır.
func _arms(path: String) -> void:
	var m := (load(path) as PackedScene).instantiate() as Node3D
	m.name = "Arms"
	for a in m.find_children("*", "AnimationPlayer", true, false):
		a.free() # dinlenme pozunda kalsın
	m.scale = Vector3.ONE * ARM_SCALE
	m.rotation.y = PI # modelin önü +Z
	add_child(m)
	var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
	var mid := (sk.get_bone_global_rest(sk.find_bone("UpperArm.L")).origin + sk.get_bone_global_rest(sk.find_bone("UpperArm.R")).origin) * 0.5
	m.position += SHOULDERS - to_local(sk.global_transform * mid) # modeller arası iskelet farkı (ör. casual_bald öne kaymış)
	for b in ["Head", "Neck", "UpperLeg.L", "UpperLeg.R", "Foot.L", "Foot.R", "Fist.L", "Fist.R"]:
		var i := sk.find_bone(b)
		if i >= 0:
			sk.set_bone_pose_scale(i, Vector3.ONE * 0.001)
	for s in ["L", "R"]: # omuzları açar: kollar ekrana ortadan değil alt köşelerden girsin
		var i := sk.find_bone("Shoulder." + s)
		var pb := sk.get_bone_global_rest(sk.get_bone_parent(i)).basis
		sk.set_bone_pose_position(i, sk.get_bone_rest(i).origin + pb.inverse() * Vector3(SHOULDER_WIDEN * (1 if s == "L" else -1), 0, 0))
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		mi.layers = 1 << (LAYER - 1)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 5, 6)) # dinlenme kutusu kameranın arkasında kalıp kollar kırpılmasın
		_no_shadow(mi)
	var ik := TwoBoneIK3D.new()
	sk.add_child(ik)
	ik.setting_count = 2
	for k in 2:
		var s: String = ["R", "L"][k]
		var t := Marker3D.new() # manşetin içi: el kökünün biraz gerisi
		t.name = "ArmTarget"
		t.position = Vector3(0, 0, 0.04)
		(hand_r if s == "R" else hand_l).add_child(t)
		var pole := Marker3D.new() # dirsek aşağı-dışa
		pole.position = Vector3(0.6 if s == "R" else -0.6, -0.9, 0.1)
		add_child(pole)
		ik.set_root_bone_name(k, "UpperArm." + s)
		ik.set_middle_bone_name(k, "LowerArm." + s)
		ik.set_end_bone_name(k, "Fist." + s)
		ik.set_target_node(k, ik.get_path_to(t))
		ik.set_pole_node(k, ik.get_path_to(pole))


## Silahı değiştirir ve çıkarma klibini oynatır; "" = eller iner (görünmez).
func equip(new_id: String) -> void:
	id = new_id
	ap.stop()
	if ap.has_animation_library(""):
		ap.remove_animation_library("") # model silinmeden önce: eski klipler "Rig/Weapon" arayıp uyarmasın
	if weapon:
		weapon.free()
		weapon = null
	visible = id != ""
	if id == "":
		return
	var mid := WA.model_id(id)
	weapon = Weapons.make_prop({"id": mid}) if mid != "" else (Potion.make() if id == "item:potion" else Node3D.new())
	weapon.name = "Weapon"
	rig.add_child(weapon)
	var w := Weapons.find(id)
	view = w.get("view", ITEM_VIEW.get(id, [Vector3(0.16, -0.17, -0.38), Vector3.ZERO]))
	for path in WA.rest(id): # dinlenme duruşu (klipler bunun üstüne fark ekler)
		var n := base.get_node_or_null(path) as Node3D
		if n:
			n.position = WA.rest(id)[path][0]
			n.rotation = WA.rest(id)[path][1]
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mi.layers = 1 << (LAYER - 1)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_no_shadow(mi) # kameranın içindeyiz: oyuncunun kendi kafasının gölgesi silahı karartmasın
	var lib := AnimationLibrary.new()
	for c in WA.clips(id):
		var a := WA.build(id, c)
		for t in a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_METHOD:
				a.track_set_path(t, "..") # yöntemler bu düğümde (_ev, _pose)
				for k in a.track_get_key_count(t): # olay klip adını taşısın: geçişte sönen klibin olayı sızmasın
					var v: Dictionary = a.track_get_key_value(t, k)
					if v.method == "_ev":
						a.track_set_key_value(t, k, {"method": "_ev_of", "args": [c, v.args[0]]})
					if a.track_get_key_time(t, k) == 0.0: # tam 0'daki yöntem anahtarı oynatma başında atlanıyor
						a.track_set_key_time(t, k, 0.001)
		lib.add_animation(c, a)
	if ap.has_animation_library(""):
		ap.remove_animation_library("")
	ap.add_animation_library("", lib)
	for p in WA.clips(id).draw.poses: # çıkarma başında el pozu anında (önceki silahın pozundan süzülmesin)
		Hands.pose(hand_l if p[1] == "L" else hand_r, p[2])
	ap.play("draw")
	ap.advance(0.0)


## Klip yoksa sessizce boşta duruşa geçer.
func play(clip: String, speed := 1.0) -> void:
	if id == "":
		return
	if not ap.has_animation(clip):
		clip = "idle"
	ap.play(clip, 0.05, speed)
	if ap.current_animation == clip:
		ap.seek(0.0, true)


func current() -> String:
	return id


func clip() -> String:
	return ap.current_animation if ap and ap.is_playing() else ""


func muzzle() -> Vector3:
	var m := weapon.find_child("muzzle", true, false) as Node3D if weapon else null
	return m.global_position if m else global_position


func show_part(name: String, on: bool) -> void:
	var n := weapon.find_child(name, true, false) as Node3D if weapon else null
	if n:
		n.visible = on


func _process(dt: float) -> void:
	if base == null:
		return
	Hands.update(hand_r, dt)
	Hands.update(hand_l, dt)
	var main := get_viewport().get_camera_3d()
	if main and main != vcam:
		global_transform = main.global_transform
		vcam.global_transform = main.global_transform
		vp.size = get_viewport().get_visible_rect().size
		vp.msaa_3d = get_viewport().msaa_3d
	base.position = view[0] + sway_offset
	base.rotation = view[1] + sway_tilt


func _ev(name: String) -> void:
	event.emit(name)


## Yalnız şu an oynayan klibin olayları geçer (karışımda sönen önceki klip "done" yayınlamasın).
func _ev_of(clip: String, name: String) -> void:
	if ap.current_animation == clip:
		event.emit(name)


func _pose(side: String, name: String) -> void:
	Hands.pose(hand_l if side == "L" else hand_r, name, true)


func _no_shadow(mi: MeshInstance3D) -> void:
	if mi.has_meta("ns"):
		return
	mi.set_meta("ns", true)
	if mi.material_override is BaseMaterial3D:
		mi.material_override.disable_receive_shadows = true
		return
	for s in mi.mesh.get_surface_count():
		var m := mi.get_active_material(s)
		if m is BaseMaterial3D:
			m = m.duplicate()
			m.disable_receive_shadows = true
			mi.set_surface_override_material(s, m)

