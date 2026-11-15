extends Node3D
## Patlama: büyüyüp sönen ateş topu + ışık parlaması + kıvılcım/duman parçacıkları.

func _ready() -> void:
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0; sm.height = 2.0
	ball.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.55, 0.1, 0.9)
	ball.material_override = m
	ball.scale = Vector3.ONE * 0.2
	add_child(ball)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 10.0
	light.omni_range = 10.0
	add_child(light)

	add_child(_burst(50, Color(1.0, 0.7, 0.2), 6.0, 12.0, 0.5, 0.06))
	add_child(_burst(25, Color(0.3, 0.3, 0.3, 0.7), 1.5, 4.0, 1.2, 0.25))

	var tw := create_tween().set_parallel()
	tw.tween_property(ball, "scale", Vector3.ONE * 2.5, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.35)
	tw.tween_property(light, "light_energy", 0.0, 0.5)
	get_tree().create_timer(1.5).timeout.connect(queue_free)


func _burst(n: int, c: Color, vmin: float, vmax: float, life: float, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = Vector3(0, -6, 0) if c.a > 0.9 else Vector3(0, 1.5, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	var sm := SphereMesh.new()
	sm.radius = size; sm.height = size * 2
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = m
	p.mesh = sm
	p.emitting = true
	return p
