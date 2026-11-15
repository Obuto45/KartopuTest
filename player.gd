extends CharacterBody3D
## Silindir gövde + yuvarlak kafa. Her oyuncu kendi hareketinin sahibi (client-authoritative):
## pozisyon 60 Hz unreliable gider, diğer tarafta yumuşatılır -> girişte gecikme hissi yok.

const RocketScript := preload("res://rocket.gd")
const ExplosionScript := preload("res://explosion.gd")
const SPEED := 7.0
const ACCEL := 60.0 # yerde hızlanma (m/s²)
const FRICTION := 45.0 # yerde tuş yokken yavaşlama
const AIR_ACCEL := 16.0 # havada kontrol (momentum korunur)
const JUMP := 8.5 # ~1.4 m zıplama
const AIR_JUMP := 7.5 # çift zıplama
const GRAVITY := 26.0
const FALL_MULT := 1.6 # düşerken daha hızlı (oyun hissi)
const MAX_FALL := 45.0
const DASH_SPEED := 20.0
const DASH_TIME := 0.15
const DASH_CD := 0.9
const MAX_HP := 100
const DAMAGE := 20 # 5 isabette ölüm
const THROW_CD := 0.8 # roket atış aralığı
const SHIELD_CD := 8.0
const SHIELD_R := 1.25
const BLAST_RADIUS := 2.5 # patlama bu mesafedekilere hasar verir

var spawn_pos := Vector3.ZERO
var rocket_n := 0
var flash := 0.0 # hasar efekti süresi
var body_mat: StandardMaterial3D
var base_col: Color
var hp := MAX_HP
var cd := 0.0
var slot := 1 # 1 = roketatar, 2 = kalkan
var shield_on := false
var shield_cd := 0.0
var shield_mesh: MeshInstance3D
var gun: MeshInstance3D
var air_jumps := 1
var dash_t := 0.0
var dash_cd := 0.0
var walk_t := 0.0

var vis: Node3D
var look: Node3D # kafa / kamera pivotu (pitch)
var cam: Camera3D
var leg_l: Node3D
var leg_r: Node3D

var net_pos := Vector3.ZERO
var net_yaw := 0.0
var net_pitch := 0.0
var net_speed := 0.0


func _mesh(parent: Node, m: Mesh, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _ready() -> void:
	add_to_group("players")
	position = spawn_pos
	net_pos = spawn_pos

	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.9
	cs.shape = cap
	cs.position.y = 0.95
	add_child(cs)

	var col := Color.from_hsv(fmod(float(get_multiplayer_authority()) * 0.137, 1.0), 0.75, 0.9)
	vis = Node3D.new()
	add_child(vis)

	var body := CylinderMesh.new()
	body.top_radius = 0.36; body.bottom_radius = 0.38; body.height = 0.95
	base_col = col
	body_mat = _mesh(vis, body, Vector3(0, 1.05, 0), col).material_override

	look = Node3D.new()
	look.position.y = 1.7
	vis.add_child(look)
	var head := SphereMesh.new()
	head.radius = 0.3; head.height = 0.6
	_mesh(look, head, Vector3.ZERO, Color(1.0, 0.85, 0.7))
	var eye := SphereMesh.new()
	eye.radius = 0.05; eye.height = 0.1
	_mesh(look, eye, Vector3(-0.11, 0.06, -0.27), Color.BLACK)
	_mesh(look, eye, Vector3(0.11, 0.06, -0.27), Color.BLACK)

	var leg := CylinderMesh.new()
	leg.top_radius = 0.11; leg.bottom_radius = 0.1; leg.height = 0.58
	leg_l = Node3D.new(); leg_l.position = Vector3(-0.17, 0.58, 0); vis.add_child(leg_l)
	leg_r = Node3D.new(); leg_r.position = Vector3(0.17, 0.58, 0); vis.add_child(leg_r)
	_mesh(leg_l, leg, Vector3(0, -0.29, 0), col.darkened(0.4))
	_mesh(leg_r, leg, Vector3(0, -0.29, 0), col.darkened(0.4))

	if is_multiplayer_authority():
		cam = Camera3D.new()
		cam.fov = 80
		cam.near = 0.05
		look.add_child(cam)
		cam.current = true
		for mi in vis.find_children("*", "MeshInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY # kendini görme, gölgen kalsın

	# Roketatar: kafa pivotuna bağlı, sağ altta (herkes görür).
	var tube := CylinderMesh.new()
	tube.top_radius = 0.09; tube.bottom_radius = 0.09; tube.height = 0.8
	gun = _mesh(look, tube, Vector3(0.28, -0.25, -0.35), Color(0.25, 0.3, 0.2))
	gun.rotation.x = -PI / 2
	var tip := CylinderMesh.new()
	tip.top_radius = 0.11; tip.bottom_radius = 0.11; tip.height = 0.08
	_mesh(gun, tip, Vector3(0, 0.4, 0), Color(0.1, 0.1, 0.1))

	# Kalkan: yarı saydam mavi küre, içeriden de görünsün.
	var sph := SphereMesh.new()
	sph.radius = SHIELD_R; sph.height = SHIELD_R * 2
	shield_mesh = _mesh(self, sph, Vector3(0, 0.95, 0), Color(0.3, 0.7, 1.0, 0.25))
	var smat: StandardMaterial3D = shield_mesh.material_override
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shield_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shield_mesh.visible = false


func _unhandled_input(e: InputEvent) -> void:
	if is_multiplayer_authority() and e is InputEventMouseMotion \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= e.relative.x * 0.0025
		look.rotation.x = clamp(look.rotation.x - e.relative.y * 0.0025, -1.45, 1.45)


func _physics_process(dt: float) -> void:
	if is_multiplayer_authority():
		_local(dt)
	else:
		_remote(dt)
	_animate(dt)


func _local(dt: float) -> void:
	var alive := hp > 0
	var active := alive and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var on_floor := is_on_floor()
	if on_floor:
		air_jumps = 1
	cd -= dt
	dash_cd -= dt
	shield_cd -= dt

	var dir := Vector3.ZERO
	if active:
		var iv := Input.get_vector("left", "right", "fwd", "back")
		dir = (transform.basis * Vector3(iv.x, 0, iv.y)).normalized()
		if Input.is_action_just_pressed("jump"):
			if on_floor:
				velocity.y = JUMP
			elif air_jumps > 0: # çift zıplama
				air_jumps -= 1
				velocity.y = AIR_JUMP
		if Input.is_action_just_pressed("dash") and dash_cd <= 0.0: # yerde ve havada
			var d := dir if dir != Vector3.ZERO else -transform.basis.z
			velocity = d * DASH_SPEED
			dash_t = DASH_TIME
			dash_cd = DASH_CD
			Sfx.play2d(Sfx.whoosh, -2.0)
		if Input.is_action_just_pressed("slot1"):
			_set_slot(1)
		if Input.is_action_just_pressed("slot2"):
			_set_slot(2)
			_try_shield()

	if dash_t > 0.0:
		dash_t -= dt # dash sırasında yerçekimi/sürtünme yok
	else:
		if not on_floor:
			var g := GRAVITY * (FALL_MULT if velocity.y < 0.0 else 1.0)
			velocity.y = max(velocity.y - g * dt, -MAX_FALL)
		var a := AIR_ACCEL
		if on_floor:
			a = ACCEL if dir != Vector3.ZERO else FRICTION
		var hv := Vector2(velocity.x, velocity.z).move_toward(Vector2(dir.x, dir.z) * SPEED, a * dt)
		velocity.x = hv.x
		velocity.z = hv.y

	if active and slot == 2 and Input.is_action_just_pressed("throw"):
		_try_shield()
	if active and slot == 1 and Input.is_action_pressed("throw") and cd <= 0.0:
		cd = THROW_CD
		var b := cam.global_basis
		var target := cam.global_position - b.z * 200.0
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, target)
		q.exclude = [get_rid()]
		var r := get_world_3d().direct_space_state.intersect_ray(q)
		if r:
			target = r.position
		# Namlu ucundan çık, nişangahın gösterdiği noktaya git.
		var origin := cam.global_position + b.x * 0.28 - b.y * 0.25 - b.z * 0.8
		rocket_n += 1
		fire_rocket.rpc(origin, (target - origin).normalized(), rocket_n)

	move_and_slide()
	if global_position.y < -20.0:
		global_position = spawn_pos
		velocity = Vector3.ZERO
	sync_state.rpc(global_position, rotation.y, look.rotation.x, Vector2(velocity.x, velocity.z).length(), slot)


@rpc("authority", "unreliable_ordered")
func sync_state(p: Vector3, yaw: float, pitch: float, spd: float, s: int) -> void:
	net_pos = p
	net_yaw = yaw
	net_pitch = pitch
	net_speed = spd
	if s != slot:
		_set_slot(s)


func _set_slot(s: int) -> void:
	slot = s
	gun.visible = s == 1


func _try_shield() -> void:
	if not shield_on and shield_cd <= 0.0:
		shield_cd = SHIELD_CD
		set_shield.rpc(true)


@rpc("authority", "call_local", "reliable")
func set_shield(on: bool) -> void:
	if on == shield_on:
		return
	shield_on = on
	shield_mesh.visible = on
	var pos := global_position + Vector3.UP
	Sfx.play3d(Sfx.shield_up if on else Sfx.shield_break, pos, 0.0)


func _remote(dt: float) -> void:
	var k: float = min(1.0, dt * 18.0)
	if global_position.distance_to(net_pos) > 6.0:
		global_position = net_pos # ışınlanma (respawn)
	else:
		global_position = global_position.lerp(net_pos, k)
	rotation.y = lerp_angle(rotation.y, net_yaw, k)
	look.rotation.x = lerp(look.rotation.x, net_pitch, k)


func _animate(dt: float) -> void:
	var spd: float = Vector2(velocity.x, velocity.z).length() if is_multiplayer_authority() else net_speed
	var amp: float = clamp(spd / SPEED, 0.0, 1.0) * 0.7
	walk_t += dt * spd * 2.0
	leg_l.rotation.x = sin(walk_t) * amp
	leg_r.rotation.x = -sin(walk_t) * amp
	vis.rotation.z = lerp(vis.rotation.z, 1.5 if hp <= 0 else 0.0, 0.1) # ölünce devril
	flash = max(flash - dt, 0.0)
	body_mat.albedo_color = base_col.lerp(Color(1, 0.1, 0.1), flash / 0.35)
	body_mat.emission_enabled = flash > 0.0
	body_mat.emission = Color(1, 0, 0) * (flash / 0.35)


@rpc("authority", "call_local", "reliable")
func fire_rocket(origin: Vector3, dir: Vector3, n: int) -> void:
	var r: Node3D = RocketScript.new()
	r.name = "R%d_%d" % [get_multiplayer_authority(), n]
	r.shooter = self
	r.dir = dir
	r.position = origin
	get_parent().get_parent().add_child(r)
	Sfx.play3d(Sfx.fire, origin, -2.0)


## Atanın makinesi çarpışmayı bulunca herkese yayınlar.
@rpc("authority", "call_local", "reliable")
func explode(rocket_name, pos: Vector3) -> void:
	var world := get_parent().get_parent()
	var r := world.get_node_or_null(NodePath(str(rocket_name)))
	if r:
		r.queue_free()
	var fx: Node3D = ExplosionScript.new()
	fx.position = pos
	world.add_child(fx)
	Sfx.play3d(Sfx.boom, pos, 4.0)
	# Hasarı her makine yalnızca kendi oyuncusu için uygular.
	var me = get_parent().get_node_or_null(str(multiplayer.get_unique_id()))
	if me == null or me == self or me.hp <= 0:
		return
	var c: Vector3 = me.global_position + Vector3(0, 0.95, 0)
	if c.distance_to(pos) < BLAST_RADIUS:
		me.velocity += (c - pos).normalized() * 7.0 + Vector3.UP * 3.0 # sarsıntı / itme
		if me.shield_on:
			me.set_shield.rpc(false) # kalkan tek roketi emer
		else:
			me.take_hit()


## Roket kurbanın kendi makinesinde hasar uygular.
func take_hit() -> void:
	set_hp.rpc(hp - DAMAGE)
	if hp <= 0:
		get_node("/root/Main").report_death.rpc_id(1, get_multiplayer_authority())


@rpc("authority", "call_local", "reliable")
func set_hp(v: int) -> void:
	if v < hp:
		flash = 0.35
		if is_multiplayer_authority():
			Sfx.play2d(Sfx.hurt)
		else:
			Sfx.play3d(Sfx.hurt, global_position + Vector3.UP)
	hp = max(v, 0)


func respawn() -> void:
	hp = MAX_HP
	shield_on = false
	shield_mesh.visible = false
	shield_cd = 0.0
	dash_cd = 0.0
	velocity = Vector3.ZERO
	global_position = spawn_pos
	net_pos = spawn_pos
