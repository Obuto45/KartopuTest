extends Node
## Açık Dünya karanlık haritada: godot --headless --path . res://tests/open_world_test.tscn  ->  OPEN_WORLD_TEST: N/M
## Yerleşim tohumdan aynı, zeminde, sınırda, aralıklı, biyomlara yayılmış; uzak düşman uyur, yakındaki uyanık.

const WorldScript := preload("res://world.gd")
const OpenWorldScript := preload("res://open_world.gd")

var good := 0
var total := 0


func _ok(title: String, cond: bool, note := "") -> void:
	total += 1
	good += int(cond)
	print("[%s] %s %s" % ["OK" if cond else "HATA", title, note])


func _ready() -> void:
	var w: Node3D = WorldScript.new()
	var lay: Dictionary = OpenWorldScript.make_layout(w)
	var lay2: Dictionary = OpenWorldScript.make_layout(WorldScript.new())
	_ok("aynı tohum aynı yerleşim", str(lay.clear) == str(lay2.clear))
	_ok("8 ev, 5 kamp, 4 karakol", lay.houses.size() == 8 and lay.camps.size() == 5 and lay.outposts.size() == 4)
	var pts: Array = lay.clear
	var on_ground := true
	var inside := true
	var gap := INF
	for i in pts.size():
		var p: Vector3 = pts[i]
		on_ground = on_ground and absf(p.y - w.height(p.x, p.z)) < 0.5
		inside = inside and absf(p.x) < WorldScript.HALF - 20.0 and absf(p.z) < WorldScript.HALF - 20.0
		for j in range(i + 1, pts.size()):
			gap = minf(gap, Vector2(p.x - pts[j].x, p.z - pts[j].z).length())
	_ok("hepsi zeminde", on_ground)
	_ok("hepsi dünya sınırı içinde", inside)
	_ok("en az 60 m aralık", gap >= 60.0, "%.1f m" % gap)
	var biomes := {}
	for h: Dictionary in lay.houses:
		biomes[h.biome] = biomes.get(h.biome, 0) + 1
	_ok("evler 4 biyoma yayılmış", biomes.size() == 4, str(biomes))
	var boss: Vector3 = lay.camps[4].pos
	_ok("boss kampı uzakta, kül dağlarında", Vector2(boss.x, boss.z).length() > 300.0 and w.biome_at(boss.x, boss.z) == 2)
	var d0 := Vector2(lay.houses[0].pos.x, lay.houses[0].pos.z).length()
	var d7 := Vector2(lay.houses[7].pos.x, lay.houses[7].pos.z).length()
	_ok("evler yakından uzağa sıralı (kutu kademesi)", d0 < d7)

	# Tam kurulum: main.gd _start_open_world gibi
	var root := Node3D.new()
	add_child(root)
	w.clear_pts = lay.clear
	root.add_child(w)
	var players := Node3D.new()
	root.add_child(players)
	w.players = players
	var ow: Node = OpenWorldScript.new()
	ow.world = w
	ow.layout = lay
	root.add_child(ow)
	_ok("48 karakter muhafızı", ow.rivals_total == 48, str(ow.rivals_total))
	for i in 30:
		await get_tree().physics_frame
	var far_sleep := true
	for e: Node3D in ow.elist:
		var k := Vector2i(floori(e.position.x / WorldScript.CHUNK), floori(e.position.z / WorldScript.CHUNK))
		if not w.chunks.has(k):
			far_sleep = far_sleep and e.process_mode == Node.PROCESS_MODE_DISABLED
	_ok("yüklenmemiş chunk'taki düşmanlar uyuyor", far_sleep)
	var fell := false
	for e: Node3D in ow.elist:
		fell = fell or e.position.y < w.height(e.position.x, e.position.z) - 3.0
	_ok("hiçbir düşman zeminin altına düşmedi", not fell)
	print("OPEN_WORLD_TEST: %d/%d" % [good, total])
	get_tree().quit(0 if good == total else 1)
