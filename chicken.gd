extends Node3D
## Ortamda gezinen süs tavuğu / civciv: dolanır, yem gagalar, oyuncu ya da patlama yaklaşınca kaçar.
## shortcut: yalnızca görüntü, ağda eşitlenmez (her makinede yerleri farklı) ve çarpışması yok;
## vurulabilir/toplanabilir olacaksa host'un yönettiği bir düğüme çevrilmeli.

const HALF := 28.5 # duvarın içinde kal
const KEEP_OUT := 4.5 # merkezden uzak dur (TD'de kule orada)

var chick := false
# Silahların yaratıklarda aradığı alanlar ("enemies" grubu): TD silahları tavuğu da vurabilsin.
var hp := 1
var radius := 0.3
var height := 0.5
var rng := RandomNumberGenerator.new()
var target: Vector3
var wait := 0.0
var t := 0.0
var scare := 0.0
var body: Node3D
var head: Node3D
var tail_node: Node3D
var wings: Array = []
var legs: Array = [] # [Node3D pivot, float phase_sign]
var allow_water := false
# Açık dünya (world.gd) ayarları; TD'de varsayılanlar kullanılır.
var bounds := Rect2(-HALF, -HALF, HALF * 2.0, HALF * 2.0) # dolaşma alanı, ebeveyne göre
var keep_out := KEEP_OUT # ebeveynin merkezinden uzak durma yarıçapı (0: yok)
var ground := Callable() # (x, z) -> zemin yüksekliği; yoksa y = 0
var vis_end := 0.0 # parçaların görünürlük mesafesi (0: sınırsız)
var speed := 0.9 # gezinme hızı (kaçarken 5)


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, size: Vector3, col: Color, rough := 0.80) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = size
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	mi.material_override = m
	mi.visibility_range_end = vis_end
	parent.add_child(mi)
	return mi


func _leg_pivot(parent: Node3D, pivot_pos: Vector3, phase: float) -> Node3D:
	var piv := Node3D.new()
	piv.position = pivot_pos
	parent.add_child(piv)
	legs.append([piv, phase])
	return piv


func _ready() -> void:
	_model()
	add_to_group("chickens")
	add_to_group("enemies")
	if not chick and scale == Vector3.ONE:
		scale = Vector3.ONE * rng.randf_range(0.9, 1.15)
	target = position
	wait = rng.randf_range(0.0, 3.0)
	t = rng.randf() * 10.0


## Görünüş: body, head ve wings burada kurulur (critter.gd başka hayvan için ezer).
func _model() -> void:
	var white: Color = Color(1.0, 0.85, 0.3) if chick else [Color(0.97, 0.95, 0.9), Color(0.72, 0.42, 0.22), Color(0.25, 0.22, 0.2)][rng.randi() % 3]
	var orange := Color(0.95, 0.55, 0.1)
	var ball := SphereMesh.new()
	ball.radial_segments = 10; ball.rings = 5 # az köşeli: oyunun low-poly diliyle uyumlu
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0; cone.radial_segments = 6
	var leg := CylinderMesh.new()
	leg.radial_segments = 5
	body = Node3D.new()
	add_child(body)
	_part(body, ball, Vector3(0, 0.3, 0), Vector3(0.34, 0.32, 0.46), white)
	_part(body, ball, Vector3(0, 0.42, 0.24), Vector3(0.12, 0.2, 0.16), white.darkened(0.12)).rotation.x = -0.7 # kuyruk
	for sx in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(sx * 0.17, 0.36, 0.0)
		body.add_child(w)
		_part(w, ball, Vector3(sx * 0.02, -0.06, 0.02), Vector3(0.07, 0.2, 0.3), white.darkened(0.08))
		wings.append(w)
		var lp := _leg_pivot(self, Vector3(sx * 0.07, 0.14, 0), sx)
		_part(lp, leg, Vector3(0, -0.07, 0), Vector3(0.032, 0.07, 0.032), orange, 0.55)
		_part(lp, ball, Vector3(0, -0.13, -0.02), Vector3(0.055, 0.02, 0.08), orange, 0.6)
	head = Node3D.new()
	head.position = Vector3(0, 0.42, -0.17)
	body.add_child(head)
	_part(head, ball, Vector3(0, 0.12, -0.03), Vector3(0.21, 0.22, 0.21), white)
	_part(head, cone, Vector3(0, 0.1, -0.16), Vector3(0.09, 0.05, 0.09), orange, 0.45).rotation.x = -PI / 2 # gaga
	for sx in [-1.0, 1.0]:
		_part(head, ball, Vector3(sx * 0.075, 0.15, -0.09), Vector3.ONE * 0.042, Color(0.04, 0.04, 0.05), 0.15)
		_part(head, ball, Vector3(sx * 0.088, 0.162, -0.106), Vector3.ONE * 0.014, Color.WHITE, 0.1)
	if not chick:
		_part(head, ball, Vector3(0, 0.24, -0.02), Vector3(0.05, 0.1, 0.14), Color(0.85, 0.12, 0.1), 0.6) # ibik
		_part(head, ball, Vector3(0, 0.03, -0.12), Vector3(0.05, 0.08, 0.05), Color(0.85, 0.12, 0.1), 0.6)
	if chick:
		scale = Vector3.ONE * 0.5


func _pick(from: Vector3, away: Vector3, dist: float) -> void:
	for _try in 6:
		var dir := away if away != Vector3.ZERO else Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
		if dir.length_squared() < 0.001:
			dir = Vector3(1, 0, 0)
		var p := from + dir.normalized().rotated(Vector3.UP, rng.randf_range(-0.65, 0.65)) * dist
		p.x = clampf(p.x, bounds.position.x, bounds.end.x)
		p.z = clampf(p.z, bounds.position.y, bounds.end.y)
		if Vector2(p.x, p.z).length() < keep_out:
			p = Vector3(p.x, 0, p.z).normalized() * keep_out if p.length() > 0.1 else Vector3(keep_out, 0, 0)
		if allow_water or not ground.is_valid() or float(ground.call(p.x, p.z)) >= 0.12:
			target = Vector3(p.x, 0, p.z)
			return
		away = Vector3.ZERO
	target = Vector3(from.x, 0, from.z)


## Patlama ya da oyuncu: dünya koordinatındaki from noktasından uzağa koşar (chunk-yerel dönüşümle!).
func flee(from: Vector3) -> void:
	scare = 1.8
	wait = 0.0
	var local_from: Vector3 = get_parent().to_local(from) if get_parent() is Node3D else from
	var away := position - Vector3(local_from.x, position.y, local_from.z)
	away.y = 0.0
	_pick(position, away, rng.randf_range(5.5, 9.0))


## Vuruldu: tüy bulutu bırakıp yok olur (player.chicken_die her makinede çağırır).
func die() -> void:
	hp = 0
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.05)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	p.mesh = q
	p.amount = 24
	p.lifetime = 1.2
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, -2.5, 0)
	p.angle_max = 360.0
	p.position = position + Vector3.UP * 0.3
	get_parent().add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)
	queue_free()


func boom(at: Vector3) -> void:
	if at.distance_to(global_position) < 14.0:
		flee(at)


func _process(dt: float) -> void:
	t += dt
	scare -= dt
	if scare <= 0.0:
		for p in get_tree().get_nodes_in_group("players"):
			if p.global_position.distance_squared_to(global_position) < 9.0:
				flee(p.global_position)
				break
	var to := target - position
	to.y = 0.0
	var moving := to.length() > 0.15
	if moving:
		var spd := 5.0 if scare > 0.0 else speed
		position += to.normalized() * minf(spd * dt, to.length())
		if ground.is_valid():
			position.y = ground.call(position.x, position.z)
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), minf(dt * 10.0, 1.0))
	else:
		wait -= dt
		if wait <= 0.0:
			wait = rng.randf_range(1.5, 5.0)
			_pick(position, Vector3.ZERO, rng.randf_range(1.0, 4.0))
	var run := scare > 0.0 and moving
	body.position.y = absf(sin(t * (22.0 if run else 9.0))) * (0.07 if run else 0.025) if moving else 0.0
	# dururken ara ara yere eğilip gagalar/otlar; yürürken başı doğal sallanır
	var peck := maxf(sin(t * 1.3 + position.x), 0.0) * absf(sin(t * 7.5))
	head.rotation.x = sin(t * 8.5) * 0.10 if moving else -peck * 0.65
	head.rotation.y = sin(t * 1.4 + position.z) * 0.25 if not moving else 0.0
	for i in wings.size():
		wings[i].rotation.z = (1.0 if i == 0 else -1.0) * (absf(sin(t * 24.0)) * 1.15 if run else 0.0)
	var leg_freq := 16.0 if run else 8.5
	var leg_amp := 0.65 if run else 0.36
	for pair in legs:
		var piv: Node3D = pair[0]
		var ph: float = pair[1]
		piv.rotation.x = sin(t * leg_freq) * leg_amp * ph if moving else lerpf(piv.rotation.x, 0.0, minf(dt * 8.0, 1.0))
	if tail_node:
		tail_node.rotation.y = sin(t * (10.0 if run else 3.2) + position.x) * (0.35 if run else 0.22)
