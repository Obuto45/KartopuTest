## Koddan low-poly eldivenli el. Kök bilekte; avuç içi -X (sağ) / +X (sol), parmaklar -Z.
## İç çerçeve "h": avuç -Y'ye bakar, parmak bükmek rotation.x < 0 (h, kökte Z etrafında çevrilir).
extends RefCounted

const POSES := { # [eklem1, eklem2, başparmak]
	"grip": [-1.2, -1.1, -0.9],
	"support": [-0.6, -0.5, -0.3],
	"open": [0.0, 0.0, 0.0],
	"pinch": [-1.3, -1.3, -0.9], # f0 ve başparmak ayrıca -0.9
}


static func make(color: Color, left: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "HandL" if left else "HandR"
	var h := Node3D.new()
	h.name = "h"
	h.rotation.z = PI / 2 if left else -PI / 2
	root.add_child(h)
	var glove := _mat(color)
	var sx := -1.0 if left else 1.0 # sol elde işaret parmağı yine üstte kalsın
	_box(h, "palm", Vector3(0, 0, -0.045), Vector3(0.08, 0.03, 0.09), glove)
	_box(h, "wrist", Vector3(0, 0, 0.06), Vector3(0.07, 0.04, 0.12), _mat(color.darkened(0.55)))
	for i in 4:
		var k := 0.85 if i == 3 else 1.0
		var f := Node3D.new()
		f.name = "f%d" % i
		f.position = Vector3((0.03 - i * 0.02) * sx, 0.002, -0.09)
		h.add_child(f)
		_box(f, "seg", Vector3(0, 0, -0.022 * k), Vector3(0.018, 0.02, 0.045 * k), glove)
		var a := Node3D.new()
		a.name = "a"
		a.position = Vector3(0, 0, -0.045 * k)
		f.add_child(a)
		_box(a, "b", Vector3(0, 0, -0.016 * k), Vector3(0.017, 0.018, 0.034 * k), glove)
	var t := Node3D.new()
	t.name = "thumb"
	t.position = Vector3(0.042 * sx, -0.008, -0.02)
	t.rotation.y = 0.6 * sx # dışa açık taban
	h.add_child(t)
	_box(t, "seg", Vector3(0, 0, -0.025), Vector3(0.02, 0.02, 0.05), glove)
	return root


static func pose(hand: Node3D, name: String) -> void:
	var p: Array = POSES[name]
	for i in 4:
		var f: Node3D = hand.find_child("f%d" % i, true, false)
		var r1: float = -0.9 if name == "pinch" and i == 0 else p[0]
		f.rotation.x = r1
		f.get_node("a").rotation.x = p[1]
	hand.find_child("thumb", true, false).rotation.x = p[2]


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m


static func _box(parent: Node3D, name: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = name
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
