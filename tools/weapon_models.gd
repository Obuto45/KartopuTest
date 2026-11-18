extends SceneTree
## Silah modeli üretici: "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s res://tools/weapon_models.gd
## Ardından içe aktar: aynı exe ile --headless --path . --import   (yalnız bazıları: ... weapon_models.gd -- pistol bow)
## models/<id>.glb yazar: namlu/bıçak -Z, ölçü metre, düz renkli low-poly. Ateşli silahlarda başlangıç noktası kabza üstü.
## Tasarımı değiştirmek için aşağıdaki _<id>() fonksiyonlarındaki sayıları değiştir ve yeniden çalıştır.
## Parçalar: ext (profil + kalınlık, bev = kenar pahı), box, cyl (iki nokta arası koni/silindir), sph, torus, tube.

const MATS := { # renk, metalik, pürüzlülük, [ışıma gücü]
	"dark": [Color(0.16, 0.16, 0.18), 0.55, 0.42],
	"dark2": [Color(0.24, 0.25, 0.27), 0.5, 0.5],
	"steel": [Color(0.5, 0.52, 0.56), 0.8, 0.3],
	"black": [Color(0.06, 0.06, 0.07), 0.1, 0.85],
	"white": [Color(0.95, 0.95, 0.92), 0.0, 0.6],
	"wood": [Color(0.55, 0.33, 0.16), 0.0, 0.7],
	"wooddk": [Color(0.36, 0.2, 0.1), 0.0, 0.8],
	"woodred": [Color(0.45, 0.17, 0.1), 0.0, 0.6],
	"birch": [Color(0.85, 0.72, 0.5), 0.0, 0.75],
	"olive": [Color(0.32, 0.38, 0.22), 0.1, 0.7],
	"olivedk": [Color(0.22, 0.27, 0.15), 0.1, 0.8],
	"red": [Color(0.8, 0.15, 0.1), 0.35, 0.45],
	"brass": [Color(0.88, 0.65, 0.24), 0.85, 0.3],
	"gold": [Color(1.0, 0.78, 0.3), 0.9, 0.25],
	"leather": [Color(0.32, 0.19, 0.1), 0.0, 0.9],
	"leatherdk": [Color(0.18, 0.1, 0.05), 0.0, 0.9],
	"string": [Color(0.92, 0.9, 0.82), 0.0, 0.9],
	"yellow": [Color(0.98, 0.76, 0.12), 0.0, 0.55],
	"glass": [Color(0.25, 0.6, 0.85), 0.9, 0.08, 0.6],
	"ruby": [Color(0.9, 0.08, 0.15), 0.3, 0.2, 1.2],
	"glow": [Color(0.35, 0.65, 1.0), 0.0, 0.4, 2.5],
}
const IDS := ["pistol", "shotgun", "smg", "sniper", "bow", "boomerang", "flame", "grenade", "bazooka", "sword"]

var surf := {} # parça düğümü -> malzeme -> üçgen köşeleri (model koordinatında)
var node := "body" # tri() bu parçaya yazar
var pivots := {} # parça -> dönme noktası (MeshInstance3D konumu)
var markers := {} # Marker3D adı -> konum
var org := Vector3.ZERO # sonraki parçaların kaydırması (başlangıç noktası etrafında çizilen profiller için)
var godot_sign := 1.0 # Godot'nun ön yüz sarımı: kenar çarpımı normalle aynı yönde mi (+1) ters mi (-1)


func _init() -> void:
	var a := BoxMesh.new().get_mesh_arrays()
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	godot_sign = signf((v[ix[1]] - v[ix[0]]).cross(v[ix[2]] - v[ix[0]]).dot(a[Mesh.ARRAY_NORMAL][ix[0]]))
	var only := OS.get_cmdline_user_args()
	for id in IDS:
		if only.is_empty() or id in only:
			surf = {}
			markers = {}
			pivots = {}
			part("body", Vector3.ZERO)
			call("_" + id)
			_save(id)
	quit()


func _save(id: String) -> void:
	var root := Node3D.new()
	root.name = id
	var tris := 0
	for n in surf:
		var mi := MeshInstance3D.new()
		mi.name = n
		mi.position = pivots[n]
		mi.mesh = _mesh(surf[n], pivots[n])
		root.add_child(mi)
		for m in surf[n]:
			tris += surf[n][m].size() / 3
	for k in markers:
		var mk := Marker3D.new()
		mk.name = k
		mk.position = markers[k]
		root.add_child(mk)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(root, state)
	if err == OK:
		err = doc.write_to_filesystem(state, "res://models/%s.glb" % id)
	print("%s: %d üçgen, %d parça, %s" % [id, tris, surf.size(), error_string(err)])
	root.free()


func _mesh(mats: Dictionary, pv: Vector3) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for m in mats:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var p: PackedVector3Array = mats[m]
		for i in range(0, p.size(), 3):
			st.set_normal(((p[i + 1] - p[i]).cross(p[i + 2] - p[i]) * godot_sign).normalized())
			for k in 3:
				st.add_vertex(p[i + k] - pv)
		var d: Array = MATS[m]
		var mat := StandardMaterial3D.new()
		mat.resource_name = m
		mat.albedo_color = d[0]
		mat.metallic = d[1]
		mat.roughness = d[2]
		if d.size() > 3:
			mat.emission_enabled = true
			mat.emission = d[0]
			mat.emission_energy_multiplier = d[3]
		st.set_material(mat)
		st.commit(mesh)
	return mesh


## Sonraki çizimler bu adlı hareketli parçaya gider; pivot dönme/kayma noktasıdır. part("body") gövdeye döner.
func part(name: String, pivot := Vector3.ZERO) -> void:
	node = name
	pivots[name] = pivot


func marker(name: String, pos: Vector3) -> void:
	markers[name] = pos


# ---------- Parçalar ----------

func tri(m: String, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 1e-14:
		return
	if signf(cr.dot(n)) != godot_sign:
		var t := b
		b = c
		c = t
	var d: Dictionary = surf.get_or_add(node, {})
	if not d.has(m):
		d[m] = PackedVector3Array()
	d[m].append_array([a + org, b + org, c + org])


func quad(m: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	tri(m, a, b, c, n)
	tri(m, a, c, d, n)


## Profil çiftlerini (u, v) ters sırayla döndürür.
static func _rev(a: Array) -> Array:
	var r := []
	for i in range(a.size() - 2, -1, -2):
		r.append_array([a[i], a[i + 1]])
	return r


static func _out(d: Vector2) -> Vector2: # saat yönünün tersi çokgende kenarın dış normali
	return Vector2(d.y, -d.x).normalized()


## Düz profil (u, v çiftleri) W boyunca w0..w1 kalınlıkta; bev > 0 ise ön/arka kenarlar pahlanır.
## Varsayılan: yandan görünüş (u = Z, v = Y, kalınlık X).
func ext(m: String, uv: Array, w0: float, w1: float, bev := 0.0, U := Vector3.BACK, V := Vector3.UP, W := Vector3.RIGHT) -> void:
	if w0 > w1: # aynalanmış (sol yan) parçalar ters aralıkla gelir
		var t0 := w0
		w0 = w1
		w1 = t0
	var p := PackedVector2Array()
	for i in range(0, uv.size(), 2):
		p.append(Vector2(uv[i], uv[i + 1]))
	var area := 0.0
	for i in p.size():
		area += p[i].cross(p[(i + 1) % p.size()])
	if area < 0.0:
		p.reverse()
	var n := p.size()
	var t := Geometry2D.triangulate_polygon(p)
	assert(not t.is_empty(), "%s profili üçgenlenemedi" % m)
	bev = minf(bev, (w1 - w0) * 0.45)
	var q := p # kapak çokgeni (pahta içe çekilmiş)
	if bev > 0.0:
		q = PackedVector2Array()
		for i in n:
			var n1 := _out(p[i] - p[(i - 1 + n) % n])
			var n2 := _out(p[(i + 1) % n] - p[i])
			q.append(p[i] - (n1 + n2) / maxf(1.0 + n1.dot(n2), 0.4) * bev)
	var to3 := func(c: Vector2, w: float) -> Vector3: return U * c.x + V * c.y + W * w
	for i in range(0, t.size(), 3):
		tri(m, to3.call(q[t[i]], w1), to3.call(q[t[i + 1]], w1), to3.call(q[t[i + 2]], w1), W)
		tri(m, to3.call(q[t[i]], w0), to3.call(q[t[i + 1]], w0), to3.call(q[t[i + 2]], w0), -W)
	for i in n:
		var j := (i + 1) % n
		var d := p[j] - p[i]
		var o := U * d.y - V * d.x
		quad(m, to3.call(p[i], w0 + bev), to3.call(p[j], w0 + bev), to3.call(p[j], w1 - bev), to3.call(p[i], w1 - bev), o)
		if bev > 0.0:
			var on := o.normalized()
			quad(m, to3.call(p[i], w1 - bev), to3.call(p[j], w1 - bev), to3.call(q[j], w1), to3.call(q[i], w1), on + W)
			quad(m, to3.call(p[i], w0 + bev), to3.call(p[j], w0 + bev), to3.call(q[j], w0), to3.call(q[i], w0), on - W)


func box(m: String, c: Vector3, s: Vector3, bev := 0.0) -> void:
	ext(m, [c.z - s.z / 2, c.y - s.y / 2, c.z + s.z / 2, c.y - s.y / 2, c.z + s.z / 2, c.y + s.y / 2, c.z - s.z / 2, c.y + s.y / 2],
		c.x - s.x / 2, c.x + s.x / 2, bev)


## a'dan b'ye, yarıçap r0'dan r1'e (0 = sivri uç).
func cyl(m: String, r0: float, r1: float, a: Vector3, b: Vector3, seg := 10) -> void:
	var ax := (b - a).normalized()
	var e1 := ax.cross(Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT).normalized()
	var e2 := ax.cross(e1)
	for i in seg:
		var d0 := e1 * cos(TAU * (i + 0.5) / seg) + e2 * sin(TAU * (i + 0.5) / seg)
		var d1 := e1 * cos(TAU * (i + 1.5) / seg) + e2 * sin(TAU * (i + 1.5) / seg)
		quad(m, a + d0 * r0, a + d1 * r0, b + d1 * r1, b + d0 * r1, d0 + d1)
		if r0 > 0.0:
			tri(m, a, a + d0 * r0, a + d1 * r0, -ax)
		if r1 > 0.0:
			tri(m, b, b + d0 * r1, b + d1 * r1, ax)


## Noktalardan geçen boru (hortum), eklemlerde küre.
func tube(m: String, r: float, pts: Array, seg := 8) -> void:
	for i in pts.size() - 1:
		cyl(m, r, r, pts[i], pts[i + 1], seg)
		if i > 0:
			sph(m, pts[i], r, seg, 4)


## sy: dikey basıklık/uzama.
func sph(m: String, c: Vector3, r: float, seg := 8, rings := 6, sy := 1.0) -> void:
	var pt := func(i: int, j: int) -> Vector3:
		var th := PI * j / rings
		var ph := TAU * i / seg
		return c + Vector3(r * sin(th) * cos(ph), r * cos(th) * sy, r * sin(th) * sin(ph))
	for j in rings:
		for i in seg:
			var a: Vector3 = pt.call(i, j)
			var b: Vector3 = pt.call(i + 1, j)
			var d: Vector3 = pt.call(i + 1, j + 1)
			var e: Vector3 = pt.call(i, j + 1)
			quad(m, a, b, d, e, (a + b + d + e) / 4.0 - c)


## Halka: merkez c, düzleminin normali ax.
func torus(m: String, c: Vector3, ax: Vector3, R: float, r: float, seg := 12, tb := 5) -> void:
	ax = ax.normalized()
	var e1 := ax.cross(Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT).normalized()
	var e2 := ax.cross(e1)
	var pt := func(i: int, j: int) -> Array:
		var dir := e1 * cos(TAU * i / seg) + e2 * sin(TAU * i / seg)
		var rc := c + dir * R
		return [rc + (dir * cos(TAU * j / tb) + ax * sin(TAU * j / tb)) * r, rc]
	for i in seg:
		for j in tb:
			var a: Array = pt.call(i, j)
			var b: Array = pt.call(i + 1, j)
			var d: Array = pt.call(i + 1, j + 1)
			var e: Array = pt.call(i, j + 1)
			quad(m, a[0], b[0], d[0], e[0], (a[0] + b[0] + d[0] + e[0]) / 4.0 - (a[1] + b[1]) / 2.0)


## Yandan vida başı: x yüzeyinde (iki yanda).
func screws(m: String, x: float, pts: Array, r := 0.004) -> void:
	for s in [-1.0, 1.0]:
		for p in pts:
			cyl(m, r, r, Vector3(x * s, p.y, p.x), Vector3((x + 0.0015) * s, p.y, p.x), 6)


## U biçimli tetik korkuluğu: ön üst (z0, y0), arka uç z1, derinlik h.
func guard(m: String, z0: float, z1: float, y0: float, h: float, th := 0.007) -> void:
	ext(m, [z0, y0, z0, y0 - h * 0.6, z0 + 0.012, y0 - h, z1, y0 - h, z1, y0 - h + th,
		z0 + 0.012 + th * 0.5, y0 - h + th, z0 + th, y0 - h * 0.6, z0 + th, y0], -0.006, 0.006, 0.002)
	var prev := node
	part("trigger", Vector3(0, y0, z0 + 0.033))
	ext("steel", [z0 + 0.03, y0, z0 + 0.036, y0, z0 + 0.032, y0 - h * 0.5, z0 + 0.024, y0 - h * 0.8,
		z0 + 0.019, y0 - h * 0.78, z0 + 0.025, y0 - h * 0.5], -0.0035, 0.0035)
	part(prev, pivots[prev])


## Ray dişleri (üst ray): merkez c, uzunluk L.
func rail(c: Vector3, L: float, w := 0.022) -> void:
	box("dark2", c, Vector3(w, 0.007, L), 0.001)
	var k := int(L / 0.022)
	for i in k:
		box("dark", c + Vector3(0, 0.005, -L / 2 + 0.011 + i * L / k), Vector3(w + 0.002, 0.004, 0.009))


# ---------- Silahlar ----------

func _pistol() -> void:
	part("slide", Vector3(0, 0.03, -0.07))
	marker("muzzle", Vector3(0, 0.024, -0.194))
	marker("grip_l", Vector3(0, -0.07, 0.02))
	ext("dark", [0.05, 0.002, 0.05, 0.048, 0.045, 0.054, -0.165, 0.054, -0.19, 0.037, -0.19, 0.002], -0.021, 0.021, 0.004) # sürgü
	box("black", Vector3(0.007, 0.0535, -0.02), Vector3(0.02, 0.004, 0.042)) # fişek çıkış
	for i in 5:
		box("dark2", Vector3(0, 0.028, 0.012 + i * 0.008), Vector3(0.0435, 0.036, 0.004))
	for i in 3:
		box("dark2", Vector3(0, 0.028, -0.13 - i * 0.008), Vector3(0.0435, 0.03, 0.004))
	cyl("steel", 0.0095, 0.0095, Vector3(0, 0.024, -0.185), Vector3(0, 0.024, -0.193), 12)
	cyl("black", 0.006, 0.006, Vector3(0, 0.024, -0.19), Vector3(0, 0.024, -0.1935), 8)
	part("body")
	ext("dark2", [0.045, 0.002, -0.15, 0.002, -0.155, -0.012, -0.15, -0.024, -0.08, -0.024, -0.075, -0.016, 0.045, -0.016],
		-0.019, 0.019, 0.003) # gövde
	cyl("steel", 0.007, 0.007, Vector3(0, -0.006, -0.15), Vector3(0, -0.006, -0.157), 8)
	for z in [-0.1, -0.115, -0.13]:
		box("black", Vector3(0, -0.024, z), Vector3(0.03, 0.004, 0.006))
	ext("black", [-0.002, -0.016, 0.06, -0.016, 0.074, -0.004, 0.077, -0.012, 0.062, -0.036, 0.042, -0.142, -0.018, -0.137],
		-0.018, 0.018, 0.004) # kabza
	for s in [-1.0, 1.0]: # ahşap kabza yanakları, yivleri ve vidaları
		ext("wood", [0.004, -0.03, 0.05, -0.035, 0.036, -0.125, -0.01, -0.122], 0.0175 * s, 0.0215 * s, 0.0015)
		for i in 4:
			var y := -0.055 - i * 0.017
			box("wooddk", Vector3(0.0213 * s, y, 0.019 - i * 0.0035), Vector3(0.0012, 0.003, 0.034))
	screws("steel", 0.0215, [Vector2(0.024, -0.042), Vector2(0.006, -0.112)], 0.0035)
	part("mag", Vector3(0, -0.141, 0.012))
	box("dark", Vector3(0, -0.141, 0.012), Vector3(0.042, 0.008, 0.05), 0.002) # şarjör tabanı
	part("body")
	guard("dark2", -0.077, -0.002, -0.016, 0.036)
	part("slide", Vector3(0, 0.03, -0.07))
	ext("dark", [-0.172, 0.054, -0.164, 0.054, -0.165, 0.064, -0.171, 0.064], -0.003, 0.003) # arpacık
	box("white", Vector3(0, 0.06, -0.1638), Vector3(0.003, 0.003, 0.001))
	for s in [-1.0, 1.0]: # gez
		box("dark", Vector3(0.0075 * s, 0.061, 0.04), Vector3(0.006, 0.014, 0.014), 0.001)
		box("white", Vector3(0.0075 * s, 0.062, 0.0472), Vector3(0.002, 0.002, 0.001))
	part("hammer", Vector3(0, 0.034, 0.054))
	ext("dark", [0.05, 0.032, 0.058, 0.032, 0.064, 0.05, 0.059, 0.053, 0.052, 0.043], -0.005, 0.005) # horoz
	part("body")
	box("dark", Vector3(-0.0205, 0.002, -0.03), Vector3(0.003, 0.008, 0.032)) # sürgü kilidi
	box("dark", Vector3(-0.0205, 0.006, 0.04), Vector3(0.004, 0.01, 0.018)) # emniyet
	cyl("steel", 0.003, 0.003, Vector3(-0.0205, -0.008, -0.055), Vector3(0.0205, -0.008, -0.055), 6)


func _shotgun() -> void:
	cyl("dark", 0.019, 0.019, Vector3(0, 0.032, -0.02), Vector3(0, 0.032, -0.65), 12) # namlu
	cyl("dark2", 0.021, 0.021, Vector3(0, 0.032, -0.65), Vector3(0, 0.032, -0.665), 12)
	cyl("black", 0.013, 0.013, Vector3(0, 0.032, -0.665), Vector3(0, 0.032, -0.6655), 10)
	box("dark", Vector3(0, 0.054, -0.34), Vector3(0.008, 0.006, 0.62)) # nişan rayı
	sph("brass", Vector3(0, 0.06, -0.652), 0.004, 6, 4)
	box("dark", Vector3(0, 0.012, -0.555), Vector3(0.022, 0.05, 0.016), 0.003) # namlu kelepçesi
	cyl("dark", 0.016, 0.016, Vector3(0, -0.006, -0.04), Vector3(0, -0.006, -0.56), 12) # şarjör borusu
	cyl("dark2", 0.018, 0.018, Vector3(0, -0.006, -0.56), Vector3(0, -0.006, -0.582), 12)
	cyl("steel", 0.012, 0.012, Vector3(0, -0.006, -0.582), Vector3(0, -0.006, -0.586), 10)
	torus("steel", Vector3(0, -0.03, -0.572), Vector3.RIGHT, 0.008, 0.0018, 8, 4)
	part("pump", Vector3(0, -0.011, -0.32))
	ext("wood", [-0.19, 0.014, -0.44, 0.014, -0.452, 0.004, -0.452, -0.022, -0.44, -0.036, -0.2, -0.036, -0.188, -0.022, -0.188, 0.004],
		-0.031, 0.031, 0.006) # pompa
	for i in 7:
		box("wooddk", Vector3(0, -0.011, -0.225 - i * 0.031), Vector3(0.0635, 0.047, 0.006))
	for s in [-1.0, 1.0]:
		box("steel", Vector3(0.021 * s, 0.002, -0.12), Vector3(0.004, 0.008, 0.15))
	part("body")
	ext("dark", [0.13, 0.058, 0.0, 0.058, -0.03, 0.05, -0.04, 0.035, -0.04, -0.032, 0.13, -0.032], -0.028, 0.028, 0.004) # mekanizma
	box("black", Vector3(0.0275, 0.025, 0.03), Vector3(0.004, 0.024, 0.056))
	box("steel", Vector3(0.028, 0.025, 0.042), Vector3(0.004, 0.012, 0.022))
	box("black", Vector3(0, -0.033, 0.03), Vector3(0.03, 0.004, 0.07))
	screws("steel", 0.028, [Vector2(0.08, 0.0), Vector2(0.11, 0.0)])
	guard("dark", -0.048, 0.015, -0.032, 0.04)
	cyl("red", 0.004, 0.004, Vector3(-0.009, -0.04, -0.044), Vector3(0.009, -0.04, -0.044), 6) # emniyet
	ext("wood", [0.03, -0.03, 0.0, -0.125, 0.05, -0.13, 0.095, -0.055, 0.33, -0.10, 0.40, -0.104, 0.40, 0.032, 0.13, 0.05, 0.13, -0.03],
		-0.026, 0.026, 0.006) # dipçik
	for s in [-1.0, 1.0]:
		ext("wooddk", [0.025, -0.045, 0.01, -0.11, 0.045, -0.112, 0.07, -0.05], 0.0245 * s, 0.0268 * s, 0.001) # kabza tırtılı
	ext("black", [0.40, 0.033, 0.418, 0.035, 0.418, -0.107, 0.40, -0.105], -0.028, 0.028, 0.004)
	box("white", Vector3(0, -0.036, 0.4015), Vector3(0.054, 0.136, 0.003))
	torus("steel", Vector3(0, -0.105, 0.3), Vector3.RIGHT, 0.008, 0.0018, 8, 4)
	box("black", Vector3(-0.031, 0.012, 0.045), Vector3(0.006, 0.065, 0.11), 0.002) # yan fişeklik
	for i in 4:
		var z := 0.008 + i * 0.025
		cyl("red", 0.0085, 0.0085, Vector3(-0.038, -0.012, z), Vector3(-0.038, 0.04, z), 8)
		cyl("brass", 0.009, 0.009, Vector3(-0.038, -0.022, z), Vector3(-0.038, -0.012, z), 8)
	part("shell", Vector3(0, -0.045, 0.0)) # sol eldeki yedek fişek (viewmodel gizler)
	cyl("red", 0.0085, 0.0085, Vector3(0, -0.045, -0.026), Vector3(0, -0.045, 0.026), 8)
	cyl("brass", 0.009, 0.009, Vector3(0, -0.045, 0.026), Vector3(0, -0.045, 0.036), 8)
	part("body")
	marker("muzzle", Vector3(0, 0.032, -0.666))
	marker("grip_l", Vector3(0, -0.011, -0.32))


func _smg() -> void:
	ext("dark", [0.10, 0.072, -0.20, 0.072, -0.235, 0.055, -0.235, 0.02, 0.10, 0.02], -0.028, 0.028, 0.004) # üst gövde
	ext("dark2", [0.10, 0.02, -0.2, 0.02, -0.2, -0.012, 0.10, -0.012], -0.026, 0.026, 0.003) # alt gövde
	rail(Vector3(0, 0.078, -0.06), 0.24)
	for s in [-1.0, 1.0]:
		box("dark2", Vector3(0.03 * s, 0.035, -0.19), Vector3(0.006, 0.012, 0.08), 0.001)
	cyl("steel", 0.023, 0.023, Vector3(0, 0.035, -0.235), Vector3(0, 0.035, -0.34), 10) # namlu kılıfı
	for z in [-0.255, -0.28, -0.305]:
		box("black", Vector3(0, 0.035, z), Vector3(0.048, 0.01, 0.012))
		box("black", Vector3(0, 0.035, z), Vector3(0.01, 0.048, 0.012))
	cyl("dark", 0.014, 0.014, Vector3(0, 0.035, -0.34), Vector3(0, 0.035, -0.385), 10) # alev gizleyici
	box("black", Vector3(0, 0.035, -0.37), Vector3(0.03, 0.004, 0.02))
	box("black", Vector3(0, 0.035, -0.37), Vector3(0.004, 0.03, 0.02))
	cyl("black", 0.007, 0.007, Vector3(0, 0.035, -0.385), Vector3(0, 0.035, -0.3855), 8)
	ext("dark", [-0.055, -0.012, -0.125, -0.012, -0.128, -0.03, -0.052, -0.03], -0.02, 0.02, 0.003) # şarjör yuvası
	part("mag", Vector3(0, -0.03, -0.09))
	ext("dark2", [-0.06, -0.03, -0.12, -0.03, -0.14, -0.17, -0.083, -0.182], -0.016, 0.016, 0.003) # şarjör
	ext("black", [-0.143, -0.168, -0.08, -0.18, -0.078, -0.192, -0.145, -0.18], -0.018, 0.018, 0.002)
	for i in 3:
		box("black", Vector3(0, -0.06 - i * 0.035, -0.096 - i * 0.006), Vector3(0.0325, 0.004, 0.04))
	part("body")
	ext("black", [0.0, -0.012, 0.048, -0.012, 0.064, -0.125, 0.06, -0.135, 0.018, -0.138, 0.012, -0.125], -0.02, 0.02, 0.004) # kabza
	for s in [-1.0, 1.0]:
		ext("dark2", [0.012, -0.03, 0.045, -0.03, 0.055, -0.11, 0.022, -0.115], 0.0195 * s, 0.0215 * s, 0.001)
	guard("dark", -0.05, -0.002, -0.012, 0.034)
	part("charging", Vector3(-0.033, 0.055, -0.13))
	box("steel", Vector3(-0.033, 0.055, -0.13), Vector3(0.012, 0.012, 0.022), 0.002) # kurma kolu
	part("body")
	box("black", Vector3(-0.0275, 0.055, -0.08), Vector3(0.003, 0.006, 0.12))
	box("black", Vector3(0.0275, 0.045, -0.03), Vector3(0.003, 0.016, 0.045)) # fişek çıkış
	cyl("steel", 0.007, 0.007, Vector3(0.026, 0.0, 0.06), Vector3(0.031, 0.0, 0.06), 8) # seçici
	box("red", Vector3(0.031, 0.0, 0.07), Vector3(0.003, 0.004, 0.018))
	ext("dark", [-0.20, 0.082, -0.18, 0.082, -0.183, 0.104, -0.197, 0.104], -0.011, 0.011, 0.002) # arpacık
	box("glow", Vector3(0, 0.098, -0.1825), Vector3(0.003, 0.003, 0.002))
	box("dark", Vector3(0, 0.094, 0.08), Vector3(0.024, 0.022, 0.01), 0.002) # gez
	box("black", Vector3(0, 0.097, 0.08), Vector3(0.006, 0.006, 0.012))
	for s in [-1.0, 1.0]: # katlanır dipçik
		cyl("steel", 0.005, 0.005, Vector3(0.018 * s, 0.05, 0.10), Vector3(0.018 * s, 0.045, 0.31), 6)
	cyl("steel", 0.005, 0.005, Vector3(0, 0.0, 0.10), Vector3(0, 0.0, 0.31), 6)
	cyl("dark", 0.008, 0.008, Vector3(-0.03, 0.045, 0.105), Vector3(0.03, 0.045, 0.105), 8)
	ext("black", [0.30, 0.075, 0.325, 0.075, 0.325, -0.03, 0.30, -0.03], -0.026, 0.026, 0.005)
	torus("steel", Vector3(0, -0.018, 0.09), Vector3.RIGHT, 0.008, 0.0018, 8, 4)
	marker("muzzle", Vector3(0, 0.035, -0.386))
	marker("grip_l", Vector3(0, 0.0, -0.2))


func _sniper() -> void:
	cyl("dark", 0.017, 0.013, Vector3(0, 0.042, -0.14), Vector3(0, 0.042, -0.84), 12) # namlu
	for s in [-1.0, 1.0]:
		box("black", Vector3(0.014 * s, 0.042, -0.47), Vector3(0.003, 0.004, 0.42))
	box("black", Vector3(0, 0.0555, -0.47), Vector3(0.004, 0.003, 0.42))
	cyl("dark2", 0.023, 0.023, Vector3(0, 0.042, -0.84), Vector3(0, 0.042, -0.92), 8) # namlu freni
	for z in [-0.862, -0.894]:
		box("black", Vector3(0, 0.042, z), Vector3(0.05, 0.014, 0.016))
	cyl("black", 0.008, 0.008, Vector3(0, 0.042, -0.92), Vector3(0, 0.042, -0.9205), 8)
	ext("olive", [-0.47, 0.028, 0.12, 0.028, 0.43, 0.048, 0.43, -0.115, 0.37, -0.118, 0.22, -0.06, 0.12, -0.06,
		0.085, -0.13, 0.03, -0.13, 0.03, -0.04, -0.45, -0.04, -0.47, -0.02], -0.032, 0.032, 0.007) # kundak
	for s in [-1.0, 1.0]:
		ext("olivedk", [0.04, -0.05, 0.075, -0.05, 0.08, -0.12, 0.045, -0.12], 0.031 * s, 0.0335 * s, 0.001)
		ext("olivedk", [-0.42, -0.005, -0.15, -0.005, -0.15, -0.03, -0.42, -0.03], 0.031 * s, 0.0335 * s, 0.001)
	box("dark2", Vector3(0, -0.044, -0.3), Vector3(0.018, 0.008, 0.18), 0.001)
	ext("olivedk", [0.2, 0.035, 0.37, 0.05, 0.37, 0.074, 0.21, 0.064], -0.026, 0.026, 0.005) # yanak desteği
	screws("steel", 0.026, [Vector2(0.25, 0.05), Vector2(0.33, 0.058)], 0.005)
	ext("black", [0.43, 0.05, 0.448, 0.052, 0.448, -0.117, 0.43, -0.117], -0.032, 0.032, 0.005)
	box("white", Vector3(0, -0.033, 0.4315), Vector3(0.062, 0.162, 0.003))
	cyl("dark", 0.006, 0.006, Vector3(0, -0.116, 0.39), Vector3(0, -0.15, 0.39), 6)
	sph("black", Vector3(0, -0.152, 0.39), 0.01, 6, 4, 0.6)
	ext("dark", [0.12, 0.072, -0.16, 0.072, -0.18, 0.06, -0.18, 0.028, 0.12, 0.028], -0.025, 0.025, 0.004) # mekanizma
	rail(Vector3(0, 0.077, -0.02), 0.26, 0.02)
	box("black", Vector3(0.025, 0.05, -0.02), Vector3(0.003, 0.018, 0.07))
	part("bolt", Vector3(0, 0.052, 0.12))
	cyl("steel", 0.01, 0.01, Vector3(0, 0.052, 0.12), Vector3(0, 0.052, 0.155), 10) # sürgü
	cyl("steel", 0.005, 0.005, Vector3(0.02, 0.052, 0.11), Vector3(0.062, 0.034, 0.12), 6)
	sph("dark", Vector3(0.066, 0.032, 0.12), 0.013, 8, 5)
	part("body")
	part("mag", Vector3(0, -0.04, -0.03))
	ext("dark", [-0.06, -0.04, 0.0, -0.04, 0.0, -0.078, -0.06, -0.078], -0.022, 0.022, 0.003) # şarjör
	part("body")
	guard("dark", 0.0, 0.07, -0.06, 0.036)
	cyl("dark", 0.0185, 0.0185, Vector3(0, 0.118, -0.16), Vector3(0, 0.118, 0.06), 12) # dürbün
	cyl("dark", 0.0185, 0.031, Vector3(0, 0.118, -0.16), Vector3(0, 0.118, -0.2), 12)
	cyl("dark", 0.031, 0.031, Vector3(0, 0.118, -0.2), Vector3(0, 0.118, -0.265), 12)
	cyl("dark2", 0.033, 0.033, Vector3(0, 0.118, -0.262), Vector3(0, 0.118, -0.272), 12)
	cyl("glass", 0.027, 0.027, Vector3(0, 0.118, -0.265), Vector3(0, 0.118, -0.2655), 12)
	cyl("dark", 0.0185, 0.025, Vector3(0, 0.118, 0.06), Vector3(0, 0.118, 0.09), 12)
	cyl("dark", 0.025, 0.025, Vector3(0, 0.118, 0.09), Vector3(0, 0.118, 0.12), 12)
	cyl("black", 0.027, 0.027, Vector3(0, 0.118, 0.12), Vector3(0, 0.118, 0.137), 12)
	cyl("glass", 0.02, 0.02, Vector3(0, 0.118, 0.137), Vector3(0, 0.118, 0.1375), 12)
	box("dark", Vector3(0, 0.118, -0.05), Vector3(0.048, 0.044, 0.05), 0.006) # taret yuvası
	cyl("steel", 0.014, 0.014, Vector3(0, 0.14, -0.05), Vector3(0, 0.162, -0.05), 12)
	cyl("dark", 0.015, 0.015, Vector3(0, 0.162, -0.05), Vector3(0, 0.168, -0.05), 12)
	cyl("steel", 0.013, 0.013, Vector3(0.024, 0.118, -0.05), Vector3(0.044, 0.118, -0.05), 12)
	cyl("dark2", 0.011, 0.011, Vector3(-0.024, 0.118, -0.05), Vector3(-0.04, 0.118, -0.05), 10)
	for z in [-0.12, 0.03]: # halkalar ve ayaklar
		cyl("dark2", 0.022, 0.022, Vector3(0, 0.118, z - 0.007), Vector3(0, 0.118, z + 0.007), 12)
		box("dark2", Vector3(0, 0.091, z), Vector3(0.024, 0.03, 0.016), 0.002)
	box("dark", Vector3(0, -0.05, -0.38), Vector3(0.03, 0.016, 0.03), 0.003) # çatal ayak
	for s in [-1.0, 1.0]:
		cyl("dark", 0.006, 0.006, Vector3(0.012 * s, -0.052, -0.4), Vector3(0.02 * s, -0.052, -0.62), 6)
		sph("black", Vector3(0.02 * s, -0.052, -0.626), 0.009, 6, 4)
	torus("steel", Vector3(0, -0.052, -0.3), Vector3.RIGHT, 0.008, 0.0018, 8, 4)
	marker("muzzle", Vector3(0, 0.042, -0.921))
	marker("grip_l", Vector3(0, -0.05, -0.3))


func _bow() -> void:
	# Gövde: ok rafı oyuğu olan koyu ahşap; uzuvlar açık ahşap, iç yüzde koyu şerit, uçlar geri kıvrık.
	ext("woodred", [-0.258, 0.15, -0.282, 0.08, -0.29, 0.0, -0.282, -0.08, -0.258, -0.15, -0.238, -0.15, -0.226, -0.06,
		-0.222, 0.0, -0.236, 0.03, -0.236, 0.06, -0.226, 0.07, -0.238, 0.15], -0.017, 0.017, 0.005)
	for sgn in [-1.0, 1.0]:
		var outer := []
		var inn := []
		var mid := []
		for i in 11:
			var s := i / 10.0
			var y: float = (0.13 + 0.34 * s) * sgn
			var z := -0.255 + 0.12 * s * s - 0.05 * pow(maxf(s - 0.78, 0.0) / 0.22, 2.0)
			var th := 0.013 * (1.0 - 0.45 * s)
			outer.append_array([z - th, y])
			inn.append_array([z + th, y])
			mid.append_array([z + th * 0.15, y])
		ext("birch", outer + _rev(inn), -0.013, 0.013, 0.003)
		ext("wooddk", inn + _rev(mid), -0.0134, 0.0134)
		cyl("steel", 0.007, 0.007, Vector3(-0.019, 0.12 * sgn, -0.255), Vector3(0.019, 0.12 * sgn, -0.255), 8) # uzuv cıvatası
		sph("black", Vector3(0, 0.47 * sgn, -0.181), 0.007, 6, 4)
	ext("leather", [-0.24, 0.028, -0.222, 0.028, -0.218, -0.065, -0.24, -0.065], -0.0185, 0.0185, 0.004) # kabza sargısı
	for i in 5:
		box("leatherdk", Vector3(0, 0.02 - i * 0.02, -0.229), Vector3(0.0385, 0.003, 0.026))
	box("dark", Vector3(0.0185, 0.032, -0.236), Vector3(0.006, 0.004, 0.014)) # ok rafı
	for sgn in [1.0, -1.0]: # kiriş: uç noktalarından dönen iki yarı, ortada (kiriş noktası) birleşir
		part("string_top" if sgn > 0 else "string_bot", Vector3(0, 0.47 * sgn, -0.178))
		box("string", Vector3(0, 0.235 * sgn, -0.178), Vector3(0.0025, 0.47, 0.0025))
		box("black", Vector3(0, 0.0275 * sgn, -0.178), Vector3(0.004, 0.055, 0.004))
		sph("leatherdk", Vector3(0, 0.3 * sgn, -0.178), 0.008, 6, 4, 1.4) # susturucu
	cyl("brass", 0.003, 0.003, Vector3(0, 0.03, -0.1805), Vector3(0, 0.036, -0.1805), 6)
	var ax := 0.021 # ok gövdenin yanından geçer, rafa oturur
	var ay := 0.036
	part("arrow", Vector3(ax, ay, -0.178))
	cyl("birch", 0.0045, 0.0045, Vector3(ax, ay, -0.17), Vector3(ax, ay, -0.72), 6) # ok
	cyl("red", 0.0055, 0.005, Vector3(ax, ay, -0.178), Vector3(ax, ay, -0.168), 6)
	org = Vector3(ax, ay, 0)
	for k in 3: # tüyler
		var a := TAU * k / 3.0
		var V := Vector3(sin(a), cos(a), 0)
		var W := V.cross(Vector3.BACK)
		var col := "white" if k == 0 else "red"
		ext(col, [-0.185, 0.004, -0.245, 0.004, -0.235, 0.02, -0.2, 0.016], -0.0008, 0.0008, 0.0, Vector3.BACK, V, W)
	for k in 2: # sivri uç: iki dik kanat
		var V := Vector3.UP if k == 0 else Vector3.RIGHT
		var W := Vector3.RIGHT if k == 0 else Vector3.UP
		ext("steel", [-0.715, 0.0, -0.735, 0.012, -0.785, 0.0, -0.735, -0.012], -0.0012, 0.0012, 0.0, Vector3.BACK, V, W)
	org = Vector3.ZERO
	part("body")
	marker("muzzle", Vector3(ax, ay, -0.785))
	marker("grip_l", Vector3(0, -0.02, -0.23))


func _boomerang() -> void:
	# Üstten görünüş: u = X, v = Z, kalınlık Y. Sağ yarı çizilir, sol yarı aynası.
	var half := [0.0, -0.378, 0.03, -0.372, 0.235, -0.15, 0.248, -0.13, 0.245, -0.106, 0.228, -0.092, 0.208, -0.094, 0.0, -0.282]
	var shape := half.duplicate()
	for i in range(half.size() - 4, 1, -2): # sol yarı: uçtan dirseğe, x aynası (dirsek uçları ortak)
		shape.append_array([-half[i], half[i + 1]])
	var top := func(m: String, uv: Array, w0: float, w1: float, b := 0.0): ext(m, uv, w0, w1, b, Vector3.RIGHT, Vector3.BACK, Vector3.UP)
	top.call("wood", shape, -0.009, 0.009, 0.006)
	for s in [-1.0, 1.0]:
		for b in [[0.3, 0.36, "red"], [0.4, 0.44, "yellow"], [0.48, 0.54, "red"], [0.86, 0.9, "black"]]:
			var o0 := Vector2(0.235 * b[0] * s, -0.375 + 0.225 * b[0])
			var o1 := Vector2(0.235 * b[1] * s, -0.375 + 0.225 * b[1])
			var i1 := Vector2(0.208 * b[1] * s, -0.282 + 0.188 * b[1])
			var i0 := Vector2(0.208 * b[0] * s, -0.282 + 0.188 * b[0])
			for w in [[0.0088, 0.0102], [-0.0102, -0.0088]]:
				top.call(b[2], [o0.x, o0.y, o1.x, o1.y, i1.x, i1.y, i0.x, i0.y], w[0], w[1])
		for k in 4: # nokta süsleri
			var f := 0.62 + k * 0.06
			var c := Vector2(0.222 * f * s, -0.33 + 0.205 * f)
			cyl("yellow", 0.005, 0.005, Vector3(c.x, 0.0088, c.y), Vector3(c.x, 0.0104, c.y), 6)
	cyl("yellow", 0.022, 0.022, Vector3(0, 0.0088, -0.33), Vector3(0, 0.0104, -0.33), 12) # dirsek amblemi
	cyl("red", 0.014, 0.014, Vector3(0, 0.0104, -0.33), Vector3(0, 0.0114, -0.33), 12)
	marker("muzzle", Vector3(0, 0, -0.33))
	marker("grip_l", Vector3(0, 0, -0.33))


func _flame() -> void:
	ext("dark", [0.13, 0.035, -0.02, 0.035, -0.05, 0.02, -0.05, -0.03, 0.13, -0.03], -0.03, 0.03, 0.005) # arka gövde
	screws("steel", 0.03, [Vector2(0.02, 0.018), Vector2(0.1, 0.018), Vector2(0.1, -0.016)])
	ext("black", [0.13, 0.03, 0.30, 0.02, 0.30, -0.08, 0.27, -0.08, 0.2, -0.03, 0.13, -0.03], -0.022, 0.022, 0.004) # dipçik
	ext("dark2", [0.30, 0.022, 0.315, 0.022, 0.315, -0.082, 0.30, -0.082], -0.024, 0.024, 0.004)
	cyl("dark", 0.02, 0.02, Vector3(0, 0, -0.05), Vector3(0, 0, -0.56), 10) # boru
	cyl("steel", 0.036, 0.036, Vector3(0, 0, -0.22), Vector3(0, 0, -0.5), 12) # ısı kalkanı
	for z in [-0.22, -0.5]:
		cyl("dark", 0.039, 0.039, Vector3(0, 0, z - 0.008), Vector3(0, 0, z + 0.008), 12)
	for i in 6:
		var z := -0.25 - i * 0.04
		box("black", Vector3(0, 0.0345, z), Vector3(0.026, 0.004, 0.014))
		box("black", Vector3(0, 0, z), Vector3(0.073, 0.012, 0.014))
	ext("dark", [-0.44, 0.03, -0.44, 0.075, -0.26, 0.075, -0.26, 0.03, -0.275, 0.03, -0.275, 0.062, -0.425, 0.062, -0.425, 0.03],
		-0.008, 0.008, 0.003) # taşıma kolu
	cyl("brass", 0.026, 0.042, Vector3(0, 0, -0.56), Vector3(0, 0, -0.63), 12) # meme
	cyl("black", 0.034, 0.034, Vector3(0, 0, -0.63), Vector3(0, 0, -0.6305), 12)
	box("dark", Vector3(0, 0, -0.629), Vector3(0.07, 0.004, 0.002))
	box("dark", Vector3(0, 0, -0.629), Vector3(0.004, 0.07, 0.002))
	box("dark", Vector3(0, -0.047, -0.42), Vector3(0.022, 0.022, 0.04), 0.003) # ateşleyici
	cyl("steel", 0.007, 0.007, Vector3(0, -0.047, -0.44), Vector3(0, -0.047, -0.61), 8)
	part("pilot", Vector3(0, -0.047, -0.616))
	sph("glow", Vector3(0, -0.047, -0.616), 0.009, 8, 5)
	part("body")
	cyl("red", 0.005, 0.005, Vector3(0.011, -0.047, -0.42), Vector3(0.016, -0.047, -0.42), 8)
	tube("black", 0.007, [Vector3(-0.03, -0.12, -0.06), Vector3(-0.036, -0.11, -0.01), Vector3(-0.036, -0.06, 0.02), Vector3(-0.03, -0.02, 0.03)])
	part("tank", Vector3(0, -0.09, -0.2))
	var t := -0.09 # yakıt tankı
	cyl("red", 0.052, 0.052, Vector3(0, t, -0.07), Vector3(0, t, -0.33), 14)
	cyl("red", 0.052, 0.034, Vector3(0, t, -0.33), Vector3(0, t, -0.348), 14)
	cyl("red", 0.034, 0.0, Vector3(0, t, -0.348), Vector3(0, t, -0.352), 14)
	cyl("red", 0.052, 0.034, Vector3(0, t, -0.07), Vector3(0, t, -0.052), 14)
	cyl("red", 0.034, 0.0, Vector3(0, t, -0.052), Vector3(0, t, -0.048), 14)
	cyl("yellow", 0.0525, 0.0525, Vector3(0, t, -0.3), Vector3(0, t, -0.312), 14)
	for z in [-0.12, -0.26]:
		cyl("dark", 0.0545, 0.0545, Vector3(0, t, z - 0.008), Vector3(0, t, z + 0.008), 14)
		box("steel", Vector3(0.056, t, z), Vector3(0.006, 0.016, 0.02), 0.002)
	cyl("dark", 0.008, 0.008, Vector3(0, -0.04, -0.2), Vector3(0, -0.015, -0.2), 8)
	cyl("brass", 0.008, 0.008, Vector3(0, -0.044, -0.09), Vector3(0, -0.026, -0.09), 8) # vana
	torus("red", Vector3(0, -0.028, -0.09), Vector3.UP, 0.012, 0.0022, 10, 4)
	cyl("steel", 0.018, 0.018, Vector3(0.045, t, -0.19), Vector3(0.062, t, -0.19), 12) # basınç saati
	cyl("white", 0.015, 0.015, Vector3(0.062, t, -0.19), Vector3(0.0625, t, -0.19), 12)
	box("red", Vector3(0.0628, t + 0.005, -0.193), Vector3(0.001, 0.011, 0.002))
	part("body")
	marker("muzzle", Vector3(0, 0, -0.631))
	marker("grip_l", Vector3(0, 0.07, -0.35))
	ext("black", [0.0, -0.03, 0.045, -0.03, 0.06, -0.14, 0.054, -0.148, 0.018, -0.148, 0.012, -0.14], -0.02, 0.02, 0.004) # kabza
	guard("dark", -0.05, 0.0, -0.03, 0.034)


func _grenade() -> void:
	var c := Vector3(0, 0, -0.15)
	var sy := 1.15
	sph("olive", c, 0.052, 12, 8, sy) # gövde
	for row in 4: # ananas dilimleri
		var th := deg_to_rad(52 + row * 26)
		for k in 8:
			var ph := TAU * (k + 0.5 * (row % 2)) / 8.0
			var p := c + Vector3(sin(th) * cos(ph), cos(th) * sy, sin(th) * sin(ph)) * 0.047
			sph("olivedk" if (row + k) % 2 else "olive", p, 0.0095, 6, 4, 0.8)
	cyl("dark", 0.016, 0.016, c + Vector3(0, -0.058, 0), c + Vector3(0, -0.064, 0), 10)
	cyl("steel", 0.02, 0.018, c + Vector3(0, 0.056, 0), c + Vector3(0, 0.076, 0), 10) # tapa
	cyl("yellow", 0.0202, 0.0202, c + Vector3(0, 0.06, 0), c + Vector3(0, 0.064, 0), 10)
	box("steel", c + Vector3(0, 0.08, 0.004), Vector3(0.022, 0.012, 0.03), 0.003)
	cyl("dark", 0.011, 0.011, c + Vector3(0, 0.086, -0.004), c + Vector3(0, 0.094, -0.004), 10)
	cyl("dark", 0.004, 0.004, c + Vector3(-0.013, 0.082, 0.014), c + Vector3(0.013, 0.082, 0.014), 6)
	part("spoon", c + Vector3(0, 0.085, 0))
	org = c
	ext("steel", [0.0, 0.088, 0.035, 0.085, 0.06, 0.065, 0.068, 0.03, 0.066, 0.0, 0.06, -0.012, 0.056, -0.008,
		0.06, 0.0, 0.062, 0.03, 0.054, 0.062, 0.033, 0.079, 0.0, 0.082], -0.009, 0.009, 0.002) # mandal (kaşık)
	org = Vector3.ZERO
	part("pin", c + Vector3(0, 0.07, -0.006))
	cyl("steel", 0.0022, 0.0022, c + Vector3(-0.025, 0.07, -0.006), c + Vector3(0.03, 0.07, -0.006), 6) # pim
	part("ring", c + Vector3(0.03, 0.054, -0.006))
	torus("steel", c + Vector3(0.03, 0.054, -0.006), Vector3.RIGHT, 0.016, 0.0024, 12, 4)
	part("body")
	marker("muzzle", c)
	marker("grip_l", c + Vector3(0.03, 0.054, -0.006))


func _bazooka() -> void:
	# Namlu -Z; oyuncu modeli kutu merkezinden tutar (player.gd _prop).
	cyl("olive", 0.055, 0.055, Vector3(0, 0, 0.35), Vector3(0, 0, -0.55), 14) # tüp
	for z in [-0.35, 0.0, 0.24]:
		cyl("olivedk", 0.058, 0.058, Vector3(0, 0, z - 0.012), Vector3(0, 0, z + 0.012), 14)
	cyl("yellow", 0.0555, 0.0555, Vector3(0, 0, 0.29), Vector3(0, 0, 0.31), 14)
	cyl("dark", 0.06, 0.068, Vector3(0, 0, -0.55), Vector3(0, 0, -0.6), 14) # ağız
	cyl("black", 0.058, 0.058, Vector3(0, 0, -0.6), Vector3(0, 0, -0.601), 14)
	part("rocket", Vector3(0, 0, -0.58))
	cyl("red", 0.042, 0.042, Vector3(0, 0, -0.56), Vector3(0, 0, -0.62), 12) # roket başlığı
	cyl("red", 0.042, 0.012, Vector3(0, 0, -0.62), Vector3(0, 0, -0.68), 12)
	cyl("steel", 0.012, 0.0, Vector3(0, 0, -0.68), Vector3(0, 0, -0.695), 8)
	part("body")
	cyl("dark", 0.055, 0.078, Vector3(0, 0, 0.35), Vector3(0, 0, 0.46), 14) # arka huni
	cyl("black", 0.07, 0.07, Vector3(0, 0, 0.459), Vector3(0, 0, 0.46), 14)
	box("dark", Vector3(-0.068, 0.04, -0.12), Vector3(0.03, 0.045, 0.14), 0.006) # nişangâh
	cyl("dark", 0.016, 0.016, Vector3(-0.068, 0.045, -0.19), Vector3(-0.068, 0.045, -0.205), 10)
	cyl("glass", 0.013, 0.013, Vector3(-0.068, 0.045, -0.205), Vector3(-0.068, 0.045, -0.2055), 10)
	cyl("black", 0.014, 0.014, Vector3(-0.068, 0.045, -0.05), Vector3(-0.068, 0.045, -0.03), 10)
	box("dark", Vector3(-0.05, 0.02, -0.12), Vector3(0.02, 0.012, 0.04))
	for z in [-0.4, 0.2]: # açılır gez ve arpacık
		ext("dark", [z - 0.006, 0.05, z + 0.006, 0.05, z + 0.006, 0.09, z - 0.006, 0.09], -0.004, 0.004)
		box("glow", Vector3(0, 0.086, z), Vector3(0.009, 0.004, 0.0135))
	ext("dark", [-0.02, -0.05, 0.03, -0.05, 0.045, -0.16, 0.038, -0.168, 0.004, -0.168, -0.004, -0.16], -0.02, 0.02, 0.005) # kabza
	guard("dark2", -0.07, -0.02, -0.05, 0.036)
	ext("dark", [-0.28, -0.05, -0.24, -0.05, -0.245, -0.15, -0.275, -0.15], -0.018, 0.018, 0.005) # ön tutamak
	box("dark2", Vector3(0, -0.053, -0.12), Vector3(0.03, 0.01, 0.34), 0.002)
	box("black", Vector3(0, -0.062, 0.14), Vector3(0.05, 0.016, 0.16), 0.006) # omuz yastığı
	torus("steel", Vector3(0, -0.062, -0.45), Vector3.RIGHT, 0.009, 0.002, 8, 4)
	for z in [-0.45, -0.25, 0.1]: # perçinler
		for a in [0.6, 2.54]:
			sph("steel", Vector3(cos(a) * 0.056, sin(a) * 0.056, z), 0.004, 6, 3)
	marker("muzzle", Vector3(0, 0, -0.6))
	marker("grip_l", Vector3(0, -0.1, -0.26))


func _sword() -> void:
	# Bıçak -Z, düz yüzü yukarı (kalınlık Y); kabza +Z ucunda. Üstten görünüş: u = Z, v = X.
	var top := func(m: String, uv: Array, w0: float, w1: float, b := 0.0): ext(m, uv, w0, w1, b, Vector3.BACK, Vector3.RIGHT, Vector3.UP)
	top.call("steel", [0.0, -0.023, -0.6, -0.02, -0.68, -0.006, -0.7, 0.0, -0.68, 0.006, -0.6, 0.02, 0.0, 0.023], -0.0065, 0.0065, 0.0055) # bıçak
	for w in [[0.0058, 0.0068], [-0.0068, -0.0058]]: # oluk
		top.call("dark2", [-0.03, -0.0045, -0.46, -0.003, -0.46, 0.003, -0.03, 0.0045], w[0], w[1])
	top.call("steel", [0.0, -0.026, -0.04, -0.026, -0.04, 0.026, 0.0, 0.026], -0.008, 0.008, 0.003) # kök
	top.call("gold", [0.016, -0.085, 0.006, -0.105, -0.01, -0.1, -0.006, -0.03, -0.014, 0.0, -0.006, 0.03, -0.01, 0.1, 0.006, 0.105, 0.016, 0.085],
		-0.014, 0.014, 0.004) # balçak
	for s in [-1.0, 1.0]:
		sph("gold", Vector3(0.105 * s, 0, 0.0), 0.014, 8, 5)
		sph("ruby", Vector3(0, 0.0135 * s, 0.0), 0.009, 8, 4, 0.6)
	cyl("leather", 0.0135, 0.0135, Vector3(0, 0, 0.016), Vector3(0, 0, 0.14), 8) # kabza
	for i in 6:
		torus("leatherdk", Vector3(0, 0, 0.026 + i * 0.021), Vector3.BACK, 0.0138, 0.0028, 8, 4)
	cyl("gold", 0.016, 0.016, Vector3(0, 0, 0.012), Vector3(0, 0, 0.02), 10)
	cyl("gold", 0.016, 0.019, Vector3(0, 0, 0.14), Vector3(0, 0, 0.148), 10)
	sph("gold", Vector3(0, 0, 0.165), 0.024, 10, 6) # topuz
	sph("ruby", Vector3(0, 0, 0.188), 0.008, 8, 4)
	marker("muzzle", Vector3(0, 0, -0.7))
	marker("grip_l", Vector3(0, 0, 0.1))
