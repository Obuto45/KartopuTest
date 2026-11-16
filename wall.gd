extends StaticBody3D
## Duvar asası: yerden yükselen, ateş toplarını ve oyuncuları durduran geçici duvar.
## Görüntü yan yana birkaç kaya bloğu; hepsi çarpışma kutusunun (SIZE) içinde kalır.

const SIZE := Vector3(3.0, 2.2, 0.4)
const LIFE := 8.0
const Fx := preload("res://explosion.gd")
const STONE := preload("res://shaders/fx_stone.gdshader")


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = STONE
	var x := -SIZE.x * 0.5
	for w in [0.55, 0.4, 0.65, 0.5, 0.35, 0.55]: # toplamı SIZE.x
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var h := SIZE.y - randf() * 0.3 # tepesi dişli; kutuyu aşmaz
		bm.size = Vector3(w + 0.03, h, SIZE.z - 0.1 + randf() * 0.07)
		mi.mesh = bm
		mi.position = Vector3(x + w * 0.5, h * 0.5, 0)
		mi.rotation.y = randf_range(-0.09, 0.09) # hafif dönük bloklar: düz levha gibi durmasın
		mi.material_override = mat
		add_child(mi)
		x += w
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = SIZE
	cs.shape = sh
	cs.position.y = SIZE.y * 0.5
	add_child(cs)

	# Dipte toz ve moloz: duvar hareket ederken yerde kalsın diye top_level.
	var dust := Fx.parts(Fx.quad("puff", 1.3), 14, 1.1, 0.6, 2.2, [Color(0.5, 0.42, 0.32, 0.0), Color(0.5, 0.43, 0.34, 0.7), Color(0.55, 0.5, 0.42, 0.0)], 0.4, 1.0)
	var bm2 := BoxMesh.new()
	bm2.size = Vector3(0.12, 0.09, 0.1)
	bm2.material = Fx.mat("chunk")
	var rubble := Fx.parts(bm2, 12, 0.9, 3.0, 6.5, [Color(0.5, 0.47, 0.43), Color(0.35, 0.3, 0.25)], 1.0, 0.4)
	rubble.gravity = Vector3(0, -16, 0)
	rubble.particle_flag_align_y = true
	for p in [dust, rubble]:
		p.top_level = true
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(SIZE.x * 0.5, 0.1, SIZE.z * 0.5)
		p.direction = Vector3.UP
		p.spread = 70.0
		add_child(p)
		p.global_transform = global_transform
		p.emitting = true

	Sfx.play3d(Sfx.rumble, global_position + Vector3.UP, 0.0)
	var top := position.y
	position.y -= SIZE.y # yerin altından yükselir
	var tw := create_tween()
	tw.tween_property(self, "position:y", top, 0.2).set_ease(Tween.EASE_OUT)
	tw.tween_interval(LIFE)
	tw.tween_callback(dust.restart) # batarken de toz kalkar
	tw.tween_property(self, "position:y", top - SIZE.y, 0.4)
	tw.tween_callback(queue_free)
