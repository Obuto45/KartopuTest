extends StaticBody3D
## Duvar asası: yerden yükselen, ateş toplarını ve oyuncuları durduran geçici duvar.

const SIZE := Vector3(3.0, 2.2, 0.4)
const LIFE := 8.0


func _ready() -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = SIZE
	mi.mesh = bm
	mi.position.y = SIZE.y * 0.5
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.5, 0.45)
	m.roughness = 0.95
	mi.material_override = m
	add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = SIZE
	cs.shape = sh
	cs.position.y = SIZE.y * 0.5
	add_child(cs)

	Sfx.play3d(Sfx.rumble, global_position + Vector3.UP, 0.0)
	var top := position.y
	position.y -= SIZE.y # yerin altından yükselir
	var tw := create_tween()
	tw.tween_property(self, "position:y", top, 0.2).set_ease(Tween.EASE_OUT)
	tw.tween_interval(LIFE)
	tw.tween_property(self, "position:y", top - SIZE.y, 0.4)
	tw.tween_callback(queue_free)
