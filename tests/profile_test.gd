extends Node
## Kalıcı profil testi, ağsız: godot --headless res://tests/profile_test.tscn

const Profile := preload("res://profile.gd")
const TMP := "user://profile_test.cfg"

var good := 0
var total := 0


func check(name: String, ok: bool) -> void:
	total += 1
	if ok:
		good += 1
	else:
		print("  BAŞARISIZ: ", name)


func _clear() -> void:
	for f in [TMP, TMP + ".bak", TMP + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	Profile.reload()


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _run(won: bool, wave: int, diff: String, kills := 0, mvp := 1, extra := {}) -> Dictionary:
	var s := {"won": won, "wave": wave, "difficulty": diff, "endless": false, "mvp": mvp,
		"players": {1: {"dmg": 1, "kills": kills, "crits": 0, "builds": 0, "deaths": 1}}}
	s.merge(extra, true)
	return s


func _ready() -> void:
	Profile.use_path(TMP)
	_clear()

	# Varsayılan
	check("gold 0", Profile.gold() == 0)
	check("pistol açık", Profile.is_unlocked("weapon:pistol") and Profile.is_unlocked("weapon:bazooka"))
	check("yay kapalı", not Profile.is_unlocked("weapon:bow"))
	check("diff:hard kapalı", not Profile.is_unlocked("diff:hard") and Profile.is_unlocked("diff:normal"))
	check("bilinmeyen id", not Profile.is_unlocked("weapon:xyz"))
	check("öğretici yok", not Profile.tutorial_done())

	# Kazanç
	Profile.add_run(_run(true, 10, "normal", 0, 99), 1)
	check("normal zafer w10 = 90", Profile.gold() == 90)
	Profile.add_run(_run(true, 10, "hard", 0, 99), 1)
	check("hard x1.5 = +135", Profile.gold() == 225)
	Profile.add_run(_run(false, 3, "normal", 0, 1), 1)
	check("kayıp + MVP = 15+10", Profile.gold() == 250)

	# Açılımlar
	check("normal zaferi -> hard açık", Profile.is_unlocked("diff:hard"))
	check("hard zaferi -> kabus açık", Profile.is_unlocked("diff:nightmare"))
	check("zafer -> sniper + endless", Profile.is_unlocked("weapon:sniper") and Profile.is_unlocked("mode:endless"))
	check("hard w10 -> alev", Profile.is_unlocked("weapon:flame"))
	check("bumerang w5", Profile.is_unlocked("weapon:boomerang"))
	Profile.add_run(_run(false, 2, "easy", 112, 99), 1)
	check("yay ilerleme 112/150", Profile.unlock_progress("weapon:bow") == [112, 150])
	var nw := Profile.add_run(_run(false, 2, "easy", 40, 99), 1)
	check("yeni açılım yok", nw.is_empty() and not Profile.is_unlocked("weapon:bow"))
	nw = Profile.add_run(_run(false, 2, "easy", 150, 99), 1)
	check("yay açıldı", nw == ["weapon:bow"])

	# Kozmetik
	_clear()
	check("yetersiz gold reddi", not Profile.cosm_buy("tint:red") and not Profile.cosm_owned("tint:red"))
	var d := Profile.load_data()
	d.gold = 200
	Profile.save_data(d)
	check("satın alma", Profile.cosm_buy("tint:red") and Profile.gold() == 140 and Profile.cosm_owned("tint:red"))
	check("tekrar alınmaz", not Profile.cosm_buy("tint:red") and Profile.gold() == 140)
	check("bilinmeyen id", not Profile.cosm_buy("xyz"))
	check("sahip olunmayan seçilemez", not Profile.cosm_select("tint", "tint:blue"))
	check("yuva uyuşmazlığı", not Profile.cosm_select("fx", "tint:red"))
	check("seçim", Profile.cosm_select("tint", "tint:red") and Profile.cosm_sel().tint == "tint:red")
	var ok_prices := true
	for id in Profile.COSMETICS:
		var cc: Dictionary = Profile.COSMETICS[id]
		ok_prices = ok_prices and cc.price >= 60 and cc.price <= 300 and id.begins_with(cc.slot + ":") and Profile.SLOTS.has(cc.slot)
	check("katalog: fiyat 60-300, yuva tutarlı", ok_prices)
	check("ağ doğrulama: katalog dışı / yanlış yuva / tip atılır",
		Profile.cosm_clean({"tint": "fx:blue", "title": "title:king", "fx": 5, "x": "tint:red"}) == {"tint": "", "title": "title:king", "fx": ""}
		and Profile.cosm_clean(7) == {"tint": "", "title": "", "fx": ""} and Profile.cosm_clean({"fx": "fx:nope"}).fx == "")
	check("renk / unvan", Profile.cosm_color("tint:red") != Color.WHITE and Profile.cosm_title("title:king") == "Saç Kralı" and Profile.cosm_title("") == "")
	Profile.cosm_select("tint", "")
	check("seçim kaldırma", Profile.cosm_sel().tint == "")
	Profile.cosm_select("tint", "tint:red")

	# Göç: eski yükseltme kademeleri bir kez iade edilir, kayıt silinir
	_clear()
	_write(TMP, "[meta]
gold=10
[upgrades]
tower_hp=2
reroll=1
bilinmeyen=3
")
	Profile.reload()
	check("göç iadesi 180+60", Profile.gold() == 250)
	Profile.reload()
	check("göç tek sefer (dosya yeniden yazıldı)", Profile.gold() == 250 and not FileAccess.get_file_as_string(TMP).contains("[upgrades]"))
	_clear()
	Profile.reload()
	d = Profile.load_data()
	d.gold = 200
	Profile.save_data(d)
	Profile.cosm_buy("tint:red")
	Profile.cosm_select("tint", "tint:red")

	# Başarım
	Profile.achieve("ACH_EVOLVED")
	var t: int = Profile.achievements()["ACH_EVOLVED"]
	Profile.use_path(TMP)
	Profile.achieve("ACH_EVOLVED")
	check("başarım tekrar yazmaz", Profile.achievements()["ACH_EVOLVED"] == t and Profile.achievements().size() == 1)
	for i in 10:
		Profile.stat_add("chickens")
	check("tavuk başarımı", Profile.achievements().has("ACH_CHICKEN_HUNTER"))
	Profile.add_run(_run(true, 10, "normal", 5, 1, {"tower_hp": 100, "tower_max": 100}), 1)
	check("flawless + lone wolf", Profile.achievements().has("ACH_FLAWLESS") and Profile.achievements().has("ACH_LONE_WOLF"))

	# Kapat-aç
	var g := Profile.gold()
	Profile.set_tutorial_done()
	Profile.reload()
	check("yeniden yükleme", Profile.gold() == g and Profile.cosm_owned("tint:red") and Profile.cosm_sel().tint == "tint:red" and Profile.tutorial_done()
		and Profile.achievements().has("ACH_EVOLVED") and Profile.stat("chickens") == 10)

	# Bozuk dosya -> .bak
	check("bak var", FileAccess.file_exists(TMP + ".bak"))
	_write(TMP, "bozuk [[[ = =")
	Profile.reload()
	check("bak'tan yükleme", Profile.cosm_owned("tint:red") and Profile.gold() > 0)

	# İkisi de bozuk
	_write(TMP, "bozuk [[[ = =")
	_write(TMP + ".bak", "[meta\n gold=")
	Profile.reload()
	check("ikisi bozuk -> varsayılan", Profile.gold() == 0 and not Profile.cosm_owned("tint:red") and not Profile.tutorial_done())
	check("varsayılan sonrası çalışır", Profile.add_run(_run(true, 1, "normal"), 1) is Array)

	# Bozuk değerler clamp
	_write(TMP, "[meta]\ngold=-50\ntutorial=\"x\"\n[upgrades]\ntower_hp=99\n[stats]\nkills=\"abc\"\n")
	_clear_bak()
	Profile.reload()
	check("clamp (+ azami yükseltme iadesi 1130)", Profile.gold() == 1130 and Profile.stat("kills") == 0)

	# Sonsuz modda 10. dalgayı geçmek zafer sayılır (Zor -> Kabus açılır)
	_clear()
	Profile.reload()
	Profile.add_run(_run(false, 13, "hard", 0, 99, {"endless": true}), 1)
	check("sonsuz zafer: Zor -> Kabus açık", Profile.is_unlocked("diff:nightmare"))

	_clear()
	Profile.use_path("")
	print("PROFILE_TEST: %d/%d" % [good, total])
	get_tree().quit(0 if good == total else 1)


func _clear_bak() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP + ".bak"))
