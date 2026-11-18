extends RefCounted
## Kalıcı oyuncu profili: Altın Saç, açılımlar, kalıcı yükseltmeler, istatistikler, başarımlar, öğretici.
## Kullanım: const Profile := preload("res://profile.gd") — hepsi statik; user://profile.cfg (+ .bak yedek).
##
## GENEL API
##   load_data() -> Dictionary                 kopya: {gold, stats, upgrades, ach, tutorial}
##   save_data(d: Dictionary)                  d'yi temizleyip kaydeder
##   is_unlocked(id: String) -> bool           "weapon:<id>", "diff:<id>", "mode:endless"
##   unlock_progress(id) -> Array              [şimdiki, hedef]; başta açıklar [1, 1]
##   add_run(summary, me) -> Array             Altın Saç + istatistik + başarım; YENİ açılan id'ler
##   gold() -> int
##   upgrade_level(id) -> int                  id: tower_hp | start_money | reroll | banish
##   upgrade_max(id) -> int
##   upgrade_cost(id) -> int                   sıradaki kademe fiyatı; azami ise -1
##   buy_upgrade(id) -> bool                   yetersiz gold / azami ise false
##   tower_hp_mult() -> float                  1 + 0,04 x kademe
##   start_money_bonus() -> int                10 x kademe   (reroll / banish hakkı: upgrade_level)
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
const PRICES := [60, 120, 200, 300, 450]
const UPGRADE_MAX := {"tower_hp": 5, "start_money": 5, "reroll": 3, "banish": 2}
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


static func _path() -> String:
	return Engine.get_meta("profile_path", "") if Engine.get_meta("profile_path", "") != "" else PATH


static func _defaults() -> Dictionary:
	return {"gold": 0, "stats": {}, "upgrades": {}, "ach": {}, "tutorial": false}


static func _num(v: Variant, lo: int, hi: int) -> int:
	return clampi(int(v), lo, hi) if v is int or v is float else lo


## Bozuk / eksik değerleri düzeltir; her zaman geçerli bir sözlük döner.
static func _clean(d: Dictionary) -> Dictionary:
	var o := _defaults()
	o.gold = _num(d.get("gold"), 0, MAX_GOLD)
	o.tutorial = d.get("tutorial") is bool and d.tutorial
	for sec in ["stats", "upgrades", "ach"]:
		var src: Variant = d.get(sec)
		if not src is Dictionary:
			continue
		for k in src:
			if not k is String:
				continue
			if sec == "upgrades":
				if UPGRADE_MAX.has(k):
					o.upgrades[k] = _num(src[k], 0, UPGRADE_MAX[k])
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
	for sec in ["stats", "upgrades", "ach"]:
		var m := {}
		if cfg.has_section(sec):
			for k in cfg.get_section_keys(sec):
				m[k] = cfg.get_value(sec, k)
		d[sec] = m
	return _clean(d)


static func _data() -> Dictionary:
	if _cache.is_empty() or _cache_path != _path():
		var p := _path()
		var d := _read(p)
		if d.is_empty():
			d = _read(p + ".bak")
		_cache = d if not d.is_empty() else _defaults()
		_cache_path = p
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
	for sec in ["stats", "upgrades", "ach"]:
		for k in d[sec]:
			cfg.set_value(sec, k, d[sec][k])
	# Eski dosya yalnız sağlamsa yedeğe alınır (bozuk dosya iyi yedeğin üstüne yazılmasın).
	if FileAccess.file_exists(p) and not _read(p).is_empty():
		DirAccess.copy_absolute(ProjectSettings.globalize_path(p), ProjectSettings.globalize_path(p + ".bak"))
	cfg.save(p)


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


# ---------- Altın Saç ve kalıcı yükseltmeler ----------

static func gold() -> int:
	return _data().gold


static func upgrade_level(id: String) -> int:
	return _data().upgrades.get(id, 0)


static func upgrade_max(id: String) -> int:
	return UPGRADE_MAX.get(id, 0)


static func upgrade_cost(id: String) -> int:
	var l := upgrade_level(id)
	return -1 if l >= upgrade_max(id) else PRICES[l]


static func buy_upgrade(id: String) -> bool:
	var c := upgrade_cost(id)
	if c < 0 or c > gold():
		return false
	_data().gold -= c
	_data().upgrades[id] = upgrade_level(id) + 1
	_flush()
	return true


static func tower_hp_mult() -> float:
	return 1.0 + 0.04 * upgrade_level("tower_hp")


static func start_money_bonus() -> int:
	return 10 * upgrade_level("start_money")


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
