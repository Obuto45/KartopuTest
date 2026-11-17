extends Node3D
## Kendi gözünden silah duruşu ve el kavrayışı, sayısal: godot --headless --path . res://tests/grip_test.tscn
## Her silahta: namlu nişangâha (10 m) dönük mü, yuvarlanma (roll), parmak ucu-silah yüzeyi aralığı, el-silah
## iç içe geçmesi, avuç teması, işaret parmağı-tetik, sol avuç yönü, bilek kırığı (ön kol - el ekseni açısı).
## Mesafeler silahın gerçek üçgenlerine (glb) ve elin gerçek ağ köşelerine göre, mm. Çıktı: GRIP_TEST: x/y

const VM := preload("res://viewmodel.gd")
const WA := preload("res://weapon_anims.gd")
const Hands := preload("res://hands.gd")
const IDS := ["pistol", "smg", "shotgun", "sniper", "bazooka", "flame", "bow", "sword", "boomerang", "grenade", "item:bomb", "item:potion", "build"]
const GUNS := ["pistol", "smg", "shotgun", "sniper", "bazooka", "flame", "bow"]
const AIM := Vector3(0, 0, -10) # nişangâh noktası (kamera uzayı)

var quick := "quick" in OS.get_cmdline_user_args() # yalnız namlu + bilek (hızlı)
var good := 0
var total := 0
var vm: Node3D
var _arm := {} # skeleton_updated anında: taraf -> [dirsek, bilek kemiği] (kamera uzayı)


func chk(what: String, ok: bool, info = "") -> void:
	total += 1
	if ok:
		good += 1
	print(("ok   " if ok else "FAIL ") + what + ("" if str(info) == "" else "  [" + str(info) + "]"))


func _ready() -> void:
	var cam := Camera3D.new() # kamera kökte: viewmodel uzayı = dünya
	add_child(cam)
	cam.current = true
	vm = VM.new()
	add_child(vm)
	vm.setup(Color(0.85, 0.65, 0.5), "res://models/chars/casual_male.glb")
	var sk: Skeleton3D = vm.find_children("*", "Skeleton3D", true, false)[0]
	sk.skeleton_updated.connect(func() -> void:
		for s in ["L", "R"]:
			_arm[s] = [sk.global_transform * sk.get_bone_global_pose(sk.find_bone("LowerArm." + s)).origin,
				sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Fist." + s)).origin])
	for id in IDS:
		await hold(vm, id)
		measure(id)
	print("GRIP_TEST: %d/%d" % [good, total])
	get_tree().quit(0 if good == total else 1)


## Silahı al, dinlenme pozuna anında otur (salınımsız), IK otursun.
static func hold(v: Node3D, id: String) -> void:
	v.equip(id)
	v.play("idle")
	v.ap.advance(0.5)
	v.sway_offset = Vector3.ZERO
	v.sway_tilt = Vector3.ZERO
	Hands.pose(v.hand_r, WA.hold_r(id))
	Hands.pose(v.hand_l, WA.hold_l(id))
	for i in 3:
		await v.get_tree().process_frame


func measure(id: String) -> void:
	var w: Node3D = vm.weapon
	var tris := _tris(w)
	print("--- ", id)
	if id in GUNS:
		var m := w.find_child("muzzle", true, false) as Node3D
		var d := -w.global_basis.z.normalized()
		var to := (AIM - m.global_position).normalized()
		var ang := rad_to_deg(d.angle_to(to))
		var up := (Vector3.UP - d * d.dot(Vector3.UP)).normalized()
		var wu := w.global_basis.y - d * d.dot(w.global_basis.y)
		var roll := rad_to_deg(wu.signed_angle_to(up, d))
		chk(id + ": namlu nişangâha < 3°", ang < 3.0, "%.1f°" % ang)
		chk(id + ": roll < 2°", absf(roll) < 2.0, "%.1f°" % roll)
	if id == "build":
		return
	for side in ["R", "L"]:
		if quick:
			_wrist(id, side)
			continue
		var hand: Node3D = vm.hand_r if side == "R" else vm.hand_l
		var pose: String = WA.hold_r(id) if side == "R" else WA.hold_l(id)
		if side == "L" and (id in WA.ONE_HAND):
			continue
		var near := _near(tris, _aabb(hand))
		var tips := []
		for i in 4:
			tips.append(_gap(_verts(hand.find_child("f%d" % i, true, false).get_node("a/b/seg")), near))
		var thumb := _gap(_verts(hand.find_child("thumb", true, false).get_node("a/b/seg")), near)
		var all := []
		for mi: MeshInstance3D in hand.find_children("*", "MeshInstance3D", true, false):
			if not mi.name.begins_with("wrist"):
				all.append_array(_verts(mi))
		var pen := _gap(all, near)
		var palm := _gap(_verts(hand.find_child("palm_pad", true, false)), near)
		var mm := func(x: float) -> String: return "%.1f" % (x * 1000.0)
		var info := "uçlar %s başparmak %s avuç %s en derin %s mm" % [str(tips.map(mm)), mm.call(thumb), mm.call(palm), mm.call(pen)]
		chk("%s %s: el silaha girmiyor (≥ -3 mm)" % [id, side], pen >= -0.003, info)
		if pose == "grip" or pose == "bottle":
			chk("%s %s: 4 parmak ucu yüzeyde (-2..5 mm)" % [id, side], tips.all(func(t): return t >= -0.002 and t <= 0.005), info)
			chk("%s %s: avuç değiyor (≤ 6 mm)" % [id, side], palm <= 0.006, info)
		elif pose == "support" and id in WA.UNDER:
			chk("%s %s: destek parmakları değiyor (3/4 ≤ 6 mm)" % [id, side], tips.filter(func(t): return t <= 0.006).size() >= 3, info)
			if id in WA.UNDER:
				chk("%s %s: avuç yukarı" % [id, side], hand.global_basis.x.normalized().dot(Vector3.UP) > 0.5, "%.2f" % hand.global_basis.x.normalized().dot(Vector3.UP))
		elif pose == "pinch":
			chk("%s %s: çimdik ucu yüzeyde (≤ 6 mm)" % [id, side], minf(tips[0], thumb) <= 0.006, info)
		if side == "R" and pose == "grip" and w.find_child("trigger", true, false):
			var tg := _tris(w.find_child("trigger", true, false))
			var f0: Node = hand.find_child("f0", true, false)
			var idx := _verts(f0.get_node("a/seg")) + _verts(f0.get_node("a/b/seg"))
			var dt := _gap(idx, tg)
			chk("%s: işaret parmağı tetikte (≤ 12 mm)" % id, dt <= 0.012, "%.1f mm" % (dt * 1000))
		_wrist(id, side)


func _wrist(id: String, side: String) -> void:
	var hand: Node3D = vm.hand_r if side == "R" else vm.hand_l
	if side == "L" and (id in WA.ONE_HAND):
		return
	if _arm.has(side):
		var tgt: Vector3 = hand.global_transform * Vector3(0, 0, 0.04)
		var fore: Vector3 = tgt - _arm[side][0]
		var bend := rad_to_deg(fore.angle_to(-hand.global_basis.z))
		var reach: float = (_arm[side][1] - tgt).length()
		chk("%s %s: kol ele yetişiyor (≤ 10 mm)" % [id, side], reach <= 0.01, "%.0f mm" % (reach * 1000))
		chk("%s %s: bilek doğal (< 35°)" % [id, side], bend < 35.0, "%.0f°, kol ucu %.0f mm, dirsek %s bilek %s" % [bend, reach * 1000, _arm[side][0].snapped(Vector3.ONE * 0.01), tgt.snapped(Vector3.ONE * 0.01)])


# ---------- geometri ----------

## Düğüm altındaki görünür ağların üçgenleri (dünya uzayı): [a, b, c, dış normal] dizisi.
static func _tris(root: Node3D) -> Array:
	var out := []
	var mis: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		mis.append(root)
	for mi: MeshInstance3D in mis:
		if not mi.is_visible_in_tree():
			continue
		var f := mi.mesh.get_faces()
		var t := mi.global_transform
		for i in range(0, f.size(), 3):
			var a := t * f[i]
			var b := t * f[i + 1]
			var c := t * f[i + 2]
			out.append([a, b, c, (c - a).cross(b - a).normalized()]) # Godot: saat yönü ön yüz
	return out


static func _verts(mi: Node) -> Array:
	var out := {}
	if mi is MeshInstance3D:
		for v in mi.mesh.get_faces():
			out[mi.global_transform * v] = true
	return out.keys()


static func _aabb(n: Node3D) -> AABB:
	var b := AABB(n.global_position, Vector3.ZERO)
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		b = b.merge(mi.global_transform * mi.get_aabb())
	return b


static func _near(tris: Array, box: AABB) -> Array:
	box = box.grow(0.02)
	return tris.filter(func(t): return box.intersects(AABB(t[0], Vector3.ZERO).expand(t[1]).expand(t[2])))


## En küçük işaretli uzaklık (eksi = silahın içinde); üçgen yoksa 1 m.
static func _gap(pts: Array, tris: Array) -> float:
	var best := 1.0
	for p: Vector3 in pts:
		var d := 1e9
		var s := 1.0
		var al := -1.0
		for t in tris:
			var c := _cp(p, t[0], t[1], t[2])
			var e := p.distance_to(c)
			if e < d - 1e-7 or (e < d + 1e-7 and e > 1e-9 and absf((p - c).dot(t[3])) / e > al):
				d = e
				al = absf((p - c).dot(t[3])) / e if e > 1e-9 else 1.0
				s = -1.0 if (p - c).dot(t[3]) < 0.0 else 1.0
		best = minf(best, d * s)
	return best


## Üçgende en yakın nokta (Ericson, Real-Time Collision Detection 5.1.5).
static func _cp(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and d4 - d3 >= 0.0 and d5 - d6 >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var den := 1.0 / (va + vb + vc)
	return a + ab * (vb * den) + ac * (vc * den)
