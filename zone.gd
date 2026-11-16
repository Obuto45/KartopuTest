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
	var ring := TorusMesh.new()
	ring.inner_radius = a.r * 0.96; ring.outer_radius = a.r
	_flat(ring, 0.9)
	var disc := CylinderMesh.new()
	disc.top_radius = a.r; disc.bottom_radius = a.r; disc.height = 0.04
	fill_mat = _flat(disc, 0.22)
	if a.get("boom", false) and delay > 0.0 and not a.has("linger") and not a.has("mine"): # gökten düşen taş
		var s := SphereMesh.new()
		s.radius = 0.7; s.height = 1.4
		rock = MeshInstance3D.new()
		rock.mesh = s
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.25, 0.1, 0.05)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.4, 0.05)
		m.emission_energy_multiplier = 2.5
		rock.material_override = m
		rock.position = Vector3(6, 30, 4)
		add_child(rock)
		create_tween().tween_property(rock, "position", Vector3.ZERO, delay).set_ease(Tween.EASE_IN)


func _physics_process(dt: float) -> void:
	t += dt
	if not is_instance_valid(caster):
		queue_free()
		return
	fill_mat.albedo_color.a = 0.16 + 0.1 * absf(sin(t * 6.0)) # nabız
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
