extends Node
## Açık dünya: godot --headless --path . res://tests/world_test.tscn  ->  WORLD_TEST: N/M
## Tohum kararlılığı, 4 biyomun varlığı, hayvan planı, patikalar, doğma noktası, chunk yükleme/kaldırma, zemin çarpışması.

const WorldScript := preload("res://world.gd")

var good := 0
var total := 0


func _ok(title: String, cond: bool, note := "") -> void:
	total += 1
	good += int(cond)
	print("[%s] %s %s" % ["OK" if cond else "HATA", title, note])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	var a: Node3D = WorldScript.new()
	var b: Node3D = WorldScript.new()
	var same := true
	var seen := {}
	for x in range(-500, 500, 25):
		for z in range(-500, 500, 25):
			if a.height(x, z) != b.height(x, z) or a.biome_at(x, z) != b.biome_at(x, z):
				same = false
			seen[a.biome_at(x, z)] = seen.get(a.biome_at(x, z), 0) + 1
	_ok("aynı tohum aynı yükseklik/biyom", same)
	_ok("4 biyomun hepsi haritada", seen.size() == 4, str(seen))
	# Hayvanlar: tohumdan, her makinede aynı; chunk başına sınırlı; tür biyoma uygun.
	var fsame := true
	var fcap := true
	var fkind := true
	var kinds := {}
	for x in range(-8, 8):
		for z in range(-8, 8):
			var k := Vector2i(x, z)
			var fa: Array = a.fauna(k)
			fsame = fsame and str(fa) == str(b.fauna(k))
			fcap = fcap and fa.size() <= WorldScript.MAX_FAUNA
			for it in fa:
				kinds[it[0]] = kinds.get(it[0], 0) + 1
				var p: Vector3 = it[1] + Vector3(x, 0, z) * WorldScript.CHUNK
				var ok := false
				for bi in 4:
					ok = ok or (it[0] in WorldScript.FAUNA[bi] and a.weights(p.x, p.z)[bi] > 0.05)
				fkind = fkind and ok
	_ok("hayvanlar: aynı tohum aynı yer, chunk başına sınırlı, biyoma uygun", fsame and fcap and fkind and kinds.size() >= 6, str(kinds))
	# Patikalar: yol ortası toprak, yollar arası değil.
	var on := true
	for i in WorldScript.ROADS:
		for r in [30.0, 120.0, 300.0]:
			var q := Vector2(r, 0).rotated(a.road_angle(i, r))
			on = on and a.path_at(q.x, q.y) > 0.99
	var mid := Vector2(100, 0).rotated((a.road_angle(0, 100) + a.road_angle(1, 100)) * 0.5)
	_ok("patika: yol ortası toprak, merkez meydan, yollar arası çimen", on and a.path_at(0, 0) > 0.99 and a.path_at(mid.x, mid.y) == 0.0)
	b.free()

	var cam := Camera3D.new() # ortam güncellemesi kamerayı okur
	add_child(cam)
	var players := Node3D.new()
	add_child(players)
	var walker := Node3D.new()
	players.add_child(walker)
	a.players = players
	add_child(a)
	var sp: Array = a.spawns()
	var above := true
	for p in sp:
		above = above and p.y > a.height(p.x, p.z) + 0.5
	_ok("doğma noktaları zemin üstünde", above, str(sp[0]))
	await _frames(3)
	var hit := get_viewport().world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(sp[0], sp[0] + Vector3.DOWN * 5.0))
	_ok("doğma noktasının altında çarpışan zemin", not hit.is_empty())

	var worst := 0.0
	for i in 120:
		await get_tree().process_frame
		worst = maxf(worst, a.build_ms)
	var r: int = WorldScript.RADIUS[Settings.quality]
	_ok("merkez chunk'ları yüklü", a.chunks.has(Vector2i(0, 0)) and a.chunks.has(Vector2i(-1, -1)), "%d chunk" % a.chunks.size())
	_ok("uzak chunk yüklenmedi", not a.chunks.has(Vector2i(r + 2, 0)))
	print("en yavaş chunk: %.1f ms, adımlar: %s" % [worst, a.stage_ms])
	# Kurulmuş chunk'larda: yol üstünde çarpışan dekor yok, hayvan sayısı plana eşit.
	var clear := true
	var animals := 0
	var planned := 0
	var road_chunks := 0
	for k in a.chunks:
		var node: Node3D = a.chunks[k]
		if not node.has_meta("done"):
			continue
		var fa := node.get_node_or_null("Fauna")
		animals += fa.get_child_count() if fa else 0
		planned += a.fauna(k).size()
		if (node.get_meta("ps") as PackedFloat32Array).has(1.0):
			road_chunks += 1
		for c in node.get_node("Body").get_children(): # çarpışan dekor (ağaç, kaya, duvar); zemin ağı hariç
			if not c.shape is ConcavePolygonShape3D:
				var o: Vector3 = c.position + node.position
				if a.path_dist(o.x, o.z) < 3.0:
					clear = false
	_ok("yol üstünde dekor yok, hayvanlar chunk'la doğdu", clear and road_chunks > 0 and animals == planned and animals > 0,
		"yollu chunk %d, hayvan %d/%d" % [road_chunks, animals, planned])

	walker.position = Vector3(320, 0, 320)
	for i in 150:
		await get_tree().process_frame
	_ok("yeni konumun chunk'ı yüklendi", a.chunks.has(Vector2i(5, 5)), "%d chunk" % a.chunks.size())
	_ok("eski merkez chunk'ı kaldırıldı", not a.chunks.has(Vector2i(0, 0)))
	walker.position = Vector3(2000, 0, 2000) # dünya dışı: geçersiz chunk kurulmamalı
	for i in 30:
		await get_tree().process_frame
	var bad: Array = a.chunks.keys().filter(func(k): return not a._valid(k))
	_ok("dünya dışında chunk yok", bad.is_empty())

	print("WORLD_TEST: %d/%d" % [good, total])
	get_tree().quit(0 if good == total else 1)
