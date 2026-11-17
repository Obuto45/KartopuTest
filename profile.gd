extends RefCounted
## Kalıcı oyuncu profili: Altın Saç, açılımlar, kalıcı yükseltmeler, istatistikler, başarımlar, öğretici.
## Kullanım: const Profile := preload("res://profile.gd") — statik; user://profile.cfg (+ .bak yedek).
## Steam başarımları gerçek App ID gelince achieve() içinden bağlanır (480 Spacewar'ındır).

const PATH := "user://profile.cfg"


## Bütün profil (yoksa / bozuksa varsayılanlar).
static func load_data() -> Dictionary:
	return {}


static func save_data(d: Dictionary) -> void:
	pass


## Silah / zorluk / kalıcı yükseltme açık mı? id örnekleri: "weapon:bow", "diff:hard".
static func is_unlocked(id: String) -> bool:
	return true


## Maç sonu: özeti işler, Altın Saç ekler, açılımları kontrol eder; yeni açılan id'leri döner.
static func add_run(summary: Dictionary, me: int) -> Array:
	return []


static func achieve(id: String) -> void:
	pass


static func stat_add(key: String, n := 1) -> void:
	pass
