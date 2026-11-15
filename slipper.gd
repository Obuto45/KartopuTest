extends Node3D
## Güdümlü mermi: Terlikli Anne'nin terliği ve Kahvehane Dayısı'nın seken okey taşı.
## Her makinede aynı hedefi kovalar; isabete yalnızca hedefin kendi makinesi karar verir
## (hasar modeliyle aynı: herkes kendi oyuncusuna uygular).

const BOUNCE_R := 12.0 # okey taşı bu mesafedeki sıradaki oyuncuya seker

var thrower: Node3D
var target: Node3D
var dir := Vector3.FORWARD
var life := 4.0
var kind := "slipper" # ya da "tile"
var speed := 13.0
var turn := 3.2 # sn başına dönüş; düşük olduğu için keskin dönüşle terlikten kaçılabilir
var dmg := 30
var bounces := 0 # isabetten sonra kaç kez daha seker
var hit := [] # vurulanlar: aynı kişiye iki kez sekmez
var body: Node3D


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
	body = Node3D.new()
	add_child(body)
	if kind == "tile": # krem rengi okey taşı, üstünde kırmızı sayı lekesi
		speed = 22.0; turn = 8.0; dmg = 20; bounces = 2
		var b := BoxMesh.new()
		b.size = Vector3(0.2, 0.28, 0.07)
		_part(b, Color(0.96, 0.92, 0.8))
		var dot := BoxMesh.new()
		dot.size = Vector3(0.08, 0.12, 0.075)
		_part(dot, Color(0.85, 0.1, 0.1))
	else:
		var b := BoxMesh.new()
		b.size = Vector3(0.16, 0.05, 0.36) # taban
		_part(b, Color(0.2, 0.45, 0.9))
		var t := TorusMesh.new() # üstteki bant
		t.inner_radius = 0.06; t.outer_radius = 0.085
		_part(t, Color(0.95, 0.95, 0.95), Vector3(0, 0.03, -0.06)).rotation.z = PI / 2


func _physics_process(dt: float) -> void:
	life -= dt
	if life <= 0.0 or not is_instance_valid(target) or target.hp <= 0:
		queue_free()
		return
	var aim: Vector3 = target.global_position + Vector3.UP * 1.0
	var to := aim - global_position
	dir = dir.lerp(to.normalized(), minf(turn * dt, 1.0)).normalized()
	global_position += dir * speed * dt
	body.rotate_x(-dt * 18.0) # takla atarak gelsin
	if to.length() > 0.8:
		return
	Sfx.play3d(Sfx.hurt, aim, 2.0)
	if target.is_multiplayer_authority(): # vurulan, kendi makinesinde
		target.velocity += dir * 5.0 + Vector3.UP * 2.0
		if target.shield_on:
			target.set_shield.rpc(false)
		else:
			target.take_hit(dmg)
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
