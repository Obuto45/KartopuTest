extends SceneTree
## Silah modeli üretici: "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s res://tools/weapon_models.gd
## Ardından içe aktar: aynı exe ile --headless --path . --import
## models/<id>.glb yazar: namlu -Z, kabza üstü başlangıç noktasında, ölçü metre, düz renkli low-poly.
## Tasarımı değiştirmek için aşağıdaki _<id>() fonksiyonlarındaki sayıları değiştir ve yeniden çalıştır.
## Parçalar: ext (yandan profil, X boyunca kalınlık), box, cyl (iki nokta arası koni/silindir), sph, torus.

const MATS := { # renk, metalik, pürüzlülük
	"dark": [Color(0.16, 0.16, 0.18), 0.5, 0.45],
	"steel": [Color(0.42, 0.44, 0.48), 0.7, 0.35],
	"black": [Color(0.07, 0.07, 0.08), 0.1, 0.85],
	"wood": [Color(0.52, 0.32, 0.16), 0.0, 0.75],
	"birch": [Color(0.82, 0.7, 0.5), 0.0, 0.8],
	"olive": [Color(0.3, 0.36, 0.22), 0.1, 0.7],
	"red": [Color(0.78, 0.16, 0.1), 0.3, 0.5],
	"brass": [Color(0.85, 0.62, 0.22), 0.8, 0.35],
	"leather": [Color(0.3, 0.18, 0.1), 0.0, 0.9],
	"string": [Color(0.92, 0.9, 0.82), 0.0, 0.9],
	"yellow": [Color(0.95, 0.75, 0.15), 0.0, 0.6],
	"glass": [Color(0.2, 0.5, 0.7), 0.9, 0.1],
	"blue": [Color(0.3, 0.6, 1.0), 0.0, 0.4],
}
const IDS := ["pistol", "shotgun", "smg", "sniper", "bow", "boomerang", "flame", "grenade"]

var surf := {} # malzeme -> üçgen köşeleri
var godot_sign := 1.0 # Godot'nun ön yüz sarımı: kenar çarpımı normalle aynı yönde mi (+1) ters mi (-1)


func _init() -> void:
	var a := BoxMesh.new().get_mesh_arrays()
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	godot_sign = signf((v[ix[1]] - v[ix[0]]).cross(v[ix[2]] - v[ix[0]]).dot(a[Mesh.ARRAY_NORMAL][ix[0]]))
	var only := OS.get_cmdline_user_args() # isteğe bağlı: -- pistol bow
	for id in IDS:
		if only.is_empty() or id in only:
			surf = {}
			call("_" + id)
			_save(id)
	quit()


func _save(id: String) -> void:
	var mesh := ArrayMesh.new()
	for m in surf:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var p: PackedVector3Array = surf[m]
		for i in range(0, p.size(), 3):
			st.set_normal(((p[i + 1] - p[i]).cross(p[i + 2] - p[i]) * godot_sign).normalized())
			for k in 3:
				st.add_vertex(p[i + k])
		var mat := StandardMaterial3D.new()
		mat.resource_name = m
		mat.albedo_color = MATS[m][0]
		mat.metallic = MATS[m][1]
		mat.roughness = MATS[m][2]
		st.set_material(mat)
		st.commit(mesh)
	var root := Node3D.new()
	root.name = id
	var mi := MeshInstance3D.new()
	mi.name = id
	mi.mesh = mesh
	root.add_child(mi)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(root, state)
	if err == OK:
		err = doc.write_to_filesystem(state, "res://models/%s.glb" % id)
	var tris := 0
	for m in surf:
		tris += surf[m].size() / 3
	print("%s: %d üçgen, %d malzeme, %s" % [id, tris, surf.size(), error_string(err)])
	root.free()


# ---------- Parçalar ----------

func tri(m: String, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 1e-14:
		return
	if signf(cr.dot(n)) != godot_sign:
		var t := b
		b = c
		c = t
	if not surf.has(m):
		surf[m] = PackedVector3Array()
	surf[m].append_array([a, b, c])


func quad(m: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	tri(m, a, b, c, n)
	tri(m, a, c, d, n)


## Düz profil (u, v çiftleri) W boyunca w0..w1 kalınlıkta. Varsayılan: yandan görünüş (u = Z, v = Y, kalınlık X).
func ext(m: String, uv: Array, w0: float, w1: float, U := Vector3.BACK, V := Vector3.UP, W := Vector3.RIGHT) -> void:
	var p := PackedVector2Array()
	for i in range(0, uv.size(), 2):
		p.append(Vector2(uv[i], uv[i + 1]))
	var area := 0.0
	for i in p.size():
		area += p[i].cross(p[(i + 1) % p.size()])
	if area < 0.0:
		p.reverse() # saat yönünün tersi: dış normal kenarın sağında
	var t := Geometry2D.triangulate_polygon(p)
	assert(not t.is_empty(), "%s profili üçgenlenemedi" % m)
	var to3 := func(q: Vector2, w: float) -> Vector3: return U * q.x + V * q.y + W * w
	for i in range(0, t.size(), 3):
		tri(m, to3.call(p[t[i]], w1), to3.call(p[t[i + 1]], w1), to3.call(p[t[i + 2]], w1), W)
		tri(m, to3.call(p[t[i]], w0), to3.call(p[t[i + 1]], w0), to3.call(p[t[i + 2]], w0), -W)
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		var d := b - a
		quad(m, to3.call(a, w0), to3.call(b, w0), to3.call(b, w1), to3.call(a, w1), U * d.y - V * d.x)


func box(m: String, c: Vector3, s: Vector3) -> void:
	ext(m, [c.z - s.z / 2, c.y - s.y / 2, c.z + s.z / 2, c.y - s.y / 2, c.z + s.z / 2, c.y + s.y / 2, c.z - s.z / 2, c.y + s.y / 2],
		c.x - s.x / 2, c.x + s.x / 2)


## a'dan b'ye, yarıçap r0'dan r1'e (0 = sivri uç).
func cyl(m: String, r0: float, r1: float, a: Vector3, b: Vector3, seg := 8) -> void:
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
func torus(m: String, c: Vector3, ax: Vector3, R: float, r: float, seg := 10, tube := 5) -> void:
	ax = ax.normalized()
	var e1 := ax.cross(Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT).normalized()
	var e2 := ax.cross(e1)
	var pt := func(i: int, j: int) -> Array:
		var dir := e1 * cos(TAU * i / seg) + e2 * sin(TAU * i / seg)
		var rc := c + dir * R
		return [rc + (dir * cos(TAU * j / tube) + ax * sin(TAU * j / tube)) * r, rc]
	for i in seg:
		for j in tube:
			var a: Array = pt.call(i, j)
			var b: Array = pt.call(i + 1, j)
			var d: Array = pt.call(i + 1, j + 1)
			var e: Array = pt.call(i, j + 1)
			quad(m, a[0], b[0], d[0], e[0], (a[0] + b[0] + d[0] + e[0]) / 4.0 - (a[1] + b[1]) / 2.0)


func mirror_x(f: Callable) -> void:
	f.call(1.0)
	f.call(-1.0)


# ---------- Silahlar ----------

func _pistol() -> void:
	ext("dark", [0.05, 0.0, 0.05, 0.05, -0.17, 0.05, -0.19, 0.032, -0.19, 0.0], -0.021, 0.021) # sürgü
	ext("steel", [0.045, 0.0, -0.15, 0.0, -0.15, -0.022, 0.045, -0.022], -0.019, 0.019) # gövde
	ext("wood", [0.045, -0.02, 0.0, -0.02, -0.015, -0.135, 0.035, -0.14, 0.058, -0.03], -0.022, 0.022) # kabza
	box("dark", Vector3(0, -0.138, 0.01), Vector3(0.046, 0.008, 0.052)) # şarjör tabanı
	box("steel", Vector3(0, -0.048, -0.04), Vector3(0.012, 0.006, 0.065)) # tetik korkuluğu
	box("steel", Vector3(0, -0.035, -0.072), Vector3(0.012, 0.03, 0.006))
	box("dark", Vector3(0, -0.033, -0.028), Vector3(0.006, 0.024, 0.006)) # tetik
	cyl("black", 0.009, 0.009, Vector3(0, 0.022, -0.189), Vector3(0, 0.022, -0.1915))
	box("dark", Vector3(0, 0.056, -0.172), Vector3(0.006, 0.012, 0.01)) # arpacık
	box("dark", Vector3(0, 0.056, 0.042), Vector3(0.022, 0.012, 0.01)) # gez
	box("dark", Vector3(0, 0.035, 0.058), Vector3(0.01, 0.022, 0.014)) # horoz
	for z in [0.012, 0.022, 0.032]: # sürgü tırtıkları
		box("steel", Vector3(0, 0.027, z), Vector3(0.0445, 0.036, 0.004))


func _shotgun() -> void:
	cyl("dark", 0.019, 0.019, Vector3(0, 0.03, 0.0), Vector3(0, 0.03, -0.66)) # namlu
	cyl("dark", 0.016, 0.016, Vector3(0, -0.008, -0.05), Vector3(0, -0.008, -0.56)) # şarjör borusu
	cyl("steel", 0.017, 0.017, Vector3(0, -0.008, -0.56), Vector3(0, -0.008, -0.575))
	ext("wood", [-0.20, 0.012, -0.44, 0.012, -0.45, -0.01, -0.43, -0.035, -0.21, -0.035, -0.19, -0.01], -0.03, 0.03) # pompa
	for z in [-0.25, -0.29, -0.33, -0.37, -0.41]:
		box("dark", Vector3(0, -0.012, z), Vector3(0.062, 0.03, 0.008))
	ext("dark", [0.12, 0.055, -0.02, 0.055, -0.05, 0.04, -0.05, -0.03, 0.12, -0.03], -0.027, 0.027) # mekanizma
	box("steel", Vector3(0.0275, 0.022, 0.035), Vector3(0.002, 0.022, 0.06)) # fişek çıkış
	ext("wood", [0.03, -0.03, 0.0, -0.12, 0.05, -0.12, 0.09, -0.05, 0.33, -0.10, 0.40, -0.10, 0.40, 0.03, 0.12, 0.045, 0.12, -0.03],
		-0.025, 0.025) # dipçik
	box("black", Vector3(0, -0.035, 0.406), Vector3(0.054, 0.135, 0.012))
	box("dark", Vector3(0, -0.06, -0.015), Vector3(0.012, 0.006, 0.06))
	box("dark", Vector3(0, -0.045, -0.044), Vector3(0.012, 0.03, 0.006))
	box("steel", Vector3(0, -0.043, -0.012), Vector3(0.006, 0.024, 0.006))
	sph("brass", Vector3(0, 0.052, -0.645), 0.006, 6, 4)
	for z in [-0.06, -0.085]: # yan fişekler
		cyl("red", 0.009, 0.009, Vector3(0.032, -0.0, z), Vector3(0.032, 0.03, z), 6)
		cyl("brass", 0.0095, 0.0095, Vector3(0.032, -0.008, z), Vector3(0.032, 0.0, z), 6)


func _smg() -> void:
	ext("dark", [0.10, 0.07, -0.20, 0.07, -0.23, 0.05, -0.23, -0.01, 0.10, -0.01], -0.028, 0.028) # gövde
	box("steel", Vector3(0, 0.077, -0.06), Vector3(0.02, 0.014, 0.22)) # ray
	cyl("steel", 0.022, 0.022, Vector3(0, 0.03, -0.23), Vector3(0, 0.03, -0.33)) # namlu kılıfı
	for z in [-0.255, -0.28, -0.305]:
		box("black", Vector3(0, 0.03, z), Vector3(0.046, 0.012, 0.012))
	cyl("dark", 0.013, 0.013, Vector3(0, 0.03, -0.33), Vector3(0, 0.03, -0.38))
	cyl("black", 0.007, 0.007, Vector3(0, 0.03, -0.38), Vector3(0, 0.03, -0.3815))
	ext("dark", [-0.065, -0.01, -0.115, -0.01, -0.135, -0.17, -0.085, -0.18], -0.016, 0.016) # şarjör
	ext("black", [0.0, -0.01, 0.045, -0.01, 0.06, -0.125, 0.015, -0.13], -0.02, 0.02) # kabza
	box("dark", Vector3(0, -0.042, -0.025), Vector3(0.012, 0.006, 0.05))
	box("steel", Vector3(0, -0.028, -0.012), Vector3(0.006, 0.022, 0.006))
	box("steel", Vector3(0, 0.05, 0.2), Vector3(0.012, 0.01, 0.2)) # tel dipçik
	box("steel", Vector3(0, 0.0, 0.21), Vector3(0.012, 0.01, 0.22))
	box("black", Vector3(0, 0.025, 0.315), Vector3(0.04, 0.09, 0.015))
	box("dark", Vector3(0, 0.09, -0.19), Vector3(0.014, 0.02, 0.01))
	box("dark", Vector3(0, 0.092, 0.07), Vector3(0.02, 0.016, 0.012))
	box("steel", Vector3(0.034, 0.05, -0.12), Vector3(0.012, 0.01, 0.02)) # kurma kolu


func _sniper() -> void:
	cyl("dark", 0.016, 0.012, Vector3(0, 0.04, -0.12), Vector3(0, 0.04, -0.8)) # namlu
	cyl("steel", 0.022, 0.022, Vector3(0, 0.04, -0.8), Vector3(0, 0.04, -0.87)) # namlu freni
	box("black", Vector3(0, 0.04, -0.835), Vector3(0.046, 0.012, 0.014))
	ext("olive", [-0.45, 0.025, 0.10, 0.025, 0.42, 0.045, 0.42, -0.11, 0.36, -0.11, 0.20, -0.055, 0.10, -0.055,
		0.07, -0.125, 0.02, -0.125, 0.03, -0.035, -0.43, -0.035], -0.03, 0.03) # kundak
	box("olive", Vector3(0, 0.06, 0.29), Vector3(0.05, 0.03, 0.17)) # yanak desteği
	box("black", Vector3(0, -0.032, 0.426), Vector3(0.062, 0.16, 0.012))
	ext("dark", [0.11, 0.07, -0.15, 0.07, -0.17, 0.055, -0.17, 0.025, 0.11, 0.025], -0.024, 0.024) # mekanizma
	cyl("steel", 0.006, 0.006, Vector3(0.024, 0.055, 0.06), Vector3(0.058, 0.04, 0.06), 6) # sürgü kolu
	sph("steel", Vector3(0.062, 0.038, 0.06), 0.012, 6, 4)
	cyl("dark", 0.02, 0.02, Vector3(0, 0.115, -0.18), Vector3(0, 0.115, 0.08)) # dürbün
	cyl("dark", 0.02, 0.03, Vector3(0, 0.115, -0.18), Vector3(0, 0.115, -0.26))
	cyl("glass", 0.027, 0.027, Vector3(0, 0.115, -0.26), Vector3(0, 0.115, -0.262))
	cyl("dark", 0.02, 0.026, Vector3(0, 0.115, 0.08), Vector3(0, 0.115, 0.13))
	cyl("glass", 0.023, 0.023, Vector3(0, 0.115, 0.13), Vector3(0, 0.115, 0.132))
	cyl("steel", 0.012, 0.012, Vector3(0, 0.13, -0.05), Vector3(0, 0.15, -0.05), 6)
	cyl("steel", 0.012, 0.012, Vector3(0.015, 0.115, -0.05), Vector3(0.035, 0.115, -0.05), 6)
	box("dark", Vector3(0, 0.085, -0.12), Vector3(0.02, 0.03, 0.02))
	box("dark", Vector3(0, 0.085, 0.04), Vector3(0.02, 0.03, 0.02))
	mirror_x(func(s): cyl("dark", 0.006, 0.006, Vector3(0.02 * s, -0.04, -0.4), Vector3(0.02 * s, -0.04, -0.62), 6)) # katlı çatal ayak
	box("dark", Vector3(0, -0.065, 0.005), Vector3(0.012, 0.006, 0.06))
	box("steel", Vector3(0, -0.048, 0.015), Vector3(0.006, 0.024, 0.006))


func _bow() -> void:
	var limb := []
	var inner := []
	for i in 13:
		var t := -1.0 + i / 6.0
		var z := -0.25 + 0.1 * t * t # uçlar oyuncuya doğru kıvrılır
		var th := 0.022 * (1.0 - 0.5 * absf(t))
		limb.append_array([z - th, 0.46 * t])
		inner.push_front(0.46 * t)
		inner.push_front(z + th)
	ext("wood", limb + inner, -0.014, 0.014)
	box("leather", Vector3(0, 0, -0.25), Vector3(0.034, 0.11, 0.06)) # kabza sargısı
	mirror_x(func(s): sph("dark", Vector3(0, 0.46 * s, -0.15), 0.012, 6, 4))
	box("string", Vector3(0, 0, -0.139), Vector3(0.003, 0.92, 0.003)) # kiriş
	cyl("birch", 0.0045, 0.0045, Vector3(0.02, 0, -0.13), Vector3(0.02, 0, -0.72), 6) # ok
	cyl("steel", 0.013, 0.0, Vector3(0.02, 0, -0.72), Vector3(0.02, 0, -0.78), 4)
	box("red", Vector3(0.02, 0.012, -0.18), Vector3(0.002, 0.016, 0.06)) # tüyler
	box("red", Vector3(0.02, -0.012, -0.18), Vector3(0.002, 0.016, 0.06))
	box("red", Vector3(0.032, 0, -0.18), Vector3(0.016, 0.002, 0.06))


func _boomerang() -> void:
	# Üstten görünüş: u = X, v = Z, kalınlık Y.
	var top := func(m: String, uv: Array, w0: float, w1: float): ext(m, uv, w0, w1, Vector3.RIGHT, Vector3.BACK, Vector3.UP)
	top.call("wood", [0.0, -0.37, 0.24, -0.14, 0.235, -0.105, 0.205, -0.095, 0.0, -0.28, -0.205, -0.095, -0.235, -0.105, -0.24, -0.14],
		-0.011, 0.011)
	for s in [-1.0, 1.0]:
		for b in [[0.35, 0.42], [0.52, 0.59]]: # kanat şeritleri
			var o0 := Vector2(0.24 * b[0] * s, -0.37 + 0.23 * b[0])
			var o1 := Vector2(0.24 * b[1] * s, -0.37 + 0.23 * b[1])
			var i1 := Vector2(0.205 * b[1] * s, -0.28 + 0.185 * b[1])
			var i0 := Vector2(0.205 * b[0] * s, -0.28 + 0.185 * b[0])
			top.call("yellow", [o0.x, o0.y, o1.x, o1.y, i1.x, i1.y, i0.x, i0.y], 0.011, 0.0125)


func _flame() -> void:
	cyl("dark", 0.02, 0.02, Vector3(0, 0, 0.06), Vector3(0, 0, -0.55)) # boru
	cyl("steel", 0.034, 0.034, Vector3(0, 0, -0.24), Vector3(0, 0, -0.5)) # ısı kalkanı
	for z in [-0.28, -0.33, -0.38, -0.43]:
		box("black", Vector3(0, 0.032, z), Vector3(0.03, 0.006, 0.012))
	cyl("brass", 0.026, 0.04, Vector3(0, 0, -0.55), Vector3(0, 0, -0.62)) # meme
	cyl("black", 0.03, 0.03, Vector3(0, 0, -0.62), Vector3(0, 0, -0.6215))
	cyl("steel", 0.007, 0.007, Vector3(0, -0.045, -0.45), Vector3(0, -0.045, -0.6), 6) # pilot alev
	sph("blue", Vector3(0, -0.045, -0.605), 0.009, 6, 4)
	box("dark", Vector3(0, -0.028, -0.47), Vector3(0.012, 0.03, 0.012))
	cyl("red", 0.05, 0.05, Vector3(0, -0.085, -0.06), Vector3(0, -0.085, -0.32)) # yakıt tankı
	cyl("red", 0.05, 0.025, Vector3(0, -0.085, -0.32), Vector3(0, -0.085, -0.35))
	cyl("red", 0.05, 0.025, Vector3(0, -0.085, -0.06), Vector3(0, -0.085, -0.03))
	for z in [-0.12, -0.26]:
		cyl("dark", 0.053, 0.053, Vector3(0, -0.085, z + 0.008), Vector3(0, -0.085, z - 0.008))
	cyl("dark", 0.008, 0.008, Vector3(0, -0.04, -0.2), Vector3(0, -0.015, -0.2), 6)
	cyl("steel", 0.018, 0.018, Vector3(0.045, -0.085, -0.19), Vector3(0.06, -0.085, -0.19)) # basınç saati
	cyl("string", 0.014, 0.014, Vector3(0.06, -0.085, -0.19), Vector3(0.0605, -0.085, -0.19))
	ext("dark", [0.12, 0.03, 0.0, 0.03, 0.0, -0.025, 0.12, -0.025], -0.028, 0.028) # arka gövde
	ext("black", [0.0, -0.02, 0.045, -0.02, 0.06, -0.13, 0.015, -0.135], -0.02, 0.02) # kabza
	box("dark", Vector3(0, -0.055, -0.02), Vector3(0.012, 0.006, 0.05))
	box("steel", Vector3(0, -0.038, -0.01), Vector3(0.006, 0.024, 0.006))


func _grenade() -> void:
	var c := Vector3(0, 0, -0.15)
	sph("olive", c, 0.055, 8, 6, 1.15) # gövde
	cyl("dark", 0.0565, 0.0565, c + Vector3(0, -0.005, 0), c + Vector3(0, 0.005, 0))
	cyl("steel", 0.02, 0.017, c + Vector3(0, 0.058, 0), c + Vector3(0, 0.085, 0)) # tapa
	cyl("dark", 0.012, 0.012, c + Vector3(0, 0.085, 0), c + Vector3(0, 0.095, 0))
	box("steel", c + Vector3(0, 0.075, 0.03), Vector3(0.016, 0.006, 0.045)) # mandal
	box("steel", c + Vector3(0, 0.035, 0.062), Vector3(0.016, 0.075, 0.006))
	torus("steel", c + Vector3(0.032, 0.078, 0), Vector3.RIGHT, 0.016, 0.0025) # pim halkası
