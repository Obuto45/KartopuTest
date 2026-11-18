## Kendi gözünden silah klipleri: veriden Animation üretir.
## Klip: {"len", "tracks": {yol: [[t, konum, dönüş(Euler)], ...]}, "poses": [[t, "L"|"R", poz]], "events": [[t, ad]],
## "vis": [[t, yol, görünür]], "props": [[t, "yol:özellik", değer]]} (props: sürekli, lineer değer izi; ör. iksirin
## "Rig/Weapon:fill" sıvı seviyesi). Konum/dönüş anahtarları DİNLENME duruşuna EKLENEN farktır; dinlenme duruşu
## modelden (parça pivotları, grip_l) ve aşağıdaki el tablolarından gelir. Klipte geçmeyen düğümler dinlenmeye döner.
## Yollar viewmodel'in kökünden: "Rig" (silah + sağ el), "Rig/Weapon", "Rig/Weapon/<parça>", "Rig/HandR", "HandL".
## Olaylar: ready fired mag_in shell chamber release pin gulp caught done.
extends RefCounted

const Z := Vector3.ZERO
const HS := preload("res://hands.gd").SCALE # el ölçeği: el çerçevesindeki noktalar bununla küçülür
const ONE_HAND := ["sword", "boomerang", "item:potion"]
const BARE := ["build"] # elde model yok: iki el ekranın altında
const UNDER := ["smg", "sniper", "shotgun", "bazooka", "flame"] # sol el namlu altında, avuç yukarı
## El çerçevesi (hands.gd): avuç -X (sağ) / +X (sol), başparmak+işaret +Y, parmaklar -Z.
## Sağ elin tuttuğu nokta (silah uzayında) ve el dönüşü; bilek konumu poza göre hesaplanır (_hold).
const HOLD_R := {
	"bow": [Vector3(0.021, 0.036, -0.168), Z], # çimdik okun gezinde (germe klibi el+oku birlikte çeker)
	"grenade": [Vector3(0, -0.008, -0.15), Z], # "bottle" avucu gövdeyi sarar
	"item:bomb": [Vector3(0, -0.008, -0.15), Z],
	"sword": [Vector3(0, 0, 0.1), Vector3(-PI / 2, 0, 0)], # başparmak namluya (−Z), avuç sola, sap avuçta
	"boomerang": [Vector3(0.2, 0, -0.145), Vector3(0, -0.35, PI / 2)], # avuç aşağı, kanat ucunu üstten kavrar
	"item:potion": [Z, Vector3(0, 0, -0.6)], # "bottle" gövde ortasında; avuç yukarı-sola: şişe parmaklara oturur
}
const BUILD_R := [Vector3(0.06, 0.06, 0.0), Vector3(0, 0, 1.2)] # yapı: boş el, ekranın sağ altında, avuç aşağı-içe
## Ateşli silah kabzaları (silah uzayında, .superpowers/sdd/grip_probe.gd ile ışınla ölçüldü):
## [ön yüz z, el ortası y, yarı genişlik, eğim (rad, + = kabza altı öne)].
const GRIPS := {
	"pistol": [-0.009, -0.082, 0.021, 0.19],
	"smg": [0.008, -0.075, 0.021, -0.13],
	"shotgun": [0.010, -0.092, 0.026, 0.3],
	"sniper": [0.065, -0.115, 0.032, 0.35],
	"bazooka": [-0.01, -0.12, 0.02, -0.14],
	"flame": [0.005, -0.075, 0.02, -0.11],
}
## Aşağıdaki üç nokta el boyu 0.85 iken uydurulmuştu (değer / 0.85 = birim el); el büyüyünce HS ile ölçeklenmezse
## el kabzaya göre yanlış yerde durur (parmaklar açılır, serçe kabzaya girer).
const FIT_HS := 0.85
const GRIP_C := Vector3(-0.0385, 0, -0.068) * HS / FIT_HS # "grip" pozunun sardığı silindirin ekseni (sağ el kökünde)
const BOTTLE_C := Vector3(-0.0625, 0, -0.0595) * HS / FIT_HS # "bottle" pozunun sardığı küre/şişe merkezi
const PINCH_R := Vector3(-0.064, 0.02, -0.094) * HS # sağ el "pinch" ucu
const PINCH := Vector3(0.064, 0.02, -0.094) * HS # sol el "pinch" ucu (işaret-başparmak arası)
const CORK := Vector3(0.044, 0.023, -0.1006) * HS / FIT_HS # sol el "cork" uçlarının ortası (aralarındaki doğru ~ -Z boyunca)

## Silah başına uydurulmuş el (taraf "R"/"L"): "o" bilek kayması (el çerçevesinde, m), "f"/"s"/"t" kavrama pozu
## (hands.gd POSES biçimi). tests/grip_fit.gd yazar: avuç yüzeye yaslanır, her parmak zinciri silahın üçgenlerine
## değene dek kapanır. Elle düzenleme; aracı yeniden çalıştır.
# FIT:begin
const FIT := {
	"smg": {"R": {"o": Vector3(0.0010, 0.0000, 0.0000), "f": [[-0.866, 0.000, 0.000], [-1.320, -0.525, -0.390], [-1.237, -0.525, -0.390], [-0.990, -0.455, -0.338]], "s": 0.000, "t": [-1.361, -0.937, -2.862, -0.575, -0.650]}, "L": {"o": Vector3(0.0058, 0.0000, 0.0000), "f": [[-0.330, -0.665, -0.494], [-0.949, 0.000, 0.000], [-0.866, -0.350, -0.260], [-1.155, 0.000, 0.000]], "s": 0.030, "t": [-0.521, -0.513, -0.719, -0.239, -0.298]}},
	"pistol": {"R": {"o": Vector3(0.0030, 0.0000, 0.0000), "f": [[0.000, -0.805, -0.598], [-1.196, -0.700, -0.520], [-1.196, -0.595, -0.442], [-1.073, -0.385, -0.286]], "s": 0.000, "t": [-1.384, -0.944, -2.900, -0.050, -0.100]}, "L": {"o": Vector3(0.0012, 0.0000, 0.0000), "f": [[-1.196, -0.700, -0.520], [-1.155, -0.770, -0.572], [-0.907, -0.770, -0.572], [-0.495, -0.700, -0.520]], "s": 0.030, "t": [-0.250, -0.600, -1.000, -0.050, -0.100]}},
	"shotgun": {"R": {"o": Vector3(0.0032, 0.0000, 0.0000), "f": [[-1.237, -0.035, -0.026], [-0.619, 0.000, 0.000], [-1.402, -0.175, -0.130], [-1.114, -0.350, -0.260]], "s": 0.000, "t": [-1.384, -0.944, -1.900, -0.050, -0.100]}, "L": {"o": Vector3(-0.0189, 0.0000, 0.0000), "f": [[0.000, 0.000, 0.000], [-0.825, -0.525, -0.390], [-1.320, 0.000, 0.000], [-1.320, -0.070, -0.052]], "s": 0.030, "t": [-0.163, -0.878, -0.778, -0.050, -0.100]}},
	"sniper": {"R": {"o": Vector3(-0.0016, 0.0000, 0.0000), "f": [[-0.041, -0.840, -0.624], [-0.165, -0.140, -0.104], [-0.412, -0.490, -0.364], [-0.371, -0.420, -0.312]], "s": 0.000, "t": [-1.055, -0.276, -1.639, -0.050, -0.100]}, "L": {"o": Vector3(0.0122, 0.0000, 0.0000), "f": [[0.206, -0.805, -0.598], [-0.247, -0.735, -0.546], [-0.742, -0.315, -0.234], [-0.949, -0.210, -0.156]], "s": 0.030, "t": [-0.205, -0.745, -1.047, -0.050, -0.100]}},
	"bazooka": {"R": {"o": Vector3(0.0020, 0.0000, 0.0000), "f": [[-0.577, -1.295, -0.962], [-1.361, -0.490, -0.364], [-1.279, -0.525, -0.390], [-1.031, -0.455, -0.338]], "s": 0.000, "t": [-1.373, -0.941, -2.881, -0.554, -0.628]}, "L": {"o": Vector3(0.0122, 0.0000, 0.0000), "f": [[-0.825, -0.945, -0.702], [-1.031, -0.980, -0.728], [-0.949, -0.910, -0.676], [-0.742, -0.665, -0.494]], "s": 0.000, "t": [-1.052, -0.277, -1.990, -0.680, -0.760]}},
	"flame": {"R": {"o": Vector3(0.0013, 0.0000, 0.0000), "f": [[-1.320, 0.000, 0.000], [0.144, 0.000, 0.000], [-1.320, -0.070, -0.052], [-0.990, -0.490, -0.364]], "s": 0.000, "t": [-1.384, -0.944, -1.900, -0.050, -0.100]}, "L": {"o": Vector3(0.0271, 0.0000, 0.0000), "f": [[-1.196, -0.140, -0.104], [-1.196, -0.070, -0.052], [-1.073, -0.105, -0.078], [-0.412, -1.225, -0.910]], "s": 0.000, "t": [-0.533, -0.586, -1.350, -0.050, -0.100]}},
	"bow": {"L": {"o": Vector3(0.0109, 0.0000, 0.0000), "f": [[-0.083, -0.735, -0.546], [-0.165, -0.840, -0.624], [-0.165, -0.700, -0.520], [-0.330, 0.000, 0.000]], "s": 0.000, "t": [0.019, -0.518, -0.549, -0.050, -0.100]}},
	"sword": {"R": {"o": Vector3(-0.0187, 0.0000, 0.0000), "f": [[-1.031, -1.155, -0.858], [-1.155, -1.190, -0.884], [-1.073, -1.155, -0.858], [-0.701, -0.910, -0.676]], "s": 0.000, "t": [-0.964, -0.313, -2.197, -0.701, -0.782]}},
	"boomerang": {"R": {"o": Vector3(-0.0181, 0.0000, 0.0000), "f": [[-0.289, -0.805, -0.598], [-0.495, -1.260, -0.936], [-0.619, -1.330, -0.988], [-0.577, -0.980, -0.728]], "s": 0.000, "t": [-0.930, -0.326, -2.140, -0.722, -0.804]}},
	"grenade": {"R": {"o": Vector3(-0.0050, 0.0000, 0.0000), "f": [[-0.990, 0.000, 0.000], [-0.907, -0.350, -0.260], [-0.907, -0.245, -0.182], [-0.949, -0.070, -0.052]], "s": 0.000, "t": [-0.270, -0.503, -1.145, -0.050, -0.100]}},
	"item:bomb": {"R": {"o": Vector3(-0.0050, 0.0000, 0.0000), "f": [[-0.990, 0.000, 0.000], [-0.907, -0.350, -0.260], [-0.907, -0.245, -0.182], [-0.949, -0.070, -0.052]], "s": 0.000, "t": [-0.270, -0.503, -1.145, -0.050, -0.100]}},
	"item:potion": {"R": {"o": Vector3(-0.0161, 0.0000, 0.0000), "f": [[-1.130, 0.000, 0.000], [-1.040, -0.050, -0.120], [-1.030, 0.000, -0.060], [-1.020, 0.000, 0.000]], "s": 0.000, "t": [-0.360, -0.282, -1.534, -0.050, -0.100]}},
}
# FIT:end

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
	var r := {"Rig": [Z, Z], "Rig/Weapon": [Z, Z]}
	var c: Vector3 = {"bottle": BOTTLE_C, "pinch": PINCH_R}.get(hold_r(id), GRIP_C)
	r["Rig/HandR"] = BUILD_R if id in BARE else (_hold(HOLD_R[id][0], HOLD_R[id][1], c) if HOLD_R.has(id) else _wrap(GRIPS.get(id, GRIPS.pistol)))
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
	if id == "item:potion":
		r["Rig/Weapon/cork"] = [Vector3(0, 0.085, 0), Z] # potion.gd tıpası
	if id in BARE:
		r["HandL"] = [Vector3(-0.24, 0.06, 0.0), Vector3(0, 0, -1.2)] # sağın aynası
	elif id in ONE_HAND:
		r["HandL"] = [gl, Z]
	elif id == "bazooka": # dikey ön kabza: sağ elin aynası
		r["HandL"] = [gl + Vector3(GRIP_C.x, 0.0, -GRIP_C.z), Z]
	elif id == "flame": # üst sap: avuç aşağı (z -90°), parmaklar sağ-ileri sapı üstten sarar
		var rot := Vector3(0, -1.2, -PI / 2)
		r["HandL"] = _hold(gl, rot, Vector3(-GRIP_C.x, 0, GRIP_C.z))
	elif id in UNDER: # avuç yukarı (z 90°), parmaklar sağ-ileri (y -1): önü alttan sarar
		var rot := Vector3(0.6, -0.85, PI / 2)
		r["HandL"] = [gl + Vector3(0, -0.027, 0) - Basis.from_euler(rot) * Vector3(0.017, 0, -0.047) * HS, rot]
	elif id == "bow": # yay gövdesini yumrukla tutar ("grip", sağ elin aynası)
		r["HandL"] = [gl + Vector3(GRIP_C.x, 0, -GRIP_C.z), Z]
	elif id in ["grenade", "item:bomb"]: # çimdik ucu halkada
		r["HandL"] = [gl - PINCH, Z]
	else: # tabanca: sol avuç kabzanın solunda (sağ parmakların üstünde), parmaklar önden sarar
		r["HandL"] = [r["Rig/HandR"][0] + Vector3(-0.094, 0.012, -0.008) * HS, Vector3(-0.25, -0.2, 0)]
	for s: String in FIT.get(id, {}):
		var hp := "Rig/HandR" if s == "R" else "HandL"
		r[hp] = [r[hp][0] + Basis.from_euler(r[hp][1]) * FIT[id][s].get("o", Z), r[hp][1]]
	if r["Rig"] != [Z, Z]: # sol el Rig'in dışında (Base'de): kaydırılmış silahla birlikte taşınır
		var rb := Basis.from_euler(r["Rig"][1])
		r["HandL"] = [r["Rig"][0] + rb * r["HandL"][0], (rb * Basis.from_euler(r["HandL"][1])).get_euler()]
	_rest[id] = r
	return r


## Kabza ölçüsünden sağ el bileği: "grip" silindiri kabzanın ön yüzüne yaslanır, avuç sağ yüzde.
static func _wrap(g: Array) -> Array:
	var rot := Vector3(g[3], 0, 0)
	var a := Vector3(minf(g[2] - 0.021 * HS / FIT_HS, 0.003), g[1], g[0] + 0.008) # kalın kabzada parmak uçları sol yüzü bulsun
	return _hold(a, rot, GRIP_C)


## Pozun tuttuğu nokta (c, el kökünde) silah uzayında a'ya gelsin: bilek konumu.
static func _hold(a: Vector3, rot: Vector3, c: Vector3) -> Array:
	return [a - Basis.from_euler(rot) * c, rot]


## Dinlenme pozu: uydurulmuşsa FIT sözlüğü, yoksa hold_r/hold_l adı.
static func pose_of(id: String, side: String) -> Variant:
	var f: Dictionary = FIT.get(id, {}).get(side, {})
	return f if f.has("f") else (hold_r(id) if side == "R" else hold_l(id))


## Sağ elin dinlenme pozu.
static func hold_r(id: String) -> String:
	return "bottle" if id in ["grenade", "item:bomb", "item:potion"] else ("pinch" if id == "bow" else ("open" if id in BARE else "grip"))


## Sol elin dinlenme pozu.
static func hold_l(id: String) -> String:
	if id in ONE_HAND or id in BARE:
		return "open"
	return "pinch" if id in ["grenade", "item:bomb"] else ("grip" if id in ["bow", "bazooka", "flame"] else "support")


static func build(id: String, clip: String, parts_only := false) -> Animation:
	var c: Dictionary = clips(id)[clip]
	var rs := rest(id)
	var a := Animation.new()
	a.length = c.len
	var tracks: Dictionary = c.get("tracks", {})
	var no_parts := parts_only and model_id(id) == "" # 3. şahısta modelsiz eşya (iksir) boş düğüm: tıpa vb. yok
	for path in rs:
		var out: String = path
		if parts_only:
			if not path.begins_with("Rig/Weapon/") or no_parts:
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
			if not path.begins_with("Rig/Weapon/") or no_parts:
				continue
			out = path.trim_prefix("Rig/Weapon/")
		var tv := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(tv, out + ":visible")
		a.value_track_set_update_mode(tv, Animation.UPDATE_DISCRETE)
		for e in vis[path]:
			a.track_insert_key(tv, e[0], e[1])
	var props := {} # "yol:özellik" -> değer izi
	for p in c.get("props", []):
		var out: String = p[1]
		if parts_only:
			if not out.begins_with("Rig/Weapon/") or no_parts:
				continue
			out = out.trim_prefix("Rig/Weapon/")
		if not props.has(out):
			props[out] = a.add_track(Animation.TYPE_VALUE)
			a.track_set_path(props[out], out)
			a.value_track_set_update_mode(props[out], Animation.UPDATE_CONTINUOUS)
			a.track_set_interpolation_type(props[out], Animation.INTERPOLATION_LINEAR)
		a.track_insert_key(props[out], p[0], p[2])
	if not parts_only:
		var tm := a.add_track(Animation.TYPE_METHOD)
		a.track_set_path(tm, ".")
		# Aynı zamana ikinci yöntem anahtarı öncekini ezer: olaylar tam zamanında, pozlar hafifçe kaydırılır
		# (klip sonundaysa geriye: "done" ile aynı andaki poz klibin dışına düşmesin).
		var used := {}
		for e in c.get("events", []):
			used[snappedf(e[0], 0.0001)] = true
			a.track_insert_key(tm, e[0], {"method": "_ev", "args": [e[1]]})
		for p in c.get("poses", []):
			var t: float = p[0]
			var step := -0.0001 if t >= a.length - 0.0001 else 0.0001
			while used.has(snappedf(t, 0.0001)):
				t += step
			used[snappedf(t, 0.0001)] = true
			a.track_insert_key(tm, t, {"method": "_pose", "args": [p[1], p[2]]})
	return a


# ---------- Klip verisi ----------

static func _k(t: float, p := Z, r := Z) -> Array:
	return [t, p, r]


static func _make(id: String) -> Dictionary:
	var hold: Variant = pose_of(id, "L")
	var hr: Variant = pose_of(id, "R")
	var c := {}
	var low := Vector3(0, -0.22, 0.05)
	var down := Vector3(-0.7, 0, 0.25)
	c["draw"] = {"len": 0.35, "tracks": {
			"Rig": [_k(0, low, down), _k(0.22, Vector3(0, 0.012, -0.01), Vector3(0.07, 0, -0.04)), _k(0.35)],
			"HandL": [_k(0, low + Vector3(0, -0.1, 0)), _k(0.22, Vector3(0, 0.012, -0.01)), _k(0.35)]},
		"poses": [[0.0, "R", hr], [0.0, "L", hold]], "events": [[0.35, "ready"]]}
	c["idle"] = {"len": 0.1, "poses": [[0.0, "R", hr], [0.0, "L", hold]]}
	match id:
		"pistol":
			c["fire"] = _fire(0.18, 0.35, {"Rig/Weapon/slide": [_k(0), _k(0.03, Vector3(0, 0, 0.045)), _k(0.09)],
				"Rig/Weapon/hammer": [_k(0), _k(0.03, Z, Vector3(0.7, 0, 0)), _k(0.1)]})
			c["dry"] = _dry({"Rig/Weapon/hammer": [_k(0), _k(0.05, Z, Vector3(0.4, 0, 0)), _k(0.1)]})
			c["reload"] = _mag_reload(1.3, "Rig/Weapon/mag", {}, hold)
			var back := Vector3(0, 0, 0.045)
			c["reload_empty"] = _mag_reload(1.6, "Rig/Weapon/mag", {
				"Rig/Weapon/slide": [_k(0, back), _k(1.6 * 0.88, back), _k(1.6 * 0.92)]}, hold) # sonda sürgü bırakılır
		"smg":
			c["fire"] = _fire(0.09, 0.25, {})
			c["dry"] = _dry({})
			var cp := Vector3(0, 0, 0.05)
			c["reload"] = _mag_reload(1.8, "Rig/Weapon/mag", {
				"Rig/Weapon/charging": [_k(0), _k(1.8 * 0.88), _k(1.8 * 0.93, cp), _k(1.8 * 0.98)]}, hold)
		"sniper":
			var bolt := _bolt(0.35)
			c["fire"] = _fire(1.0, 1.4, {"Rig/Weapon/bolt": bolt})
			c["fire"].events.append([0.8, "chamber"])
			c["fire"].tracks["Rig"].append_array([_k(0.35, Vector3(-0.02, 0.0, 0.02), Vector3(0.05, 0, 0.15)), _k(0.85), _k(1.0)])
			c["dry"] = _dry({})
			c["reload"] = _mag_reload(2.4, "Rig/Weapon/mag", {"Rig/Weapon/bolt": _bolt(2.4 * 0.86)}, hold)
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
				"HandL": [_k(0, pocket), _k(0.35)]}, "poses": [[0.2, "L", hold]], "events": [[0.35, "done"]]}
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
				"poses": [[0.25 * L, "L", "grip"], [0.9 * L, "L", hold]], "events": [[0.85 * L, "mag_in"], [L, "done"]]}
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
				"poses": [[0.18 * L, "L", "grip"], [0.9 * L, "L", hold]], "events": [[0.85 * L, "mag_in"], [L, "done"]]}
		"bow":
			var nock := Vector3(0, 0, 0.07) # el kameraya fazla yaklaşmasın
			c["draw_string"] = {"len": 0.6, "tracks": {
					"Rig/Weapon/string_top": [_k(0), _k(0.6, Z, Vector3(-0.31, 0, 0))],
					"Rig/Weapon/string_bot": [_k(0), _k(0.6, Z, Vector3(0.31, 0, 0))],
					"Rig/Weapon/arrow": [_k(0), _k(0.6, nock)],
					"Rig/HandR": [_k(0), _k(0.6, nock)],
					"Rig": [_k(0), _k(0.6, Vector3(-0.03, 0.01, 0), Vector3(0, 0, 0.12))]},
				"poses": [[0.0, "R", hr]]}
			c["release"] = {"len": 0.3, "tracks": {
					"Rig/Weapon/string_top": [_k(0, Z, Vector3(-0.31, 0, 0)), _k(0.04, Z, Vector3(0.06, 0, 0)), _k(0.1)],
					"Rig/Weapon/string_bot": [_k(0, Z, Vector3(0.31, 0, 0)), _k(0.04, Z, Vector3(-0.06, 0, 0)), _k(0.1)],
					"Rig/HandR": [_k(0, nock), _k(0.08, nock + Vector3(0.04, 0.02, 0.04)), _k(0.3)],
					"Rig": [_k(0, Vector3(-0.03, 0.01, 0), Vector3(0, 0, 0.12)), _k(0.06, Vector3(0, 0.01, 0.02), Vector3(0.05, 0, 0)), _k(0.3)]},
				"vis": [[0.02, "Rig/Weapon/arrow", false]],
				"poses": [[0.0, "R", "open"], [0.25, "R", hr]], "events": [[0.02, "release"], [0.3, "done"]]}
			c["reload"] = {"len": 0.35, "tracks": {
					"Rig/Weapon/arrow": [_k(0, Vector3(0.06, -0.15, 0.2)), _k(0.3)],
					"Rig/HandR": [_k(0, Vector3(0.06, -0.15, 0.2)), _k(0.3)]},
				"vis": [[0.0, "Rig/Weapon/arrow", true]],
				"poses": [[0.0, "R", hr]], "events": [[0.35 * 0.85, "mag_in"], [0.35, "done"]]}
		"grenade", "item:bomb":
			var pull := Vector3(0.12, 0.02, 0.0)
			var cock := [Vector3(0.06, 0.1, 0.16), Vector3(0.45, 0, -0.2)]
			c["prime"] = {"len": 0.5, "tracks": {
					"Rig/Weapon/pin": [_k(0), _k(0.04), _k(0.15, pull)],
					"Rig/Weapon/ring": [_k(0), _k(0.04), _k(0.15, pull)],
					"HandL": [_k(0), _k(0.04), _k(0.15, pull), _k(0.5, Vector3(-0.05, -0.25, 0.1))],
					"Rig": [_k(0), _k(0.15), _k(0.5, cock[0], cock[1])]},
				"vis": [[0.0, "Rig/Weapon/pin", true], [0.0, "Rig/Weapon/ring", true], [0.25, "Rig/Weapon/pin", false], [0.25, "Rig/Weapon/ring", false]],
				"poses": [[0.0, "L", hold], [0.25, "L", "open"]], "events": [[0.15, "pin"]]}
			c["throw"] = {"len": 0.4, "tracks": {
					"Rig": [_k(0, cock[0], cock[1]), _k(0.12, Vector3(-0.02, 0.06, -0.35), Vector3(-0.5, 0, 0.1)), _k(0.4, Vector3(0, -0.3, 0), Vector3(-0.6, 0, 0))],
					"HandL": [_k(0, Vector3(-0.05, -0.25, 0.1))],
					"Rig/Weapon/spoon": [_k(0), _k(0.12), _k(0.2, Vector3(0.05, 0.1, 0.05), Vector3(0, 0, -1.5))]},
				"vis": [[0.0, "Rig/Weapon/pin", false], [0.0, "Rig/Weapon/ring", false], [0.13, "Rig/Weapon", false]],
				"poses": [[0.12, "R", "open"]], "events": [[0.12, "release"], [0.4, "done"]]}
			c["reload"] = {"len": 0.8, "tracks": {
					"Rig": [_k(0, Vector3(0, -0.3, 0.05), Vector3(-0.6, 0, 0)), _k(0.6)],
					"HandL": [_k(0, Vector3(-0.05, -0.25, 0.1)), _k(0.6)]},
				"poses": [[0.0, "R", hr], [0.5, "L", hold]], "events": [[0.8 * 0.85, "mag_in"], [0.8, "done"]]}
		"boomerang":
			c["throw"] = {"len": 0.35, "tracks": {
					"Rig": [_k(0), _k(0.1, Vector3(0.1, 0.05, 0.15), Vector3(0, 0.6, 0.2)), _k(0.2, Vector3(-0.1, 0.02, -0.3), Vector3(0, -0.8, -0.2)),
						_k(0.35, Vector3(0, -0.25, 0), Vector3(-0.4, 0, 0))]},
				"vis": [[0.21, "Rig/Weapon", false]],
				"poses": [[0.2, "R", "open"]], "events": [[0.2, "release"], [0.35, "done"]]}
			c["catch"] = {"len": 0.3, "tracks": {
					"Rig": [_k(0, Vector3(0.05, 0.05, -0.15), Vector3(0.2, 0.3, 0)), _k(0.08, Vector3(0.03, 0.0, 0.03)), _k(0.3)]},
				"poses": [[0.0, "R", hr]], "events": [[0.0, "caught"], [0.3, "done"]]}
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
			c["drink"] = _drink()
	if id not in ONE_HAND and id not in BARE:
		for n in c:
			var tr: Dictionary = c[n].get("tracks", {})
			if tr.has("Rig") and not tr.has("HandL"):
				tr["HandL"] = _follow(id, tr["Rig"])
	return c


## İki elli silahta Rig oynarken sol el (Rig dışında) kabzadan kopmasın: Rig izinden sol el izi.
static func _follow(id: String, rig: Array) -> Array:
	var hl: Array = rest(id)["HandL"]
	assert(rest(id)["Rig"] == [Z, Z], "Rig dinlenmesi sıfır sayıldı")
	var hb := Basis.from_euler(hl[1])
	var out := []
	for k in rig:
		var b := Basis.from_euler(k[2])
		out.append(_k(k[0], k[1] + b * hl[0] - hl[0], (b * hb).get_euler() - hl[1]))
	return out


## İksir içme (~1.7 sn): kaldır (hafif önden çökme) → sol el avuç aşağı tıpayı işaret-başparmak uçları arasında
## kavrar, çevirir, çeker (pop ~0.5, şişe sarsılır) → tıpa elde aşağı-dışa → şişe alt-ortada ağza, ~60° eğik, boyun
## kameraya → üç yudum (sıvı adım adım azalır, "gulp" ortadaki yudumda) → boş şişe aşağı, gizlenir → "done".
## Tıpa çekildikten sonra el tıpaya bağlı: önce tıpanın yolu (base uzayında) yazılır, el ondan türetilir, tıpa izi
## o anki şişe dönüşümüne göre şişe uzayına çevrilir (aynı anahtar zamanları: ikisi birlikte yumuşar).
static func _drink() -> Dictionary:
	var L := 1.7
	var rs := rest("item:potion")
	var gl: Vector3 = rs["HandL"][0]
	var cork0: Vector3 = rs["Rig/Weapon/cork"][0]
	var chest := [Vector3(-0.17, -0.02, 0.05), Vector3(0, 0, 0.15)] # göğüs hizası, ağız sol ele dönük
	# Ağızda: gövde ekranın alt-ortasında, boyun ~60° eğik yukarı-kameraya (iksir view'una göre fark).
	var mouth := [Vector3(-0.15, 0.03, 0.1), Vector3(1.05, 0, 0.12)]
	var sip := [mouth[0] + Vector3(0, 0.008, 0.012), mouth[1] + Vector3(0.12, 0, 0)] # yudum: biraz daha eğ, ağza it
	var rig := [_k(0), _k(0.12, Vector3(0.01, -0.02, 0.01), Vector3(-0.06, 0, -0.03)), _k(0.3, chest[0], chest[1]),
		_k(0.48, chest[0], chest[1]), _k(0.5, chest[0] + Vector3(0.004, -0.01, 0), chest[1] + Vector3(0.07, 0, 0.06)),
		_k(0.56, chest[0] + Vector3(0, 0.004, 0), chest[1] + Vector3(-0.02, 0, -0.02)), _k(0.62, chest[0], chest[1]),
		_k(0.74, mouth[0] + Vector3(0, -0.02, -0.02), mouth[1] * 0.85), _k(0.8, mouth[0], mouth[1])]
	for t0 in [0.84, 1.01, 1.18]: # üç yudum
		rig.append_array([_k(t0 + 0.05, sip[0], sip[1]), _k(t0 + 0.12, mouth[0], mouth[1])])
	rig.append_array([_k(1.36, mouth[0] + Vector3(0.05, -0.06, -0.03), Vector3(0.4, 0, 0)),
		_k(1.52, Vector3(0.06, -0.16, 0.04), Vector3(-0.35, 0, -0.2)), _k(L, Vector3(0.12, -0.36, 0.08), Vector3(-0.7, 0, -0.35))])
	var rig_at := func(k: Array) -> Transform3D: return Transform3D(Basis.from_euler(k[2]), k[1])
	# Tıpa ekseni (Y) avucun içine bakar (-X); uçlar arasındaki doğru (~ -Z) tıpanın yanlarını sıkıştırır.
	var held := Transform3D(Basis(Vector3.BACK, PI / 2), CORK).affine_inverse() # tıpa -> sol el kökü
	var neck: Transform3D = rig_at.call(_k(0, chest[0], chest[1])) * Transform3D(Basis(Vector3.UP, -PI / 2), cork0) # avuç aşağı, parmaklar sağa
	var hand_at := func(c: Transform3D) -> Array: # tıpa dönüşümünden el izi farkı (dinlenme dönüşü sıfır)
		var h := c * held
		return [h.origin - gl, h.basis.get_euler()]
	var g: Array = hand_at.call(neck)
	var hl := [_k(0), _k(0.2, Vector3(0.03, 0.12, -0.05)), _k(0.32, g[0] + Vector3(-0.05, -0.04, 0.03), g[1]), _k(0.42, g[0], g[1])]
	# [t, tıpa boyunca kayma, tıpanın kendi dönüşü, dünya kayması]: 0.48 çevir, 0.5 pop, sonra yukarı-sola, aşağı-dışa
	var path := [[0.48, 0.0, Vector3(0, 0.45, 0), Z], [0.5, 0.035, Vector3(0, 0.55, 0), Z],
		[0.56, 0.06, Vector3(0, 0.6, 0.15), Vector3(-0.03, 0.03, 0.0)], [0.62, 0.06, Vector3(0, 0.6, 0.35), Vector3(-0.08, 0.01, 0.02)],
		[0.74, 0.06, Vector3(-0.3, 0.6, 0.5), Vector3(-0.17, -0.13, 0.05)], [0.92, 0.06, Vector3(-0.5, 0.6, 0.5), Vector3(-0.2, -0.33, 0.06)]]
	var ck := [_k(0), _k(0.42, Z, Vector3(0, -PI / 2, 0))]
	for e in path:
		var c := Transform3D(Basis(), e[3]) * neck * Transform3D(Basis.from_euler(e[2]), Vector3(0, e[1], 0))
		var hk: Array = hand_at.call(c)
		hl.append(_k(e[0], hk[0], hk[1]))
		var rk: Array = rig[0]
		for k in rig: # bu andaki (ya da hemen önceki) şişe anahtarı
			if k[0] <= e[0] + 0.001:
				rk = k
		var b: Transform3D = rig_at.call(rk).affine_inverse() * c
		ck.append(_k(e[0], b.origin - cork0, b.basis.get_euler()))
	hl.append(_k(L))
	var fill := [[0.0, "Rig/Weapon:fill", 1.0], [0.84, "Rig/Weapon:fill", 1.0]]
	var lv := 1.0
	for t0 in [0.84, 1.01, 1.18]:
		lv -= 0.95 / 3.0
		fill.append_array([[t0 + 0.1, "Rig/Weapon:fill", lv], [t0 + 0.17, "Rig/Weapon:fill", lv]])
	return {"len": L, "tracks": {"Rig": rig, "HandL": hl, "Rig/Weapon/cork": ck}, "props": fill,
		"vis": [[0.95, "Rig/Weapon/cork", false], [1.6, "Rig/Weapon", false]],
		"poses": [[0.0, "R", "bottle"], [0.0, "L", "open"], [0.3, "L", "cork"], [0.95, "L", "open"]],
		"events": [[1.05, "gulp"], [L, "done"]]}


## Geri tepme: kick büyüklüğünde; ek parça izleriyle.
static func _fire(L: float, kick: float, extra: Dictionary) -> Dictionary:
	var t := minf(0.05, L * 0.4)
	var tr := {"Rig": [_k(0), _k(t, Vector3(0.002 * kick, 0.01 * kick, 0.03 * kick), Vector3(0.08 * kick, 0.012 * kick, 0.025 * kick)),
		_k(minf(L, t * 4.0) * 0.55, Vector3(0, -0.002 * kick, 0.006 * kick), Vector3(-0.012 * kick, 0, -0.006 * kick)), _k(minf(L, t * 4.0))]}
	tr.merge(extra)
	return {"len": L, "tracks": tr, "events": [[0.0, "fired"], [L, "done"]]}


static func _dry(extra: Dictionary) -> Dictionary:
	var tr := {"Rig": [_k(0), _k(0.05, Vector3(0, 0.003, 0.005), Vector3(0.02, 0, 0)), _k(0.2)]}
	tr.merge(extra)
	return {"len": 0.2, "tracks": tr, "events": [[0.2, "done"]]}


## Şarjörlü doldurma: silah 25° içe yatar, şarjör düşer, sol el cepten yenisini getirip takar, tokat.
static func _mag_reload(L: float, mag: String, extra: Dictionary, rest_pose: Variant) -> Dictionary:
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
		"poses": [[0.2 * L, "L", "grip"], [0.9 * L, "L", "open"], [L, "L", rest_pose]],
		"events": [[0.85 * L, "mag_in"], [L, "done"]]}


## Sürgü: kaldır, geri, ileri, indir (t0'dan başlayarak ~0.45 sn).
static func _bolt(t0: float) -> Array:
	var up := Vector3(0, 0, 1.2)
	return [_k(0), _k(t0), _k(t0 + 0.1, Z, up), _k(t0 + 0.2, Vector3(0, 0, 0.08), up), _k(t0 + 0.32, Z, up), _k(t0 + 0.42)]


## Kılıç savuruşu: hazırlık (a) -> vuruş (b), isabet anı ortada.
static func _swing(L: float, pa: Vector3, ra: Vector3, pb: Vector3, rb: Vector3) -> Dictionary:
	return {"len": L, "tracks": {"Rig": [_k(0), _k(0.08, pa, ra), _k(0.22, pb, rb), _k(0.3, pb * 1.1, rb * 1.08), _k(L)]},
		"events": [[0.15, "fired"], [L, "done"]]}
