extends CharacterBody3D
## Açık Dünya Rakip Karakter Muhafızı: characters.gd'deki 52 karakterden rastgele biri.
## Evleri ve bölgeleri korur; oyuncu yaklaşınca veya saldırınca devreye girer ve KENDİ Q YETENEĞİNİ (ch.sk) kullanır!
## "enemies" grubundadır -> tüm oyuncu silahları, kritik, yanma, sekme ve ragdoll doğrudan çalışır.

const Chars := preload("res://characters.gd")
const EnemyScript := preload("res://enemy.gd")
const Fx := preload("res://explosion.gd")
const Ragdoll := preload("res://ragdoll.gd")
const WallScript := preload("res://wall.gd")
const MODEL_SCALE := 0.74
const TICK := 0.22

var eid := 0
var char_idx := 0
var ch: Dictionary
var type := "rival"
var elite := false
var hp := 120
var max_hp := 120
var dmg := 12
var armor := 0
var money := 0
var radius := 0.44
var height := 1.9
var spd_k := 1.0
var slow_t := 0.0
var slow_k := 1.0

var td: Node # OpenWorld denetçisi
var host := false
var net_pos := Vector3.ZERO
var net_vel := Vector3.ZERO
var net_yaw := 0.0
var home_pos := Vector3.ZERO
var aggro_r := 15.0
var leash_r := 38.0
var camp_id := ""
var _aggro := false
var _patrol_t := 0.0
var _patrol_pt := Vector3.ZERO

var model: Node3D
var meshes: Array = []
var anim: AnimationPlayer
var cur := ""
var bar: MeshInstance3D
var name_lbl: Label3D
var shield_mesh: MeshInstance3D
var _base_overlay: Material

var tick_t := 0.0
var atk_cd := 0.0
var skill_cd := 3.0
var swing_t := 0.0
var flash_t := 0.0
var stun_vis := 0.0
var stars: Node3D
var dir := Vector3.ZERO
var aim := 0.0
var moving := false
var model_scale := Vector3.ONE * MODEL_SCALE
var hit_tw: Tween
var shield_on := false
var haste_t := 0.0
var armor_t := 0.0
var size_t := 0.0
var invis_t := 0.0
var land_armed := false
var _active_projs := []


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("rivals")
	collision_layer = 2
	collision_mask = 1
	ch = Chars.get_char(char_idx)
	hp = roundi(float(ch.get("hp", 100)) * (1.45 if elite else 1.15))
	max_hp = hp
	dmg = roundi((13.0 if elite else 10.0) * (float(ch.get("sword_dmg", 20)) / 20.0))
	armor = 2 if elite else 0
	var s := 1.18 if elite else 1.0
	radius = 0.44 * s
	height = 1.9 * s
	model_scale = Vector3.ONE * MODEL_SCALE * s
	tick_t = randf() * TICK
	skill_cd = randf_range(2.0, 5.5)

	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius; cap.height = height
	cs.shape = cap
	cs.position.y = height * 0.5
	add_child(cs)

	model = load("res://models/chars/%s.glb" % ch.model).instantiate()
	model.rotation.y = PI
	model.scale = model_scale
	add_child(model)

	var rim := ShaderMaterial.new()
	rim.shader = preload("res://shaders/char_rim.gdshader")
	var rc: Color = ch.color.lightened(0.18)
	rim.set_shader_parameter("rim_color", Color(rc.r, rc.g, rc.b, 0.55 if elite else 0.35))
	rim.set_shader_parameter("rim_power", 2.6 if elite else 3.2)
	var outline := ShaderMaterial.new()
	outline.shader = preload("res://shaders/outline.gdshader")
	outline.set_shader_parameter("width", 0.02 if elite else 0.016)
	rim.next_pass = outline
	_base_overlay = rim
	meshes = model.find_children("*", "MeshInstance3D", true, false)
	for mi in meshes:
		mi.material_overlay = _base_overlay

	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	for n in ["Idle", "Run", "Walk", "Victory"]:
		if anim.has_animation(n):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR

	bar = EnemyScript.make_bar(1.05 * s, height + 0.35)
	add_child(bar)

	name_lbl = Label3D.new()
	name_lbl.text = ("★ " if elite else "") + tr(ch.name)
	name_lbl.position = Vector3(0, height + 0.62, 0)
	name_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_lbl.font_size = 38
	name_lbl.pixel_size = 0.0052
	name_lbl.outline_size = 12
	name_lbl.modulate = ch.color.lightened(0.35)
	add_child(name_lbl)

	# Kalkan küresi (skill ile açılır)
	shield_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.15; sm.height = 2.3; sm.radial_segments = 16; sm.rings = 8
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.35, 0.85, 1.0, 0.28)
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = smat
	shield_mesh.mesh = sm
	shield_mesh.position.y = height * 0.5
	shield_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shield_mesh.visible = false
	add_child(shield_mesh)
	host = multiplayer.is_server()
	net_pos = global_position
	net_yaw = rotation.y


func _physics_process(dt: float) -> void:
	if hp <= 0:
		return
	if flash_t > 0.0:
		flash_t -= dt
		if flash_t <= 0.0:
			_set_overlay(_base_overlay)
	if haste_t > 0.0:
		haste_t -= dt
	if armor_t > 0.0:
		armor_t -= dt
	if size_t > 0.0:
		size_t -= dt
		if size_t <= 0.0:
			create_tween().tween_property(model, "scale", model_scale, 0.3)
	if invis_t > 0.0:
		invis_t -= dt
		if invis_t <= 0.0:
			model.visible = true
	swing_t -= dt
	atk_cd -= dt
	skill_cd -= dt
	slow_t -= dt
	if stun_vis > 0.0:
		stun_vis -= dt
		if stars:
			stars.rotate_y(dt * 5.0)
		if stun_vis <= 0.0 and stars:
			stars.queue_free()
			stars = null

	if host:
		tick_t -= dt
		if tick_t <= 0.0:
			tick_t += TICK
			_think()

		var spd: float = 5.2 * ch.get("speed", 1.0) * spd_k * (1.45 if haste_t > 0.0 else 1.0) * (slow_k if slow_t > 0.0 else 1.0)
		if td and (td.get("is_night") or td.get("night_on")):
			spd *= 1.12
		moving = dir.length_squared() > 0.01
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		if is_on_floor():
			if land_armed and velocity.y <= 0.0:
				land_armed = false
				_land_slam()
			velocity.y = 0.0
		else:
			velocity.y -= 22.0 * dt
		if moving or not is_on_floor():
			move_and_slide()
			if moving:
				aim = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, aim, minf(1.0, dt * 10.0))
	else:
		global_position = net_pos if global_position.distance_squared_to(net_pos) > 36.0 else global_position.lerp(net_pos + net_vel * 0.1, minf(1.0, dt * 12.0))
		rotation.y = lerp_angle(rotation.y, net_yaw, minf(1.0, dt * 10.0))
		var lp := _local_player()
		name_lbl.visible = lp != null and global_position.distance_to(lp.global_position) < 28.0 and invis_t <= 0.0

	var want := "Idle"
	if swing_t > 0.0:
		want = "Punch" if anim.has_animation("Punch") else "Idle"
	elif moving:
		want = "Run" if dir.length() > 0.65 and anim.has_animation("Run") else ("Walk" if anim.has_animation("Walk") else "Run")
	if want != cur and anim.has_animation(want):
		cur = want
		anim.play(want, 0.14)


func _local_player() -> Node3D:
	if td == null:
		return null
	var my_id := str(multiplayer.get_unique_id())
	for p in td.plist:
		if is_instance_valid(p) and str(p.name) == my_id:
			return p as Node3D
	return _nearest_player()


func _think() -> void:
	if td == null or td.state != "fight":
		dir = Vector3.ZERO
		return
	var p := _nearest_player()
	var d_p := global_position.distance_to(p.global_position) if p else 999.0
	name_lbl.visible = d_p < 28.0 and invis_t <= 0.0
	var ar := aggro_r * (1.25 if td.get("is_night") or td.get("night_on") else 1.0)
	if p:
		var ph := Vector2(p.global_position.x - home_pos.x, p.global_position.z - home_pos.z).length()
		var home_d := Vector2(global_position.x - home_pos.x, global_position.z - home_pos.z).length()
		if not _aggro and d_p <= ar:
			_alert_camp()
		elif _aggro and ph > leash_r and home_d > leash_r * 0.7:
			_aggro = false
	else:
		_aggro = false

	if _aggro and p:
		var to := p.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		aim = atan2(-to.x, -to.z)
		# Kendi Q yeteneğini kullan!
		if skill_cd <= 0.0 and slow_t <= 0.0 and dist < 24.0:
			skill_cd = clampf(float(ch.get("cd", 11.0)) * 0.85, 6.0, 14.0)
			if td and td.has_method("rival_skill"):
				td.rival_skill.rpc(eid, p.name.to_int())
			else:
				_cast_skill(p)
		# Temel saldırı: menzilli (büyücü/kovboy/asker) veya yakın dövüş
		var ranged: bool = ch.sk.has("homing") or ch.sk.has("volley") or (ch.sk.has("area") and ch.sk.area.get("at", "") == "aim")
		var reach := 10.5 if ranged else 2.2
		if dist <= reach:
			dir = Vector3.ZERO
			if atk_cd <= 0.0 and slow_t <= 0.0:
				atk_cd = 1.65 if ranged else 1.1
				if td and td.has_method("rival_attack"):
					td.rival_attack.rpc(eid, p.global_position, ranged)
				else:
					_basic_attack(p, ranged)
			return
		var want := to / maxf(dist, 0.001)
		for o in td.elist:
			if o != self and is_instance_valid(o):
				var v: Vector3 = global_position - o.global_position
				var m: float = radius + o.radius + 0.4
				var l2 := v.x * v.x + v.z * v.z
				if l2 < m * m and l2 > 0.0001:
					var l := sqrt(l2)
					want += Vector3(v.x, 0, v.z) * ((m - l) / m / l * 1.4)
		dir = want.normalized()
		return

	# Sakin muhafız devriyesi (ev / kamp çevresi)
	_patrol_t -= TICK
	if _patrol_t <= 0.0:
		_patrol_t = randf_range(2.5, 5.2)
		var ang := randf() * TAU
		var rad := randf_range(1.8, 6.5)
		_patrol_pt = home_pos + Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
	var to_h := _patrol_pt - global_position
	to_h.y = 0.0
	dir = to_h.normalized() * 0.38 if to_h.length() > 0.9 else Vector3.ZERO


func _alert_camp() -> void:
	_aggro = true
	if td == null or camp_id == "":
		return
	for o in td.elist:
		if is_instance_valid(o) and o.get("camp_id") == camp_id:
			o._aggro = true


func _nearest_player() -> Node3D:
	if td == null:
		return null
	var best: Node3D = null
	var bd := INF
	for p in td.plist:
		if is_instance_valid(p) and p.hp > 0:
			var dd := global_position.distance_squared_to(p.global_position)
			if dd < bd:
				bd = dd
				best = p
	return best


func attack_visual(target_pos: Vector3, ranged: bool) -> void:
	if hp <= 0:
		return
	swing_t = 0.45
	cur = ""
	var d_val := roundi(dmg * (1.2 if td and (td.get("is_night") or td.get("night_on")) else 1.0))
	if ranged:
		_fire_bolt(target_pos + Vector3.UP * 0.9, ch.color, d_val, 22.0, 0.0)
	else:
		Sfx.play3d(Sfx.whoosh, global_position + Vector3.UP, -6.0)
		if host:
			var p := _nearest_player()
			if p and global_position.distance_to(p.global_position) <= 2.8:
				td.hit_player(p, d_val)


func _basic_attack(p: Node3D, ranged: bool) -> void:
	attack_visual(p.global_position, ranged)


# ---------- Karakterin Kendi Q Yeteneği (characters.gd::sk) ----------

func _cast_skill(p: Node3D) -> void:
	var sk: Dictionary = ch.sk
	var col: Color = ch.color
	var world := td.get_parent()
	EnemyScript.float_text(world, global_position + Vector3.UP * (height + 0.9), tr(ch.skill_name) + "!", col.lightened(0.35), 0.010)
	Sfx.play3d(Sfx.shield_up, global_position + Vector3.UP, -4.0)

	# 1. Kendine etki (self)
	if sk.has("self"):
		var sf: Dictionary = sk.self
		if sf.has("heal") or sf.has("heal_missing") or sf.has("regen"):
			var gain: int = int(sf.get("heal", 28))
			hp = mini(hp + gain, max_hp)
			bar.set_instance_shader_parameter("f", float(hp) / max_hp)
			_ring_fx(global_position, 2.2, Color(0.35, 0.95, 0.55, 0.8), 0.45)
		if sf.has("shield"):
			shield_on = true
			shield_mesh.visible = true
		if sf.has("haste"):
			haste_t = float(sf.haste[1])
			_ring_fx(global_position, 2.0, Color(0.55, 0.9, 1.0, 0.75), 0.35)
		if sf.has("armor"):
			armor_t = float(sf.armor[1])
			_ring_fx(global_position, 2.2, Color(1.0, 0.82, 0.25, 0.8), 0.4)
		if sf.has("size"):
			var k: float = float(sf.size[0])
			size_t = float(sf.size[1])
			create_tween().tween_property(model, "scale", model_scale * k, 0.3).set_trans(Tween.TRANS_BACK)
		if sf.has("invis"):
			invis_t = minf(float(sf.invis), 3.0)
			model.visible = false
			_ring_fx(global_position, 1.8, Color(0.8, 0.85, 0.95, 0.6), 0.35)
		if sf.has("leap"):
			var to := (p.global_position - global_position)
			to.y = 0.0
			var fdir := to.normalized() if to.length() > 0.1 else -global_basis.z
			velocity = fdir * minf(float(sf.leap[0]), 14.0) + Vector3.UP * minf(float(sf.leap[1]), 11.0)
			if sk.has("area") and sk.area.get("land", false):
				land_armed = true
		if sf.has("blink"):
			var to := (p.global_position - global_position)
			to.y = 0.0
			var step := minf(to.length() - 2.2, float(sf.blink))
			if step > 1.0:
				_ring_fx(global_position, 1.8, col, 0.3)
				global_position += to.normalized() * step
				_ring_fx(global_position, 2.0, col, 0.35)

	# 2. Duvar örme (Duvarcı)
	if sk.has("walls"):
		var to := (p.global_position - global_position)
		var fdir := Vector3(to.x, 0, to.z).normalized()
		var w := WallScript.new()
		w.position = global_position + fdir * 2.8
		w.rotation.y = atan2(-fdir.x, -fdir.z)
		world.add_child(w)

	# 3. Işınlanıp arkadan vurma / yer değiştirme
	if sk.get("backstab", false):
		var back_p := p.global_position + p.global_basis.z * 2.0
		_ring_fx(global_position, 1.6, col, 0.3)
		if host:
			global_position = Vector3(back_p.x, global_position.y, back_p.z)
			td.hit_player(p, 16)
		_ring_fx(back_p, 2.0, col, 0.35)
		return
	if sk.get("swap", false):
		var my_p := global_position
		if host:
			global_position = p.global_position
		_ring_fx(global_position, 2.2, col, 0.4)
		_ring_fx(my_p, 2.2, col, 0.4)
		return

	# 4. Yaylım roketi / dev gülle (volley)
	if sk.has("volley"):
		var cnt: int = mini(int(sk.volley[0]), 4)
		var spr: float = float(sk.volley[1])
		var big: bool = bool(sk.volley[2])
		var to := (p.global_position + Vector3.UP * 0.9 - (global_position + Vector3.UP * 1.2)).normalized()
		for i in cnt:
			var d_vec := to.rotated(Vector3.UP, spr * (i - (cnt - 1) * 0.5))
			_fire_bolt(global_position + Vector3.UP * 1.2 + d_vec * 28.0, Color(1.0, 0.55, 0.12), 22 if big else 12, 18.0 if big else 24.0, 3.6 if big else 2.2)

	# 5. Güdümlü mermi (Bumerang, Kart, Şut)
	if sk.has("homing"):
		var h: Dictionary = sk.homing
		_spawn_homing(p, col, mini(int(h.get("dmg", 16)), 20), clampf(float(h.get("speed", 16.0)) * 0.72, 10.0, 17.0), float(h.get("knock", 5.0)))

	# 6. Alan yeteneği (Meteor, Girdap, Flaş, Düdük, Acı Sos, Havlama...)
	if sk.has("area") and not sk.area.get("land", false):
		var a: Dictionary = sk.area
		var ac: Color = a.get("color", col)
		var r: float = clampf(float(a.get("r", 4.0)), 2.5, 7.5)
		var at_pos := p.global_position if a.get("at", "") == "aim" else global_position
		at_pos.y = _ground_y(at_pos.x, at_pos.z) + 0.05
		var dly: float = float(a.get("delay", 0.0))
		if dly > 0.0:
			_delayed_strike(at_pos, r, ac, dly, a)
		elif a.has("linger"):
			_linger_zone(at_pos, r, ac, minf(float(a.linger), 3.5), a)
		else:
			_ring_fx(at_pos, r, Color(ac, 0.9), 0.45)
			if a.get("boom", false):
				_boom(at_pos, 1.0)
			_apply_area_to_player(p, at_pos, r, a)


func _land_slam() -> void:
	var a: Dictionary = ch.sk.get("area", {})
	var r: float = float(a.get("r", 4.0))
	var ac: Color = a.get("color", ch.color)
	_ring_fx(global_position, r, Color(ac, 0.9), 0.5)
	if a.get("boom", false):
		_boom(global_position, 1.1)
	var p := _nearest_player()
	if p:
		_apply_area_to_player(p, global_position, r, a)


func _apply_area_to_player(p: Node3D, at: Vector3, r: float, a: Dictionary) -> void:
	if not is_instance_valid(p) or p.hp <= 0:
		return
	var diff := p.global_position - at
	diff.y = 0.0
	if diff.length() > r:
		return
	if host:
		var dd: int = mini(int(a.get("dmg", 0)), 26)
		if dd > 0:
			td.hit_player(p, dd)
		if a.has("burn"):
			td.hit_player(p, mini(int(a.burn[0]), 10))
	if p.is_multiplayer_authority():
		if a.has("knock") or a.has("up"):
			var dir_out := diff.normalized() if diff.length() > 0.1 else Vector3.FORWARD
			p.velocity += dir_out * minf(float(a.get("knock", 0.0)) * 0.65, 9.0) + Vector3.UP * minf(float(a.get("up", 0.0)) * 0.65, 9.0)
		if a.has("pull") or a.has("yank"):
			var dir_in := -diff.normalized() if diff.length() > 0.2 else Vector3.ZERO
			p.velocity += dir_in * minf(float(a.get("pull", a.get("yank", 8.0))) * 0.7, 11.0)
		if a.has("blind"):
			p.buffs["blind"] = [1.0, minf(float(a.blind), 1.0)]
		if a.has("slow"):
			p.buffs["slow"] = [clampf(float(a.slow[0]), 0.45, 0.85), minf(float(a.slow[1]), 2.2)]
		if a.has("stun"):
			p.buffs["slow"] = [0.25, minf(float(a.stun), 1.0)] # açık dünyada tamamen kilitlemek yerine sert yavaşlatma


func _delayed_strike(at: Vector3, r: float, col: Color, dly: float, a: Dictionary) -> void:
	var world := td.get_parent()
	var warn := Fx.ground(r, Color(col, 0.85), Vector4(0.95, 0.06, 0.04, 1.8))
	warn.position = at + Vector3.UP * 0.06
	world.add_child(warn)
	var fill := Fx.ground(r, Color(col, 0.35), Vector4(0.0, 0.04, 0.06, 1.4))
	fill.position = at + Vector3.UP * 0.08
	world.add_child(fill)
	var tw := fill.create_tween()
	Fx.anim(tw, fill, "shape", Vector4(0.0, 0.04, 0.06, 1.4), Vector4(0.0, 0.96, 0.06, 1.4), dly)
	# Gökten düşen meteor / kaya
	var rock: MeshInstance3D = null
	if a.get("boom", false):
		var s := SphereMesh.new()
		s.radius = 0.65; s.height = 1.3; s.radial_segments = 16; s.rings = 8
		rock = MeshInstance3D.new()
		rock.mesh = s
		rock.material_override = Fx.mat("ball")
		rock.set_instance_shader_parameter("progress", 0.38)
		rock.set_instance_shader_parameter("seed", randf() * 15.0)
		rock.position = at + Vector3(4, 24, 3)
		world.add_child(rock)
		rock.create_tween().tween_property(rock, "position", at, dly).set_ease(Tween.EASE_IN)
	get_tree().create_timer(dly, false).timeout.connect(func() -> void:
		if is_instance_valid(warn): warn.queue_free()
		if is_instance_valid(fill): fill.queue_free()
		if is_instance_valid(rock): rock.queue_free()
		if not is_instance_valid(self) or not is_instance_valid(td):
			return
		_boom(at, 1.15)
		var p := _nearest_player()
		if p:
			_apply_area_to_player(p, at, r, a))


func _linger_zone(at: Vector3, r: float, col: Color, dur: float, a: Dictionary) -> void:
	var world := td.get_parent()
	var ring := Fx.ground(r, Color(col, 0.72), Vector4(0.92, 0.08, 0.08, 1.6))
	ring.position = at + Vector3.UP * 0.07
	world.add_child(ring)
	var ticks := maxi(int(dur / 0.6), 2)
	for i in ticks:
		get_tree().create_timer(0.5 + i * 0.6, false).timeout.connect(func() -> void:
			if not is_instance_valid(self) or not is_instance_valid(td):
				return
			var p := _nearest_player()
			if p:
				_apply_area_to_player(p, at, r, a))
	get_tree().create_timer(dur + 0.3, false).timeout.connect(func() -> void:
		if is_instance_valid(ring):
			ring.queue_free())


func _fire_bolt(target: Vector3, col: Color, d_val: int, speed: float, blast_r: float) -> void:
	var world := td.get_parent()
	var start := global_position + Vector3.UP * (height * 0.68)
	var d_vec := (target - start).normalized()
	var dist := minf(start.distance_to(target), 30.0)
	var fly_t := clampf(dist / maxf(speed, 8.0), 0.12, 1.4)
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.24 if blast_r > 2.8 else 0.14; s.height = s.radius * 2.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r * 1.8 + 0.3, col.g * 1.8 + 0.2, col.b * 1.8 + 0.2)
	s.material = m
	mi.mesh = s
	mi.position = start
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var trail := Fx.parts(Fx.quad("glow", 0.20), 12, 0.22, 0.0, 0.3, [Color(col, 0.8), Color(col, 0.0)], 0.8, 0.2, false)
	trail.local_coords = false
	mi.add_child(trail)
	trail.emitting = true
	world.add_child(mi)
	var end_p := start + d_vec * dist
	var tw := mi.create_tween()
	tw.tween_property(mi, "position", end_p, fly_t)
	tw.tween_callback(func() -> void:
		if is_instance_valid(self) and is_instance_valid(td):
			if blast_r > 0.0:
				_boom(end_p, blast_r * 0.35)
			if host:
				var p := _nearest_player()
				if p and p.global_position.distance_to(end_p) < maxf(blast_r, 1.75):
					td.hit_player(p, d_val)
		if is_instance_valid(mi):
			mi.queue_free())


func _spawn_homing(p: Node3D, col: Color, d_val: int, speed: float, knock: float) -> void:
	var world := td.get_parent()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.45, 0.08, 0.45)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r * 1.7 + 0.3, col.g * 1.7 + 0.3, col.b * 1.7 + 0.3)
	bm.material = m
	mi.mesh = bm
	mi.position = global_position + Vector3.UP * 1.15
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	# Basit takip döngüsü (2.2 sn ömür, keskin dönüşle kaçılabilir)
	var dir_v := (p.global_position + Vector3.UP - mi.position).normalized()
	var steps := 36
	var step_dt := 0.06
	var state_arr := [dir_v, false]
	for i in steps:
		get_tree().create_timer(i * step_dt, false).timeout.connect(func() -> void:
			if state_arr[1] or not is_instance_valid(mi) or not is_instance_valid(td):
				return
			mi.rotate_y(0.6)
			if is_instance_valid(p) and p.hp > 0:
				var want := (p.global_position + Vector3.UP * 0.9 - mi.position).normalized()
				state_arr[0] = (state_arr[0] as Vector3).lerp(want, 0.14).normalized()
			mi.position += (state_arr[0] as Vector3) * speed * step_dt
			if is_instance_valid(p) and p.hp > 0 and mi.position.distance_to(p.global_position + Vector3.UP * 0.9) < 1.15:
				state_arr[1] = true
				if host:
					td.hit_player(p, d_val)
				if p.is_multiplayer_authority():
					p.velocity += (state_arr[0] as Vector3) * knock * 0.5
				_ring_fx(mi.position, 1.2, col, 0.25)
				mi.queue_free())
	get_tree().create_timer(steps * step_dt + 0.05, false).timeout.connect(func() -> void:
		if is_instance_valid(mi):
			mi.queue_free())


func _ground_y(x: float, z: float) -> float:
	if td and td.has_method("_gy"):
		return float(td._gy(x, z))
	return 0.0


func _ring_fx(at: Vector3, r: float, col: Color, dur: float) -> void:
	if td == null:
		return
	var ring := Fx.ground(r, col, Vector4(0.15, 0.14, 0.08, 1.8))
	ring.position = Vector3(at.x, _ground_y(at.x, at.z) + 0.08, at.z)
	td.get_parent().add_child(ring)
	var tw := ring.create_tween().set_parallel()
	Fx.anim(tw, ring, "shape", Vector4(0.15, 0.14, 0.08, 1.8), Vector4(0.96, 0.03, 0.08, 1.8), dur).set_ease(Tween.EASE_OUT)
	Fx.anim(tw, ring, "col", col, Color(col, 0.0), dur).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(ring.queue_free)


func _boom(at: Vector3, k: float) -> void:
	if td == null:
		return
	var fx: Node3D = Fx.new()
	fx.position = at
	fx.scale = Vector3.ONE * k
	td.get_parent().add_child(fx)
	Sfx.play3d(Sfx.boom, at, 0.0)


# ---------- Hasar, Sersemleme ve Ölüm (enemy.gd uyumlu) ----------

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
		l.font_size = 56
		l.pixel_size = 0.004
		l.outline_size = 10
		l.modulate = Color(1.0, 0.9, 0.25)
		l.position = Vector3(cos(i * TAU / 3.0), 0, sin(i * TAU / 3.0)) * radius * 0.85
		stars.add_child(l)


func _set_overlay(m: Material) -> void:
	for mi in meshes:
		if is_instance_valid(mi):
			mi.material_overlay = m


func apply_hit(v: int, n: int, crit: bool) -> void:
	if hp <= 0:
		return
	if not _aggro:
		_alert_camp()
	if shield_on and n > 0: # kalkan bir darbeyi emer ve kırılır
		shield_on = false
		shield_mesh.visible = false
		Sfx.play3d(Sfx.shield_break, global_position + Vector3.UP, 0.0)
		_ring_fx(global_position, 1.8, Color(0.45, 0.9, 1.0, 0.9), 0.35)
		return
	if armor_t > 0.0 and n > 0:
		v = maxi(hp - maxi(roundi(n * 0.55), 1), 0)
	hp = v
	var world := td.get_parent()
	if n > 0:
		EnemyScript.float_text(world, global_position + Vector3(randf_range(-0.3, 0.3), height + 0.3, randf_range(-0.3, 0.3)),
			str(n), Color(1.0, 0.85, 0.15) if crit else Color.WHITE, 0.013 if crit else 0.008)
		flash_t = 0.12
		if hp > 0:
			if hit_tw:
				hit_tw.kill()
			hit_tw = create_tween()
			hit_tw.tween_property(model, "scale", model_scale * Vector3(1.10, 0.88, 1.10), 0.05)
			hit_tw.tween_property(model, "scale", model_scale, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_set_overlay(EnemyScript.shared("flash", func() -> Resource:
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.albedo_color = Color(0.7, 0.7, 0.7)
			return m))
	bar.visible = hp < max_hp and hp > 0
	bar.set_instance_shader_parameter("f", float(hp) / max_hp)
	if hp > 0:
		return
	# Ölüm: ragdoll + şok halkası + kıvılcım + toprağa gömülme
	remove_from_group("enemies")
	remove_from_group("rivals")
	collision_layer = 0
	collision_mask = 0
	name_lbl.visible = false
	shield_mesh.visible = false
	model.visible = true
	_set_overlay(_base_overlay)
	var c := global_position + Vector3.UP * height * 0.5
	var rag := Ragdoll.start(model, global_basis.z * 0.8)
	if rag == null and anim.has_animation("Death"):
		anim.play("Death", 0.1)
	_ring_fx(global_position, 2.8 if elite else 1.8, Color(ch.color, 0.85), 0.4)
	var p := Fx.parts(EnemyScript.spark_mesh(), 14, 0.7, 2.0, 5.2, [ch.color.lightened(0.3), Color(1.0, 0.8, 0.2, 0.0)], 1.0, 0.25)
	p.position = c
	p.direction = Vector3.UP
	p.spread = 65.0
	p.gravity = Vector3(0, -9, 0)
	world.add_child(p)
	p.emitting = true
	p.create_tween().tween_callback(p.queue_free).set_delay(1.0)
	Sfx.play3d(Sfx.kill, c, -5.0)
	var tw := create_tween()
	tw.tween_interval(2.0 if rag else 1.1)
	if rag:
		tw.tween_callback(Ragdoll.sink.bind(rag))
		tw.tween_interval(1.0)
	tw.tween_callback(queue_free)
