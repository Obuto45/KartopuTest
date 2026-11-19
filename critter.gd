extends "res://chicken.gd"
## Açık dünyanın süs hayvanları: tavukla aynı gezinme/kaçma/vurulma davranışı, yalnızca görünüş ve yürüyüş farklı.
## kind: deer (geyik), rabbit (tavşan), frog (kurbağa), crow (karga), lizard (kertenkele), cat (kedi).
## shortcut: chicken.gd gibi yalnızca görüntü; doğma yeri tohumdan gelir, sonraki yürüyüş her makinede yerel.

var kind := "rabbit"
var _hop := 0.0 # sekerek giden türlerde gövde sıçrama yüksekliği


func _model() -> void:
	var ball := SphereMesh.new()
	ball.radial_segments = 10; ball.rings = 5
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0; cone.radial_segments = 6
	var leg := CylinderMesh.new()
	leg.radial_segments = 5
	body = Node3D.new()
	add_child(body)
	head = Node3D.new()
	var eye := Color(0.04, 0.04, 0.04)
	match kind:
		"deer":
			var c := Color(0.5, 0.32, 0.18).lerp(Color(0.62, 0.42, 0.24), rng.randf())
			_part(body, ball, Vector3(0, 0.95, 0), Vector3(0.36, 0.38, 0.85), c)
			_part(body, ball, Vector3(0, 1.0, 0.42), Vector3(0.1, 0.12, 0.08), Color(0.92, 0.9, 0.85)) # kuyruk
			_part(body, ball, Vector3(0, 1.22, -0.36), Vector3(0.17, 0.42, 0.18), c).rotation.x = -0.5 # boyun
			head.position = Vector3(0, 1.42, -0.48)
			body.add_child(head)
			_part(head, ball, Vector3(0, 0, -0.08), Vector3(0.17, 0.18, 0.32), c)
			_part(head, ball, Vector3(0, -0.03, -0.24), Vector3(0.07, 0.06, 0.06), eye) # burun
			for sx in [-1.0, 1.0]:
				_part(head, ball, Vector3(sx * 0.08, 0.04, -0.12), Vector3.ONE * 0.035, eye)
				_part(head, ball, Vector3(sx * 0.11, 0.1, 0.04), Vector3(0.05, 0.11, 0.03), c).rotation.z = sx * -0.6 # kulak
				if rng.randf() < 0.5: # boynuz
					_part(head, leg, Vector3(sx * 0.07, 0.24, 0.0), Vector3(0.03, 0.16, 0.03), Color(0.85, 0.78, 0.62)).rotation.z = sx * -0.35
				for sz in [-1.0, 1.0]:
					_part(self, leg, Vector3(sx * 0.13, 0.4, sz * 0.3), Vector3(0.07, 0.4, 0.07), c.darkened(0.2))
			radius = 0.5
			height = 1.6
			speed = 1.1
		"rabbit":
			var c: Color = [Color(0.55, 0.45, 0.36), Color(0.75, 0.72, 0.68), Color(0.38, 0.3, 0.24)][rng.randi() % 3]
			_part(body, ball, Vector3(0, 0.18, 0), Vector3(0.22, 0.22, 0.32), c)
			_part(body, ball, Vector3(0, 0.22, 0.17), Vector3.ONE * 0.09, Color(0.95, 0.95, 0.92))
			head.position = Vector3(0, 0.3, -0.16)
			body.add_child(head)
			_part(head, ball, Vector3(0, 0, -0.03), Vector3(0.16, 0.15, 0.18), c)
			for sx in [-1.0, 1.0]:
				_part(head, ball, Vector3(sx * 0.05, 0.03, -0.09), Vector3.ONE * 0.03, eye)
				_part(head, ball, Vector3(sx * 0.035, 0.16, 0.02), Vector3(0.045, 0.2, 0.06), c).rotation.z = sx * -0.2
			_hop = 0.16
			speed = 1.3
		"frog":
			var c := Color(0.22, 0.42, 0.14).lerp(Color(0.4, 0.46, 0.16), rng.randf())
			_part(body, ball, Vector3(0, 0.09, 0), Vector3(0.24, 0.14, 0.28), c)
			head.position = Vector3(0, 0.13, -0.08)
			body.add_child(head)
			for sx in [-1.0, 1.0]:
				_part(head, ball, Vector3(sx * 0.06, 0.03, 0), Vector3.ONE * 0.07, c)
				_part(head, ball, Vector3(sx * 0.07, 0.05, -0.02), Vector3.ONE * 0.035, eye)
				_part(body, ball, Vector3(sx * 0.12, 0.04, 0.08), Vector3(0.08, 0.06, 0.16), c.darkened(0.15)) # arka bacak
			_hop = 0.22
			speed = 0.5
		"crow":
			var c := Color(0.06, 0.06, 0.08)
			_part(body, ball, Vector3(0, 0.24, 0), Vector3(0.2, 0.2, 0.36), c)
			_part(body, ball, Vector3(0, 0.27, 0.26), Vector3(0.12, 0.04, 0.22), c) # kuyruk
			for sx in [-1.0, 1.0]:
				var w := Node3D.new()
				w.position = Vector3(sx * 0.1, 0.28, 0.0)
				body.add_child(w)
				_part(w, ball, Vector3(sx * 0.02, -0.03, 0.04), Vector3(0.05, 0.12, 0.3), Color(0.1, 0.1, 0.13))
				wings.append(w)
				_part(self, leg, Vector3(sx * 0.05, 0.08, 0), Vector3(0.025, 0.08, 0.025), Color(0.2, 0.2, 0.2))
			head.position = Vector3(0, 0.34, -0.15)
			body.add_child(head)
			_part(head, ball, Vector3(0, 0.03, -0.03), Vector3.ONE * 0.15, c)
			_part(head, cone, Vector3(0, 0.02, -0.15), Vector3(0.05, 0.06, 0.05), Color(0.15, 0.15, 0.15)).rotation.x = -PI / 2
			speed = 0.8
		"lizard":
			var c := Color(0.42, 0.2, 0.1).lerp(Color(0.3, 0.26, 0.22), rng.randf())
			_part(body, ball, Vector3(0, 0.06, 0), Vector3(0.11, 0.06, 0.3), c)
			_part(body, cone, Vector3(0, 0.05, 0.33), Vector3(0.05, 0.2, 0.05), c).rotation.x = PI / 2 # kuyruk
			head.position = Vector3(0, 0.06, -0.28)
			body.add_child(head)
			_part(head, ball, Vector3(0, 0, -0.03), Vector3(0.08, 0.05, 0.11), c)
			for sx in [-1.0, 1.0]:
				_part(head, ball, Vector3(sx * 0.035, 0.02, -0.03), Vector3.ONE * 0.02, Color(0.8, 0.6, 0.1))
				for sz in [-1.0, 1.0]:
					_part(body, ball, Vector3(sx * 0.11, 0.03, sz * 0.12), Vector3(0.08, 0.03, 0.04), c.darkened(0.2))
			speed = 1.6
		_: # cat
			var c: Color = [Color(0.85, 0.5, 0.2), Color(0.45, 0.45, 0.47), Color(0.1, 0.1, 0.1), Color(0.92, 0.9, 0.86)][rng.randi() % 4]
			_part(body, ball, Vector3(0, 0.27, 0), Vector3(0.19, 0.19, 0.42), c)
			_part(body, leg, Vector3(0, 0.42, 0.28), Vector3(0.045, 0.15, 0.045), c).rotation.x = 0.6 # kuyruk
			head.position = Vector3(0, 0.38, -0.24)
			body.add_child(head)
			_part(head, ball, Vector3(0, 0.02, -0.03), Vector3(0.17, 0.15, 0.15), c)
			for sx in [-1.0, 1.0]:
				_part(head, cone, Vector3(sx * 0.055, 0.12, -0.01), Vector3(0.05, 0.04, 0.04), c)
				_part(head, ball, Vector3(sx * 0.04, 0.04, -0.1), Vector3.ONE * 0.03, Color(0.5, 0.75, 0.2))
				for sz in [-1.0, 1.0]:
					_part(self, leg, Vector3(sx * 0.08, 0.1, sz * 0.15), Vector3(0.06, 0.1, 0.06), c)
			radius = 0.35
			speed = 1.0


func _process(dt: float) -> void:
	super(dt)
	if _hop > 0.0: # kurbağa/tavşan seker: yürürken kısa zıplamalar
		var to := target - position
		body.position.y = absf(sin(t * 6.0)) * _hop if Vector2(to.x, to.z).length() > 0.15 else 0.0
