## Koddan yuvarlak hatlı, parmaklı eldiven el. Kök bilekte; avuç içi -X (sağ) / +X (sol), parmaklar -Z.
## Başparmak ve işaret parmağı kökte +Y (üst) tarafında. İç çerçeve "h": avuç -Y'ye bakar, parmak bükmek rotation.x < 0 (h, kökte Z etrafında çevrilir).
## Parmak i: f<i> (kök eklem) → a (orta eklem) → b (uç eklem). Başparmak: thumb (taban) → a → b.
extends RefCounted

const BLEND_RATE := 30.0 # 1 - exp(-30 * 0.08) ≈ %91: hedefe ~0.08 sn'de yaklaşır

## Parmaklar (işaret, orta, yüzük, serçe): [x, eklem z, boğum boyları, yarıçap]. h içinde; x, sx ile aynalanır.
const FINGERS := [
	[0.0275, -0.088, [0.037, 0.023, 0.019], 0.0093],
	[0.0090, -0.092, [0.040, 0.025, 0.020], 0.0097],
	[-0.0095, -0.089, [0.037, 0.024, 0.019], 0.0091],
	[-0.0270, -0.080, [0.029, 0.019, 0.017], 0.0081],
]
const THUMB_POS := Vector3(0.024, -0.009, -0.020)
const THUMB_LEN := [0.040, 0.030, 0.026]
const THUMB_R := [0.0125, 0.0105, 0.0097]

## "f": parmak başına [kök, orta, uç] rotation.x (eksi = bük); "s": yelpaze açıklığı (rotation.y);
## "t": başparmak [taban eğim x, taban sapma y, taban yuvarlanma z, orta, uç] (y/z sol elde aynalanır).
## grip/bottle/pinch/cork .superpowers/sdd/hands_fit.gd ile uyduruldu (silindir sarma, uç teması, çarpışmasızlık).
const POSES := {
	"open": {"f": [[-0.06, -0.10, -0.06], [-0.05, -0.10, -0.06], [-0.06, -0.12, -0.07], [-0.08, -0.14, -0.08]],
		"s": 0.07, "t": [-0.25, -0.60, -1.00, -0.05, -0.10]},
	"grip": {"f": [[-1.21, -0.76, -0.78], [-1.20, -0.88, -0.70], [-1.12, -0.80, -0.65], [-1.56, -1.21, -0.92]],
		"s": 0.0, "t": [-1.06, -0.57, -2.00, -0.28, -0.68]},
	"support": {"f": [[-0.45, -0.50, -0.30], [-0.50, -0.55, -0.35], [-0.55, -0.60, -0.35], [-0.60, -0.65, -0.40]],
		"s": 0.03, "t": [-0.45, -0.25, -1.15, -0.20, -0.15]},
	"pinch": {"f": [[-0.85, -0.85, -0.55], [-1.00, -1.20, -0.70], [-1.15, -1.30, -0.70], [-1.25, -1.30, -0.70]],
		"s": 0.0, "t": [-0.60, -0.25, -1.24, -0.35, -0.50]},
	"bottle": {"f": [[-0.95, -0.56, -0.47], [-1.03, -0.65, -0.53], [-0.98, -0.56, -0.48], [-0.82, -0.26, -0.27]],
		"s": 0.0, "t": [-1.04, -0.10, -0.36, 0.30, 0.20]},
	"cork": {"f": [[-0.55, -0.55, -0.37], [-0.60, -0.60, -0.40], [-0.70, -0.65, -0.40], [-0.80, -0.70, -0.40]],
		"s": 0.02, "t": [-0.49, -0.13, -1.20, -0.10, -0.20]},
}

static var _meshes := {} # aynı boyutlu ağlar bütün eller arasında paylaşılır


static func make(color: Color, left: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "HandL" if left else "HandR"
	var h := Node3D.new()
	h.name = "h"
	h.rotation.z = PI / 2 if left else -PI / 2
	root.add_child(h)
	# Başparmak/işaret h'de +X*sx → kökte +Y (iki elde de üstte): sağ el gerçekten sağ, sol el onun aynası.
	var sx := 1.0 if left else -1.0
	var glove := _mat(color, 0.7)
	var pad := _mat(color.darkened(0.18), 0.85) # avuç ve parmak ucu deri yaması
	var cuff := _mat(color.darkened(0.5), 0.75)
	# Avuç: basık elipsoit + eklem sırtı + topuk + serçe kenarı (köşeler yumuşak)
	_mi(h, "palm", _sphere(), glove, Vector3(0, 0.001, -0.047), Vector3.ZERO, Vector3(0.080, 0.032, 0.098))
	_mi(h, "palm_pad", _sphere(), pad, Vector3(0, -0.005, -0.050), Vector3.ZERO, Vector3(0.068, 0.026, 0.080))
	_mi(h, "knuckle_bar", _capsule(0.0135, 0.074), glove, Vector3(0, 0.002, -0.081), Vector3(0, 0, PI / 2))
	_mi(h, "heel", _capsule(0.016, 0.078), glove, Vector3(-0.002 * sx, -0.003, -0.017), Vector3(0, 0, PI / 2), Vector3(0.8, 1, 1))
	_mi(h, "edge", _capsule(0.0135, 0.075), glove, Vector3(-0.028 * sx, -0.002, -0.048), Vector3(PI / 2, 0, 0), Vector3(0.9, 1, 1))
	_mi(h, "thenar", _sphere(), glove, Vector3(0.020 * sx, -0.011, -0.034), Vector3(0, 0.45 * sx, 0), Vector3(0.034, 0.026, 0.056))
	# Bilek bağlantısı ve ~8 cm manşet (kol içine girer, aradaki boşluğu örter)
	_mi(h, "wrist_joint", _capsule(0.025, 0.05), glove, Vector3(0, -0.001, -0.004), Vector3(PI / 2, 0, 0), Vector3(1.2, 1, 0.7))
	var wrist := Node3D.new()
	wrist.name = "wrist"
	wrist.position = Vector3(0, 0, 0.044)
	wrist.scale = Vector3(1, 0.8, 1)
	h.add_child(wrist)
	_mi(wrist, "cuff", _cyl(0.035, 0.039, 0.08), cuff, Vector3.ZERO, Vector3(-PI / 2, 0, 0))
	_mi(wrist, "rim", _torus(0.037, 0.045), cuff, Vector3(0, 0, 0.038), Vector3(PI / 2, 0, 0))
	_mi(wrist, "strap", _cyl(0.0365, 0.0375, 0.016), pad, Vector3(0, 0, -0.016), Vector3(-PI / 2, 0, 0))
	var joints: Array[Node3D] = []
	for i in 4:
		var d: Array = FINGERS[i]
		var lens: Array = d[2]
		var r: float = d[3]
		var f := Node3D.new()
		f.name = "f%d" % i
		f.position = Vector3(d[0] * sx, 0.003, d[1])
		h.add_child(f)
		_mi(h, "knuckle%d" % i, _sphere(), glove, Vector3(d[0] * sx, 0.008, d[1] + 0.003), Vector3.ZERO, Vector3(2.0, 1.6, 2.0) * r)
		_chain(f, lens, [r, r * 0.94, r * 0.88], glove, pad, joints)
	var t := Node3D.new()
	t.name = "thumb"
	t.position = Vector3(THUMB_POS.x * sx, THUMB_POS.y, THUMB_POS.z)
	h.add_child(t)
	_chain(t, THUMB_LEN, THUMB_R, glove, pad, joints)
	root.set_meta("joints", joints)
	root.set_meta("sx", sx)
	pose(root, "open")
	return root


## Üç boğumlu zincir: j (kök) → a → b; her boğum yuvarlak uçlu kapsül, uç boğum deri yamalı.
static func _chain(j: Node3D, lens: Array, radii: Array, glove: Material, pad: Material, joints: Array[Node3D]) -> void:
	for s in 3:
		joints.append(j)
		var l: float = lens[s]
		var r: float = radii[s]
		_mi(j, "seg", _capsule(r, l + 2.0 * r), pad if s == 2 else glove, Vector3(0, 0, -l * 0.5), Vector3(PI / 2, 0, 0))
		if s < 2:
			var n := Node3D.new()
			n.name = "a" if s == 0 else "b"
			n.position = Vector3(0, 0, -l)
			j.add_child(n)
			j = n


static func pose(hand: Node3D, name: String, blend := false) -> void:
	var to := _targets(hand, name)
	hand.set_meta("pose_to", to)
	if blend:
		return
	var js: Array = hand.get_meta("joints")
	for i in js.size():
		js[i].rotation = to[i]


static func update(hand: Node3D, dt: float) -> void:
	if not hand.has_meta("pose_to"):
		return
	var to: Array = hand.get_meta("pose_to")
	var js: Array = hand.get_meta("joints")
	var k := 1.0 - exp(-BLEND_RATE * dt)
	for i in js.size():
		js[i].rotation = js[i].rotation.lerp(to[i], k)


## Eklem sırasıyla (f0 a b, f1 a b, ..., thumb a b) hedef açılar.
static func _targets(hand: Node3D, name: String) -> Array:
	var p: Dictionary = POSES[name]
	var sx: float = hand.get_meta("sx")
	var out := []
	for i in 4:
		var f: Array = p.f[i]
		out.append(Vector3(f[0], -p.s * (1.5 - i) * sx, 0))
		out.append(Vector3(f[1], 0, 0))
		out.append(Vector3(f[2], 0, 0))
	var t: Array = p.t
	out.append(Vector3(t[0], t[1] * sx, t[2] * sx))
	out.append(Vector3(t[3], 0, 0))
	out.append(Vector3(t[4], 0, 0))
	return out


static func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func _mi(parent: Node3D, name: String, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _sphere() -> Mesh:
	if not _meshes.has("s"):
		var m := SphereMesh.new() # birim çap; boyut düğüm ölçeğinden
		m.radius = 0.5
		m.height = 1.0
		m.radial_segments = 24
		m.rings = 12
		_meshes["s"] = m
	return _meshes["s"]


static func _capsule(r: float, h: float) -> Mesh:
	var key := "c%.4f_%.4f" % [r, h]
	if not _meshes.has(key):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = h
		m.radial_segments = 16
		m.rings = 4
		_meshes[key] = m
	return _meshes[key]


static func _cyl(top: float, bottom: float, h: float) -> Mesh:
	var key := "y%.4f_%.4f_%.4f" % [top, bottom, h]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = h
		m.radial_segments = 24
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


static func _torus(inner: float, outer: float) -> Mesh:
	var key := "t%.4f_%.4f" % [inner, outer]
	if not _meshes.has(key):
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = 24
		m.ring_segments = 8
		_meshes[key] = m
	return _meshes[key]
