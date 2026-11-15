extends Node3D
## Ormanlık harita: çimen zemin, büyük ağaçlar, kayalar, çimen öbekleri ve çiçekler.
## Çarpışan her şey sabit tohumla ve aynı sırayla yerleşir -> herkeste aynı harita.

const HALF := 30.0 # oyun alanı 60 x 60 m

var spawns: Array = [] # oyuncu doğma noktaları, etrafı boş kalır
var _bark: StandardMaterial3D
var _leaves: Array = []
var _rock_mats: Array = []


func _mat(c: Color, rough := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _ready() -> void:
	_bark = _mat(Color(0.33, 0.22, 0.14))
	for c in [Color(0.15, 0.4, 0.14), Color(0.2, 0.48, 0.16), Color(0.26, 0.52, 0.2)]:
		_leaves.append(_mat(c))
	for c in [Color(0.45, 0.45, 0.43), Color(0.52, 0.5, 0.46), Color(0.38, 0.37, 0.36)]:
		_rock_mats.append(_mat(c, 0.9))

	_environment()
	_box(Vector3(0, -0.5, 0), Vector3(HALF * 2, 1, HALF * 2), Color(0.3, 0.52, 0.2)) # çimen zemin
	for w in [[Vector3(0, 1.5, -HALF), Vector3(HALF * 2, 3, 1)], [Vector3(0, 1.5, HALF), Vector3(HALF * 2, 3, 1)],
			[Vector3(-HALF, 1.5, 0), Vector3(1, 3, HALF * 2)], [Vector3(HALF, 1.5, 0), Vector3(1, 3, HALF * 2)]]:
		_box(w[0], w[1], Color(0.42, 0.4, 0.36)) # taş sınır duvarı

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
	for i in 44: # duvarın dışında orman kenarı (yalnızca görüntü)
		var a := TAU * i / 44.0 + rng.randf_range(-0.05, 0.05)
		var d := rng.randf_range(HALF + 3.0, HALF + 9.0)
		_tree(Vector3(cos(a) * d * 1.05, 0, sin(a) * d * 1.05), rng.randf_range(1.1, 1.7), rng, false)

	# Süs: çarpışmasız, binlerce örnek tek çizimde (MultiMesh).
	_grass(rng, 6000)
	_flowers(rng, 900)


func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.45, 0.8)
	sky_mat.sky_horizon_color = Color(0.66, 0.78, 0.88)
	sky_mat.ground_horizon_color = Color(0.45, 0.55, 0.4)
	sky_mat.ground_bottom_color = Color(0.18, 0.26, 0.14)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = sky_mat
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.68, 0.78, 0.86)
	env.fog_density = 0.006
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 40, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)


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


func _box(pos: Vector3, size: Vector3, c: Color) -> void:
	var b := StaticBody3D.new()
	b.position = pos
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	b.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	add_child(b)


func _tree(pos: Vector3, s: float, rng: RandomNumberGenerator, collide: bool) -> void:
	var root: Node3D = StaticBody3D.new() if collide else Node3D.new()
	root.position = pos
	root.rotation.y = rng.randf() * TAU
	var trunk_h := 7.0 * s
	var tm := CylinderMesh.new()
	tm.top_radius = 0.3 * s; tm.bottom_radius = 0.55 * s; tm.height = trunk_h
	var trunk := MeshInstance3D.new()
	trunk.mesh = tm
	trunk.position.y = trunk_h * 0.5
	trunk.material_override = _bark
	root.add_child(trunk)
	# Yaprak: gövde tepesinde iç içe geçmiş 4 küre.
	for k in 4:
		var r := rng.randf_range(2.0, 2.9) * s
		var sm := SphereMesh.new()
		sm.radius = r; sm.height = r * 1.7
		var leaf := MeshInstance3D.new()
		leaf.mesh = sm
		var off := Vector3(rng.randf_range(-1.3, 1.3), rng.randf_range(-0.6, 1.0), rng.randf_range(-1.3, 1.3)) * s
		leaf.position = Vector3(0, trunk_h + 0.6 * s, 0) + (off if k > 0 else Vector3.ZERO)
		leaf.material_override = _leaves[rng.randi() % _leaves.size()]
		root.add_child(leaf)
	if collide: # yalnızca gövde çarpışır; yapraklar içinden geçilir
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.5 * s; sh.height = trunk_h
		cs.shape = sh
		cs.position.y = trunk_h * 0.5
		root.add_child(cs)
	add_child(root)


func _rock(p: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	var b := StaticBody3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * rng.randf_range(1.0, 1.5)
	sm.radial_segments = 7 # az yüzey -> köşeli kaya görünümü
	sm.rings = 4
	b.position = Vector3(p.x, sm.height * 0.2, p.y) # biraz gömülü
	b.rotation = Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * TAU, rng.randf_range(-0.25, 0.25))
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = _rock_mats[rng.randi() % _rock_mats.size()]
	b.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = sm.create_convex_shape()
	b.add_child(cs)
	add_child(b)


## items: [[Transform3D, Color], ...] -> tek çizimde binlerce örnek.
func _multimesh(mesh: Mesh, items: Array) -> void:
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
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _vc_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true # renk her örnekten gelir
	return m


func _rand_ground(rng: RandomNumberGenerator) -> Vector3:
	return Vector3(rng.randf_range(-HALF + 0.6, HALF - 0.6), 0, rng.randf_range(-HALF + 0.6, HALF - 0.6))


func _grass(rng: RandomNumberGenerator, n: int) -> void:
	var tuft := PrismMesh.new()
	tuft.size = Vector3(0.15, 0.32, 0.04)
	tuft.material = _vc_mat()
	var items := []
	for i in n:
		var h := rng.randf_range(0.6, 1.4)
		var pos := _rand_ground(rng)
		pos.y = 0.16 * h
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1, h, 1))
		items.append([Transform3D(basis, pos), Color(0.22, 0.5, 0.16).lerp(Color(0.45, 0.62, 0.2), rng.randf())])
	_multimesh(tuft, items)


func _flowers(rng: RandomNumberGenerator, n: int) -> void:
	var colors := [Color(0.95, 0.2, 0.25), Color(1.0, 0.85, 0.2), Color(0.97, 0.97, 0.97),
		Color(0.7, 0.35, 0.9), Color(0.35, 0.55, 1.0), Color(1.0, 0.55, 0.15)]
	var head := SphereMesh.new()
	head.radius = 0.08; head.height = 0.12
	head.radial_segments = 8; head.rings = 4
	head.material = _vc_mat()
	var stem := CylinderMesh.new()
	stem.top_radius = 0.012; stem.bottom_radius = 0.012; stem.height = 0.3
	stem.material = _vc_mat()
	# Çiçekler 15'li öbekler halinde, her öbek tek renk.
	var stems := []
	var heads := []
	var center := Vector3.ZERO
	var col := Color.WHITE
	for i in n:
		if i % 15 == 0:
			center = _rand_ground(rng)
			col = colors[rng.randi() % colors.size()]
		var pos := center + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5))
		pos.x = clampf(pos.x, -HALF + 0.6, HALF - 0.6)
		pos.z = clampf(pos.z, -HALF + 0.6, HALF - 0.6)
		stems.append([Transform3D(Basis(), pos + Vector3(0, 0.15, 0)), Color(0.2, 0.45, 0.15)])
		heads.append([Transform3D(Basis(), pos + Vector3(0, 0.32, 0)), col])
	_multimesh(stem, stems)
	_multimesh(head, heads)
