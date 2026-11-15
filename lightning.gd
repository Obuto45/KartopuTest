extends Node3D
## Yıldırım: önce yerde uyarı halkası, kısa gecikmeden sonra gökten iner.
## Görsel her makinede yerel; hasarı her makine kendi oyuncusu için uygular.

const DELAY := 0.35 # kaçmak için uyarı süresi
const HEIGHT := 22.0

var caster: Node3D
var radius := 2.2


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _ready() -> void:
	var ring := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius; cm.bottom_radius = radius; cm.height = 0.04
	ring.mesh = cm
	ring.position.y = 0.03
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rm := _mat(Color(0.5, 0.8, 1.0, 0.15))
	ring.material_override = rm
	add_child(ring)
	create_tween().tween_property(rm, "albedo_color:a", 0.6, DELAY)
	await get_tree().create_timer(DELAY).timeout
	ring.queue_free()
	_strike()


func _strike() -> void:
	# Zikzak şimşek: yukarıdan aşağı kırık çizgi, alta yaklaştıkça sapma azalır.
	var pts := [Vector3(randf_range(-2, 2), HEIGHT, randf_range(-2, 2))]
	for i in range(1, 9):
		var t := i / 9.0
		pts.append(Vector3(randf_range(-0.9, 0.9) * (1.0 - t), HEIGHT * (1.0 - t), randf_range(-0.9, 0.9) * (1.0 - t)))
	pts.append(Vector3.ZERO)
	var bolt := _mat(Color(0.85, 0.95, 1.0, 1.0))
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.14, 0.14, a.distance_to(b))
		seg.mesh = bm
		seg.material_override = bolt
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(seg)
		seg.position = (a + b) * 0.5
		seg.look_at(global_position + b, Vector3.RIGHT)

	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.85, 1.0)
	light.light_energy = 16.0
	light.omni_range = 14.0
	light.position.y = 2.0
	add_child(light)

	var sparks := CPUParticles3D.new()
	sparks.amount = 40
	sparks.lifetime = 0.5
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.direction = Vector3.UP
	sparks.spread = 80.0
	sparks.initial_velocity_min = 3.0
	sparks.initial_velocity_max = 8.0
	sparks.gravity = Vector3(0, -12, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.04; sm.height = 0.08
	sm.material = _mat(Color(0.7, 0.9, 1.0))
	sparks.mesh = sm
	sparks.emitting = true
	add_child(sparks)

	Sfx.play3d(Sfx.thunder, global_position, 6.0)
	if is_instance_valid(caster):
		caster.apply_blast(global_position, radius, caster.LIGHTNING_DMG)

	var tw := create_tween().set_parallel()
	tw.tween_property(bolt, "albedo_color:a", 0.0, 0.3)
	tw.tween_property(light, "light_energy", 0.0, 0.4)
	get_tree().create_timer(1.0).timeout.connect(queue_free)
