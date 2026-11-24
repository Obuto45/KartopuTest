extends CharacterBody3D
## TD yaratığı. Host simüle eder (basit yönelme, navmesh yok); istemcide td.gd'nin toplu yayınından
## gelen konuma yumuşatılır. Can, hasar sayısı, ölüm: td.gd'nin rpc'leri her makinede apply_hit çağırır.
## Mermiler için okunur alanlar: hp, radius, height, global_position (ayak noktası).
## Çarpışma katmanı 2: oyuncular içinden geçer (sürü oyuncuyu hapsetmesin), ışınlar yine isabet eder.

const Balance := preload("res://balance.gd")
const Fx := preload("res://explosion.gd")
const Ragdoll := preload("res://ragdoll.gd")
const TICK := 0.2 # yapay zekâ karar aralığı (sn); kareler arası yalnızca yürür
const MODEL_SCALE := 0.72
const TOWER_R := 2.1
const STUCK_T := 1.5 # bu kadar ilerleyemezse: önündeki yapıya saldırır ya da yana kaçar
const SPIT_T := 0.45 # uzaktan atışın uçuş süresi (kaçılabilir)
const BAR_CODE := "shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
instance uniform float f = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 e = min(UV, 1.0 - UV) * vec2(12.0, 2.0);
	bool rim = min(e.x, e.y) < 0.22;
	ALBEDO = rim ? vec3(0.0) : (UV.x < f ? mix(vec3(0.9, 0.15, 0.1), vec3(0.3, 0.9, 0.3), f) : vec3(0.12));
	ALPHA = 0.9;
}"

static var _shared := {} # paylaşılan malzeme / ağ: 40 yaratık 40 kopya üretmesin

var eid := 0
var type := ""
var d: Dictionary # Balance.ENEMIES[type]
var hp := 1
var max_hp := 1
var dmg := 1
var radius := 0.4
var height := 1.9
var armor := 0
var bonus_armor := 0 # "armored" modifikatörü
var spd_k := 1.0 # hız çarpanı ("fast", üst sınırlı)
var elite := false
var money := 0 # ölünce verdiği para (mod / zorluk çarpanlı)
var tint_key := ""
var td: Node
var host := false
var model: Node3D
var meshes: Array
var anim: AnimationPlayer
var cur := ""
var run_anim := "Run"
var atk_anim := "Punch"
var bar: MeshInstance3D
var flash_t := 0.0
const EMBER := """shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never;
uniform float t = 0.0;
varying vec3 wp;
float h(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float vn(vec3 p) { // yumuşak değer gürültüsü
	vec3 i = floor(p); vec3 f = smoothstep(0.0, 1.0, fract(p));
	return mix(mix(mix(h(i), h(i + vec3(1,0,0)), f.x), mix(h(i + vec3(0,1,0)), h(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(h(i + vec3(0,0,1)), h(i + vec3(1,0,1)), f.x), mix(h(i + vec3(0,1,1)), h(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = vn(wp * 6.0) * 0.65 + vn(wp * 15.0) * 0.35;
	float c = t * 1.25 - 0.1; // yanma cephesi
	float edge = 1.0 - smoothstep(0.0, 0.07, abs(n - c));
	float burnt = step(n, c);
	ALBEDO = mix(vec3(0.06, 0.04, 0.03), vec3(1.0, 0.55, 0.15) * 4.0, edge);
	ALPHA = clamp(max(burnt, edge), 0.0, 1.0);
}"""
var model_scale := Vector3.ONE # doğma büyümesinin hedefi
var hit_tw: Tween # darbe sekmesi; üst üste vuruşta öncekini keser
var swing_t := 0.0 # > 0: vuruş animasyonu oynuyor
var stun_vis := 0.0 # > 0: sersem (sallanır, kafasında yıldızlar döner)
var stars: Node3D
var walk_t := 0.0
var moving := false
var net_pos := Vector3.ZERO
var net_vel := Vector3.ZERO # istemci: son iki eşitlemeden hız (ileri tahmin)
var net_yaw := 0.0
# Yalnızca host:
var tick_t := 0.0
var dir := Vector3.ZERO # yatay yürüme yönü (sıfır = duruyor)
var aim := 0.0 # bakılacak yön
var atk_cd := 0.0
var last_pos := Vector3.ZERO
var stuck_t := 0.0
var side := 0.0
var side_t := 0.0
var block: Node3D # yolu kesen, saldırılan yapı
var slow_t := 0.0
var slow_k := 1.0
# Açık dünya (Hikaye modu): aggro_r > 0 ise yaratık kendi kampında devriye gezer, oyuncu yaklaşınca saldırır.
var home_pos := Vector3.ZERO
var aggro_r := 0.0
var leash_r := 0.0
var camp_id := ""
var _aggro := false
var _patrol_t := 0.0
var _patrol_pt := Vector3.ZERO


## Paylaşılan kaynak: yoksa make ile üretir.
static func shared(k: String, make: Callable) -> Resource:
	if not _shared.has(k):
		_shared[k] = make.call()
	return _shared[k]


## Kameraya dönük can çubuğu (yapılar da kullanır). Doluluk: örnek başına "f".
static func make_bar(w: float, y: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = shared("bar%.1f" % w, func() -> Resource:
		var q := QuadMesh.new()
		q.size = Vector2(w, 0.13)
		var m := ShaderMaterial.new()
		m.shader = Shader.new()
		m.shader.code = BAR_CODE
		q.material = m
		return q)
	mi.position.y = y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false # ilk hasara kadar gizli: kalabalıkta ekran dolmasın
	return mi


## Dünyada yükselip sönen yazı (hasar sayısı, para).
static func float_text(world: Node, pos: Vector3, text: String, c: Color, px: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = px
	l.font_size = 48
	l.outline_size = 14
	l.modulate = c
	l.position = pos
	world.add_child(l)
	var tw := l.create_tween().set_parallel()
	l.position.x += randf_range(-0.15, 0.15)
	l.scale = Vector3.ONE * (1.8 if px > 0.01 else 1.3) # sayı büyük çıkıp oturur (kritikte daha çok)
	tw.tween_property(l, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(l, "position:y", pos.y + 1.1, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


static func spark_mesh() -> Mesh:
	return shared("spark", func() -> Resource:
		var s := SphereMesh.new()
		s.radius = 0.06; s.height = 0.12
		s.radial_segments = 4; s.rings = 2
		s.material = Fx.mat("spark")
		return s)


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 1
	host = multiplayer.is_server()
	d = Balance.ENEMIES[type]
	var s: float = d.scale * (1.25 if elite else 1.0)
	radius = 0.4 * s
	height = 1.9 * s
	armor = d.get("armor", 0) + bonus_armor
	tint_key = "tint" + type + ("E" if elite else "")
	max_hp = hp
	net_pos = position
	last_pos = position
	tick_t = randf() * TICK # kararlar karelere yayılsın
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = height
	cs.shape = cap
	cs.position.y = height * 0.5
	add_child(cs)

	model = load("res://models/chars/%s.glb" % d.model).instantiate()
	model.rotation.y = PI # modellerin önü +Z'ye bakıyor
	add_child(model)
	var tint: Color = Color(1.8, 1.5, 0.6) if elite else d.tint # elit: parlak
	var over := shared(tint_key, func() -> Resource: # çarpma karışımı + kenar ışığı + stilize dış çizgi
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
		m.albedo_color = tint
		var rim := ShaderMaterial.new()
		rim.shader = preload("res://shaders/char_rim.gdshader")
		rim.set_shader_parameter("rim_color", Color(1.0, 0.78, 0.25, 0.65) if elite else Color(1.0, 0.45, 0.32, 0.26))
		rim.set_shader_parameter("rim_power", 2.4 if elite else 3.4)
		var outline := ShaderMaterial.new()
		outline.shader = preload("res://shaders/outline.gdshader")
		outline.set_shader_parameter("width", 0.022 if elite else 0.015)
		outline.set_shader_parameter("color", Color(0.22, 0.12, 0.02, 1.0) if elite else Color(0.10, 0.05, 0.07, 1.0))
		rim.next_pass = outline
		m.next_pass = rim
		return m)
	meshes = model.find_children("*", "MeshInstance3D", true, false)
	for mi in meshes:
		mi.material_overlay = over
	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	for n in ["Idle", "Run", "Walk", "Victory"]: # dosyada döngü işareti yok
		if anim.has_animation(n):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	run_anim = "Run" if d.speed >= 4.5 or not anim.has_animation("Walk") else "Walk"
	atk_anim = d.get("anim", "Punch")
	bar = make_bar(clampf(0.9 * s, 0.8, 2.4), height + 0.45)
	add_child(bar)
	# Yerden büyüyerek çıkar.
	model_scale = Vector3.ONE * MODEL_SCALE * s
	model.scale = model_scale * 0.15
	create_tween().tween_property(model, "scale", model_scale, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _physics_process(dt: float) -> void:
	if hp <= 0:
		return
	if flash_t > 0.0:
		flash_t -= dt
		if flash_t <= 0.0:
			_overlay(_shared[tint_key])
	swing_t -= dt
	if host:
		_host(dt)
	else:
		global_position = net_pos if global_position.distance_squared_to(net_pos) > 36.0 else global_position.lerp(net_pos + net_vel * 0.1, minf(1.0, dt * 12.0))
		rotation.y = lerp_angle(rotation.y, net_yaw, minf(1.0, dt * 10.0))
	var want := "Idle"
	if td.state == "lost":
		want = "Victory"
	elif swing_t > 0.0:
		want = atk_anim
	elif moving:
		want = run_anim
	_sway(dt)
	if want != cur:
		cur = want
		anim.play(want, 0.15)
		# Adım hızı yürüme hızına uysun (koşu ~7, yürüyüş ~4,7 m/sn'ye göre çizilmiş).
		anim.speed_scale = clampf(d.speed / ((7.0 if want == "Run" else 4.7) * d.scale), 0.5, 2.2) if want == run_anim else 1.0


## Yürürken yana yalpalama, sersemken yalpalayıp dönen yıldızlar (yalnız görüntü: model düğümü).
func _sway(dt: float) -> void:
	walk_t += dt * (9.0 if moving else 0.0)
	var roll := sin(walk_t) * 0.05 if moving else 0.0
	var pitch := 0.0
	if stun_vis > 0.0:
		stun_vis -= dt
		var t := Time.get_ticks_msec() * 0.001
		roll = sin(t * 7.0) * 0.18
		pitch = cos(t * 5.0) * 0.1
		if stars:
			stars.rotate_y(dt * 5.0)
		if stun_vis <= 0.0 and stars:
			stars.queue_free()
			stars = null
	model.rotation.z = lerpf(model.rotation.z, roll, minf(1.0, dt * 10.0))
	model.rotation.x = lerpf(model.rotation.x, pitch, minf(1.0, dt * 10.0))


func stun_fx(t: float) -> void:
	stun_vis = maxf(stun_vis, t)
	if stars:
		return
	stars = Node3D.new()
	stars.position = Vector3.UP * (height + 0.15)
	add_child(stars)
	for i in 3:
		var l := Label3D.new()
		l.text = "★"
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 64
		l.pixel_size = 0.004
		l.outline_size = 10
		l.modulate = Color(1.0, 0.9, 0.25)
		l.position = Vector3(cos(i * TAU / 3.0), 0, sin(i * TAU / 3.0)) * radius * 0.8
		stars.add_child(l)


func _overlay(m: Material) -> void:
	for mi in meshes:
		mi.material_overlay = m


# ---------- Host: yapay zekâ ----------

func _host(dt: float) -> void:
	tick_t -= dt
	atk_cd -= dt
	slow_t -= dt
	if tick_t <= 0.0:
		tick_t += TICK
		_think()
	moving = dir != Vector3.ZERO
	var spd: float = d.speed * spd_k * (slow_k if slow_t > 0.0 else 1.0)
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * dt
	if moving or not is_on_floor():
		move_and_slide()
		if moving:
			aim = atan2(-dir.x, -dir.z)
	if td and td.has_method("_gy"):
		var gy: float = td._gy(global_position.x, global_position.z)
		if global_position.y < gy - 1.5:
			global_position.y = gy + 0.25
			velocity.y = 0.0
	rotation.y = lerp_angle(rotation.y, aim, minf(1.0, dt * 10.0))


func _think() -> void:
	if td.state != "fight":
		dir = Vector3.ZERO
		return
	# Açık dünya (Hikaye modu) yapay zekâsı: kamp çevresinde devriye, oyuncu yaklaşınca saldırı, uzaklaşınca kampa dönüş.
	if aggro_r > 0.0:
		var p := _nearest_player()
		var home_d := Vector2(global_position.x - home_pos.x, global_position.z - home_pos.z).length()
		if p:
			var pd := Vector2(global_position.x - p.global_position.x, global_position.z - p.global_position.z).length()
			var ph := Vector2(p.global_position.x - home_pos.x, p.global_position.z - home_pos.z).length()
			if not _aggro and pd <= aggro_r:
				_aggro = true
				for o in td.elist:
					if is_instance_valid(o) and o.get("camp_id") == camp_id:
						o._aggro = true
			elif _aggro and leash_r > 0.0 and ph > leash_r and home_d > leash_r * 0.75:
				_aggro = false
		else:
			_aggro = false
		if _aggro and p:
			var to_p := p.global_position - global_position
			to_p.y = 0.0
			var pd := to_p.length()
			var reach_p: float = d.range + radius + 0.45
			if pd <= reach_p:
				dir = Vector3.ZERO
				aim = atan2(-to_p.x, -to_p.z)
				stuck_t = 0.0
				if atk_cd <= 0.0:
					atk_cd = d.rate
					_attack(p, p.global_position)
				return
			var want_p := to_p / maxf(pd, 0.001)
			for o in td.elist:
				if o != self and is_instance_valid(o):
					var v: Vector3 = global_position - o.global_position
					var m: float = radius + o.radius + 0.35
					var l2 := v.x * v.x + v.z * v.z
					if l2 < m * m and l2 > 0.0001:
						var l := sqrt(l2)
						want_p += Vector3(v.x, 0, v.z) * ((m - l) / m / l * 1.4)
			dir = want_p.normalized()
			return
		# Sakin devriye: kamp noktası etrafında kısa yürüyüşler
		_patrol_t -= TICK
		if _patrol_t <= 0.0:
			_patrol_t = randf_range(2.2, 4.5)
			var ang := randf() * TAU
			var rad := randf_range(1.2, 5.0)
			_patrol_pt = home_pos + Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
		var to_h := _patrol_pt - global_position
		to_h.y = 0.0
		if to_h.length() > 0.8:
			dir = to_h.normalized() * 0.42
		else:
			dir = Vector3.ZERO
		return
	# Hedef: yolu kesen yapı > (avcıysa) en yakın canlı oyuncu > kule.
	var tgt: Node3D = null
	var goal := Vector3.ZERO
	var reach: float = d.range + TOWER_R + radius
	if is_instance_valid(block) and block.hp > 0 and global_position.distance_squared_to(block.global_position) < 16.0:
		tgt = block
		goal = block.global_position
		reach = 99.0 # zaten dibinde
	else:
		block = null
		if d.target == "player":
			tgt = _nearest_player()
			if tgt:
				goal = tgt.global_position
				reach = d.range + radius + 0.4
	var to := goal - global_position
	to.y = 0.0
	var dist := to.length()
	if dist <= reach:
		dir = Vector3.ZERO
		aim = atan2(-to.x, -to.z)
		stuck_t = 0.0
		if atk_cd <= 0.0:
			atk_cd = d.rate
			_attack(tgt, goal)
		return
	var want := to / dist
	# Takılma: gerçek yer değiştirmeye bakılır (kaçan oyuncuyu kovalamak takılma sayılmasın).
	var moved := global_position.distance_to(last_pos)
	last_pos = global_position
	stuck_t = stuck_t + TICK if moved < d.speed * TICK * 0.3 else 0.0
	if stuck_t >= STUCK_T:
		stuck_t = 0.0
		for i in get_slide_collision_count():
			var c := get_slide_collision(i).get_collider() as Node3D
			if c and c.is_in_group("builds"):
				block = c
		if block == null: # ağaç / kaya: bir süre yana kaç
			side = 1.0 if randf() < 0.5 else -1.0
			side_t = 1.2
	if side_t > 0.0:
		side_t -= TICK
		want = want.rotated(Vector3.UP, side * 1.3)
	# Ayrışma: üst üste binmesinler, hedefin çevresine yayılsınlar.
	for o in td.elist:
		if o != self:
			var v: Vector3 = global_position - o.global_position
			var m: float = radius + o.radius + 0.3
			var l2 := v.x * v.x + v.z * v.z
			if l2 < m * m and l2 > 0.0001:
				var l := sqrt(l2)
				want += Vector3(v.x, 0, v.z) * ((m - l) / m / l * 1.5)
	dir = want.normalized()


func _nearest_player() -> Node3D:
	var best: Node3D = null
	var bd := INF
	for p in td.plist:
		if is_instance_valid(p) and p.hp > 0:
			var dd := global_position.distance_squared_to(p.global_position)
			if dd < bd:
				bd = dd
				best = p
	return best


func _attack(tgt: Node3D, goal: Vector3) -> void:
	td.enemy_fx.rpc(eid, goal)
	if d.has("explode"):
		td.explode(self)
	elif tgt == null:
		td.hurt_tower(dmg)
	elif tgt == block:
		td.hurt_build(tgt, dmg * (2 if type == "ogre" else 1)) # Dev Goblin yapıları ezer
	elif d.range > 4.0: # uzaktan: mermi varınca oyuncu hâlâ oradaysa
		td.delayed_hit(tgt, goal, dmg, SPIT_T)
	else:
		td.hit_player(tgt, dmg)


# ---------- Her makinede: görsel ----------

## Vuruş anı (td.enemy_fx): animasyon; uzaktan vuran için hedefe uçan tükürük.
func attack_fx(pos: Vector3) -> void:
	if hp <= 0:
		return
	swing_t = 0.55
	cur = ""
	anim.stop()
	# hazırlık: geriye çekilip öne atılır, sonra yerine döner
	var lw := create_tween()
	lw.tween_property(model, "position:z", 0.15, 0.1).set_ease(Tween.EASE_OUT)
	lw.tween_property(model, "position:z", -0.3, 0.08).set_ease(Tween.EASE_IN)
	lw.tween_property(model, "position:z", 0.0, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if d.range > 4.0 and not d.has("explode"):
		var mi := MeshInstance3D.new()
		mi.mesh = shared("spit", func() -> Resource:
			var s := SphereMesh.new()
			s.radius = 0.16; s.height = 0.32
			s.radial_segments = 8; s.rings = 4
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.2, 2.4, 0.4)
			s.material = m
			return s)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = global_position + Vector3.UP * height * 0.75
		var trail := Fx.parts(Fx.quad("glow", 0.22), 14, 0.25, 0.0, 0.4,
			[Color(0.65, 1.0, 0.25, 0.75), Color(0.25, 0.8, 0.1, 0.0)], 0.9, 0.2, false)
		trail.local_coords = false
		mi.add_child(trail)
		trail.emitting = true
		var world_ref := td.get_parent()
		world_ref.add_child(mi)
		var land_p := pos + Vector3.UP * 0.9
		var tw := mi.create_tween()
		tw.tween_property(mi, "position", land_p, SPIT_T)
		tw.tween_callback(func() -> void:
			if is_instance_valid(world_ref):
				var spl := Fx.parts(Fx.quad("glow", 0.28), 10, 0.35, 1.5, 4.2,
					[Color(0.75, 1.0, 0.25, 0.9), Color(0.25, 0.7, 0.08, 0.0)], 1.0, 0.2)
				spl.position = land_p
				spl.gravity = Vector3(0, -10, 0)
				spl.finished.connect(spl.queue_free)
				world_ref.add_child(spl)
				spl.emitting = true
			mi.queue_free())


## td._hit çağırır: yeni can, gösterilecek hasar (0 = sessiz, -1 = kendini patlattı), kritik mi.
func apply_hit(v: int, n: int, crit: bool) -> void:
	if hp <= 0:
		return
	if aggro_r > 0.0 and not _aggro:
		_aggro = true
		for o in td.elist:
			if is_instance_valid(o) and o.get("camp_id") == camp_id:
				o._aggro = true
	hp = v
	var world := td.get_parent()
	if n > 0:
		float_text(world, global_position + Vector3(randf_range(-0.3, 0.3), height + 0.3, randf_range(-0.3, 0.3)),
			str(n), Color(1.0, 0.85, 0.15) if crit else Color.WHITE, 0.013 if crit else 0.008)
		flash_t = 0.12
		if crit and hp > 0: # kritik: yaratık bir an donar (hit-stop), sonra sürer
			anim.speed_scale = 0.0
			create_tween().tween_callback(func() -> void: # düğümle birlikte ölür: silinmiş yaratığa çağrı gitmez
				if hp > 0:
					cur = "").set_delay(0.09) # bir sonraki karede animasyon ve hız yeniden kurulur
		if hp > 0: # darbe: kısa ezilip geri sekme (doğma büyümesi bitmişse)
			var base := model_scale
			if hit_tw:
				hit_tw.kill()
			hit_tw = create_tween()
			hit_tw.tween_property(model, "scale", base * Vector3(1.12, 0.86, 1.12), 0.05)
			hit_tw.tween_property(model, "scale", base, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_overlay(shared("flash", func() -> Resource:
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.albedo_color = Color(0.7, 0.7, 0.7)
			return m))
	bar.visible = hp < max_hp and hp > 0
	bar.set_instance_shader_parameter("f", float(hp) / max_hp)
	if hp > 0:
		return
	# Ölüm: hedef olmaktan çık, düş, altın kıvılcım saç, yere bat.
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	_overlay(_shared[tint_key])
	var c := global_position + Vector3.UP * height * 0.5
	if n == -1:
		var fx: Node3D = Fx.new()
		fx.position = c
		fx.scale = Vector3.ONE * 0.9
		world.add_child(fx)
		Sfx.play3d(Sfx.boom, c, 0.0)
		queue_free()
		return
	anim.speed_scale = 1.0
	if hit_tw:
		hit_tw.kill()
	model.scale = model_scale
	var rag := Ragdoll.start(model, global_basis.z * 0.8) # son vuruşların yönünde savrulur
	if rag == null: # Düşük kalite: eski ölüm animasyonu
		anim.play("Death", 0.1)
	var p := Fx.parts(spark_mesh(), 18 if (elite or type == "boss") else 10, 0.75, 2.2, 5.8,
		[Color(1.0, 0.85, 0.2), Color(1.0, 0.6, 0.1, 0.0)], 1.1, 0.25)
	p.position = c
	p.direction = Vector3.UP
	p.spread = 65.0
	p.gravity = Vector3(0, -9, 0)
	world.add_child(p)
	p.emitting = true
	p.create_tween().tween_callback(p.queue_free).set_delay(1.0)
	if elite or type == "boss": # elit / boss ölünce şok halkası
		var rc := Color(0.88, 0.45, 1.0, 0.85) if type == "boss" else Color(1.0, 0.78, 0.25, 0.80)
		var rsz := 6.5 if type == "boss" else 3.2
		var ring := Fx.ground(rsz, rc, Vector4(0.15, 0.16, 0.1, 2.0))
		ring.position = global_position + Vector3.UP * 0.08
		world.add_child(ring)
		var rtw := ring.create_tween().set_parallel()
		Fx.anim(rtw, ring, "shape", Vector4(0.15, 0.16, 0.1, 2.0), Vector4(0.96, 0.03, 0.1, 2.0), 0.45).set_ease(Tween.EASE_OUT)
		Fx.anim(rtw, ring, "col", rc, Color(rc, 0.0), 0.45).set_ease(Tween.EASE_IN)
		rtw.chain().tween_callback(ring.queue_free)
	if money > 0:
		float_text(world, c + Vector3.UP * 0.4, "+%d" % money, Color(1.0, 0.8, 0.2), 0.007)
	Sfx.play3d(Sfx.kill, c, -6.0)
	var tw := create_tween()
	tw.tween_interval(1.8 if rag else 1.1)
	# Kor halinde dağılma: gövdede kayan parlak benekler, model küçülüp batar.
	var em := ShaderMaterial.new()
	em.shader = shared("ember", func() -> Resource:
		var sh := Shader.new()
		sh.code = EMBER
		return sh)
	em.set_shader_parameter("t", 0.0) # başsız (testte) gölgelendirici derlenmez: parametre baştan var olsun
	_overlay(em)
	if rag: # ragdoll: kor yayılırken toprağa gömülür
		tw.tween_callback(Ragdoll.sink.bind(rag))
		tw.tween_property(em, "shader_parameter/t", 1.0, 1.0)
		tw.tween_callback(queue_free)
		return
	tw.set_parallel()
	tw.tween_property(em, "shader_parameter/t", 1.0, 0.8)
	tw.tween_property(model, "scale", model_scale * 0.05, 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "position:y", position.y - height * 0.3, 0.8)
	tw.chain().tween_callback(queue_free)
