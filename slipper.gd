extends Node3D
## Güdümlü mermi (characters.gd'deki "homing" verisi): bumerang, seken kart, futbol topu.
## Her makinede aynı hedefi kovalar; isabete yalnızca hedefin kendi makinesi karar verir
## (hasar modeliyle aynı: herkes kendi oyuncusuna uygular).

const BOUNCE_R := 12.0 # kart bu mesafedeki sıradaki oyuncuya seker

var thrower: Node3D
var target: Node3D
var dir := Vector3.FORWARD
var life := 4.0
var h: Dictionary # look, speed, turn, bounces + etki anahtarları (dmg, knock...)
var speed := 13.0
var turn := 3.2 # sn başına dönüş; düşükse keskin dönüşle kaçılabilir
var bounces := 0 # isabetten sonra kaç kez daha seker
var hit := [] # vurulanlar: aynı kişiye iki kez sekmez
var body: Node3D

const Fx := preload("res://explosion.gd")


func _part(m: Mesh, c: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mi.material_override = mat
	mi.position = pos
	body.add_child(mi)
	return mi


func _ready() -> void:
	speed = h.speed
	turn = h.turn
	bounces = h.get("bounces", 0)
	body = Node3D.new()
	add_child(body)
	# Arkasında kısa, yumuşak ışık izi: havada dönen mermi kolay seçilsin.
	var tc: Color = {"card": Color(1.0, 0.3, 0.3), "ball": Color(0.85, 0.92, 1.0)}.get(h.look, Color(1.0, 0.7, 0.3))
	var trail := Fx.parts(Fx.quad("glow", 0.34), 14, 0.35, 0.0, 0.2, [Color(tc, 0.5), Color(tc, 0.0)], 1.0, 0.25, false)
	trail.local_coords = false
	add_child(trail)
	match h.look:
		"card": # oyun kartı: beyaz yüz, kırmızı karo
			var b := BoxMesh.new()
			b.size = Vector3(0.22, 0.32, 0.012)
			_part(b, Color(0.97, 0.97, 0.95))
			var dot := BoxMesh.new()
			dot.size = Vector3(0.08, 0.08, 0.016)
			_part(dot, Color(0.85, 0.1, 0.1)).rotation.z = PI / 4
		"ball": # futbol topu
			var b := SphereMesh.new()
			b.radius = 0.2; b.height = 0.4
			_part(b, Color(0.95, 0.95, 0.95))
			var patch := SphereMesh.new()
			patch.radius = 0.09; patch.height = 0.18
			for p in [Vector3(0.14, 0.05, 0.1), Vector3(-0.12, 0.1, -0.1), Vector3(0, -0.16, 0.08), Vector3(0.02, 0.15, -0.12)]:
				_part(patch, Color(0.1, 0.1, 0.1), p)
		_: # bumerang: iki kollu, ahşap
			var arm := BoxMesh.new()
			arm.size = Vector3(0.07, 0.03, 0.34)
			for a in [0.6, -0.6]:
				var mi := _part(arm, Color(0.72, 0.48, 0.25), Vector3(sin(a) * 0.15, 0, cos(a) * 0.15 - 0.1))
				mi.rotation.y = a


func _physics_process(dt: float) -> void:
	life -= dt
	if life <= 0.0 or not is_instance_valid(thrower) or not is_instance_valid(target) or target.hp <= 0:
		queue_free()
		return
	turn += h.get("turn_gain", 0.0) * dt # zamanla keskinleşir: hedefin etrafında sonsuza dek dönmesin
	var aim: Vector3 = target.global_position + Vector3.UP * 1.0
	var to := aim - global_position
	dir = dir.lerp(to.normalized(), minf(turn * dt, 1.0)).normalized()
	global_position += dir * speed * dt
	if h.look == "ball":
		body.rotate_x(-dt * 18.0) # top takla atar
	else:
		body.rotate_y(dt * 18.0) # bumerang ve kart yatay döner
	if to.length() > 0.8:
		return
	Sfx.play3d(Sfx.hurt, aim, 2.0)
	if target.is_multiplayer_authority(): # vurulan, kendi makinesinde
		thrower.affect(target, h, global_position - dir)
	hit.append(target)
	var next: Node3D = null
	if bounces > 0:
		# shortcut: sıradaki hedefi her makine kendi gördüğü konumlardan seçer; iki aday
		# neredeyse eşit uzaklıktaysa makineler farklı seçebilir. Sorun olursa hedef listesini atan belirlesin.
		var bd := BOUNCE_R
		for p in target.get_parent().get_children():
			var d: float = p.global_position.distance_to(target.global_position)
			if p != thrower and p.hp > 0 and not hit.has(p) and d < bd:
				next = p
				bd = d
	if next == null:
		queue_free()
		return
	bounces -= 1
	target = next
	life = 3.0
