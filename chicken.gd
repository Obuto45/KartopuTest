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
var wings: Array = []


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, size: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = size
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	mi.material_override = m
	parent.add_child(mi)
	return mi


func _ready() -> void:
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
		_part(self, leg, Vector3(sx * 0.07, 0.07, 0), Vector3(0.035, 0.07, 0.035), orange)
	head = Node3D.new()
	head.position = Vector3(0, 0.42, -0.17)
	body.add_child(head)
	_part(head, ball, Vector3(0, 0.12, -0.03), Vector3(0.21, 0.22, 0.21), white)
	_part(head, cone, Vector3(0, 0.1, -0.16), Vector3(0.09, 0.05, 0.09), orange).rotation.x = -PI / 2 # gaga
	for sx in [-1.0, 1.0]:
		_part(head, ball, Vector3(sx * 0.075, 0.15, -0.09), Vector3.ONE * 0.04, Color(0.05, 0.05, 0.05))
	if not chick:
		_part(head, ball, Vector3(0, 0.24, -0.02), Vector3(0.05, 0.1, 0.14), Color(0.85, 0.12, 0.1)) # ibik
		_part(head, ball, Vector3(0, 0.03, -0.12), Vector3(0.05, 0.08, 0.05), Color(0.85, 0.12, 0.1))
	add_to_group("chickens")
	add_to_group("enemies")
	scale = Vector3.ONE * (0.5 if chick else rng.randf_range(0.9, 1.15))
	target = position
	wait = rng.randf_range(0.0, 3.0)
	t = rng.randf() * 10.0


func _pick(from: Vector3, away: Vector3, dist: float) -> void:
	var dir := away if away != Vector3.ZERO else Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
	var p := from + dir.normalized().rotated(Vector3.UP, rng.randf_range(-0.6, 0.6)) * dist
	p.x = clampf(p.x, -HALF, HALF)
	p.z = clampf(p.z, -HALF, HALF)
	if Vector2(p.x, p.z).length() < KEEP_OUT:
		p = Vector3(p.x, 0, p.z).normalized() * KEEP_OUT if p.length() > 0.1 else Vector3(KEEP_OUT, 0, 0)
	target = Vector3(p.x, 0, p.z)


## Patlama ya da oyuncu: from noktasından uzağa koşar.
func flee(from: Vector3) -> void:
	scare = 1.6
	wait = 0.0
	_pick(position, position - Vector3(from.x, 0, from.z), rng.randf_range(5.0, 8.0))


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
	var moving := to.length() > 0.15
	if moving:
		var spd := 5.0 if scare > 0.0 else 0.9
		position += to.normalized() * minf(spd * dt, to.length())
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), minf(dt * 10.0, 1.0))
	else:
		wait -= dt
		if wait <= 0.0:
			wait = rng.randf_range(1.5, 5.0)
			_pick(position, Vector3.ZERO, rng.randf_range(1.0, 4.0))
	var run := scare > 0.0 and moving
	body.position.y = absf(sin(t * (22.0 if run else 9.0))) * (0.07 if run else 0.025) if moving else 0.0
	# dururken ara ara yere eğilip gagalar; yürürken başı ileri geri sallanır
	var peck := maxf(sin(t * 1.3 + position.x), 0.0) * absf(sin(t * 9.0))
	head.rotation.x = sin(t * 9.0) * 0.12 if moving else -peck * 0.9
	for i in 2:
		wings[i].rotation.z = (1.0 if i == 0 else -1.0) * (absf(sin(t * 28.0)) * 1.1 if run else 0.0)
