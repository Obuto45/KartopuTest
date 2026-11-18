extends Node
## Ragdoll testi: godot --headless res://tests/ragdoll_test.tscn
## Zemine bir karakter koyar, ragdoll'a çevirir, darbe ve patlamayla savurur; düştü mü, zeminde mi, geri alınıyor mu.

const Ragdoll := preload("res://ragdoll.gd")

var good := 0
var total := 0


func chk(what: String, ok: bool, info = "") -> void:
	total += 1
	if ok:
		good += 1
	print(("ok   " if ok else "FAIL ") + what + ("" if ok else "  " + str(info)))


var seen := {} # model -> {kemik: y}; değiştirici (ragdoll) sonucu yalnız skeleton_updated anında okunur


func _bone_y(m: Node3D, bn: String) -> float:
	return seen[m].get(bn, -99.0)


func _model(x: float, s: float) -> Node3D:
	var m: Node3D = load("res://models/chars/zombie_male.glb").instantiate()
	m.position = Vector3(x, 0, 0)
	m.scale = Vector3.ONE * s
	add_child(m)
	m.find_children("*", "AnimationPlayer", true, false)[0].play("Idle")
	var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
	seen[m] = {}
	sk.skeleton_updated.connect(func() -> void:
		for bn in ["Head", "Hips", "Foot.L", "LowerLeg.L"]:
			seen[m][bn] = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bn))).origin.y)
	return m


func _ready() -> void:
	var g := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	g.add_child(cs)
	add_child(g)
	await get_tree().physics_frame
	var a := _model(0, 0.7)
	var b := _model(5, 1.2)
	await get_tree().create_timer(0.2).timeout
	var head0 := _bone_y(a, "Head")
	Ragdoll.poke(a.global_position + Vector3(0, 1.0, 0), Vector3(0, 0, -4))
	var sa := Ragdoll.start(a)
	var sb := Ragdoll.start(b, Vector3(2, 1, 0))
	chk("ragdoll kuruldu", sa != null and sa.get_child_count() >= 12, sa)
	await get_tree().create_timer(2.5).timeout
	var head1 := _bone_y(a, "Head")
	chk("kafa yere düştü", head1 < head0 * 0.4, [head0, head1])
	var far := 0.0
	for pb in sa.get_children():
		far = maxf(far, pb.global_position.distance_to(a.global_position))
	chk("ragdoll patlamadı (kemikler gövdeye yakın)", far < 2.5, far)
	chk("zeminin altına geçmedi", head1 > -0.05 and _bone_y(a, "Hips") > -0.05, [head1, _bone_y(a, "Hips")])
	chk("büyük model de yerde", _bone_y(b, "Head") < 0.8 and _bone_y(b, "Head") > -0.05, _bone_y(b, "Head"))
	var hx := _bone_y(b, "Hips")
	Ragdoll.poke(b.global_position + Vector3(-1, 0, 0), Vector3(0, 20, 0), 4.0)
	await get_tree().create_timer(0.25).timeout
	chk("yatan ragdoll patlamayla havalandı", _bone_y(b, "Hips") > hx + 0.3, [hx, _bone_y(b, "Hips")])
	var fy := _bone_y(a, "Foot.L")
	chk("ayak baldırla birlikte", absf(fy - _bone_y(a, "LowerLeg.L")) < 0.35, [fy, _bone_y(a, "LowerLeg.L")])
	Ragdoll.stop(sa)
	await get_tree().create_timer(0.3).timeout
	chk("geri alınınca ayağa kalktı", _bone_y(a, "Head") > head0 * 0.8, _bone_y(a, "Head"))
	await get_tree().create_timer(2.0).timeout # yere insin
	Ragdoll.sink(sb)
	await get_tree().create_timer(1.0).timeout
	chk("batırılan zeminin altına indi", _bone_y(b, "Hips") < 0.0, _bone_y(b, "Hips"))
	# oyuncu gibi: model kendi kapsülünün içinde; ragdoll kapsüle çarpıp fırlamamalı
	var body := CharacterBody3D.new()
	var bc := CollisionShape3D.new()
	bc.shape = CapsuleShape3D.new()
	bc.shape.height = 1.8
	bc.position.y = 0.9
	body.add_child(bc)
	body.position = Vector3(-6, 0, 0)
	add_child(body)
	var c := _model(0, 0.7)
	c.reparent(body, false)
	await get_tree().create_timer(0.2).timeout
	Ragdoll.flinch(c, c.global_position + Vector3.UP, Vector3(0, 0, 3))
	await get_tree().create_timer(0.1).timeout
	Ragdoll.start(c)
	await get_tree().create_timer(2.0).timeout
	var sk: Skeleton3D = c.find_children("*", "Skeleton3D", true, false)[0]
	var hips: Node3D = sk.find_child("PB_Hips", true, false)
	chk("kapsülün içinden fırlamadı", hips and Vector2(hips.global_position.x + 6, hips.global_position.z).length() < 1.5 and hips.global_position.y < 0.6, hips.global_position if hips else null)
	print("RAGDOLL_TEST: %d/%d" % [good, total])
	get_tree().quit(0 if good == total else 1)
