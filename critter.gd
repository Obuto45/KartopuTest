extends "res://chicken.gd"
## Açık dünyanın özenli stilize hayvanları: geyik, tavşan, kurbağa, karga, kertenkele, kedi.
## Hareketli bacaklar, sallanan kuyruklar, simetrik dallı boynuzlar, parlak gözler ve türe özgü yürüyüşler.

var kind := "rabbit"
var _hop := 0.0 # sekerek giden türlerde sıçrama yüksekliği
var _hop_freq := 6.5


func _model() -> void:
	var ball := SphereMesh.new()
	ball.radial_segments = 14; ball.rings = 7
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0; cone.radial_segments = 8
	var leg := CylinderMesh.new()
	leg.radial_segments = 8
	body = Node3D.new()
	add_child(body)
	head = Node3D.new()
	var eye := Color(0.03, 0.03, 0.04)
	var shine := Color(0.98, 0.98, 1.0)
	match kind:
		"deer":
			var c := Color(0.54, 0.34, 0.18).lerp(Color(0.68, 0.46, 0.26), rng.randf())
			var cream := Color(0.92, 0.87, 0.76)
			var hoof := Color(0.16, 0.13, 0.11)
			# Gövde, açık karın ve benekler
			_part(body, ball, Vector3(0, 0.96, 0), Vector3(0.38, 0.40, 0.88), c)
			_part(body, ball, Vector3(0, 0.83, 0.02), Vector3(0.30, 0.24, 0.72), cream)
			for sp in [Vector3(-0.15, 1.06, 0.08), Vector3(0.16, 1.04, 0.16), Vector3(-0.13, 1.08, -0.14), Vector3(0.14, 1.07, -0.06)]:
				_part(body, ball, sp, Vector3(0.055, 0.035, 0.065), cream)
			# Kuyruk (sallanan beyaz-kahve kuyruk)
			tail_node = Node3D.new()
			tail_node.position = Vector3(0, 1.04, 0.42)
			body.add_child(tail_node)
			_part(tail_node, ball, Vector3(0, -0.04, 0.06), Vector3(0.10, 0.14, 0.12), cream)
			_part(tail_node, ball, Vector3(0, 0.0, 0.07), Vector3(0.08, 0.10, 0.08), c.darkened(0.15))
			# Boyun ve göğüs tüyü
			_part(body, ball, Vector3(0, 1.24, -0.36), Vector3(0.18, 0.44, 0.20), c).rotation.x = -0.45
			_part(body, ball, Vector3(0, 1.12, -0.40), Vector3(0.14, 0.26, 0.14), cream).rotation.x = -0.35
			# Baş, burun, kulaklar ve simetrik dallı boynuzlar
			head.position = Vector3(0, 1.46, -0.48)
			body.add_child(head)
			_part(head, ball, Vector3(0, 0.01, -0.06), Vector3(0.19, 0.19, 0.26), c)
			_part(head, ball, Vector3(0, -0.03, -0.20), Vector3(0.12, 0.11, 0.18), c.lightened(0.08))
			_part(head, ball, Vector3(0, -0.02, -0.29), Vector3(0.065, 0.055, 0.055), eye, 0.25)
			var has_antlers := rng.randf() < 0.6 # tek seferde zar at -> iki boynuz hep simetrik!
			var antler_c := Color(0.84, 0.76, 0.60)
			for sx in [-1.0, 1.0]:
				_part(head, ball, Vector3(sx * 0.085, 0.045, -0.12), Vector3.ONE * 0.038, eye, 0.12)
				_part(head, ball, Vector3(sx * 0.095, 0.056, -0.138), Vector3.ONE * 0.014, shine, 0.1)
				var ear := _part(head, ball, Vector3(sx * 0.13, 0.11, 0.03), Vector3(0.055, 0.13, 0.04), c)
				ear.rotation.z = sx * -0.65
				_part(head, ball, Vector3(sx * 0.12, 0.10, 0.01), Vector3(0.032, 0.08, 0.02), Color(0.88, 0.68, 0.62)).rotation.z = sx * -0.65
				if has_antlers:
					var ant := Node3D.new()
					ant.position = Vector3(sx * 0.05, 0.10, 0.0)
					head.add_child(ant)
					var main_b := _part(ant, leg, Vector3(sx * 0.06, 0.15, 0.0), Vector3(0.026, 0.16, 0.026), antler_c, 0.55)
					main_b.rotation.z = sx * -0.38
					var tine1 := _part(ant, leg, Vector3(sx * 0.12, 0.27, -0.04), Vector3(0.02, 0.10, 0.02), antler_c, 0.55)
					tine1.rotation = Vector3(-0.35, 0.0, sx * -0.15)
					var tine2 := _part(ant, leg, Vector3(sx * 0.14, 0.24, 0.05), Vector3(0.018, 0.09, 0.018), antler_c, 0.55)
					tine2.rotation = Vector3(0.3, 0.0, sx * -0.55)
				for sz in [-1.0, 1.0]:
					var lp := _leg_pivot(body, Vector3(sx * 0.14, 0.78, sz * 0.29), sx * sz)
					_part(lp, leg, Vector3(0, -0.34, 0), Vector3(0.062, 0.36, 0.062), c.darkened(0.14))
					_part(lp, leg, Vector3(0, -0.72, 0), Vector3(0.066, 0.06, 0.072), hoof, 0.45)
			radius = 0.55
			height = 1.65
			speed = 1.35
		"rabbit":
			var c: Color = [Color(0.62, 0.50, 0.38), Color(0.86, 0.83, 0.78), Color(0.44, 0.34, 0.26), Color(0.76, 0.56, 0.34)][rng.randi() % 4]
			var pink := Color(0.95, 0.66, 0.70)
			_part(body, ball, Vector3(0, 0.19, 0.02), Vector3(0.24, 0.23, 0.34), c)
			_part(body, ball, Vector3(0, 0.13, 0.0), Vector3(0.18, 0.14, 0.26), c.lightened(0.22))
			tail_node = Node3D.new()
			tail_node.position = Vector3(0, 0.20, 0.19)
			body.add_child(tail_node)
			_part(tail_node, ball, Vector3(0, 0.02, 0.03), Vector3.ONE * 0.105, Color(0.97, 0.96, 0.94))
			head.position = Vector3(0, 0.31, -0.16)
			body.add_child(head)
			_part(head, ball, Vector3(0, 0.01, -0.02), Vector3(0.17, 0.16, 0.19), c)
			_part(head, ball, Vector3(0, -0.01, -0.115), Vector3(0.042, 0.032, 0.03), pink, 0.4)
			for sx in [-1.0, 1.0]:
				_part(head, ball, Vector3(sx * 0.065, 0.03, -0.085), Vector3.ONE * 0.032, eye, 0.12)
				_part(head, ball, Vector3(sx * 0.074, 0.04, -0.098), Vector3.ONE * 0.011, shine, 0.1)
				_part(head, ball, Vector3(sx * 0.045, 0.16, 0.02), Vector3(0.048, 0.21, 0.055), c).rotation = Vector3(0.15, 0, sx * -0.22)
				_part(head, ball, Vector3(sx * 0.045, 0.16, -0.002), Vector3(0.026, 0.15, 0.02), pink).rotation = Vector3(0.15, 0, sx * -0.22)
				_part(body, ball, Vector3(sx * 0.11, 0.11, 0.10), Vector3(0.09, 0.12, 0.14), c.darkened(0.08)) # arka but
				_part(body, ball, Vector3(sx * 0.09, 0.04, 0.06), Vector3(0.055, 0.04, 0.12), c.lightened(0.1)) # pati
				_part(body, ball, Vector3(sx * 0.06, 0.05, -0.12), Vector3(0.045, 0.07, 0.06), c.lightened(0.08))
			_hop = 0.22
			_hop_freq = 7.5
			speed = 1.45
		"frog":
			allow_water = true
			var c := Color(0.20, 0.50, 0.18).lerp(Color(0.34, 0.56, 0.20), rng.randf())
			var belly := Color(0.82, 0.88, 0.62)
			_part(body, ball, Vector3(0, 0.10, 0.01), Vector3(0.25, 0.15, 0.29), c, 0.38)
			_part(body, ball, Vector3(0, 0.06, -0.03), Vector3(0.19, 0.10, 0.22), belly, 0.5)
			for sp in [Vector3(-0.06, 0.165, 0.04), Vector3(0.07, 0.16, 0.08), Vector3(0.0, 0.17, -0.02)]:
				_part(body, ball, sp, Vector3(0.05, 0.02, 0.05), c.darkened(0.32), 0.35)
			head.position = Vector3(0, 0.14, -0.08)
			body.add_child(head)
			for sx in [-1.0, 1.0]:
				_part(head, ball, Vector3(sx * 0.065, 0.04, -0.01), Vector3.ONE * 0.072, c, 0.35)
				_part(head, ball, Vector3(sx * 0.072, 0.055, -0.038), Vector3.ONE * 0.042, Color(0.95, 0.80, 0.15), 0.15)
				_part(head, ball, Vector3(sx * 0.076, 0.058, -0.056), Vector3.ONE * 0.024, eye, 0.1)
				_part(body, ball, Vector3(sx * 0.13, 0.06, 0.08), Vector3(0.09, 0.08, 0.17), c.darkened(0.14), 0.4)
				_part(body, ball, Vector3(sx * 0.11, 0.03, -0.10), Vector3(0.05, 0.06, 0.07), c.darkened(0.1), 0.4)
			_hop = 0.28
			_hop_freq = 5.5
			speed = 0.65
		"crow":
			var c := Color(0.08, 0.10, 0.15)
			var sheen := Color(0.14, 0.18, 0.28)
			_part(body, ball, Vector3(0, 0.25, 0), Vector3(0.21, 0.21, 0.38), c, 0.42)
			tail_node = Node3D.new()
			tail_node.position = Vector3(0, 0.27, 0.18)
			body.add_child(tail_node)
			_part(tail_node, ball, Vector3(0, 0.01, 0.12), Vector3(0.15, 0.04, 0.24), sheen, 0.42)
			for sx in [-1.0, 1.0]:
				var w := Node3D.new()
				w.position = Vector3(sx * 0.10, 0.29, -0.02)
				body.add_child(w)
				_part(w, ball, Vector3(sx * 0.04, -0.03, 0.05), Vector3(0.06, 0.14, 0.34), sheen, 0.40)
				_part(w, ball, Vector3(sx * 0.12, -0.01, 0.10), Vector3(0.14, 0.04, 0.22), c, 0.45)
				wings.append(w)
				var lp := _leg_pivot(body, Vector3(sx * 0.055, 0.15, 0), sx)
				_part(lp, leg, Vector3(0, -0.07, 0), Vector3(0.022, 0.08, 0.022), Color(0.22, 0.22, 0.24), 0.5)
				_part(lp, ball, Vector3(0, -0.14, -0.02), Vector3(0.045, 0.018, 0.065), Color(0.22, 0.22, 0.24), 0.5)
			head.position = Vector3(0, 0.35, -0.15)
			body.add_child(head)
			_part(head, ball, Vector3(0, 0.03, -0.03), Vector3(0.15, 0.15, 0.17), c, 0.4)
			_part(head, cone, Vector3(0, 0.015, -0.17), Vector3(0.052, 0.08, 0.052), Color(0.18, 0.19, 0.22), 0.32).rotation.x = -PI / 2
			for sx in [-1.0, 1.0]:
				_part(head, ball, Vector3(sx * 0.06, 0.045, -0.07), Vector3.ONE * 0.028, Color(0.92, 0.78, 0.22), 0.15)
				_part(head, ball, Vector3(sx * 0.066, 0.046, -0.082), Vector3.ONE * 0.016, eye, 0.1)
			speed = 0.95
		"lizard":
			var c := Color(0.48, 0.26, 0.12).lerp(Color(0.26, 0.44, 0.22), rng.randf())
			var crest := c.lightened(0.28)
			_part(body, ball, Vector3(0, 0.07, 0), Vector3(0.13, 0.075, 0.34), c, 0.45)
			for zi in [-0.10, -0.02, 0.06, 0.13]:
				_part(body, cone, Vector3(0, 0.115, zi), Vector3(0.025, 0.04, 0.03), crest, 0.5)
			tail_node = Node3D.new()
			tail_node.position = Vector3(0, 0.06, 0.16)
			body.add_child(tail_node)
			_part(tail_node, cone, Vector3(0, 0.0, 0.20), Vector3(0.06, 0.28, 0.06), c, 0.45).rotation.x = PI / 2
			head.position = Vector3(0, 0.075, -0.20)
			body.add_child(head)
			_part(head, ball, Vector3(0, 0, -0.05), Vector3(0.095, 0.065, 0.14), c, 0.45)
			for sx in [-1.0, 1.0]:
				_part(head, ball, Vector3(sx * 0.042, 0.025, -0.06), Vector3.ONE * 0.024, Color(0.95, 0.72, 0.15), 0.15)
				for sz in [-1.0, 1.0]:
					var lp := _leg_pivot(body, Vector3(sx * 0.06, 0.05, sz * 0.11), sx * sz)
					_part(lp, ball, Vector3(sx * 0.06, -0.02, 0), Vector3(0.09, 0.035, 0.045), c.darkened(0.18), 0.5)
			speed = 1.85
		_: # cat
			var coat := rng.randi() % 4
			var c: Color = [Color(0.88, 0.52, 0.20), Color(0.46, 0.48, 0.52), Color(0.12, 0.12, 0.15), Color(0.94, 0.90, 0.84)][coat]
			var chest := Color(0.96, 0.94, 0.90) if coat != 3 else Color(0.84, 0.72, 0.58)
			var pink := Color(0.95, 0.62, 0.68)
			_part(body, ball, Vector3(0, 0.28, 0), Vector3(0.21, 0.20, 0.45), c)
			_part(body, ball, Vector3(0, 0.25, -0.17), Vector3(0.15, 0.15, 0.14), chest)
			tail_node = Node3D.new()
			tail_node.position = Vector3(0, 0.34, 0.20)
			body.add_child(tail_node)
			_part(tail_node, leg, Vector3(0, 0.10, 0.07), Vector3(0.045, 0.15, 0.045), c).rotation.x = 0.55
			_part(tail_node, ball, Vector3(0, 0.21, 0.13), Vector3(0.048, 0.065, 0.048), chest if coat == 0 else c)
			head.position = Vector3(0, 0.39, -0.24)
			body.add_child(head)
			_part(head, ball, Vector3(0, 0.02, -0.02), Vector3(0.19, 0.17, 0.17), c)
			_part(head, ball, Vector3(0, -0.01, -0.10), Vector3(0.08, 0.06, 0.06), chest)
			_part(head, ball, Vector3(0, 0.005, -0.13), Vector3(0.03, 0.022, 0.022), pink, 0.35)
			for sx in [-1.0, 1.0]:
				_part(head, cone, Vector3(sx * 0.062, 0.125, -0.01), Vector3(0.056, 0.06, 0.048), c).rotation.z = sx * -0.18
				_part(head, cone, Vector3(sx * 0.060, 0.12, -0.024), Vector3(0.03, 0.04, 0.02), pink).rotation.z = sx * -0.18
				_part(head, ball, Vector3(sx * 0.048, 0.042, -0.092), Vector3.ONE * 0.034, Color(0.42, 0.86, 0.30), 0.14)
				_part(head, ball, Vector3(sx * 0.050, 0.042, -0.108), Vector3(0.012, 0.024, 0.012), eye, 0.1)
				for sz in [-1.0, 1.0]:
					var lp := _leg_pivot(body, Vector3(sx * 0.082, 0.21, sz * 0.15), sx * sz)
					_part(lp, leg, Vector3(0, -0.10, 0), Vector3(0.056, 0.11, 0.056), c)
					_part(lp, ball, Vector3(0, -0.195, -0.01), Vector3(0.062, 0.038, 0.075), chest)
			radius = 0.36
			speed = 1.15


func _process(dt: float) -> void:
	super(dt)
	var to := target - position
	to.y = 0.0
	var moving := to.length() > 0.15
	if _hop > 0.0: # kurbağa / tavşan: yaylı sıçrama + gövde eğimi
		var phase := sin(t * (_hop_freq * (1.5 if scare > 0.0 else 1.0)))
		body.position.y = absf(phase) * _hop if moving else 0.0
		body.rotation.x = (phase * 0.22) if moving else lerpf(body.rotation.x, 0.0, minf(dt * 8.0, 1.0))
	elif kind == "crow" and scare > 0.0 and moving:
		body.position.y = 0.18 + absf(sin(t * 16.0)) * 0.18 # ürken karga alçaktan kanat çırparak kaçar
