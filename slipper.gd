extends Node3D
## Terlikli Anne'nin güdümlü terliği. Her makinede aynı hedefi kovalar; isabete yalnızca
## hedefin kendi makinesi karar verir (hasar modeliyle aynı: herkes kendi oyuncusuna uygular).

const SPEED := 13.0
const TURN := 3.2 # sn başına dönüş; düşük olduğu için keskin dönüşle kaçılabilir
const DMG := 30

var thrower: Node3D
var target: Node3D
var dir := Vector3.FORWARD
var life := 4.0
var sole: Node3D


func _ready() -> void:
	sole = Node3D.new()
	add_child(sole)
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.16, 0.05, 0.36) # taban
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.45, 0.9)
	m.material_override = mat
	sole.add_child(m)
	var strap := MeshInstance3D.new() # üstteki bant
	var t := TorusMesh.new()
	t.inner_radius = 0.06; t.outer_radius = 0.085
	strap.mesh = t
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.95, 0.95, 0.95)
	strap.material_override = smat
	strap.position = Vector3(0, 0.03, -0.06)
	strap.rotation.z = PI / 2
	sole.add_child(strap)


func _physics_process(dt: float) -> void:
	life -= dt
	if life <= 0.0 or not is_instance_valid(target) or target.hp <= 0:
		queue_free()
		return
	var aim: Vector3 = target.global_position + Vector3.UP * 1.0
	var to := aim - global_position
	dir = dir.lerp(to.normalized(), minf(TURN * dt, 1.0)).normalized()
	global_position += dir * SPEED * dt
	sole.rotate_x(-dt * 18.0) # takla atarak gelsin
	if to.length() > 0.8:
		return
	queue_free()
	Sfx.play3d(Sfx.hurt, aim, 2.0)
	if target.is_multiplayer_authority(): # vurulan, kendi makinesinde
		target.velocity += dir * 5.0 + Vector3.UP * 2.0
		if target.shield_on:
			target.set_shield.rpc(false)
		else:
			target.take_hit(DMG)
