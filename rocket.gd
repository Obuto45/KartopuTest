extends Node3D
## Roket her makinede görsel olarak uçar. Çarpışmaya yalnızca atanın kopyası karar verir
## ve patlamayı herkese yayınlar -> herkes patlamayı aynı yerde görür.

const SPEED := 30.0
const HIT_RADIUS := 0.55 # oyuncu gövdesine çarpma toleransı

var shooter: Node3D
var dir := Vector3.FORWARD
var life := 3.0
var done := false
var fire: CPUParticles3D
var spd := SPEED
var big := false # gülle: iri ve ağır


func _ready() -> void:
	spd = SPEED * shooter.ch.get("throw_mult", 1.0) * (0.8 if big else 1.0)
	var up := Vector3.UP if abs(dir.y) < 0.99 else Vector3.FORWARD
	look_at(global_position + dir, up)

	# Roket gövdesi (uzun ekseni uçuş yönünde) + arkasında alev topu ve alev izi.
	var shell := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.07; cm.height = 0.42
	shell.mesh = cm
	shell.rotation.x = PI / 2
	var sm0 := StandardMaterial3D.new()
	sm0.albedo_color = Color(0.2, 0.2, 0.22) if big else Color(0.75, 0.2, 0.15)
	sm0.metallic = 0.6; sm0.roughness = 0.4
	shell.material_override = sm0
	add_child(shell)
	if big:
		cm.radius = 0.22; cm.height = 0.44 # top gülle
	for layer in [[0.12, Color(1.0, 0.95, 0.6, 1.0)], [0.2, Color(1.0, 0.45, 0.05, 0.55)]]:
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = layer[0]; s.height = layer[0] * 2
		mi.mesh = s
		var m := StandardMaterial3D.new()
		m.albedo_color = layer[1]
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position.z = 0.25 # roketin arkasında
		add_child(mi)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.15)
	light.light_energy = 3.0
	light.omni_range = 4.0
	add_child(light)

	fire = CPUParticles3D.new()
	fire.emitting = false # namluda başlarsa atanın kamerasını kapatır; _physics_process açar
	fire.amount = 60
	fire.lifetime = 0.4
	fire.local_coords = false
	fire.direction = Vector3(0, 0, 1)
	fire.spread = 25.0
	fire.initial_velocity_min = 0.5
	fire.initial_velocity_max = 1.5
	fire.gravity = Vector3(0, 2.0, 0) # alev yukarı kıvrılır
	fire.scale_amount_min = 0.8
	fire.scale_amount_max = 1.4
	var ramp := Gradient.new() # sarı -> turuncu -> sönük kırmızı
	ramp.set_color(0, Color(1.0, 0.75, 0.2, 1.0))
	ramp.set_color(1, Color(0.6, 0.1, 0.0, 0.0))
	ramp.add_point(0.4, Color(1.0, 0.4, 0.05, 0.7))
	fire.color_ramp = ramp
	var sm := SphereMesh.new()
	sm.radius = 0.09; sm.height = 0.18
	var smat := StandardMaterial3D.new()
	smat.vertex_color_use_as_albedo = true # renk rampası parçacıklara uygulansın
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = smat
	fire.mesh = sm
	add_child(fire)


func _physics_process(dt: float) -> void:
	if done:
		return
	life -= dt
	fire.emitting = life < 2.93 # ~2 m sonra iz başlar
	var from := global_position
	var to := from + dir * spd * dt
	var hit = null
	if life <= 0.0:
		hit = from
	# Oyuncular: kapsülü 3 noktalı küre zinciriyle yakla, ince ışın içinden geçmesin.
	if hit == null:
		for p in get_tree().get_nodes_in_group("players"):
			if p == shooter or p.hp <= 0:
				continue
			# Kalkanlı oyuncu: kalkan küresinin yüzeyinde patla.
			var k: float = 1.0 if p.shield_on else p.size_k # Devleş / Ufal: vurulacak gövde de büyür, küçülür
			var pts := [0.95] if p.shield_on else [0.45, 0.95, 1.6]
			var rad: float = p.SHIELD_R if p.shield_on else HIT_RADIUS * k
			for h in pts:
				var c: Vector3 = p.global_position + Vector3(0, h * k, 0)
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
