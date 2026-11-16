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
var light: OmniLight3D
var smoke: CPUParticles3D

const Fx := preload("res://explosion.gd")


func _piece(m: PrimitiveMesh, c: Color, y: float, metal := 0.6) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.metallic = metal; mat.roughness = 0.4
	mi.material_override = mat
	mi.position.z = -y # +y: burun tarafı
	mi.rotation.x = -PI / 2 # uzun eksen uçuş yönünde
	add_child(mi)
	return mi


func _ready() -> void:
	spd = SPEED * shooter.ch.get("throw_mult", 1.0) * (0.8 if big else 1.0)
	var up := Vector3.UP if abs(dir.y) < 0.99 else Vector3.FORWARD
	look_at(global_position + dir, up)

	if big: # top gülle
		var ball := SphereMesh.new()
		ball.radius = 0.22; ball.height = 0.44
		_piece(ball, Color(0.2, 0.2, 0.22), 0.0)
	else: # roket: gövde + sivri burun + beyaz şerit + lüle + dört kanat
		var tube := CylinderMesh.new()
		tube.top_radius = 0.06; tube.bottom_radius = 0.06; tube.height = 0.3
		_piece(tube, Color(0.75, 0.2, 0.15), 0.0)
		var nose := CylinderMesh.new()
		nose.top_radius = 0.0; nose.bottom_radius = 0.06; nose.height = 0.15
		_piece(nose, Color(0.9, 0.9, 0.88), 0.225, 0.2)
		var band := CylinderMesh.new()
		band.top_radius = 0.064; band.bottom_radius = 0.064; band.height = 0.04
		_piece(band, Color(0.9, 0.9, 0.88), 0.08, 0.2)
		var noz := CylinderMesh.new()
		noz.top_radius = 0.035; noz.bottom_radius = 0.055; noz.height = 0.06
		_piece(noz, Color(0.12, 0.12, 0.14), -0.18)
		var fin := PrismMesh.new()
		fin.size = Vector3(0.1, 0.14, 0.012)
		fin.left_to_right = 0.0 # dik kenar gövdede, eğik kenar öne bakar
		for i in 4:
			var f := _piece(fin, Color(0.25, 0.25, 0.28), -0.1)
			f.rotate_z(i * PI / 2)
			f.position += f.basis.x * 0.1
	for layer in [[0.1, Color(2.5, 2.2, 1.4, 1.0)], [0.19, Color(1.0, 0.45, 0.05, 0.5)]]: # çekirdek 1'in üstünde: ışıma yakalar
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

	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.15)
	light.light_energy = 3.0
	light.omni_range = 4.0
	add_child(light)

	# Alev izi: namluda başlarsa atanın kamerasını kapatır; _physics_process açar.
	fire = Fx.parts(Fx.quad("glow", 0.42), 48, 0.3, 0.5, 1.5, [Color(1.0, 0.62, 0.2, 0.55), Color(1.0, 0.35, 0.05, 0.4), Color(0.6, 0.1, 0.0, 0.0)], 1.0, 0.3, false)
	fire.emitting = false
	fire.local_coords = false
	fire.direction = Vector3(0, 0, 1)
	fire.spread = 20.0
	fire.position.z = 0.5
	add_child(fire)
	# Duman izi dünyaya bağlı: roket patlayıp silinince havada asılı kalıp dağılır.
	smoke = Fx.parts(Fx.quad("puff", 1.0), 56, 1.1, 0.1, 0.5, [Color(0.5, 0.35, 0.2, 0.0), Color(0.42, 0.4, 0.38, 0.55), Color(0.55, 0.54, 0.52, 0.0)], 0.35, 1.0, false)
	smoke.emitting = false
	smoke.gravity = Vector3(0, 0.6, 0)
	smoke.transform = global_transform
	# Yayıcı karede ~0.5 m yol alır: uçuş ekseninde uzun kutudan çıksın, iz boncuk boncuk olmasın.
	for p in [fire, smoke]:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(0.03, 0.03, 0.28)
	Fx.drop(self, smoke, 1.2)


func _physics_process(dt: float) -> void:
	if done:
		return
	life -= dt
	fire.emitting = life < 2.93 # ~2 m sonra iz başlar
	smoke.emitting = fire.emitting
	smoke.position = global_position - dir * 0.5
	light.light_energy = 2.4 + randf() * 1.6 # alev titrer
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
