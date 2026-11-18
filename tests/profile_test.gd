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

	# Yükseltme
	_clear()
	check("yetersiz gold reddi", not Profile.buy_upgrade("tower_hp") and Profile.upgrade_level("tower_hp") == 0)
	var d := Profile.load_data()
	d.gold = 200
	Profile.save_data(d)
	check("satın alma", Profile.buy_upgrade("tower_hp") and Profile.gold() == 140 and Profile.upgrade_level("tower_hp") == 1)
	check("2. kademe 120", Profile.buy_upgrade("tower_hp") and Profile.gold() == 20)
	check("hp çarpanı", is_equal_approx(Profile.tower_hp_mult(), 1.08))
	check("reroll azami 3", Profile.upgrade_max("reroll") == 3 and Profile.upgrade_cost("banish") == 60)
	check("bilinmeyen yükseltme", not Profile.buy_upgrade("xyz"))

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
	check("yeniden yükleme", Profile.gold() == g and Profile.upgrade_level("tower_hp") == 2 and Profile.tutorial_done()
		and Profile.achievements().has("ACH_EVOLVED") and Profile.stat("chickens") == 10)

	# Bozuk dosya -> .bak
	check("bak var", FileAccess.file_exists(TMP + ".bak"))
	_write(TMP, "bozuk [[[ = =")
	Profile.reload()
	check("bak'tan yükleme", Profile.upgrade_level("tower_hp") == 2 and Profile.gold() > 0)

	# İkisi de bozuk
	_write(TMP, "bozuk [[[ = =")
	_write(TMP + ".bak", "[meta\n gold=")
	Profile.reload()
	check("ikisi bozuk -> varsayılan", Profile.gold() == 0 and Profile.upgrade_level("tower_hp") == 0 and not Profile.tutorial_done())
	check("varsayılan sonrası çalışır", Profile.add_run(_run(true, 1, "normal"), 1) is Array)

	# Bozuk değerler clamp
	_write(TMP, "[meta]\ngold=-50\ntutorial=\"x\"\n[upgrades]\ntower_hp=99\n[stats]\nkills=\"abc\"\n")
	_clear_bak()
	Profile.reload()
	check("clamp", Profile.gold() == 0 and Profile.upgrade_level("tower_hp") == 5 and Profile.stat("kills") == 0)

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
