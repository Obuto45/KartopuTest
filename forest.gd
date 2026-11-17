extends Node3D
## Ormanlık harita: altın saat ışığı, gürültülü çimen zemin, ağaçlar, kayalar, taş duvar ve süsler.
## Çarpışan her şey sabit tohumla (rng) ve aynı sırayla yerleşir -> herkeste aynı harita.
## Yalnızca görüntü olan her şey ayrı üreteçten (_vis) gelir: rng sırasına dokunmaz.

const ChickenScript := preload("res://chicken.gd")
const HALF := 30.0 # oyun alanı 60 x 60 m
const MASK_HALF := 50.0 # zemin maskesinin kapladığı yarı kenar (m)
const MASK_N := 128
const BARK := Color(0.44, 0.3, 0.19)

var spawns: Array = [] # oyuncu doğma noktaları, etrafı boş kalır
var _vis := RandomNumberGenerator.new()
var _fn := FastNoiseLite.new()
var _noise: ImageTexture
var _mask: Image # R: ağaç altı gölge, G: toprak (patika, ağaç dibi)
var _rock_mat: ShaderMaterial
var _rock_cols := [Color(0.54, 0.5, 0.44), Color(0.62, 0.56, 0.46), Color(0.44, 0.42, 0.39)]
# Ağaç ve süs parçaları tek tek düğüm olmaz: [Transform3D, Color] listelerinde toplanır, sonda MultiMesh olur.
var _trunks := []
var _blobs := []
var _cones := []
var _pebbles := []
var _tree_pos := [] # alan içi ağaçlar: [konum, ölçek] (dibine mantar/çalı)


func _smat(path: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	m.set_shader_parameter("noise_tex", _noise)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


func _ready() -> void:
	_vis.seed = 7
	# Tek gürültü dokusu her yerde kullanılır (zemin, çimen rüzgârı, taş, bulut). Eşzamanlı üretilir:
	# NoiseTexture2D arka planda dolduğu için gök ışığı ilk karede yanlış hesaplanırdı.
	_fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_fn.frequency = 0.02
	var nimg := _fn.get_seamless_image(256, 256)
	nimg.generate_mipmaps()
	_noise = ImageTexture.create_from_image(nimg)
	_fn.frequency = 1.0 # bundan sonra ağ yamultmada kullanılır
	_fn.fractal_type = FastNoiseLite.FRACTAL_NONE
	_mask = Image.create(MASK_N, MASK_N, false, Image.FORMAT_RGB8)
	_rock_mat = _smat("res://shaders/stone.gdshader", {"moss": 0.75})
	var ground_mat := _smat("res://shaders/ground.gdshader", {"arena_half": HALF, "mask_half": MASK_HALF})
	var wall_mat := _smat("res://shaders/stone.gdshader", {"tint": Color(0.56, 0.52, 0.46), "blocks": 1.0, "moss": 0.85})

	_environment()
	_box(Vector3(0, -0.5, 0), Vector3(HALF * 2, 1, HALF * 2), ground_mat) # çimen zemin
	for w in [[Vector3(0, 1.5, -HALF), Vector3(HALF * 2, 3, 1)], [Vector3(0, 1.5, HALF), Vector3(HALF * 2, 3, 1)],
			[Vector3(-HALF, 1.5, 0), Vector3(1, 3, HALF * 2)], [Vector3(HALF, 1.5, 0), Vector3(1, 3, HALF * 2)]]:
		_box(w[0], w[1], wall_mat) # taş sınır duvarı

	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var used := [] # [konum (Vector2), yarıçap]
	for i in 24: # alan içindeki büyük ağaçlar (çarpışmalı)
		var p = _free_spot(rng, 2.0, used)
		if p != null:
			_tree(Vector3(p.x, 0, p.y), rng.randf_range(0.9, 1.4), rng, true)
	for i in 28: # kayalar: büyükler siper, küçükler süs
		var big := i < 12
		var r := rng.randf_range(1.2, 2.2) if big else rng.randf_range(0.4, 0.9)
		var p = _free_spot(rng, r + 0.6, used)
		if p != null:
			_rock(p, r, rng)
	# --- Buradan sonrası yalnızca görüntü: rng yerine _vis. ---
	var n := 0
	while n < 250: # duvarın dışında sık orman: ufuk boş kalmaz
		var p := Vector3(_vis.randf_range(-1, 1), 0, _vis.randf_range(-1, 1)) * (HALF + 34.0)
		var d := maxf(absf(p.x), absf(p.z)) - HALF
		if d > 2.6 and _vis.randf() < 1.3 - d / 34.0: # duvara yakın daha sık
			_tree(p, _vis.randf_range(1.1, 1.9), _vis, false)
			n += 1

	# Dış zemin: çarpışma kutusunun biraz altında dev düzlem (ağaçlar boşlukta durmasın).
	var outer := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(700, 700)
	outer.mesh = pm
	outer.position.y = -0.04
	outer.material_override = ground_mat
	add_child(outer)

	_paths()
	_wall_dress(wall_mat)
	_props(used)
	ground_mat.set_shader_parameter("mask_tex", ImageTexture.create_from_image(_mask))
	_grass(ground_mat, 18000)
	_flowers(ground_mat, 750)
	_ambient()

	# Toplanan parçalar: tür başına tek çizim.
	var bark_mat := _smat("res://shaders/stone.gdshader", {"tint": BARK, "moss": 0.25, "streak": 1.0})
	var leaf_mat := _smat("res://shaders/foliage.gdshader")
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.3; trunk.bottom_radius = 0.55; trunk.height = 1.0
	trunk.radial_segments = 8; trunk.rings = 5
	# Birim gövde: taban y=0, dipte kök yayılması, hafif eğrilik. Örnek ölçeği boyu verir.
	_multimesh(_deform(trunk, func(v: Vector3) -> Vector3:
		v.y += 0.5
		var k := 1.0 + 0.45 * exp(-v.y * 14.0) * (1.0 + 0.4 * sin(atan2(v.z, v.x) * 3.0))
		return Vector3(v.x * k + sin(v.y * 4.0) * 0.05, v.y, v.z * k + cos(v.y * 3.0) * 0.04)), _trunks, bark_mat, true)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.04; cone.bottom_radius = 1.0; cone.height = 1.0
	cone.radial_segments = 10; cone.rings = 1
	_multimesh(_deform(cone, func(v: Vector3) -> Vector3: # çam katı: etek uçları dişli ve sarkık
		var a := atan2(v.z, v.x)
		var k := 1.0 + 0.2 * sin(a * 5.0)
		return Vector3(v.x * k, v.y + 0.5 - 0.12 * sin(a * 5.0) * Vector2(v.x, v.z).length(), v.z * k)), _cones, leaf_mat, true)
	_multimesh(_blob_mesh(10, 5, 0.3, 1.4), _blobs, leaf_mat, true)
	_multimesh(_blob_mesh(8, 4, 0.22, 1.7), _pebbles, _rock_mat, false)
	# Uzak tepeler: sisin içinde silüet, ufku kapatır.
	var hills := []
	for i in 18:
		var a := TAU * i / 18.0 + _vis.randf_range(-0.1, 0.1)
		var d := _vis.randf_range(150.0, 210.0)
		hills.append([Transform3D(Basis(Vector3.UP, _vis.randf() * TAU).scaled(Vector3(75, _vis.randf_range(22, 40), 75)),
			Vector3(cos(a) * d, -6, sin(a) * d)), Color(0.1, 0.2, 0.12)])
	_multimesh(_blob_mesh(14, 6, 0.25, 1.2), hills, leaf_mat, false)
	_chickens()


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = _smat("res://shaders/sky.gdshader")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.1 # gölgedeki karakterler seçilsin
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true # yalnızca çok parlak şeyler (güneş, patlama) parlar
	env.glow_intensity = 0.45
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.12
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.2
	env.fog_enabled = true
	env.fog_light_color = Color(0.86, 0.74, 0.6)
	env.fog_density = 0.004
	env.fog_sun_scatter = 0.25
	env.fog_sky_affect = 0.2 # gök kendi rengini korusun
	# Hacimsel sis: ağaç aralarından güneş huzmeleri. Pahalı olan tek ayar bu; yoğunluk düşük tutulur.
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.007
	env.volumetric_fog_albedo = Color(1.0, 0.9, 0.76)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 70.0
	env.volumetric_fog_sky_affect = 0.2
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, 40, 0) # alçak güneş: uzun gölgeler
	sun.light_color = Color(1.0, 0.84, 0.64)
	sun.light_energy = 1.7
	sun.light_volumetric_fog_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_blend_splits = true
	add_child(sun)
	var fill := DirectionalLight3D.new() # karşıdan soğuk dolgu: gölge tarafı kapkara kalmaz
	fill.rotation_degrees = Vector3(-25, 220, 0)
	fill.light_color = Color(0.6, 0.72, 1.0)
	fill.light_energy = 0.3
	fill.light_specular = 0.0
	fill.light_volumetric_fog_energy = 0.0
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY # gökte ikinci güneş çizilmesin
	add_child(fill)


## Doğma noktalarından ve diğer nesnelerden uzak boş bir nokta bulur; bulamazsa null.
func _free_spot(rng: RandomNumberGenerator, r: float, used: Array):
	for t in 30:
		var p := Vector2(rng.randf_range(-HALF + 2.5, HALF - 2.5), rng.randf_range(-HALF + 2.5, HALF - 2.5))
		var ok := true
		for sp in spawns:
			if p.distance_to(Vector2(sp.x, sp.z)) < 4.5 + r:
				ok = false
		for u in used:
			if p.distance_to(u[0]) < u[1] + r:
				ok = false
		if ok:
			used.append([p, r])
			return p
	return null


func _box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var b := StaticBody3D.new()
	b.position = pos
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	b.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	add_child(b)


## Hazır ağın her köşesini f'den geçirir, düz (yüzey başına) normalle yeniden kurar: low-poly görünüm.
## UV.y = yükseklik (0 alt, 1 üst): gölgelendiriciler alt-üst renk geçişinde kullanır.
func _deform(src: PrimitiveMesh, f: Callable, col := Color.WHITE) -> ArrayMesh:
	var a := src.get_mesh_arrays()
	var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var lo := INF
	var hi := -INF
	for i in vs.size():
		vs[i] = f.call(vs[i])
		lo = minf(lo, vs[i].y)
		hi = maxf(hi, vs[i].y)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	st.set_color(col)
	for i in a[Mesh.ARRAY_INDEX]:
		st.set_uv(Vector2(0, (vs[i].y - lo) / (hi - lo)))
		st.add_vertex(vs[i])
	st.generate_normals()
	return st.commit()


## Gürültüyle yamultulmuş birim küre: yaprak kümesi, çakıl, tepe.
func _blob_mesh(segs: int, rings: int, amp: float, freq: float) -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radius = 1.0; sm.height = 2.0
	sm.radial_segments = segs; sm.rings = rings
	return _deform(sm, func(v: Vector3) -> Vector3: return v * (1.0 + amp * _fn.get_noise_3dv(v * freq)))


func _tree(pos: Vector3, s: float, rng: RandomNumberGenerator, collide: bool) -> void:
	# rng çağrı sırası ilk sürümle birebir aynı kalmalı (ağ eşitliği): dönüş, sonra 4 x (yarıçap, kayma, ton).
	var rot := rng.randf() * TAU
	var trunk_h := 7.0 * s
	var pine := _vis.randf() < 0.35
	var leaf := Color(0.07, 0.2, 0.06).lerp(Color(0.2, 0.33, 0.05), _vis.randf())
	if pine:
		leaf = Color(0.07, 0.2, 0.1).lerp(Color(0.12, 0.27, 0.1), _vis.randf())
	elif _vis.randf() < 0.14: # ara sıra sonbahar tonu
		leaf = Color(0.5, 0.26, 0.04).lerp(Color(0.55, 0.42, 0.05), _vis.randf())
	var top := Vector3(0, trunk_h + 0.6 * s, 0)
	for k in 4:
		var r := rng.randf_range(2.0, 2.9) * s
		var off := Vector3(rng.randf_range(-1.3, 1.3), rng.randf_range(-0.6, 1.0), rng.randf_range(-1.3, 1.3)) * s
		var tone := 0.85 + 0.12 * (rng.randi() % 3)
		if not pine:
			_blobs.append([Transform3D(Basis(Vector3.UP, rot + k * 1.7).scaled(Vector3(r, r * 0.8, r)),
				pos + top + (off if k > 0 else Vector3.ZERO)), leaf * tone])
	if pine: # üst üste 5 kat, yukarı doğru daralır; en alt kat baş hizasının üstünde
		for k in 5:
			var f := k / 4.0
			var rad := lerpf(2.7, 1.1, f) * s
			_cones.append([Transform3D(Basis(Vector3.UP, rot + k * 1.3).scaled(Vector3(rad, lerpf(3.8, 3.2, f) * s, rad)),
				pos + Vector3(0, lerpf(3.8, 9.6, f) * s, 0)), leaf * lerpf(0.85, 1.15, f)])
	else: # yanlarda sarkan küçük kümeler: taç düzgün top olmasın
		for k in 3:
			var a := rot + k * TAU / 3.0 + _vis.randf_range(-0.5, 0.5)
			var r := _vis.randf_range(1.2, 1.8) * s
			_blobs.append([Transform3D(Basis(Vector3.UP, a).scaled(Vector3(r, r * 0.75, r)),
				pos + top + Vector3(cos(a) * 2.3, _vis.randf_range(-1.6, -0.6), sin(a) * 2.3) * s), leaf * _vis.randf_range(0.8, 1.05)])
	_trunks.append([Transform3D(Basis(Vector3.UP, rot).scaled(Vector3(s, trunk_h * (1.5 if pine else 1.0), s)), pos),
		Color(1, 1, 1) * _vis.randf_range(0.8, 1.2)])
	_stamp(Vector2(pos.x, pos.z), 4.5 * s, 0, 0.8)
	_stamp(Vector2(pos.x, pos.z), 1.7 * s, 1, 0.75)
	if collide: # yalnızca gövde çarpışır; yapraklar içinden geçilir
		_tree_pos.append([pos, s])
		var b := StaticBody3D.new()
		b.position = pos
		b.rotation.y = rot
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.5 * s; sh.height = trunk_h
		cs.shape = sh
		cs.position.y = trunk_h * 0.5
		b.add_child(cs)
		add_child(b)


func _rock(p: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	var b := StaticBody3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * rng.randf_range(1.0, 1.5)
	sm.radial_segments = 7 # çarpışma şekli bu kaba küreden çıkar: değiştirme
	sm.rings = 4
	b.position = Vector3(p.x, sm.height * 0.2, p.y) # biraz gömülü
	b.rotation = Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * TAU, rng.randf_range(-0.25, 0.25))
	var col: Color = _rock_cols[rng.randi() % _rock_cols.size()]
	var cs := CollisionShape3D.new()
	cs.shape = sm.create_convex_shape()
	b.add_child(cs)
	# Görüntü: aynı kürenin gürültüyle yontulmuş hali; çarpışma şeklinden belirgin taşmaz.
	var vm := SphereMesh.new()
	vm.radius = r; vm.height = sm.height
	vm.radial_segments = 9; vm.rings = 4
	var seed_off := Vector3(p.x, 0, p.y)
	var mi := MeshInstance3D.new()
	mi.mesh = _deform(vm, func(v: Vector3) -> Vector3:
		return v * (0.92 + 0.2 * _fn.get_noise_3dv(v * (1.5 / r) + seed_off)), col)
	mi.material_override = _rock_mat
	b.add_child(mi)
	add_child(b)
	_stamp(p, r * 1.8, 1, 0.7) # dibinde çıplak toprak
	for k in (3 if r > 1.1 else 1): # dibine dökülmüş çakıllar (çarpışmasız, küçük)
		var a := _vis.randf() * TAU
		var pr := r * _vis.randf_range(0.14, 0.26)
		_pebbles.append([Transform3D(Basis.from_euler(Vector3(_vis.randf(), _vis.randf() * TAU, _vis.randf())).scaled(Vector3(pr, pr * 0.7, pr)),
			Vector3(p.x + cos(a) * r * 1.05, pr * 0.3, p.y + sin(a) * r * 1.05)), col])


## Maskenin bir kanalına yumuşak daire basar (ch 0: gölge, 1: toprak).
func _stamp(p: Vector2, rad: float, ch: int, amt: float) -> void:
	var c := (p / (MASK_HALF * 2.0) + Vector2(0.5, 0.5)) * MASK_N
	var pr := rad / (MASK_HALF * 2.0) * MASK_N
	for y in range(maxi(0, int(c.y - pr)), mini(MASK_N, int(c.y + pr) + 2)):
		for x in range(maxi(0, int(c.x - pr)), mini(MASK_N, int(c.x + pr) + 2)):
			var k := 1.0 - Vector2(x + 0.5, y + 0.5).distance_to(c) / pr
			if k > 0.0:
				var col := _mask.get_pixel(x, y)
				col[ch] = maxf(col[ch], smoothstep(0.0, 1.0, k) * amt)
				_mask.set_pixel(x, y, col)


func _mask_at(p: Vector3) -> Color:
	var c := (Vector2(p.x, p.z) / (MASK_HALF * 2.0) + Vector2(0.5, 0.5)) * MASK_N
	return _mask.get_pixel(clampi(int(c.x), 0, MASK_N - 1), clampi(int(c.y), 0, MASK_N - 1))


## Toprak patikalar: her doğma noktasından ortadaki açıklığa kıvrılarak gider.
func _paths() -> void:
	_stamp(Vector2.ZERO, 5.0, 1, 0.9)
	for i in spawns.size():
		var a := Vector2(spawns[i].x, spawns[i].z)
		_stamp(a, 3.5, 1, 0.85)
		var side := a.orthogonal().normalized()
		for t in 40:
			var f := t / 40.0
			_stamp(a.lerp(Vector2.ZERO, f) + side * sin(f * 7.0 + i * 2.0) * 1.6 * sin(f * PI), 1.9, 1, 0.8)
	for i in 14: # rastgele çıplak yamalar
		_stamp(Vector2(_vis.randf_range(-HALF, HALF), _vis.randf_range(-HALF, HALF)), _vis.randf_range(1.5, 3.5), 1, 0.7)


## Duvarı süsler: aralıklı payandalar, tepede sarmaşık öbekleri, dipte çalılar. Hepsi çarpışmasız.
func _wall_dress(wall_mat: Material) -> void:
	var pillars := []
	for i in 36:
		var t := (i % 9) / 9.0 * 2.0 - 1.0 # köşe payandası bir kez
		var q := Vector3(t * HALF, 1.85, HALF).rotated(Vector3.UP, floorf(i / 9.0) * PI * 0.5)
		pillars.append([Transform3D(Basis(), q), Color(1.2, 1.17, 1.1)]) # duvardan bir ton açık
	var pb := BoxMesh.new()
	pb.size = Vector3(1.5, 3.7, 1.5)
	_multimesh(pb, pillars, wall_mat, true)
	for i in 110:
		var q := Vector3(_vis.randf_range(-HALF, HALF), 0, HALF).rotated(Vector3.UP, (i % 4) * PI * 0.5)
		var inward := Vector3(-signf(q.x) if absf(q.x) > HALF - 0.01 else 0.0, 0, -signf(q.z) if absf(q.z) > HALF - 0.01 else 0.0)
		var r := _vis.randf_range(0.6, 1.1)
		var col := Color(0.06, 0.2, 0.05).lerp(Color(0.16, 0.3, 0.06), _vis.randf())
		var yaw := Basis(Vector3.UP, _vis.randf() * TAU)
		if i < 50: # tepede sarmaşık
			_blobs.append([Transform3D(yaw.scaled(Vector3(r * 1.3, r * 0.5, r * 1.3)), q + Vector3(0, 3.0, 0)), col])
		else: # dipte çalı
			_blobs.append([Transform3D(yaw.scaled(Vector3(r, r * 0.75, r)), q + inward * 1.0 + Vector3(0, r * 0.3, 0)), col])


## Küçük süsler: kütükler, devrik gövdeler, mantarlar, çalılar, çakıllar. Çarpışmasız.
func _props(used: Array) -> void:
	for i in 12:
		var p = _free_spot(_vis, 1.6, used) # _vis ile: rng sırası etkilenmez
		if p == null:
			continue
		var yaw := Basis(Vector3.UP, _vis.randf() * TAU)
		if i < 5: # devrik gövde
			_trunks.append([Transform3D(yaw * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(0.55, _vis.randf_range(2.2, 3.2), 0.55)),
				Vector3(p.x, 0.22, p.y)), Color(0.8, 0.8, 0.8)])
		else: # kütük
			_trunks.append([Transform3D(yaw.scaled(Vector3(1.3, 0.55, 1.3)), Vector3(p.x, 0, p.y)), Color(0.9, 0.9, 0.9)])
		_stamp(p, 1.6, 1, 0.6)
	var stems := []
	var caps := []
	var cap_cols := [Color(0.8, 0.12, 0.08), Color(0.6, 0.38, 0.2), Color(0.9, 0.82, 0.65)]
	for t in _tree_pos:
		var base: Vector3 = t[0]
		var s: float = t[1]
		if _vis.randf() < 0.6: # gövde dibinde çalı
			var a := _vis.randf() * TAU
			var r := _vis.randf_range(0.55, 0.9)
			_blobs.append([Transform3D(Basis(Vector3.UP, a).scaled(Vector3(r, r * 0.75, r)), base + Vector3(cos(a), 0, sin(a)) * (0.9 * s + r * 0.6) + Vector3(0, r * 0.3, 0)),
				Color(0.06, 0.2, 0.05).lerp(Color(0.16, 0.3, 0.06), _vis.randf())])
		var col: Color = cap_cols[_vis.randi() % cap_cols.size()]
		for k in _vis.randi_range(2, 5): # mantar öbeği
			var a := _vis.randf() * TAU
			var q := base + Vector3(cos(a), 0, sin(a)) * _vis.randf_range(0.9, 1.6) * s
			var h := _vis.randf_range(0.7, 1.5)
			stems.append([Transform3D(Basis().scaled(Vector3(h, h, h)), q + Vector3(0, 0.07 * h, 0)), Color(0.9, 0.86, 0.75)])
			caps.append([Transform3D(Basis().scaled(Vector3(h, h, h)), q + Vector3(0, 0.13 * h, 0)), col])
	var stem := CylinderMesh.new()
	stem.top_radius = 0.025; stem.bottom_radius = 0.035; stem.height = 0.14
	stem.radial_segments = 6; stem.rings = 1
	stem.material = _vc_mat()
	var cap := SphereMesh.new()
	cap.radius = 0.1; cap.height = 0.08; cap.is_hemisphere = true
	cap.radial_segments = 8; cap.rings = 3
	cap.material = _vc_mat()
	_multimesh(stem, stems)
	_multimesh(cap, caps)
	for i in 90: # ufak taşlar
		var pr := _vis.randf_range(0.08, 0.28)
		var q := _rand_ground(_vis)
		_pebbles.append([Transform3D(Basis.from_euler(Vector3(_vis.randf(), _vis.randf() * TAU, _vis.randf())).scaled(Vector3(pr, pr * 0.6, pr)),
			q + Vector3(0, pr * 0.2, 0)), _rock_cols[i % 3]])


## Ucuz ortam canlılığı: ışıkta süzülen polen ve dökülen yapraklar (GPU parçacıkları, gölgesiz).
func _ambient() -> void:
	var fade := GradientTexture1D.new() # doğarken ve ölürken görünmez: pat diye belirmez
	fade.gradient = Gradient.new()
	fade.gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	fade.gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	var dot := GradientTexture2D.new()
	dot.width = 32; dot.height = 32
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5); dot.fill_to = Vector2(0.5, 0.0)
	dot.gradient = Gradient.new()
	dot.gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	for leaf in [false, true]:
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(HALF, 0.5 if leaf else 3.0, HALF)
		pm.direction = Vector3(1, 0.1, 0.4)
		pm.spread = 70.0
		pm.initial_velocity_min = 0.1
		pm.initial_velocity_max = 0.4
		pm.gravity = Vector3(0.25, -0.55, 0.1) if leaf else Vector3(0.03, 0.01, 0.0)
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 1.0 if leaf else 0.5
		pm.turbulence_noise_scale = 3.0
		pm.scale_min = 0.6
		pm.scale_max = 1.4
		pm.color_ramp = fade
		var mat := StandardMaterial3D.new()
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		var quad := QuadMesh.new()
		if leaf:
			pm.angle_min = -180.0
			pm.angle_max = 180.0
			pm.angular_velocity_min = -120.0
			pm.angular_velocity_max = 120.0
			var tones := GradientTexture1D.new()
			tones.gradient = Gradient.new()
			tones.gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
			tones.gradient.colors = PackedColorArray([Color(0.3, 0.45, 0.1), Color(0.8, 0.6, 0.1), Color(0.75, 0.3, 0.08)])
			pm.color_initial_ramp = tones
			quad.size = Vector2(0.17, 0.1)
		else:
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mat.albedo_color = Color(1.0, 0.88, 0.6, 0.8)
			mat.albedo_texture = dot
			quad.size = Vector2(0.07, 0.07)
		quad.material = mat
		var p := GPUParticles3D.new()
		p.amount = 90 if leaf else 1000
		p.lifetime = 5.5 if leaf else 10.0
		p.preprocess = p.lifetime # oyun başlarken hava zaten dolu olsun
		p.position.y = 8.5 if leaf else 3.2
		p.process_material = pm
		p.draw_pass_1 = quad
		p.visibility_aabb = AABB(Vector3(-HALF - 3, -10, -HALF - 3), Vector3(HALF * 2 + 6, 16, HALF * 2 + 6))
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)


## Süs tavukları: birkaç tavuk, her birinin peşinde bir iki civciv (chicken.gd, yalnızca görüntü).
func _chickens() -> void:
	for i in 9:
		var home := _rand_ground(_vis) * 0.9
		if Vector2(home.x, home.z).length() < 7.0:
			continue
		for j in 1 + (_vis.randi() % 3 if i < 4 else 0): # ilk dördü civcivli
			var c: Node3D = ChickenScript.new()
			c.name = "Chicken%d_%d" % [i, j] # sabit ad: ölüm ağda adla eşitlenir
			c.chick = j > 0
			c.rng.seed = _vis.randi()
			c.position = home + Vector3(_vis.randf_range(-1, 1), 0, _vis.randf_range(-1, 1)) * float(j)
			add_child(c)


## items: [[Transform3D, Color], ...] -> tek çizimde binlerce örnek.
func _multimesh(mesh: Mesh, items: Array, mat: Material = null, shadow := false) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat # null -> ağın kendi malzemesi
	if not shadow:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _vc_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true # renk her örnekten gelir
	return m


func _rand_ground(rng: RandomNumberGenerator) -> Vector3:
	return Vector3(rng.randf_range(-HALF + 0.6, HALF - 0.6), 0, rng.randf_range(-HALF + 0.6, HALF - 0.6))


## Çimen/çiçek malzemesi: zeminle aynı gürültü ve maske dokularını paylaşır.
func _sway_mat(ground_mat: ShaderMaterial, tint_mix: float, top: float) -> ShaderMaterial:
	return _smat("res://shaders/grass.gdshader", {"mask_tex": ground_mat.get_shader_parameter("mask_tex"),
		"mask_half": MASK_HALF, "tint_mix": tint_mix, "top": top})


func _grass(ground_mat: ShaderMaterial, n: int) -> void:
	# Öbek: dışa yatık üç sivri yaprak (9 üçgen). Normal gölgelendiricide verilir.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var b := Basis(Vector3.UP, k * TAU / 3.0 + 0.4)
		var pts := [Vector3(-0.04, 0, 0.02), Vector3(0.04, 0, 0.02), Vector3(-0.028, 0.2, 0.06), Vector3(0.028, 0.2, 0.06), Vector3(0, 0.4, 0.15)]
		for i in [0, 1, 2, 1, 3, 2, 2, 3, 4]:
			st.add_vertex(b * pts[i])
	var items := []
	for i in n:
		var pos := _rand_ground(_vis)
		var m := _mask_at(pos)
		if m.g > _vis.randf_range(0.35, 0.6): # patikada çimen bitmez
			continue
		var h := _vis.randf_range(0.5, 1.1) * (1.0 - 0.3 * m.r) # ağaç altında kısa
		var w := _vis.randf_range(0.8, 1.4)
		items.append([Transform3D(Basis(Vector3.UP, _vis.randf() * TAU).scaled(Vector3(w, h, w)), pos),
			Color(0.9, 0.95, 0.85).lerp(Color(1.15, 1.1, 0.8), _vis.randf())])
	_multimesh(st.commit(), items, _sway_mat(ground_mat, 1.0, 0.4))


func _flowers(ground_mat: ShaderMaterial, n: int) -> void:
	var colors := [Color(0.95, 0.2, 0.25), Color(1.0, 0.85, 0.2), Color(0.97, 0.97, 0.97),
		Color(0.7, 0.35, 0.9), Color(0.35, 0.55, 1.0), Color(1.0, 0.55, 0.15)]
	var head := SphereMesh.new()
	head.radius = 0.06; head.height = 0.08
	head.radial_segments = 8; head.rings = 4
	var stem := CylinderMesh.new()
	stem.top_radius = 0.012; stem.bottom_radius = 0.012; stem.height = 0.3
	stem.radial_segments = 5; stem.rings = 1
	# Çiçekler 15'li öbekler halinde, her öbek tek renk.
	var stems := []
	var heads := []
	var center := Vector3.ZERO
	var col := Color.WHITE
	for i in n:
		if i % 15 == 0:
			center = _rand_ground(_vis)
			col = colors[_vis.randi() % colors.size()]
		var pos := center + Vector3(_vis.randf_range(-1.5, 1.5), 0, _vis.randf_range(-1.5, 1.5))
		pos.x = clampf(pos.x, -HALF + 0.6, HALF - 0.6)
		pos.z = clampf(pos.z, -HALF + 0.6, HALF - 0.6)
		if _mask_at(pos).g > 0.45:
			continue
		# Örnek kökü zeminde kalır (rüzgâr köke göre hesaplanır); yükseklik ağın içinde.
		stems.append([Transform3D(Basis(), pos), Color(0.1, 0.25, 0.06)])
		heads.append([Transform3D(Basis(), pos), col])
	var mat := _sway_mat(ground_mat, 0.0, 0.35)
	_multimesh(_deform(stem, func(v: Vector3) -> Vector3: return v + Vector3(0, 0.15, 0)), stems, mat)
	_multimesh(_deform(head, func(v: Vector3) -> Vector3: return v + Vector3(0, 0.32, 0)), heads, mat)
