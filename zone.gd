extends Node3D
## Yerde duran etki alanı (characters.gd'deki "area" verisi):
##   delay  : bu kadar sn sonra vurur (meteor)
##   linger : bu kadar sn boyunca yarım saniyede bir vurur (beton, sis, girdap, çay halkası)
##   mine   : 1 sn'de kurulur, atan dışında ilk yaklaşanı vurur (kapan), 20 sn durur
## Her makinede aynı çalışır; etkiyi player.hit_local yalnızca o makinenin oyuncusuna uygular.

const TICK := 0.5
const MINE_LIFE := 20.0

var caster: Node3D
var a: Dictionary
var t := 0.0
var next := 0.0
var delay := 0.0
var fill_mat: StandardMaterial3D
var rock: MeshInstance3D
var ring: MeshInstance3D

const Fx := preload("res://explosion.gd")


func _flat(m: Mesh, alpha: float) -> StandardMaterial3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(a.get("color", Color.WHITE), alpha)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.06
	add_child(mi)
	return mat


func _ready() -> void:
	delay = 1.0 if a.get("mine", false) else a.get("delay", 0.0)
	var col: Color = a.get("color", Color.WHITE)
	ring = Fx.ground(a.r, Color(col, 0.95), Vector4(0.95, 0.05, 0.0, 1.8)) # parlak, nabız atan sınır halkası
	ring.position.y = 0.07
	add_child(ring)
	var disc := CylinderMesh.new()
	disc.top_radius = a.r; disc.bottom_radius = a.r; disc.height = 0.04
	fill_mat = _flat(disc, 0.22)
	if delay > 0.0: # geri sayım: içten dışa dolan leke, sınıra değdiği an vurur
		var fill := Fx.ground(a.r, Color(col, 0.4), Vector4(0.0, 0.02, 0.06, 1.4))
		fill.position.y = 0.09
		add_child(fill)
		Fx.anim(create_tween(), fill, "shape", Vector4(0.0, 0.02, 0.06, 1.4), Vector4(0.0, 0.98, 0.06, 1.4), delay)
	if a.get("boom", false) and delay > 0.0 and not a.has("linger") and not a.has("mine"): # gökten düşen taş
		var s := SphereMesh.new()
		s.radius = 0.7; s.height = 1.4
		s.radial_segments = 24; s.rings = 12
		rock = MeshInstance3D.new()
		rock.mesh = s
		rock.material_override = Fx.mat("ball") # ateş topu gölgelendiricisi yarı soğumuş halde: kor damarlı yamuk taş
		rock.set_instance_shader_parameter("progress", 0.42)
		rock.set_instance_shader_parameter("seed", randf() * 20.0)
		rock.position = Vector3(6, 30, 4)
		add_child(rock)
		# Ateş ve duman kuyruğu dünyada kalır (local_coords kapalı), taş önünden kaçar.
		var flame := Fx.parts(Fx.quad("glow", 1.5), 26, 0.4, 0.0, 1.5, [Color(1.0, 0.6, 0.2, 0.55), Color(0.9, 0.3, 0.04, 0.4), Color(0.5, 0.08, 0.0, 0.0)], 1.0, 0.3, false)
		var smoke := Fx.parts(Fx.quad("puff", 2.4), 30, 1.3, 0.0, 1.0, [Color(0.3, 0.14, 0.05, 0.0), Color(0.12, 0.1, 0.09, 0.7), Color(0.25, 0.24, 0.23, 0.0)], 0.5, 1.0, false)
		for p in [smoke, flame]:
			p.local_coords = false
			rock.add_child(p)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.5, 0.15)
		light.light_energy = 3.0
		light.omni_range = 9.0
		rock.add_child(light)
		create_tween().tween_property(rock, "position", Vector3.ZERO, delay).set_ease(Tween.EASE_IN)


func _physics_process(dt: float) -> void:
	t += dt
	if not is_instance_valid(caster):
		queue_free()
		return
	fill_mat.albedo_color.a = 0.16 + 0.1 * absf(sin(t * 6.0)) # nabız
	ring.set_instance_shader_parameter("shape", Vector4(0.95, 0.05, 0.0, 1.3 + absf(sin(t * 6.0))))
	if a.get("mine", false):
		if t > MINE_LIFE:
			queue_free()
		elif t >= delay:
			# shortcut: tetiklenmeye her makine kendi gördüğü konumlardan karar verir; gecikme yüksekse
			# makineler birkaç kare farklı patlatabilir. Sorun olursa kararı atanın makinesi yayınlasın.
			for p in get_tree().get_nodes_in_group("players"):
				if p != caster and p.hp > 0 and p.global_position.distance_to(global_position) < a.r:
					_fire()
					queue_free()
					return
		return
	if t < delay:
		return
	if t >= next:
		next = t + TICK
		_fire()
	if t >= delay + a.get("linger", 0.0):
		queue_free()


func _fire() -> void:
	if rock:
		rock.visible = false
	if a.get("boom", false):
		var off := Vector3.ZERO
		if a.has("linger"): # baraj ateşi: her vuruş alanın başka yerinde patlar
			off = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * a.r * 0.6
		caster.boom_fx(global_position + off, 1.0)
	caster.hit_local(a, global_position, Vector3.ZERO)
	if a.has("zheal") and caster.is_multiplayer_authority() and caster.global_position.distance_to(global_position) < a.r:
		caster.gain(a.zheal)
