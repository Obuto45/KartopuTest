extends Node3D
## Roket her makinede görsel olarak uçar. Çarpışmaya yalnızca atanın kopyası karar verir
## ve patlamayı herkese yayınlar -> herkes patlamayı aynı yerde görür.

const SPEED := 30.0
const HIT_RADIUS := 0.55 # oyuncu gövdesine çarpma toleransı

var shooter: Node3D
var dir := Vector3.FORWARD
var life := 3.0
var done := false


func _ready() -> void:
	var up := Vector3.UP if abs(dir.y) < 0.99 else Vector3.FORWARD
	look_at(global_position + dir, up)

	var body := CylinderMesh.new()
	body.top_radius = 0.07; body.bottom_radius = 0.07; body.height = 0.6
	var nose := CylinderMesh.new()
	nose.top_radius = 0.0; nose.bottom_radius = 0.07; nose.height = 0.18
	for part in [[body, -0.0, Color(0.35, 0.4, 0.3)], [nose, -0.39, Color(0.8, 0.15, 0.1)]]:
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.rotation.x = -PI / 2 # silindiri -Z yönüne yatır
		mi.position.z = part[1]
		var m := StandardMaterial3D.new()
		m.albedo_color = part[2]
		mi.material_override = m
		add_child(mi)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 2.0
	light.omni_range = 3.0
	light.position.z = 0.4
	add_child(light)

	var smoke := CPUParticles3D.new()
	smoke.amount = 40
	smoke.lifetime = 0.6
	smoke.local_coords = false
	smoke.position.z = 0.35
	smoke.direction = Vector3(0, 0, 1)
	smoke.spread = 15.0
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 2.0
	smoke.gravity = Vector3(0, 0.5, 0)
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.2
	var sm := SphereMesh.new()
	sm.radius = 0.08; sm.height = 0.16
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.75, 0.75, 0.75, 0.6)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = smat
	smoke.mesh = sm
	add_child(smoke)


func _physics_process(dt: float) -> void:
	if done:
		return
	life -= dt
	var from := global_position
	var to := from + dir * SPEED * dt
	var hit = null
	if life <= 0.0:
		hit = from
	# Oyuncular: kapsülü 3 noktalı küre zinciriyle yakla, ince ışın içinden geçmesin.
	if hit == null:
		for p in get_tree().get_nodes_in_group("players"):
			if p == shooter or p.hp <= 0:
				continue
			# Kalkanlı oyuncu: kalkan küresinin yüzeyinde patla.
			var pts := [0.95] if p.shield_on else [0.45, 0.95, 1.6]
			var rad: float = p.SHIELD_R if p.shield_on else HIT_RADIUS
			for h in pts:
				var c: Vector3 = p.global_position + Vector3(0, h, 0)
				var cp := Geometry3D.get_closest_point_to_segment(c, from, to)
				if cp.distance_to(c) < rad:
					hit = cp
					break
			if hit != null:
				break
	if hit == null:
		var q := PhysicsRayQueryParameters3D.create(from, to)
		if is_instance_valid(shooter):
			q.exclude = [shooter.get_rid()]
		var r := get_world_3d().direct_space_state.intersect_ray(q)
		if r:
			hit = r.position
	if hit == null:
		global_position = to
		return
	done = true
	if is_instance_valid(shooter) and shooter.is_multiplayer_authority():
		visible = false
		shooter.explode.rpc(name, hit)
	else:
		queue_free() # patlamayı atanın yayını gösterecek
