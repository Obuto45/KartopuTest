## Kendi gözünden silah klipleri: veriden Animation üretir.
## Klip: {"len", "tracks": {yol: [[t, konum, dönüş(Euler)], ...]}, "poses": [[t, "L"|"R", poz]], "events": [[t, ad]],
## "vis": [[t, yol, görünür]]}. Konum/dönüş anahtarları DİNLENME duruşuna EKLENEN farktır; dinlenme duruşu
## modelden (parça pivotları, grip_l) ve aşağıdaki el tablolarından gelir. Klipte geçmeyen düğümler dinlenmeye döner.
## Yollar viewmodel'in kökünden: "Rig" (silah + sağ el), "Rig/Weapon", "Rig/Weapon/<parça>", "Rig/HandR", "HandL".
## Olaylar: ready fired mag_in shell chamber release pin gulp caught done.
extends RefCounted

const Z := Vector3.ZERO
const ONE_HAND := ["sword", "boomerang", "item:potion"]
const BARE := ["build"] # elde model yok: iki el ekranın altında
const UNDER := ["smg", "sniper", "shotgun", "bazooka", "flame"] # sol el namlu altında, avuç yukarı
const HAND_R := { # silah başlangıcına göre sağ el bileği [konum, dönüş]
	"bow": [Vector3(0.03, 0.02, -0.06), Z],
	"grenade": [Vector3(0.06, 0.0, -0.09), Z],
	"item:bomb": [Vector3(0.06, 0.0, -0.09), Z],
	"sword": [Vector3(0.06, 0.0, 0.08), Vector3(0, PI / 2, 0)],
	"boomerang": [Vector3(0.265, 0.0, -0.07), Z],
	"item:potion": [Vector3(0.045, -0.02, 0.05), Z],
	"build": [Vector3(0.05, -0.08, 0.0), Z],
}
const R_FIRE := [Vector3(0.035, -0.05, 0.065), Z] # ateşli silahlarda kabzayı saran el

static var _clips := {}
static var _rest := {}


static func has(id: String, clip: String) -> bool:
	return clips(id).has(clip)


## Silahın (ya da eşyanın) bütün klipleri.
static func clips(id: String) -> Dictionary:
	if not _clips.has(id):
		_clips[id] = _make(id)
	return _clips[id]


## Modelin glb adı (iksirin modeli yok: viewmodel koddan şişe kurar).
static func model_id(id: String) -> String:
	return "grenade" if id == "item:bomb" else ("" if id == "item:potion" or id in BARE else id)


## Yol -> [konum, Euler] dinlenme duruşu.
static func rest(id: String) -> Dictionary:
	if _rest.has(id):
		return _rest[id]
	var r := {"Rig": [Z, Z], "Rig/Weapon": [Z, Z], "Rig/HandR": HAND_R.get(id, R_FIRE)}
	var gl := Vector3(-0.15, -0.35, 0.1) # tek elli silahlarda sol el aşağıda, görüş dışında
	var path := "res://models/%s.glb" % model_id(id)
	if model_id(id) != "" and ResourceLoader.exists(path):
		var m: Node3D = load(path).instantiate()
		for ch in m.get_children():
			if ch is MeshInstance3D and ch.name != "body":
				r["Rig/Weapon/" + ch.name] = [ch.position, ch.rotation]
			elif ch.name == "grip_l" and id not in ONE_HAND:
				gl = ch.position
		m.free()
	if id in BARE:
		r["HandL"] = [Vector3(-0.2, -0.08, 0.0), Z]
	elif id in ONE_HAND:
		r["HandL"] = [gl, Z]
	elif id in UNDER:
		r["HandL"] = [gl + Vector3(0, -0.03, 0.045), Vector3(0, 0, 1.2)]
	else:
		r["HandL"] = [gl + Vector3(-0.035, 0, 0.045), Z]
	_rest[id] = r
	return r


static func build(id: String, clip: String, parts_only := false) -> Animation:
	var c: Dictionary = clips(id)[clip]
	var rs := rest(id)
	var a := Animation.new()
	a.length = c.len
	var tracks: Dictionary = c.get("tracks", {})
	for path in rs:
		var out: String = path
		if parts_only:
			if not path.begins_with("Rig/Weapon/"):
				continue
			out = path.trim_prefix("Rig/Weapon/")
		var keys: Array = tracks.get(path, [[0.0, Z, Z]])
		var tp := a.add_track(Animation.TYPE_POSITION_3D)
		var tr := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(tp, out)
		a.track_set_path(tr, out)
		for t in [tp, tr]:
			a.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
		for k in keys:
			a.position_track_insert_key(tp, k[0], rs[path][0] + k[1])
			a.rotation_track_insert_key(tr, k[0], Quaternion.from_euler(rs[path][1] + k[2]))
	# Görünürlük: her parça ve silahın kendisi başta görünür (eldeki yedek fişek hariç), klip değiştirir.
	var vis := {}
	for path in rs:
		if path.begins_with("Rig/Weapon"):
			vis[path] = [[0.0, not path.ends_with("/shell")]]
	for v in c.get("vis", []):
		var l: Array = vis.get_or_add(v[1], [])
		l.assign(l.filter(func(e): return not is_equal_approx(e[0], v[0])))
		l.append([v[0], v[2]])
	for path in vis:
		var out: String = path
		if parts_only:
			if not path.begins_with("Rig/Weapon/"):
				continue
			out = path.trim_prefix("Rig/Weapon/")
		var tv := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(tv, out + ":visible")
		a.value_track_set_update_mode(tv, Animation.UPDATE_DISCRETE)
		for e in vis[path]:
			a.track_insert_key(tv, e[0], e[1])
	if not parts_only:
		var tm := a.add_track(Animation.TYPE_METHOD)
		a.track_set_path(tm, ".")
		for p in c.get("poses", []):
			a.track_insert_key(tm, p[0], {"method": "_pose", "args": [p[1], p[2]]})
		for e in c.get("events", []):
			a.track_insert_key(tm, e[0], {"method": "_ev", "args": [e[1]]})
	return a


# ---------- Klip verisi ----------

static func _k(t: float, p := Z, r := Z) -> Array:
	return [t, p, r]


static func _make(id: String) -> Dictionary:
	var hold := "open" if id in ONE_HAND or id in BARE else ("pinch" if id in ["grenade", "item:bomb"] else ("grip" if id == "bow" else "support"))
	var c := {}
	var low := Vector3(0, -0.22, 0.05)
	var down := Vector3(-0.7, 0, 0.25)
	c["draw"] = {"len": 0.35, "tracks": {
			"Rig": [_k(0, low, down), _k(0.35)],
			"HandL": [_k(0, low + Vector3(0, -0.1, 0)), _k(0.35)]},
		"poses": [[0.0, "R", "grip"], [0.0, "L", hold]], "events": [[0.35, "ready"]]}
	c["idle"] = {"len": 0.1, "poses": [[0.0, "R", "grip"], [0.0, "L", hold]]}
	match id:
		"pistol":
			c["fire"] = _fire(0.18, 0.35, {"Rig/Weapon/slide": [_k(0), _k(0.03, Vector3(0, 0, 0.045)), _k(0.09)],
				"Rig/Weapon/hammer": [_k(0), _k(0.03, Z, Vector3(0.7, 0, 0)), _k(0.1)]})
			c["dry"] = _dry({"Rig/Weapon/hammer": [_k(0), _k(0.05, Z, Vector3(0.4, 0, 0)), _k(0.1)]})
			c["reload"] = _mag_reload(1.3, "Rig/Weapon/mag", {})
			var back := Vector3(0, 0, 0.045)
			c["reload_empty"] = _mag_reload(1.6, "Rig/Weapon/mag", {
				"Rig/Weapon/slide": [_k(0, back), _k(1.6 * 0.88, back), _k(1.6 * 0.92)]}) # sonda sürgü bırakılır
		"smg":
			c["fire"] = _fire(0.09, 0.25, {})
			c["dry"] = _dry({})
			var cp := Vector3(0, 0, 0.05)
			c["reload"] = _mag_reload(1.8, "Rig/Weapon/mag", {
				"Rig/Weapon/charging": [_k(0), _k(1.8 * 0.88), _k(1.8 * 0.93, cp), _k(1.8 * 0.98)]})
		"sniper":
			var bolt := _bolt(0.35)
			c["fire"] = _fire(1.0, 1.4, {"Rig/Weapon/bolt": bolt})
			c["fire"].events.append([0.8, "chamber"])
			c["fire"].tracks["Rig"].append_array([_k(0.35, Vector3(-0.02, 0.0, 0.02), Vector3(0.05, 0, 0.15)), _k(0.85), _k(1.0)])
			c["dry"] = _dry({})
			c["reload"] = _mag_reload(2.4, "Rig/Weapon/mag", {"Rig/Weapon/bolt": _bolt(2.4 * 0.86)})
		"shotgun":
			var pb := Vector3(0, 0, 0.09)
			c["fire"] = _fire(0.8, 1.1, {
				"Rig/Weapon/pump": [_k(0), _k(0.22), _k(0.36, pb), _k(0.5)],
				"HandL": [_k(0), _k(0.22), _k(0.36, pb), _k(0.5)]})
			c["fire"].events.append([0.5, "chamber"])
			c["dry"] = _dry({})
			var tilt := [Vector3(0, 0.03, 0), Vector3(0.1, 0, -0.5)]
			var port := Vector3(0, -0.04, 0.32) # pompadan fişek yuvasına sol el farkı
			var pocket := Vector3(-0.05, -0.3, 0.26) # aşağı iner, kameraya yaklaşmaz
			c["reload_start"] = {"len": 0.25, "tracks": {"Rig": [_k(0), _k(0.25, tilt[0], tilt[1])],
				"HandL": [_k(0), _k(0.25, pocket)]}, "poses": [[0.1, "L", "pinch"]], "events": [[0.25, "done"]]}
			c["shell"] = {"len": 0.45, "tracks": {
					"Rig": [_k(0, tilt[0], tilt[1])],
					"HandL": [_k(0, pocket), _k(0.25, port + Vector3(0, -0.03, 0)), _k(0.35, port + Vector3(0, -0.01, -0.06)), _k(0.45, pocket)],
					"Rig/Weapon/shell": [_k(0, Vector3(-0.05, -0.2, 0.1)), _k(0.25, Vector3(0, -0.02, 0)), _k(0.35, Vector3(0, 0.0, -0.06))]},
				"vis": [[0.0, "Rig/Weapon/shell", true], [0.36, "Rig/Weapon/shell", false]],
				"poses": [[0.0, "L", "pinch"]], "events": [[0.35, "shell"]]}
			c["reload_end"] = {"len": 0.35, "tracks": {"Rig": [_k(0, tilt[0], tilt[1]), _k(0.35)],
				"HandL": [_k(0, pocket), _k(0.35)]}, "poses": [[0.2, "L", "support"]], "events": [[0.35, "done"]]}
		"bazooka":
			c["fire"] = _fire(0.5, 2.2, {})
			c["fire"]["vis"] = [[0.0, "Rig/Weapon/rocket", false]]
			c["dry"] = _dry({})
			var L := 2.0
			var rk := Vector3(0, 0, 1.05) # tüpün arka ağzı (roket pivotundan fark)
			c["reload"] = {"len": L, "tracks": {
					"Rig": [_k(0), _k(0.2 * L, Vector3(0.02, 0.06, 0), Vector3(0.2, 0, 0.3)), _k(0.85 * L, Vector3(0.02, 0.06, 0), Vector3(0.2, 0, 0.3)), _k(L)],
					"Rig/Weapon/rocket": [_k(0, rk + Vector3(0, -0.15, 0.3)), _k(0.35 * L, rk + Vector3(0, -0.15, 0.3)),
						_k(0.6 * L, rk), _k(0.8 * L, rk * 0.4), _k(0.85 * L)],
					"HandL": [_k(0), _k(0.3 * L, Vector3(-0.05, -0.2, 1.1)), _k(0.6 * L, Vector3(0.0, 0.06, 1.2)), _k(0.72 * L, Vector3(0.0, 0.06, 1.0)),
						_k(0.85 * L, Vector3(-0.05, -0.15, 0.6)), _k(L)]},
				"vis": [[0.0, "Rig/Weapon/rocket", false], [0.35 * L, "Rig/Weapon/rocket", true]],
				"poses": [[0.25 * L, "L", "grip"], [0.9 * L, "L", "support"]], "events": [[0.85 * L, "mag_in"], [L, "done"]]}
		"flame":
			c["fire"] = _fire(0.1, 0.12, {})
			c["dry"] = _dry({})
			var L := 2.2
			var hand := Vector3(0, -0.16, 0.15) # tanktan sol ele fark (tank pivotu - sol el dinlenmesi)
			var out := Vector3(-0.08, -0.25, 0.1)
			c["reload"] = {"len": L, "tracks": {
					"Rig": [_k(0), _k(0.15 * L, Vector3(-0.03, 0.03, 0), Vector3(0.1, 0, 0.44)), _k(0.88 * L, Vector3(-0.03, 0.03, 0), Vector3(0.1, 0, 0.44)), _k(L)],
					"Rig/Weapon/tank": [_k(0), _k(0.2 * L), _k(0.35 * L, out), _k(0.5 * L, out), _k(0.75 * L, Vector3(0, -0.06, 0)), _k(0.85 * L)],
					"HandL": [_k(0), _k(0.2 * L, hand), _k(0.35 * L, hand + out), _k(0.5 * L, hand + out), _k(0.75 * L, hand + Vector3(0, -0.06, 0)),
						_k(0.85 * L, hand), _k(L)]},
				"vis": [[0.0, "Rig/Weapon/tank", true], [0.4 * L, "Rig/Weapon/tank", false], [0.48 * L, "Rig/Weapon/tank", true]],
				"poses": [[0.18 * L, "L", "grip"], [0.9 * L, "L", "support"]], "events": [[0.85 * L, "mag_in"], [L, "done"]]}
		"bow":
			var nock := Vector3(0, 0, 0.15) # el kameraya fazla yaklaşmasın
			c["draw_string"] = {"len": 0.6, "tracks": {
					"Rig/Weapon/string_top": [_k(0), _k(0.6, Z, Vector3(-0.31, 0, 0))],
					"Rig/Weapon/string_bot": [_k(0), _k(0.6, Z, Vector3(0.31, 0, 0))],
					"Rig/Weapon/arrow": [_k(0), _k(0.6, nock)],
					"Rig/HandR": [_k(0), _k(0.6, nock)],
					"Rig": [_k(0), _k(0.6, Vector3(-0.03, 0.01, 0), Vector3(0, 0, 0.12))]},
				"poses": [[0.0, "R", "pinch"]]}
			c["release"] = {"len": 0.3, "tracks": {
					"Rig/Weapon/string_top": [_k(0, Z, Vector3(-0.31, 0, 0)), _k(0.04, Z, Vector3(0.06, 0, 0)), _k(0.1)],
					"Rig/Weapon/string_bot": [_k(0, Z, Vector3(0.31, 0, 0)), _k(0.04, Z, Vector3(-0.06, 0, 0)), _k(0.1)],
					"Rig/HandR": [_k(0, nock), _k(0.08, nock + Vector3(0.04, 0.02, 0.04)), _k(0.3)],
					"Rig": [_k(0, Vector3(-0.03, 0.01, 0), Vector3(0, 0, 0.12)), _k(0.06, Vector3(0, 0.01, 0.02), Vector3(0.05, 0, 0)), _k(0.3)]},
				"vis": [[0.02, "Rig/Weapon/arrow", false]],
				"poses": [[0.0, "R", "open"], [0.25, "R", "pinch"]], "events": [[0.02, "release"], [0.3, "done"]]}
			c["reload"] = {"len": 0.35, "tracks": {
					"Rig/Weapon/arrow": [_k(0, Vector3(0.06, -0.15, 0.2)), _k(0.3)],
					"Rig/HandR": [_k(0, Vector3(0.06, -0.15, 0.2)), _k(0.3)]},
				"vis": [[0.0, "Rig/Weapon/arrow", true]],
				"poses": [[0.0, "R", "pinch"]], "events": [[0.35 * 0.85, "mag_in"], [0.35, "done"]]}
		"grenade", "item:bomb":
			var pull := Vector3(0.12, 0.02, 0.0)
			var cock := [Vector3(0.06, 0.1, 0.16), Vector3(0.45, 0, -0.2)]
			c["prime"] = {"len": 0.5, "tracks": {
					"Rig/Weapon/pin": [_k(0), _k(0.04), _k(0.15, pull)],
					"Rig/Weapon/ring": [_k(0), _k(0.04), _k(0.15, pull)],
					"HandL": [_k(0), _k(0.04), _k(0.15, pull), _k(0.5, Vector3(-0.05, -0.25, 0.1))],
					"Rig": [_k(0), _k(0.15), _k(0.5, cock[0], cock[1])]},
				"vis": [[0.0, "Rig/Weapon/pin", true], [0.0, "Rig/Weapon/ring", true], [0.25, "Rig/Weapon/pin", false], [0.25, "Rig/Weapon/ring", false]],
				"poses": [[0.0, "L", "pinch"], [0.25, "L", "open"]], "events": [[0.15, "pin"]]}
			c["throw"] = {"len": 0.4, "tracks": {
					"Rig": [_k(0, cock[0], cock[1]), _k(0.12, Vector3(-0.02, 0.06, -0.35), Vector3(-0.5, 0, 0.1)), _k(0.4, Vector3(0, -0.3, 0), Vector3(-0.6, 0, 0))],
					"HandL": [_k(0, Vector3(-0.05, -0.25, 0.1))],
					"Rig/Weapon/spoon": [_k(0), _k(0.12), _k(0.2, Vector3(0.05, 0.1, 0.05), Vector3(0, 0, -1.5))]},
				"vis": [[0.0, "Rig/Weapon/pin", false], [0.0, "Rig/Weapon/ring", false], [0.13, "Rig/Weapon", false]],
				"poses": [[0.12, "R", "open"]], "events": [[0.12, "release"], [0.4, "done"]]}
			c["reload"] = {"len": 0.8, "tracks": {
					"Rig": [_k(0, Vector3(0, -0.3, 0.05), Vector3(-0.6, 0, 0)), _k(0.6)],
					"HandL": [_k(0, Vector3(-0.05, -0.25, 0.1)), _k(0.6)]},
				"poses": [[0.0, "R", "grip"], [0.5, "L", "pinch"]], "events": [[0.8 * 0.85, "mag_in"], [0.8, "done"]]}
		"boomerang":
			c["throw"] = {"len": 0.35, "tracks": {
					"Rig": [_k(0), _k(0.1, Vector3(0.1, 0.05, 0.15), Vector3(0, 0.6, 0.2)), _k(0.2, Vector3(-0.1, 0.02, -0.3), Vector3(0, -0.8, -0.2)),
						_k(0.35, Vector3(0, -0.25, 0), Vector3(-0.4, 0, 0))]},
				"vis": [[0.21, "Rig/Weapon", false]],
				"poses": [[0.2, "R", "open"]], "events": [[0.2, "release"], [0.35, "done"]]}
			c["catch"] = {"len": 0.3, "tracks": {
					"Rig": [_k(0, Vector3(0.05, 0.05, -0.15), Vector3(0.2, 0.3, 0)), _k(0.08, Vector3(0.03, 0.0, 0.03)), _k(0.3)]},
				"poses": [[0.0, "R", "grip"]], "events": [[0.0, "caught"], [0.3, "done"]]}
		"sword":
			c["swing1"] = _swing(0.45, Vector3(0.1, 0.05, 0.05), Vector3(0.2, 1.1, 0.3), Vector3(-0.15, -0.02, -0.15), Vector3(-0.1, -1.2, -0.3))
			c["swing2"] = _swing(0.45, Vector3(-0.15, 0.08, 0.02), Vector3(0.3, -1.0, -0.9), Vector3(0.12, -0.08, -0.15), Vector3(-0.3, 1.0, 0.5))
			c["swing3"] = _swing(0.55, Vector3(0.0, 0.18, 0.08), Vector3(1.3, 0, 0), Vector3(0.0, -0.15, -0.2), Vector3(-1.0, 0, 0))
		"build":
			c["idle"].poses = [[0.0, "R", "open"], [0.0, "L", "open"]]
			var push := Vector3(0, 0.04, -0.12)
			c["place"] = {"len": 0.25, "tracks": {
					"Rig": [_k(0), _k(0.1, push, Vector3(0.3, 0, 0)), _k(0.25)],
					"HandL": [_k(0), _k(0.1, push, Vector3(0.3, 0, 0)), _k(0.25)]},
				"poses": [[0.0, "R", "open"], [0.0, "L", "open"]], "events": [[0.25, "done"]]}
		"item:potion":
			var mouth := Vector3(-0.1, 0.08, 0.12)
			var tip := Vector3(0.87, 0, -0.2) # 50° eğik
			c["drink"] = {"len": 1.0, "tracks": {
					"Rig": [_k(0), _k(0.3, mouth, tip * 0.6), _k(0.45, mouth, tip), _k(0.7, mouth, tip),
						_k(0.85, Vector3(0.25, -0.1, -0.05), Vector3(0.2, 0, -0.8)), _k(1.0, Vector3(0, -0.3, 0), Vector3(-0.5, 0, 0))]},
				"vis": [[0.86, "Rig/Weapon", false]],
				"poses": [[0.0, "R", "grip"], [0.86, "R", "open"]], "events": [[0.55, "gulp"], [1.0, "done"]]}
	return c


## Geri tepme: kick büyüklüğünde; ek parça izleriyle.
static func _fire(L: float, kick: float, extra: Dictionary) -> Dictionary:
	var t := minf(0.05, L * 0.4)
	var tr := {"Rig": [_k(0), _k(t, Vector3(0, 0.01 * kick, 0.03 * kick), Vector3(0.08 * kick, 0, 0)), _k(minf(L, t * 3.0))]}
	tr.merge(extra)
	return {"len": L, "tracks": tr, "events": [[0.0, "fired"], [L, "done"]]}


static func _dry(extra: Dictionary) -> Dictionary:
	var tr := {"Rig": [_k(0), _k(0.05, Vector3(0, 0.003, 0.005), Vector3(0.02, 0, 0)), _k(0.2)]}
	tr.merge(extra)
	return {"len": 0.2, "tracks": tr, "events": [[0.2, "done"]]}


## Şarjörlü doldurma: silah 25° içe yatar, şarjör düşer, sol el cepten yenisini getirip takar, tokat.
static func _mag_reload(L: float, mag: String, extra: Dictionary) -> Dictionary:
	var tilt := Vector3(0.15, 0, 0.44)
	var tp := Vector3(-0.03, 0.03, 0)
	var drop := Vector3(0, -0.28, 0.02)
	var hold := Vector3(-0.06, -0.16, 0.06) # elde şarjör, yuvanın altında
	var tr := {
		"Rig": [_k(0), _k(0.15 * L, tp, tilt), _k(0.85 * L, tp, tilt), _k(0.9 * L, tp + Vector3(0, 0.015, 0), tilt), _k(L)],
		mag: [_k(0), _k(0.2 * L), _k(0.32 * L, drop), _k(0.5 * L, hold), _k(0.7 * L, Vector3(0, -0.08, 0)), _k(0.85 * L)],
		"HandL": [_k(0), _k(0.2 * L, Vector3(-0.08, -0.25, 0.15)), _k(0.5 * L, Vector3(-0.1, -0.22, 0.12)), _k(0.7 * L, Vector3(-0.04, -0.1, 0.06)),
			_k(0.85 * L, Vector3(-0.03, -0.04, 0.04)), _k(0.9 * L, Vector3(-0.03, -0.02, 0.03)), _k(L)],
	}
	tr.merge(extra)
	return {"len": L, "tracks": tr,
		"vis": [[0.0, mag, true], [0.33 * L, mag, false], [0.5 * L, mag, true]],
		"poses": [[0.2 * L, "L", "grip"], [0.9 * L, "L", "open"], [L, "L", "support"]],
		"events": [[0.85 * L, "mag_in"], [L, "done"]]}


## Sürgü: kaldır, geri, ileri, indir (t0'dan başlayarak ~0.45 sn).
static func _bolt(t0: float) -> Array:
	var up := Vector3(0, 0, 1.2)
	return [_k(0), _k(t0), _k(t0 + 0.1, Z, up), _k(t0 + 0.2, Vector3(0, 0, 0.08), up), _k(t0 + 0.32, Z, up), _k(t0 + 0.42)]


## Kılıç savuruşu: hazırlık (a) -> vuruş (b), isabet anı ortada.
static func _swing(L: float, pa: Vector3, ra: Vector3, pb: Vector3, rb: Vector3) -> Dictionary:
	return {"len": L, "tracks": {"Rig": [_k(0), _k(0.08, pa, ra), _k(0.22, pb, rb), _k(L)]},
		"events": [[0.15, "fired"], [L, "done"]]}
