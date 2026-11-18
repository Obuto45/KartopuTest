extends Node3D
## Silah başına kavrama uydurma (oyun açılışında değil, elle çalıştırılır):
##   godot --headless --path . res://tests/grip_fit.tscn [-- pistol smg ...]
## Her silah ve elde: (1) avuç, avuç normali boyunca silah yüzeyine 1 mm kalana dek kayar ("o");
## (2) her parmak zinciri düz başlar, eklemler küçük adımlarla bükülür; bir boğum silahın üçgenlerine değince
## o boğum ve köküne yakın eklemler durur, uca yakın olanlar kapanmayı sürdürür (çarpışmada adım geri alınır).
## Başparmak "open" pozundan şablonun yönünde kapanır. Sonuç weapon_anims.gd'de "# FIT:begin/end" arasına yazılır.

const GT := preload("res://tests/grip_test.gd")
const VM := preload("res://viewmodel.gd")
const WA := preload("res://weapon_anims.gd")
const Hands := preload("res://hands.gd")
const IDS := ["pistol", "smg", "shotgun", "sniper", "bazooka", "flame", "bow", "sword", "boomerang", "grenade", "item:bomb", "item:potion"]
const TOUCH := 0.0012 # boğum yüzeye bu kadar yakınsa değmiş say
const PEN := 0.0005 # bundan derine giren adım geri alınır (başparmakta T_PEN: yumuşak et kabzaya hafif basar)
const T_PEN := 0.0025
const PALM_GAP := 0.0 # avuç-yüzey hedef aralığı
const F_END := [-1.65, -1.75, -1.3] # parmak eklemi en çok bükülme (kök, orta, uç)
const T_END := [-1.1, -1.2] # başparmak orta/uç en çok bükülme
const T_TRY := [Vector2.ZERO, Vector2(-0.4, 0), Vector2(0.4, 0), Vector2(0, -0.5), Vector2(0, 0.5),
	Vector2(-0.4, -0.5), Vector2(-0.4, 0.5), Vector2(0.4, -0.5), Vector2(0.4, 0.5)]

var vm: Node3D
var tris := []
var pen := PEN
var lean := 0.0 # puana eklenen: q0 (şablon oranı) 1/1,4'ten uzaklığı x lean (başparmak şablon yanında kalsın)


func _ready() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	vm = VM.new()
	add_child(vm)
	vm.setup(Color(0.85, 0.65, 0.5), "res://models/chars/casual_male.glb")
	var ids: Array = OS.get_cmdline_user_args() if OS.get_cmdline_user_args().size() > 0 else IDS
	var out: Dictionary = WA.FIT.duplicate(true)
	for id: String in ids:
		await GT.hold(vm, id)
		for side in ["R", "L"]:
			var e := fit(id, side)
			if not e.is_empty():
				out.get_or_add(id, {})[side] = e
			elif out.has(id):
				out[id].erase(side)
	_write(out)
	get_tree().quit()


## Bir el: {"o": kayma, "f", "s", "t"} ya da {} (uydurulmaz).
func fit(id: String, side: String) -> Dictionary:
	var name: String = WA.hold_r(id) if side == "R" else WA.hold_l(id)
	# çimdik (yay oku, bomba halkası) şablonda kalır: uçları küçük bir parçada, öbür parmaklar havada
	if name not in ["grip", "support", "bottle"] or (side == "L" and id in WA.ONE_HAND):
		return {}
	var hand: Node3D = vm.hand_r if side == "R" else vm.hand_l
	var old: Dictionary = WA.FIT.get(id, {}).get(side, {})
	var tm: Dictionary = Hands.POSES[name]
	var cur := {"f": [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]], "s": tm.s, "t": (Hands.POSES.open.t as Array).duplicate()}
	var ret := {"o": old.get("o", Vector3.ZERO)}
	Hands.pose(hand, cur)
	tris = GT._near(GT._tris(vm.weapon), GT._aabb(hand).grow(0.06))
	var d := _palm(hand, side)
	ret.o += Vector3(-d if side == "R" else d, 0, 0)
	# iksir: içme klibi "bottle" adını kullanır (weapons_test); parmaklar şablonda, yalnız başparmak uydurulur
	var only_thumb := id == "item:potion"
	if only_thumb:
		cur.f = (tm.f as Array).duplicate(true)
	for i in (0 if only_thumb else 4):
		var end: Array = F_END
		var ch := _chain(hand.find_child("f%d" % i, true, false), Hands.FINGERS[i][2], [Hands.FINGERS[i][3], Hands.FINGERS[i][3] * 0.94, Hands.FINGERS[i][3] * 0.88])
		var tg := vm.weapon.find_child("trigger", true, false) as Node3D
		var aim := GT._tris(tg) if i == 0 and side == "R" and name == "grip" and tg else [] # işaret parmağı tetiğe
		var k := _close(hand, cur, ch, func(c: Dictionary, q0: float, q1: float) -> void:
			c.f[i] = [lerpf(0.0, end[0], q0), lerpf(0.0, end[1], q1), lerpf(0.0, end[2], q1)], 0.0, aim)
		print("  %s %s f%d: %s" % [id, side, i, str(cur.f[i])], "  [", "%.3f" % k, "]")
	var t0: Array = Hands.POSES.open.t
	var tt: Array = tm.t
	var ch := _chain(hand.find_child("thumb", true, false), Hands.THUMB_LEN, Hands.THUMB_R)
	var best := [INF, cur.t]
	pen = T_PEN
	lean = 0.01
	var wrap := 0.6 if side == "R" and name == "grip" else 0.35 # sağ kabza: başparmak şablon yanında (sola dolanır)
	for e: Vector2 in T_TRY: # taban sapma/yuvarlanma denemeleri: başparmak kabzanın öbür yanından dolansın
		var k := _close(hand, cur, ch, func(c: Dictionary, q0: float, q1: float) -> void:
			var b := []
			for j in 3: # taban: open -> şablonun 1,4 katı yönünde
				b.append(t0[j] + (tt[j] - t0[j]) * 1.4 * q0 + [0.0, e.x, e.y][j] * q0)
			c.t = b + [lerpf(t0[3], T_END[0], q1), lerpf(t0[4], T_END[1], q1)], wrap, [], wrap > 0.35)
		if k < best[0]:
			best = [k, (cur.t as Array).duplicate()]
	cur.t = best[1]
	pen = PEN
	lean = 0.0
	Hands.pose(hand, cur)
	print("  %s %s thumb: %s" % [id, side, str(cur.t)], "  [", "%.4f" % best[0], "]")
	ret.merge({"f": cur.f, "s": cur.s, "t": cur.t})
	return ret


## Avucu (parmaksız el gövdesi) normali boyunca yüzeye PALM_GAP kalana dek kaydırır; kayma (m, + = silaha doğru).
func _palm(hand: Node3D, side: String) -> float:
	var n: Vector3 = (hand.global_basis.x * (-1.0 if side == "R" else 1.0)).normalized()
	var vs := []
	for mi in hand.get_node("h").get_children():
		if mi is MeshInstance3D and not mi.name.begins_with("wrist"):
			vs.append_array(GT._verts(mi))
	var g := func(d: float) -> float: return GT._gap(vs.map(func(v): return v + n * d), tris)
	var lo := -0.04
	var hi := 0.04
	if g.call(lo) < PALM_GAP or g.call(hi) > PALM_GAP:
		print("  avuç kaydırılamadı: ", hand.name)
		return 0.0
	for i in 14:
		var m := (lo + hi) * 0.5
		if g.call(m) > PALM_GAP:
			lo = m
		else:
			hi = m
	hand.global_position += n * lo
	print("  %s avuç kayması %.1f mm" % [hand.name, lo * 1000.0])
	return lo


## Zincir: [[eklem düğümü, boy, yarıçap] x3] (yerel; dünya ölçeği düğümden gelir).
static func _chain(j: Node3D, lens: Array, radii: Array) -> Array:
	var out := []
	for s in 3:
		out.append([j, lens[s], radii[s]])
		if s < 2:
			j = j.get_node("a" if s == 0 else "b")
	return out


## Boğumun silaha işaretli uzaklığı (eksen örnekleri - yarıçap); kök boğumda eklem başı (avuca bitişik) sayılmaz.
func _link_gap(l: Array, root: bool) -> float:
	var j: Node3D = l[0]
	var sc := j.global_basis.get_scale().x
	var best := 1.0
	for t in ([0.4, 0.7, 1.0] if root else [0.0, 0.5, 1.0]):
		best = minf(best, GT._gap([j.global_transform * Vector3(0, 0, -l[1] * t)], tris) - l[2] * sc)
	return best


## Kök açısı (q0) taranır; her q0'da orta/uç eklemler birlikte (q1) ilk temasa dek bükülür, derine giren adım geri
## alınır. Seçilen: uç yüzeyde, kök/orta boğumlar yüzeye en yakın (sarar), hiçbiri girmez. aim verilirse (tetik
## üçgenleri) orta/uç boğumun aim'e uzaklığı en küçüklenir. Dönen: seçilenin puanı (INF: girmeyen aday yok).
## soft: girmeyen aday yoksa en az gireni al (sağ el başparmağı kabzanın sol yanında kalsın, açılıp dikilmesin).
func _close(hand: Node3D, cur: Dictionary, ch: Array, apply: Callable, q0_from := 0.0, aim := [], soft := false) -> float:
	var all := tris
	var c: Vector3 = ch[0][0].global_position
	var r: float = (ch[0][1] + ch[1][1] + ch[2][1]) * 1.1 + 0.03
	tris = GT._near(all, AABB(c - Vector3.ONE * r, Vector3.ONE * r * 2.0))
	var near := tris
	var best := [0.0, 0.0]
	var best_s := INF
	var least := [-INF, 0.0]
	for ia in 41:
		var q0 := lerpf(q0_from, 1.0, ia / 40.0)
		var q1 := 0.0
		var g := _gaps(hand, cur, ch, apply, q0, q1)
		if g.min() > least[0]:
			least = [g.min(), q0]
		if g.min() < -pen:
			continue
		while g.min() >= TOUCH and q1 < 1.0:
			q1 = minf(q1 + 0.02, 1.0)
			g = _gaps(hand, cur, ch, apply, q0, q1)
		if g.min() < -pen:
			q1 -= 0.02
			g = _gaps(hand, cur, ch, apply, q0, q1)
		var sc := maxf(g[2], 0.0) * 4.0 + maxf(g[0], 0.0) + maxf(g[1], 0.0) + absf(q0 - q1) * 0.01 # doğal: eklemler birlikte
		sc += absf(q0 * 1.4 - 1.0) * lean
		if not aim.is_empty():
			tris = aim
			sc = minf(_link_gap(ch[1], false), _link_gap(ch[2], false)) * 4.0 + absf(q0 - q1) * 0.004 + maxf(g[2], 0.0)
			tris = near
		if sc < best_s:
			best_s = sc
			best = [q0, q1]
	if best_s == INF and soft:
		best = [least[1], 0.0]
		best_s = -least[0]
	elif best_s == INF and q0_from > -0.5: # her aday giriyor: daha açık başla
		tris = all
		return _close(hand, cur, ch, apply, -0.5, aim)
	var g := _gaps(hand, cur, ch, apply, best[0], best[1])
	if not aim.is_empty():
		tris = aim
		print("    tetiğe %.1f mm" % (minf(_link_gap(ch[1], false), _link_gap(ch[2], false)) * 1000.0))
	tris = all
	return best_s


func _gaps(hand: Node3D, cur: Dictionary, ch: Array, apply: Callable, q0: float, q1: float) -> Array:
	apply.call(cur, q0, q1)
	Hands.pose(hand, cur)
	return [_link_gap(ch[0], true), _link_gap(ch[1], false), _link_gap(ch[2], false)]


func _write(fit: Dictionary) -> void:
	var lines := ["const FIT := {"]
	var v3 := func(v: Vector3) -> String: return "Vector3(%.4f, %.4f, %.4f)" % [v.x, v.y, v.z]
	var arr := func(a: Array) -> String: return "[" + ", ".join(a.map(func(x): return "%.3f" % x)) + "]"
	for id: String in fit:
		var sides := []
		for s: String in fit[id]:
			var e: Dictionary = fit[id][s]
			var pose := ", \"f\": [%s], \"s\": %.3f, \"t\": %s" % [", ".join((e.f as Array).map(arr)), e.s, arr.call(e.t)] if e.has("f") else ""
			sides.append("\"%s\": {\"o\": %s%s}" % [s, v3.call(e.o), pose])
		lines.append("\t\"%s\": {%s}," % [id, ", ".join(sides)])
	lines.append("}")
	var path := "res://weapon_anims.gd"
	var src := FileAccess.get_file_as_string(path)
	var a := src.find("# FIT:begin\n") + "# FIT:begin\n".length()
	var b := src.find("# FIT:end")
	assert(a > 20 and b > a)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(src.substr(0, a) + "\n".join(lines) + "\n" + src.substr(b))
	f.close()
	print("FIT yazıldı: ", fit.keys())
