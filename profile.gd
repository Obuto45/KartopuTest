extends RefCounted
## Kalıcı oyuncu profili: Altın Saç, açılımlar, kozmetikler, istatistikler, başarımlar, öğretici.
## Kullanım: const Profile := preload("res://profile.gd") — hepsi statik; user://profile.cfg (+ .bak yedek).
##
## GENEL API
##   load_data() -> Dictionary                 kopya: {gold, stats, owned, sel, ach, tutorial}
##   save_data(d: Dictionary)                  d'yi temizleyip kaydeder
##   is_unlocked(id: String) -> bool           "weapon:<id>", "diff:<id>", "mode:endless"
##   unlock_progress(id) -> Array              [şimdiki, hedef]; başta açıklar [1, 1]
##   add_run(summary, me) -> Array             Altın Saç + istatistik + başarım; YENİ açılan id'ler
##   gold() -> int
##   COSMETICS                                 katalog: id -> {slot: tint|title|fx, name, price, color | text}
##   cosm_owned(id) / cosm_buy(id) -> bool     yetersiz gold / zaten sahip / bilinmeyen id ise false
##   cosm_select(slot, id) -> bool             "" = varsayılan; sahip olunmayan seçilemez
##   cosm_sel() -> Dictionary                  {tint, title, fx} -> id ("" yok)
##   cosm_clean(v) -> Dictionary               ağdan gelen seçimi doğrular (katalogda olmayan atılır)
##   cosm_color(id) -> Color / cosm_title(id) -> String
## Eski kalıcı yükseltmeler kaldırıldı: eski kayıttaki kademeler _read'de bir kez iade edilir (LEGACY_MAX + PRICES).
##   achieve(id: String)                       bir kez yazar (Steam'e de; App ID 480 iken yazmaz)
##   achievements() -> Dictionary              id -> unix zamanı
##   stat_add(key, n := 1)                     istatistik (diske yazar; sık çağırma). "chickens" 10'da ACH_CHICKEN_HUNTER
##   stat(key) -> int
##   tutorial_done() -> bool / set_tutorial_done()
##   best_endless() -> int
##   reload()                                  önbelleği atar (diskten yeniden okutur)
## add_run summary ek anahtarları (isteğe bağlı): "tower_hp", "tower_max" (ACH_FLAWLESS için).
## Tek maç öldürme (Yay) ve istatistikler "me" oyuncusunundur.

const PATH := "user://profile.cfg"
const BALANCE := preload("res://balance.gd")


## Testte yolu değiştirir ("" = varsayılan) ve önbelleği atar; geçici yolda Steam'e yazılmaz.
static func use_path(p: String) -> void:
	# Engine meta: static var ilk erişimde sıfırlanıp atamayı eziyordu.
	Engine.set_meta("profile_path", p)
	_cache = {}

const MAX_GOLD := 9999999
const MAX_STAT := 1000000000
const PRICES := [60, 120, 200, 300, 450] # eski yükseltme kademe fiyatları (göç iadesi)
const LEGACY_MAX := {"tower_hp": 5, "start_money": 5, "reroll": 3, "banish": 2} # yalnız göç iadesi için
const SECTIONS := ["stats", "owned", "sel", "ach"]
const SLOTS := ["tint", "title", "fx"]
## Yalnız kozmetik; oyuna avantaj vermez. tint: karakter rengi, title: isim rozeti, fx: kurşun izi / namlu ateşi rengi.
const COSMETICS := {
	"tint:red": {"slot": "tint", "name": "Kızıl Ton", "price": 60, "color": Color(1.0, 0.55, 0.5)},
	"tint:blue": {"slot": "tint", "name": "Buz Mavisi", "price": 60, "color": Color(0.55, 0.75, 1.0)},
	"tint:green": {"slot": "tint", "name": "Orman Yeşili", "price": 90, "color": Color(0.6, 1.0, 0.6)},
	"tint:purple": {"slot": "tint", "name": "Gece Moru", "price": 140, "color": Color(0.8, 0.6, 1.0)},
	"tint:gold": {"slot": "tint", "name": "Saç Sarısı", "price": 300, "color": Color(1.0, 0.85, 0.35)},
	"title:hunter": {"slot": "title", "name": "Avcı", "price": 80, "text": "Avcı"},
	"title:guard": {"slot": "title", "name": "Kule Bekçisi", "price": 150, "text": "Bekçi"},
	"title:legend": {"slot": "title", "name": "Efsane", "price": 220, "text": "Efsane"},
	"title:king": {"slot": "title", "name": "Saç Kralı", "price": 300, "text": "Saç Kralı"},
	"fx:blue": {"slot": "fx", "name": "Mavi Kıvılcım", "price": 80, "color": Color(0.35, 0.7, 1.0)},
	"fx:green": {"slot": "fx", "name": "Zehir Yeşili", "price": 80, "color": Color(0.4, 1.0, 0.45)},
	"fx:pink": {"slot": "fx", "name": "Pembe Parıltı", "price": 140, "color": Color(1.0, 0.45, 0.85)},
	"fx:purple": {"slot": "fx", "name": "Mor Şimşek", "price": 200, "color": Color(0.7, 0.4, 1.0)},
	"fx:gold": {"slot": "fx", "name": "Altın Işık", "price": 260, "color": Color(1.0, 0.85, 0.3)},
}
const START_WEAPONS := ["pistol", "shotgun", "smg", "sword", "bazooka"]
## Açılım id -> [istatistik, hedef]. Listede olmayan başlangıç öğeleri hep açık.
const QUESTS := {
	"weapon:bow": ["best_match_kills", 150],
	"weapon:boomerang": ["best_wave", 5],
	"weapon:grenade": ["builds", 10],
	"weapon:flame": ["hard_best_wave", 6],
	"weapon:sniper": ["wins", 1],
	"diff:hard": ["wins_normal", 1],
	"diff:nightmare": ["wins_hard", 1],
	"mode:endless": ["wins", 1],
}
const ACHIEVEMENTS := ["ACH_FIRST_BLOOD", "ACH_HALFWAY", "ACH_RAPUNZEL_SAFE", "ACH_FLAWLESS", "ACH_HARD_WIN",
	"ACH_NIGHTMARE_WIN", "ACH_EVOLVED", "ACH_ENDLESS_15", "ACH_KILLS_1000", "ACH_UNTOUCHABLE", "ACH_ARCHITECT",
	"ACH_LONE_WOLF", "ACH_FULL_SQUAD", "ACH_CHICKEN_HUNTER"]

static var _cache := {}
static var _cache_path := ""
static var _migrated := false


static func _path() -> String:
	return Engine.get_meta("profile_path", "") if Engine.get_meta("profile_path", "") != "" else PATH


static func _defaults() -> Dictionary:
	return {"gold": 0, "stats": {}, "owned": {}, "sel": {}, "ach": {}, "tutorial": false}


static func _num(v: Variant, lo: int, hi: int) -> int:
	return clampi(int(v), lo, hi) if v is int or v is float else lo


## Bozuk / eksik değerleri düzeltir; her zaman geçerli bir sözlük döner.
static func _clean(d: Dictionary) -> Dictionary:
	var o := _defaults()
	o.gold = _num(d.get("gold"), 0, MAX_GOLD)
	o.tutorial = d.get("tutorial") is bool and d.tutorial
	for sec in SECTIONS:
		var src: Variant = d.get(sec)
		if not src is Dictionary:
			continue
		for k in src:
			if not k is String:
				continue
			if sec == "owned":
				if COSMETICS.has(k):
					o.owned[k] = 1
			elif sec == "sel":
				if SLOTS.has(k) and src[k] is String and (src[k] == "" or COSMETICS.get(src[k], {}).get("slot") == k):
					o.sel[k] = src[k]
			elif sec == "ach":
				o.ach[k] = _num(src[k], 0, MAX_STAT * 10)
			else:
				o.stats[k] = _num(src[k], 0, MAX_STAT)
	return o


## Dosyayı okur; yoksa / bozuksa {} (meta bölümü yoksa bozuk sayılır).
static func _read(path: String) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section("meta"):
		return {}
	var d := {"gold": cfg.get_value("meta", "gold", 0), "tutorial": cfg.get_value("meta", "tutorial", false)}
	for sec in SECTIONS:
		var m := {}
		if cfg.has_section(sec):
			for k in cfg.get_section_keys(sec):
				m[k] = cfg.get_value(sec, k)
		d[sec] = m
	# Göç: kaldırılan yükseltmelere harcanan Altın Saç bir kez iade edilir (kayıt sonraki _flush'ta silinir).
	if cfg.has_section("upgrades"):
		var refund := 0
		for k in cfg.get_section_keys("upgrades"):
			if LEGACY_MAX.has(k):
				for i in _num(cfg.get_value("upgrades", k), 0, LEGACY_MAX[k]):
					refund += PRICES[i]
		d.gold = _num(d.gold, 0, MAX_GOLD) + refund
		_migrated = true
	return _clean(d)


static func _data() -> Dictionary:
	if _cache.is_empty() or _cache_path != _path():
		var p := _path()
		var d := _read(p)
		if d.is_empty():
			d = _read(p + ".bak")
		_cache = d if not d.is_empty() else _defaults()
		_cache_path = p
		if _migrated:
			_migrated = false
			_flush()
	return _cache


static func reload() -> void:
	_cache = {}


static func load_data() -> Dictionary:
	return _data().duplicate(true)


static func save_data(d: Dictionary) -> void:
	_cache = _clean(d)
	_cache_path = _path()
	_flush()


static func _flush() -> void:
	var p := _path()
	var d := _data()
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "gold", d.gold)
	cfg.set_value("meta", "tutorial", d.tutorial)
	for sec in SECTIONS:
		for k in d[sec]:
			cfg.set_value(sec, k, d[sec][k])
	# Eski dosya yalnız sağlamsa yedeğe alınır (bozuk dosya iyi yedeğin üstüne yazılmasın).
	if FileAccess.file_exists(p) and not _read(p).is_empty():
		DirAccess.copy_absolute(ProjectSettings.globalize_path(p), ProjectSettings.globalize_path(p + ".bak"))
	cfg.save(p)
	_migrated = false # yukarıdaki yedek kontrolü _read'i çağırıp bayrağı yeniden kurmuş olabilir


# ---------- İstatistik ----------

static func stat(key: String) -> int:
	return _data().stats.get(key, 0)


static func _inc(key: String, n: int = 1) -> void:
	_data().stats[key] = clampi(stat(key) + n, 0, MAX_STAT)


static func _set_max(key: String, v: int) -> void:
	_data().stats[key] = maxi(stat(key), clampi(v, 0, MAX_STAT))


static func stat_add(key: String, n := 1) -> void:
	_inc(key, int(n))
	if key == "chickens" and stat(key) >= 10:
		_achieve("ACH_CHICKEN_HUNTER")
	_flush()


static func best_endless() -> int:
	return stat("best_endless")


# ---------- Açılımlar ----------

static func is_unlocked(id: String) -> bool:
	if id.begins_with("weapon:") and id.substr(7) in START_WEAPONS:
		return true
	if id == "diff:easy" or id == "diff:normal":
		return true
	return QUESTS.has(id) and stat(QUESTS[id][0]) >= QUESTS[id][1]


## [şimdiki, hedef]: arayüz "Yay: 112/150" gösterir.
static func unlock_progress(id: String) -> Array:
	if QUESTS.has(id):
		var q: Array = QUESTS[id]
		return [mini(stat(q[0]), q[1]), q[1]]
	return [1, 1] if is_unlocked(id) else [0, 1]


# ---------- Altın Saç ve kozmetikler ----------

static func gold() -> int:
	return _data().gold


static func cosm_owned(id: String) -> bool:
	return _data().owned.has(id)


static func cosm_buy(id: String) -> bool:
	if not COSMETICS.has(id) or cosm_owned(id) or COSMETICS[id].price > gold():
		return false
	_data().gold -= COSMETICS[id].price
	_data().owned[id] = 1
	_flush()
	return true


## id "" = o yuvayı varsayılana döndürür.
static func cosm_select(slot: String, id: String) -> bool:
	if not SLOTS.has(slot) or (id != "" and not (cosm_owned(id) and COSMETICS[id].slot == slot)):
		return false
	_data().sel[slot] = id
	_flush()
	return true


static func cosm_sel() -> Dictionary:
	var o := {}
	for s in SLOTS:
		o[s] = _data().sel.get(s, "")
	return o


## Ağdan gelen {tint, title, fx} sözlüğünü doğrular; geçersiz / katalogda olmayan yuva "" olur.
static func cosm_clean(v: Variant) -> Dictionary:
	var o := {"tint": "", "title": "", "fx": ""}
	if v is Dictionary:
		for s in SLOTS:
			var id: Variant = v.get(s)
			if id is String and COSMETICS.get(id, {}).get("slot") == s:
				o[s] = id
	return o


static func cosm_color(id: String) -> Color:
	return COSMETICS.get(id, {}).get("color", Color.WHITE)


static func cosm_title(id: String) -> String:
	return COSMETICS.get(id, {}).get("text", "")


# ---------- Başarımlar ----------

static func achievements() -> Dictionary:
	return _data().ach.duplicate()


static func achieve(id: String) -> void:
	if _achieve(id):
		_flush()


## Yeni yazıldıysa true (kaydetmez).
static func _achieve(id: String) -> bool:
	if id == "" or _data().ach.has(id):
		return false
	_data().ach[id] = int(Time.get_unix_time_from_system())
	_steam_set(id)
	return true


## Steam açıksa başarımı yazar; App ID 480 (Spacewar) ya da test yolu iken yazmaz.
static func _steam_set(id: String) -> void:
	if _path() != PATH or not Engine.has_singleton("Steam"):
		return
	for f in ["res://steam_appid.txt", OS.get_executable_path().get_base_dir().path_join("steam_appid.txt")]:
		if FileAccess.file_exists(f) and FileAccess.get_file_as_string(f).strip_edges() == "480":
			return
	var s: Object = Engine.get_singleton("Steam")
	if s.isSteamRunning():
		s.setAchievement(id)
		s.storeStats()


# ---------- Öğretici ----------

static func tutorial_done() -> bool:
	return _data().tutorial


static func set_tutorial_done() -> void:
	_data().tutorial = true
	_flush()


# ---------- Maç sonu ----------

static func _unlocked_set() -> Array:
	return QUESTS.keys().filter(is_unlocked)


static func add_run(summary: Dictionary, me: int) -> Array:
	var before := _unlocked_set()
	var won: bool = summary.get("won") is bool and summary.won
	var wave := clampi(int(summary.get("wave", 0)), 0, 1000)
	var diff: String = str(summary.get("difficulty", "normal"))
	var endless: bool = summary.get("endless") is bool and summary.endless
	won = won or (endless and wave > BALANCE.WAVE_COUNT) # sonsuzda 10. dalgayı geçen kazanmış sayılır
	var players: Dictionary = summary.get("players", {}) if summary.get("players") is Dictionary else {}
	var mine: Dictionary = players.get(me, players.get(str(me), {}))
	var kills: int = _num(mine.get("kills"), 0, MAX_STAT)
	var builds: int = _num(mine.get("builds"), 0, MAX_STAT)

	var mult: float = BALANCE.DIFFS.get(diff, BALANCE.DIFFS.normal).reward
	var earn := roundi((wave * 5 + (40 if won else 0)) * mult)
	if summary.get("mvp") is int and summary.mvp == me and not mine.is_empty():
		earn += 10
	var d := _data()
	d.gold = clampi(d.gold + earn, 0, MAX_GOLD)

	_inc("runs")
	_inc("kills", kills)
	_inc("builds", builds)
	_set_max("best_match_kills", kills)
	_set_max("best_wave", wave)
	if endless:
		_set_max("best_endless", wave)
	if diff == "hard" or diff == "nightmare":
		_set_max("hard_best_wave", wave)
	if won:
		_inc("wins")
		_inc("wins_" + diff)

	if kills > 0:
		_achieve("ACH_FIRST_BLOOD")
	if wave >= 5:
		_achieve("ACH_HALFWAY")
	if stat("kills") >= 1000:
		_achieve("ACH_KILLS_1000")
	if builds >= 20:
		_achieve("ACH_ARCHITECT")
	if endless and wave >= 15:
		_achieve("ACH_ENDLESS_15")
	if won:
		if diff != "easy":
			_achieve("ACH_RAPUNZEL_SAFE")
		if diff == "hard":
			_achieve("ACH_HARD_WIN")
		if diff == "nightmare":
			_achieve("ACH_NIGHTMARE_WIN")
		if int(summary.get("tower_max", 0)) > 0 and int(summary.get("tower_hp", 0)) >= int(summary.tower_max):
			_achieve("ACH_FLAWLESS")
		if not mine.is_empty() and int(mine.get("deaths", 1)) == 0:
			_achieve("ACH_UNTOUCHABLE")
		if players.size() == 1:
			_achieve("ACH_LONE_WOLF")
		if players.size() >= 4:
			_achieve("ACH_FULL_SQUAD")
	_flush()
	return _unlocked_set().filter(func(i): return not before.has(i))
