extends Node3D
## Açık dünya prototipi: 1 x 1 km, 64 m'lik chunk'lar, sabit tohum (her makinede aynı harita).
## Biyomlar iki gürültüden yumuşak ağırlıkla çıkar; chunk'lar oyuncuların çevresinde kare başına bir tane kurulur.
## Saf fonksiyonlar (height, weights, biome_at, spawns) ağaca eklenmeden de çalışır: testler bunları kullanır.

const ForestScript := preload("res://forest.gd")
const ChickenScript := preload("res://chicken.gd")
const CritterScript := preload("res://critter.gd")
const SEED := 4242
const HALF := 512.0
const CHUNK := 64.0
const CELLS := 32 # chunk başına ızgara: 2 m'lik kareler
const NAMES := ["cursed_forest", "swamp", "ash_mountains", "ruins"]
# Görünüm forest.gd'nin (kule savunması) zemin/ağaç/kaya/gök stilidir; biyomlar onun tonlamasıdır.
# Zemin tonu: rgb çarpan, a doygunluk (ground.gdshader köşe rengi).
const GROUND := [Color(0.62, 0.48, 0.8, 0.5), Color(0.72, 0.8, 0.68, 0.45), Color(1.55, 0.95, 0.72, 0.0), Color(1.05, 1.0, 0.85, 0.8)]
# Yaprak: forest rengini bu renge doğru çeker (a = miktar).
const LEAF := [Color(0.2, 0.06, 0.24, 0.6), Color(0.24, 0.26, 0.18, 0.55), Color(0.2, 0.2, 0.2, 1.0), Color(0, 0, 0, 0.0)]
const FOG := [Color(0.5, 0.36, 0.62), Color(0.56, 0.62, 0.52), Color(0.8, 0.5, 0.36), Color(0.82, 0.74, 0.62)]
const FOG_DENSITY := [0.011, 0.01, 0.008, 0.005]
const SUN := [Color(0.82, 0.66, 0.9), Color(0.82, 0.9, 0.78), Color(1.0, 0.62, 0.42), Color(1.0, 0.84, 0.64)]
const RADIUS := [2, 3, 4] # Settings.quality -> yüklü chunk yarıçapı
const VIS := [90.0, 140.0, 200.0] # dekor görünürlük mesafesi
const GRASS_VIS := [30.0, 45.0, 60.0]
const GRASS_N := [2500, 4000, 6000] # chunk başına çimen denemesi (görsel; çarpışmayı etkilemez)
# Gök ortam ışığı payı ve yerine gelen renk: kül dağında morumsu gök, kızıl-gri zemini maviye boyamasın.
const FILL := [Color(0.6, 0.72, 1.0), Color(0.6, 0.72, 1.0), Color(1.0, 0.55, 0.4), Color(0.6, 0.72, 1.0)] # dolgu ışığı rengi
const SKY_AMB := [1.0, 1.0, 0.15, 1.0]
const AMB_COL := [Color(0.45, 0.32, 0.55), Color(0.4, 0.45, 0.38), Color(0.7, 0.4, 0.28), Color(0.6, 0.52, 0.42)]
const HILL := [Color(0.13, 0.07, 0.17), Color(0.12, 0.16, 0.1), Color(0.24, 0.12, 0.08), Color(0.15, 0.18, 0.1)]
const ROADS := 6 # merkezden dışarı kıvrılan toprak yol sayısı
const SMALL := ["grass", "stem", "cap", "glow", "fstem", "fhead", "lily"] # kısa mesafede görünür, gölgesiz
const MAX_FAUNA := 4 # chunk başına en çok hayvan
const FAUNA := [["deer", "rabbit"], ["frog", "frog"], ["crow", "lizard"], ["chicken", "cat"]] # biyom -> türler
const FAR_N := 20 # uzak zemin ızgarası: FAR_N x FAR_N kare, kenarı CHUNK

var players: Node # main.gd verir; boşsa kamera ya da merkez izlenir
var chunks := {} # Vector2i -> Node3D
var build_ms := 0.0 # son kurulum adımının süresi (test/profil)
var stage_ms := {} # adım -> en uzun süre (ms): far, decor, flora, build
var _hn := FastNoiseLite.new()
var _bn := FastNoiseLite.new()
var _f: Node3D # forest.gd örneği (ağaca eklenmez): ağ üreticileri, ağaç yerleşimi, malzemeler
var _water := StandardMaterial3D.new()
var _meshes := {}
var _mats := {}
var _ground_mat: ShaderMaterial
var _pending := [] # zemini kurulmuş, dekoru sonraki karede gelecek chunk'lar: kare başı süre bölünür
var _env: Environment
var _sun: DirectionalLight3D
var _fill: DirectionalLight3D # forest.gd soğuk dolgu ışığı: kül dağında sıcağa döner
var _biome := -1
var _amb := [[], [], [], []] # biyom -> parçacık katmanları (kamerayla gezer)
var _amb_w := PackedFloat32Array([0, 0, 0, 0])
var _hills := MultiMesh.new() # ufuk tepeleri: kamerayla gezer, biyom renginde sise karışır
var _hills_mi: MultiMeshInstance3D
var _far: MeshInstance3D # yüklenmemiş chunk'ların ve dünya dışının kaba zemini
var _far_cell := Vector2i(1 << 20, 0)
var _tree_list := [] # _decor sırasında kurulan ağaçlar: [yerel konum, ölçek, biyom] (mantarlar dibine)


func _init() -> void:
	_hn.seed = SEED
	_hn.frequency = 0.006
	_hn.fractal_octaves = 4
	_bn.seed = SEED + 1
	_bn.frequency = 0.004
	_bn.fractal_octaves = 2


## Biyom ağırlıkları (toplam 1): [Lanetli Orman, Sis Bataklığı, Kül Dağları, Yıkık Krallık].
func weights(x: float, z: float) -> PackedFloat32Array:
	var a := _bn.get_noise_2d(x, z)
	var b := _bn.get_noise_2d(x + 5000.0, z - 3000.0)
	var w := PackedFloat32Array([exp(12.0 * (-a - b)), exp(12.0 * (-a + b)), exp(12.0 * (a + b)), exp(12.0 * (a - b))])
	var s := w[0] + w[1] + w[2] + w[3]
	for i in 4:
		w[i] /= s
	return w


func biome_at(x: float, z: float) -> int:
	var w := weights(x, z)
	var best := 0
	for i in 4:
		if w[i] > w[best]:
			best = i
	return best


func height(x: float, z: float, w := PackedFloat32Array()) -> float:
	if w.is_empty():
		w = weights(x, z)
	var n := _hn.get_noise_2d(x, z)
	var ridge := 1.0 - absf(n)
	var h := w[0] * (2.0 + 6.0 * n) + w[1] * (-0.8 + 1.4 * n) + w[2] * (4.0 + 40.0 * ridge * ridge) + w[3] * (1.5 + 3.0 * n)
	return lerpf(1.5, h, smoothstep(24.0, 80.0, Vector2(x, z).length())) # merkez düz: doğma alanı


## i. yolun r yarıçapındaki açısı: düz ışın, iki sinüsle kıvrılır (gürültüsüz, ucuz ve deterministik).
func road_angle(i: int, r: float) -> float:
	return TAU * i / ROADS + 0.42 * sin(r * 0.011 + i * 2.3) + 0.18 * sin(r * 0.037 + i * 5.1)


## En yakın toprak yola (ya da merkezdeki meydana) uzaklık, metre.
func path_dist(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var best := maxf(r - 7.0, 0.0) # doğma alanı: toprak meydan
	var a := atan2(z, x)
	for i in ROADS:
		var d := absf(wrapf(a - road_angle(i, r), -PI, PI))
		if d < 0.9: # uzak yolu hesaplama
			best = minf(best, d * r)
	return best


## Zemindeki toprak oranı (0..1): yolun ortasında 1, 1.3-2.8 m arasında söner.
func path_at(x: float, z: float) -> float:
	return 1.0 - smoothstep(1.3, 2.8, path_dist(x, z))


## Merkezdeki düzlükte dört doğma noktası (zeminin 1 m üstü).
func spawns() -> Array:
	var out := []
	for p in [Vector2(-3, -3), Vector2(3, 3), Vector2(-3, 3), Vector2(3, -3)]:
		out.append(Vector3(p.x, height(p.x, p.y) + 1.0, p.y))
	return out


func _ready() -> void:
	_water.albedo_color = Color(0.1, 0.15, 0.11, 0.78)
	_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water.roughness = 0.04
	_make_meshes()
	_horizon()
	_particles()
	_environment()
	for s in [[Vector3(0, 0, -HALF), Vector3(HALF * 2, 800, 2)], [Vector3(0, 0, HALF), Vector3(HALF * 2, 800, 2)],
			[Vector3(-HALF, 0, 0), Vector3(2, 800, HALF * 2)], [Vector3(HALF, 0, 0), Vector3(2, 800, HALF * 2)]]:
		var b := StaticBody3D.new() # görünmez sınır
		b.position = s[0]
		var cs := CollisionShape3D.new()
		cs.shape = BoxShape3D.new()
		cs.shape.size = s[1]
		b.add_child(cs)
		add_child(b)
	for dx in range(-1, 1): # doğma alanı ilk karede hazır olsun: oyuncu boşluğa düşmesin
		for dz in range(-1, 1):
			_build(Vector2i(dx, dz))
			_mesh(chunks[Vector2i(dx, dz)])
			_pending[-1] = [Vector2i(dx, dz), 1]


func _process(dt: float) -> void:
	var r: int = RADIUS[Settings.quality]
	var centers := _centers()
	var best := Vector2i(999, 999)
	var best_d := INF
	for k in chunks.keys(): # bir halka fazlası tutulur: sınırda gidip gelince sürekli kurulmasın
		if _dist(k, centers) > (r + 1) * CHUNK:
			_pending = _pending.filter(func(e: Array) -> bool: return e[0] != k)
			chunks[k].queue_free()
			chunks.erase(k)
	for c in centers:
		var ci := Vector2i(floori(c.x / CHUNK), floori(c.z / CHUNK))
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var k := ci + Vector2i(dx, dz)
				if chunks.has(k) or not _valid(k):
					continue
				var d := _dist(k, centers)
				if d <= r * CHUNK and d < best_d:
					best_d = d
					best = k
	for k in chunks: # uzak hayvanlar düşünmez: yalnızca yakındakiler kare başı işlenir
		var fa: Node = chunks[k].get_node_or_null("Fauna")
		if fa:
			fa.process_mode = Node.PROCESS_MODE_INHERIT if _dist(k, centers) < 110.0 else Node.PROCESS_MODE_DISABLED
	# Kare başına tek iş: uzak zemin, dekor, bitki/hayvan ya da yeni chunk zemini (kurulum kareye bölünür).
	var cam := _cam_pos()
	var cell := Vector2i(floori(cam.x / CHUNK), floori(cam.z / CHUNK))
	var t0 := Time.get_ticks_usec()
	if cell != _far_cell:
		_far_cell = cell
		_far_ground(cell)
		_took("far", t0)
	elif not _pending.is_empty():
		var e: Array = _pending.pop_front()
		var pk: Vector2i = e[0]
		if chunks.has(pk):
			if e[1] == 0:
				_mesh(chunks[pk])
				_pending.append([pk, 1])
				_took("mesh", t0)
			elif e[1] == 1:
				_decor(pk, chunks[pk], chunks[pk].get_node("Body"))
				_pending.append([pk, 2])
				_took("decor", t0)
			elif e[1] == 2:
				var grng := RandomNumberGenerator.new()
				grng.seed = chunks[pk].get_meta("grass_seed")
				var items: Dictionary = chunks[pk].get_meta("items")
				_grass(items, chunks[pk], grng)
				_add_items(chunks[pk], items)
				chunks[pk].remove_meta("items")
				_pending.append([pk, 3])
				_took("items", t0)
			else:
				_flora(pk, chunks[pk])
				_fauna_spawn(pk, chunks[pk])
				chunks[pk].set_meta("done", true)
				_took("flora", t0)
	elif best_d < INF:
		_build(best)
	_update_env(dt)


func _took(stage: String, t0: int) -> void:
	build_ms = (Time.get_ticks_usec() - t0) / 1000.0
	stage_ms[stage] = maxf(stage_ms.get(stage, 0.0), build_ms)


func _valid(k: Vector2i) -> bool:
	var n := int(HALF / CHUNK)
	return k.x >= -n and k.x < n and k.y >= -n and k.y < n


func _dist(k: Vector2i, centers: Array) -> float:
	var mid := (Vector2(k) + Vector2(0.5, 0.5)) * CHUNK
	var d := INF
	for c in centers:
		d = minf(d, mid.distance_to(Vector2(c.x, c.z)))
	return d


func _centers() -> Array:
	var out := []
	if players:
		for p in players.get_children():
			if p is Node3D:
				out.append(p.global_position)
	if out.is_empty():
		var cam := get_viewport().get_camera_3d()
		out.append(cam.global_position if cam else Vector3.ZERO)
	return out


# ---------- Chunk ----------

func _build(k: Vector2i) -> void:
	var t0 := Time.get_ticks_usec()
	var node := Node3D.new()
	node.name = "C%d_%d" % [k.x, k.y]
	node.position = Vector3(k.x, 0, k.y) * CHUNK
	var ox := k.x * CHUNK
	var oz := k.y * CHUNK
	var step := CHUNK / CELLS
	var hs := PackedFloat32Array()
	var cols := PackedColorArray()
	var ps := PackedFloat32Array() # toprak yol oranı (UV2.x -> ground.gdshader)
	var ws := []
	var lo := INF
	for j in CELLS + 1:
		for i in CELLS + 1:
			var x := ox + i * step
			var z := oz + j * step
			var w := weights(x, z)
			var c := Color(0, 0, 0, 0)
			for b in 4:
				c += GROUND[b] * w[b]
			var h := height(x, z, w)
			hs.append(h)
			ps.append(path_at(x, z))
			cols.append(c)
			ws.append(w)
			lo = minf(lo, h)
	node.set_meta("hs", hs)
	node.set_meta("ps", ps)
	node.set_meta("ws", ws)
	node.set_meta("cols", cols)
	node.set_meta("lo", lo)
	add_child(node)
	_pending.append([k, 0])
	chunks[k] = node
	_took("build", t0)


## Zemin ağı, çarpışma ve su: örnekleme bir önceki karede yapıldı (kurulum kareye bölünür).
func _mesh(node: Node3D) -> void:
	var step := CHUNK / CELLS
	var hs: PackedFloat32Array = node.get_meta("hs")
	var ps: PackedFloat32Array = node.get_meta("ps")
	var cols: PackedColorArray = node.get_meta("cols")
	var lo: float = node.get_meta("lo")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in CELLS:
		for i in CELLS:
			for q in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var id: int = (j + q.y) * (CELLS + 1) + i + q.x
				st.set_color(cols[id])
				st.set_uv2(Vector2(ps[id], 0))
				st.add_vertex(Vector3((i + q.x) * step, hs[id], (j + q.y) * step))
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _ground_mat
	node.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "Body"
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	node.add_child(body)
	if lo < 0.0: # bataklık: sığ su
		var wm := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(CHUNK, CHUNK)
		wm.mesh = pm
		wm.position = Vector3(CHUNK * 0.5, 0.0, CHUNK * 0.5)
		wm.material_override = _water
		wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(wm)


## Biyoma göre dekor: aynı chunk her makinede aynı tohumla aynı çıkar. Büyük parçalar çarpışır.
## Ağaçlar forest.gd'nin _tree'siyle kurulur (çarpışmasız çağrılır; gövde silindiri burada eklenir).
func _decor(k: Vector2i, node: Node3D, body: StaticBody3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED ^ (k.x * 73856093) ^ (k.y * 19349663)
	_f._vis.seed = rng.seed
	_tree_list = []
	var items := {}
	for key in _meshes:
		items[key] = []
	for n in 110:
		var lp := Vector3(rng.randf() * CHUNK, 0, rng.randf() * CHUNK)
		var wx := node.position.x + lp.x
		var wz := node.position.z + lp.z
		if Vector2(wx, wz).length() < 14.0 or path_dist(wx, wz) < 4.0: # doğma alanı ve yollar boş
			continue
		var b := biome_at(wx, wz)
		lp.y = height(wx, wz)
		var rot := Basis(Vector3.UP, rng.randf() * TAU)
		var s := rng.randf_range(0.8, 1.3)
		match b:
			0: # sık, koyu-morumsu orman
				if n % 3 != 2:
					_tree(items, body, lp, s, rng, b)
				else:
					_bush(items, lp, rng, b)
			1: # sazlık, seyrek solgun ağaç
				if lp.y < 0.4:
					for c in 4:
						var o := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
						items.reed.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1, rng.randf_range(1.2, 2.2), 1)), lp + o), Color(0.36, 0.38, 0.2)])
				elif n % 6 == 0:
					_tree(items, body, lp, s * 0.8, rng, b)
				elif n % 3 == 0:
					_bush(items, lp, rng, b)
			2: # kül dağı: yosunsuz gri/kızıl forest kayaları, seyrek kuru ağaç
				if n % 2 == 0:
					var r := rng.randf_range(0.8, 3.5)
					items.ash.append([Transform3D(rot.scaled(Vector3(r, r * rng.randf_range(0.6, 0.9), r)), lp - Vector3(0, r * 0.2, 0)),
						Color(0.34, 0.32, 0.31).lerp(Color(0.5, 0.2, 0.13), rng.randf() * 0.7)])
					if r > 2.0:
						_shape(body, SphereShape3D.new(), lp, Vector3(r * 0.75, 0, 0))
				elif n % 9 == 1:
					items.trunk.append([Transform3D(rot.scaled(Vector3(0.7 * s, 6.0 * s, 0.7 * s)), lp), Color(0.32, 0.3, 0.3)])
					_shape(body, CylinderShape3D.new(), lp + Vector3(0, 3.0 * s, 0), Vector3(0.4 * s, 6.0 * s, 0))
			3: # kalıntı: forest duvarı gibi örülmüş taş, payanda, sarmaşık; arada forest ağaçları
				if n % 4 == 0:
					var sz := Vector3(rng.randf_range(3, 7), rng.randf_range(1, 3.5), 1.0)
					var c := lp + Vector3(0, sz.y * 0.5 - 0.3, 0)
					items.wall.append([Transform3D(rot.scaled(sz), c), Color(1, 1, 1)])
					_shape(body, BoxShape3D.new(), c, sz, rot)
					for v in 2: # tepede sarmaşık, dipte çalı
						var r := rng.randf_range(0.6, 1.0)
						var q := lp + rot * Vector3(rng.randf_range(-0.4, 0.4) * sz.x, sz.y - 0.4 if v == 0 else r * 0.3, 0.0 if v == 0 else 0.7)
						items.blob.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(r * 1.3, r * (0.5 if v == 0 else 0.75), r * 1.3)), q),
							Color(0.06, 0.2, 0.05).lerp(Color(0.16, 0.3, 0.06), rng.randf())])
				elif n % 4 == 1:
					var ph := rng.randf_range(1.5, 3.7)
					var c := lp + Vector3(0, ph * 0.5 - 0.2, 0)
					items.pillar.append([Transform3D(rot.scaled(Vector3(1.5, ph, 1.5)), c), Color(1.2, 1.17, 1.1)])
					_shape(body, BoxShape3D.new(), c, Vector3(1.5, ph, 1.5), rot)
				elif n % 4 == 2:
					_tree(items, body, lp, s, rng, b)
				else:
					var r := rng.randf_range(0.4, 1.0)
					items.rock.append([Transform3D(rot.scaled(Vector3(r, r * 0.7, r)), lp), _f._rock_cols[n % 3]])
	node.set_meta("trees", _tree_list)
	node.set_meta("items", items)
	node.set_meta("grass_seed", rng.seed + 1)


func _add_items(node: Node3D, items: Dictionary) -> void:
	var vis: float = VIS[Settings.quality]
	for key in items:
		if items[key].is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _meshes[key]
		mm.instance_count = items[key].size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, items[key][i][0])
			mm.set_instance_color(i, items[key][i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _mats[key]
		mmi.visibility_range_end = GRASS_VIS[Settings.quality] if key in SMALL else vis
		mmi.visibility_range_end_margin = 10.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if key in ["reed", "grass", "rock"] or key in SMALL:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mmi)


## forest.gd ağacı; yaprak ve gövde biyoma göre tonlanır.
func _tree(items: Dictionary, body: StaticBody3D, lp: Vector3, s: float, rng: RandomNumberGenerator, b: int) -> void:
	_f._tree(lp, s, rng, false)
	_tree_list.append([lp, s, b])
	var leaf: Color = LEAF[b]
	for src in [[_f._blobs, items.blob], [_f._cones, items.cone]]:
		for it in src[0]:
			var c: Color = it[1]
			it[1] = c.lerp(Color(leaf.r, leaf.g, leaf.b), leaf.a)
			src[1].append(it)
		src[0].clear()
	for it in _f._trunks:
		it[1] = it[1] * (0.55 if b == 0 else 1.0)
		items.trunk.append(it)
	_f._trunks.clear()
	_shape(body, CylinderShape3D.new(), lp + Vector3(0, 3.5 * s, 0), Vector3(0.5 * s, 7.0 * s, 0))


func _bush(items: Dictionary, lp: Vector3, rng: RandomNumberGenerator, b: int) -> void:
	var r := rng.randf_range(0.55, 1.0)
	var leaf: Color = LEAF[b]
	items.blob.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(r, r * 0.75, r)), lp + Vector3(0, r * 0.3, 0)),
		Color(0.06, 0.2, 0.05).lerp(Color(0.16, 0.3, 0.06), rng.randf()).lerp(Color(leaf.r, leaf.g, leaf.b), leaf.a)])


## Forest çimeni: yükseklik zemin ızgarasının en yakın köşesinden (ucuz); su altında ve kül dağında yok.
func _grass(items: Dictionary, node: Node3D, rng: RandomNumberGenerator) -> void:
	var hs: PackedFloat32Array = node.get_meta("hs")
	var ps: PackedFloat32Array = node.get_meta("ps")
	var ws: Array = node.get_meta("ws")
	var step := CHUNK / CELLS
	var tints := [Color(0.85, 0.62, 1.0), Color(0.78, 0.86, 0.66), Color(1, 1, 1), Color(1.0, 1.0, 0.9)]
	for n in GRASS_N[Settings.quality]:
		var x := rng.randf() * CHUNK
		var z := rng.randf() * CHUNK
		var id := roundi(z / step) * (CELLS + 1) + roundi(x / step)
		var w: PackedFloat32Array = ws[id]
		if hs[id] < 0.15 or ps[id] > 0.2 or rng.randf() < w[2] * 1.3:
			continue
		var h := rng.randf_range(0.5, 1.1)
		var sw := rng.randf_range(0.8, 1.4)
		var c := Color(0, 0, 0)
		for b in 4:
			c += tints[b] * w[b]
		items.grass.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sw, h, sw)), Vector3(x, hs[id] - 0.05, z)),
			c * Color(0.9, 0.95, 0.85).lerp(Color(1.15, 1.1, 0.8), rng.randf())])


## Mantar, çiçek, nilüfer, diken: biyoma göre. Dekordan ayrı tohum (çarpışan dekorun sırası değişmesin).
func _flora(k: Vector2i, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = (SEED * 31) ^ (k.x * 83492791) ^ (k.y * 29712151)
	var items := {"stem": [], "cap": [], "glow": [], "fstem": [], "fhead": [], "lily": [], "reed": []}
	for t in node.get_meta("trees"):
		if t[2] == 0 and rng.randf() < 0.7: # lanetli orman: parlayan mor mantar
			_f._mushrooms(items.stem, items.glow, t[0], t[1], Color(1.7, 0.45, 2.6), Color(0.7, 0.62, 0.75), rng)
		elif t[2] == 1 and rng.randf() < 0.6: # bataklık: soluk beyaz mantar
			_f._mushrooms(items.stem, items.cap, t[0], t[1], Color(0.9, 0.88, 0.82), Color(0.82, 0.82, 0.78), rng)
	for n in 48:
		var lp := Vector3(rng.randf() * CHUNK, 0, rng.randf() * CHUNK)
		var wx := node.position.x + lp.x
		var wz := node.position.z + lp.z
		if Vector2(wx, wz).length() < 10.0 or path_dist(wx, wz) < 2.5:
			continue
		lp.y = height(wx, wz)
		match biome_at(wx, wz):
			1: # nilüfer: su yüzünde yaprak, kimine pembe/beyaz çiçek
				if lp.y < -0.15:
					var r := rng.randf_range(0.35, 0.7)
					items.lily.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(r, 1, r)), Vector3(lp.x, 0.015, lp.z)),
						Color(0.16, 0.3, 0.1).lerp(Color(0.3, 0.38, 0.12), rng.randf())])
					if rng.randf() < 0.4:
						items.fhead.append([Transform3D(Basis(), Vector3(lp.x, -0.27, lp.z)), [Color(1.0, 0.75, 0.85), Color(0.97, 0.95, 0.92)][rng.randi() % 2]])
			2: # kül dağı: kızıl kuru diken öbeği
				if n % 3 == 0:
					for c in 5:
						var tilt := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(0.2, 0.7))
						var hh := rng.randf_range(0.5, 1.2)
						items.reed.append([Transform3D(tilt.scaled(Vector3(0.8, hh, 0.8)), lp - Vector3(0, 0.05, 0)),
							Color(0.4, 0.09, 0.05).lerp(Color(0.22, 0.12, 0.1), rng.randf())])
			3: # kalıntı: forest'taki gibi tek renkli çiçek öbekleri
				if n % 4 == 0:
					var col: Color = ForestScript.FLOWER_COLS[rng.randi() % ForestScript.FLOWER_COLS.size()]
					for c in 12:
						var q := lp + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5))
						if q.x < 0.0 or q.z < 0.0 or q.x > CHUNK or q.z > CHUNK:
							continue
						q.y = height(node.position.x + q.x, node.position.z + q.z) - 0.02
						items.fstem.append([Transform3D(Basis(), q), Color(0.1, 0.25, 0.06)])
						items.fhead.append([Transform3D(Basis(), q), col])
	_add_items(node, items)


## Chunk'ın hayvanları (saf, ağaca dokunmaz): [[tür, yerel konum, tohum, civciv mi], ...].
## Yalnızca tohumdan çıkar: her makinede aynı yerde, aynı adla doğar; ağ trafiği yok.
func fauna(k: Vector2i) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = (SEED * 977) ^ (k.x * 49979687) ^ (k.y * 15485863)
	var out := []
	for g in rng.randi_range(0, 2): # 0-2 sürü
		var lp := Vector3(rng.randf_range(6, CHUNK - 6), 0, rng.randf_range(6, CHUNK - 6))
		var wx := k.x * CHUNK + lp.x
		var wz := k.y * CHUNK + lp.z
		var b := biome_at(wx, wz)
		var kind: String = FAUNA[b][rng.randi() % 2]
		var n: int = {"deer": rng.randi_range(1, 2), "rabbit": rng.randi_range(1, 3), "frog": rng.randi_range(2, 3),
			"crow": rng.randi_range(1, 3), "lizard": 1, "chicken": rng.randi_range(1, 3), "cat": 1}[kind]
		if Vector2(wx, wz).length() < 16.0 or (height(wx, wz) < 0.1 and kind != "frog"):
			continue
		for j in n:
			if out.size() >= MAX_FAUNA:
				return out
			var q := lp + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))
			out.append([kind, q, rng.randi(), kind == "chicken" and j > 0])
	return out


func _fauna_spawn(k: Vector2i, node: Node3D) -> void:
	var list := fauna(k)
	if list.is_empty():
		return
	var holder := Node3D.new()
	holder.name = "Fauna"
	node.add_child(holder)
	var ox := node.position.x
	var oz := node.position.z
	for i in list.size():
		var a: Array = list[i]
		var c: Node3D = ChickenScript.new() if a[0] == "chicken" else CritterScript.new()
		if a[0] != "chicken":
			c.kind = a[0]
		c.name = "A%d_%d_%d" % [k.x, k.y, i] # sabit ad: vurulunca ölüm ağda adla eşitlenir (player.chicken_die)
		c.chick = a[3]
		c.rng.seed = a[2]
		c.bounds = Rect2(1, 1, CHUNK - 2, CHUNK - 2)
		c.keep_out = 0.0
		c.ground = func(x: float, z: float) -> float: return height(x + ox, z + oz)
		c.vis_end = 70.0
		c.position = Vector3(a[1].x, height(ox + a[1].x, oz + a[1].z), a[1].z)
		holder.add_child(c)


## size: kutu için boyut; silindir için (yarıçap, boy); küre için (yarıçap). pos chunk'a göre yereldir.
func _shape(body: StaticBody3D, sh: Shape3D, pos: Vector3, size: Vector3, rot := Basis()) -> void:
	if sh is BoxShape3D:
		sh.size = size
	elif sh is CylinderShape3D:
		sh.radius = size.x
		sh.height = size.y
	elif sh is SphereShape3D:
		sh.radius = size.x
	var cs := CollisionShape3D.new()
	cs.shape = sh
	cs.transform = Transform3D(rot, pos)
	body.add_child(cs)


## Dekor ağları ve malzemeleri forest.gd'den (birim boyutta, ölçek örnekten gelir).
func _make_meshes() -> void:
	_f = ForestScript.new()
	_f._make_noise()
	# Maske yok (siyah): forest'taki ağaç altı gölge / toprak lekesi basılmaz.
	var mask := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGB8))
	_ground_mat = _f._smat("res://shaders/ground.gdshader", {"arena_half": 1.0e6, "mask_tex": mask, "uv2_dirt": true})
	var leaf: ShaderMaterial = _f._smat("res://shaders/foliage.gdshader")
	var wall: ShaderMaterial = _f._smat("res://shaders/stone.gdshader", ForestScript.WALL)
	var vc := StandardMaterial3D.new()
	vc.vertex_color_use_as_albedo = true
	vc.roughness = 1.0
	_meshes.trunk = _f._trunk_mesh()
	_mats.trunk = _f._smat("res://shaders/stone.gdshader", {"tint": ForestScript.BARK, "moss": 0.25, "streak": 1.0})
	_meshes.cone = _f._cone_mesh()
	_mats.cone = leaf
	_meshes.blob = _f._blob_mesh(10, 5, 0.3, 1.4)
	_mats.blob = leaf
	_meshes.rock = _f._blob_mesh(8, 4, 0.22, 1.7)
	_mats.rock = _f._smat("res://shaders/stone.gdshader", {"moss": 0.75})
	_meshes.ash = _f._blob_mesh(9, 4, 0.25, 1.3)
	_mats.ash = _f._smat("res://shaders/stone.gdshader", {"moss": 0.0})
	_meshes.grass = _f._grass_mesh()
	_mats.grass = _f._smat("res://shaders/grass.gdshader", {"mask_tex": mask, "tint_mix": 1.0, "top": 0.4})
	var reed := CylinderMesh.new()
	reed.top_radius = 0.0; reed.bottom_radius = 0.05; reed.height = 1.0
	reed.radial_segments = 4; reed.rings = 1
	_meshes.reed = _f._deform(reed, func(v: Vector3) -> Vector3: return v + Vector3(0, 0.5, 0))
	_mats.reed = vc
	_meshes.wall = _f._deform(BoxMesh.new(), func(v: Vector3) -> Vector3: # yıkık üst kenar
		return Vector3(v.x, v.y - (0.35 * absf(sin(v.x * 9.0)) if v.y > 0.0 else 0.0), v.z))
	_mats.wall = wall
	_meshes.pillar = BoxMesh.new()
	_mats.pillar = wall
	var mush: Array = _f._mushroom_meshes()
	_meshes.stem = mush[0]
	_mats.stem = vc
	_meshes.cap = mush[1]
	_mats.cap = vc
	_meshes.glow = mush[1]
	var glow := StandardMaterial3D.new() # 1'in üstündeki örnek rengi parlar (glow eşiği 1.4)
	glow.vertex_color_use_as_albedo = true
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats.glow = glow
	var fl: Array = _f._flower_meshes()
	var sway: ShaderMaterial = _f._smat("res://shaders/grass.gdshader", {"mask_tex": mask, "tint_mix": 0.0, "top": 0.35})
	_meshes.fstem = fl[0]
	_mats.fstem = sway
	_meshes.fhead = fl[1]
	_mats.fhead = sway
	var lily := CylinderMesh.new()
	lily.top_radius = 0.5; lily.bottom_radius = 0.5; lily.height = 0.02
	lily.radial_segments = 9; lily.rings = 1
	_meshes.lily = lily
	_mats.lily = vc


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _f:
		_f.free()


# ---------- Ortam ----------

func _environment() -> void:
	var r: Array = _f._environment(self) # forest.gd'nin gök, ışık, sis ve kalite ayarları
	_env = r[0]
	_sun = r[1]
	_fill = r[2]
	_update_env(100.0)


## Kameranın bulunduğu yerin biyom karışımına doğru sis ve güneş yumuşakça kayar.
func _update_env(dt: float) -> void:
	var p := _cam_pos()
	var w := weights(p.x, p.z)
	var fog := Color(0, 0, 0)
	var sun := Color(0, 0, 0)
	var dens := 0.0
	var amb := Color(0, 0, 0)
	var sky := 0.0
	for i in 4:
		fog += FOG[i] * w[i]
		sun += SUN[i] * w[i]
		dens += FOG_DENSITY[i] * w[i]
		amb += AMB_COL[i] * w[i]
		sky += SKY_AMB[i] * w[i]
	var t := 1.0 - exp(-dt * 0.8)
	_env.fog_light_color = _env.fog_light_color.lerp(fog, t)
	_env.fog_density = lerpf(_env.fog_density, dens, t)
	_env.ambient_light_color = _env.ambient_light_color.lerp(amb, t)
	_env.ambient_light_sky_contribution = lerpf(_env.ambient_light_sky_contribution, sky, t)
	_sun.light_color = _sun.light_color.lerp(sun, t)
	var fill := Color(0, 0, 0)
	for i in 4:
		fill += FILL[i] * w[i]
	_fill.light_color = _fill.light_color.lerp(fill, t)
	for i in 4: # biyom parçacıkları: ağırlığa göre yumuşak geçiş, kameranın çevresinde
		_amb_w[i] = lerpf(_amb_w[i], w[i], t)
		for pt: GPUParticles3D in _amb[i]:
			pt.amount_ratio = _amb_w[i]
			pt.emitting = _amb_w[i] > 0.02
			pt.position = p + Vector3(0, pt.get_meta("y"), 0)
	_hills_mi.position = Vector3(p.x, 0, p.z)
	var b := biome_at(p.x, p.z)
	if b != _biome:
		_biome = b
		Sfx.ambient(NAMES[b])


## Kamera konumu (world.gd'nin kökte, dönüşsüz durduğu varsayılır: yerel = dünya).
func _cam_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_position if cam else Vector3.ZERO


## Biyom başına parçacık katmanları, forest.gd'nin polen/yaprak yapıcısıyla.
## [yaprak mı, yarı boy, sayı, renkler, yerçekimi, boyut, kameraya göre y]
func _particles() -> void:
	var cfg := [
		[[false, Vector3(22, 3, 22), 500, [Color(1.5, 0.5, 2.4, 0.8)], Vector3(0, 0.05, 0), 0.9, 1.5], # mor sporlar
			[false, Vector3(18, 2, 18), 90, [Color(2.6, 1.0, 3.2)], Vector3(0, 0.3, 0), 0.6, 0.5]], # yükselen kıvılcım
		[[false, Vector3(20, 1.5, 20), 110, [Color(2.2, 2.6, 0.6)], Vector3.ZERO, 1.9, 1.0], # ateşböceği
			[true, Vector3(14, 1.2, 14), 260, [Color(0.05, 0.05, 0.04), Color(0.14, 0.13, 0.1)], Vector3(0, 0.02, 0), 0.22, 0.8]], # sinek
		[[true, Vector3(22, 5, 22), 600, [Color(0.22, 0.21, 0.2), Color(0.55, 0.53, 0.5), Color(0.35, 0.33, 0.32)], Vector3(0.2, -0.3, 0.05), 0.45, 4.0], # kül
			[false, Vector3(20, 3, 20), 140, [Color(2.6, 0.8, 0.2)], Vector3(0.05, 0.25, 0), 0.7, 0.5]], # kor
		[[false, Vector3(22, 3, 22), 650, ForestScript.POLLEN, Vector3(0.03, 0.01, 0.0), 1.0, 1.5], # polen
			[true, Vector3(22, 0.5, 22), 60, ForestScript.LEAF_TONES, Vector3(0.25, -0.55, 0.1), 1.0, 7.0]]] # yaprak
	for b in 4:
		for c in cfg[b]:
			var pt: GPUParticles3D = _f._particles(c[0], c[1], c[2], c[3], c[4], c[5])
			pt.set_meta("y", c[6])
			pt.amount_ratio = 0.0
			pt.emitting = false
			add_child(pt)
			_amb[b].append(pt)


## Ufuk: kamerayla gezen tepe halkası (forest.gd'nin uzak tepeleri) ve kaba uzak zemin.
func _horizon() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_hills.transform_format = MultiMesh.TRANSFORM_3D
	_hills.use_colors = true
	_hills.mesh = _f._blob_mesh(14, 6, 0.25, 1.2)
	_hills.instance_count = 24
	for i in 24: # yüklü chunk'ların ötesinde, sisin içinde silüet
		var a := TAU * i / 24.0 + rng.randf_range(-0.08, 0.08)
		var d := rng.randf_range(300.0, 370.0)
		_hills.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(90, rng.randf_range(30, 70), 90)),
			Vector3(cos(a) * d, -8, sin(a) * d)))
	_hills_mi = MultiMeshInstance3D.new()
	_hills_mi.multimesh = _hills
	_hills_mi.material_override = _mats.blob
	_hills_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hills_mi)
	_far = MeshInstance3D.new()
	_far.material_override = _ground_mat
	_far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_far)


## Uzak zemin: CHUNK aralıklı kaba ızgara; dünya dışında da height() sürer (ufuk boş kalmaz).
## Yüklenebilecek yakın chunk'ların altında 40 m gömülür, ötesinde 4 m: gerçek zeminin içinden çıkmaz.
func _far_ground(cell: Vector2i) -> void:
	var near: float = (RADIUS[Settings.quality] + 1.5) * CHUNK
	var c := (Vector2(cell) + Vector2(0.5, 0.5)) * CHUNK
	var n := FAR_N + 1
	var vs := PackedVector3Array()
	var cols := PackedColorArray()
	for j in n:
		for i in n:
			var x := (cell.x - FAR_N / 2 + i) * CHUNK
			var z := (cell.y - FAR_N / 2 + j) * CHUNK
			var w := weights(x, z)
			var y := height(x, z, w)
			if maxf(absf(x), absf(z)) < HALF:
				y -= 40.0 if Vector2(x, z).distance_to(c) < near else 4.0
			var col := Color(0, 0, 0, 0)
			for b in 4:
				col += GROUND[b] * w[b]
			vs.append(Vector3(x, y, z))
			cols.append(col)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in FAR_N:
		for i in FAR_N:
			for q in [0, 1, n, 1, n + 1, n]:
				var id: int = j * n + i + q
				st.set_color(cols[id])
				st.set_uv2(Vector2.ZERO) # yol yok
				st.add_vertex(vs[id])
	st.generate_normals()
	_far.mesh = st.commit()
	for i in _hills.instance_count: # tepe rengi: altındaki biyom
		var hp := _hills.get_instance_transform(i).origin + Vector3(c.x, 0, c.y)
		var w := weights(hp.x, hp.z)
		var hc := Color(0, 0, 0)
		for b in 4:
			hc += HILL[b] * w[b]
		_hills.set_instance_color(i, hc)
