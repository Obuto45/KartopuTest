extends RefCounted
## Tower Defense modunun tüm sayıları tek yerde. Kullanım: const Balance := preload("res://balance.gd")
## Ölçü birimi: oyuncunun başlangıç gücü ~25 hasar/sn (arena roketi 20 hasar / 0,8 sn), canı 100, hızı 7 m/sn.
## Dalga akışı ve tür ağırlıkları fikri: quiver-dev/tower-defense-godot4 (MIT) ve
## brannotaylor/SurvivorsClone_Complete (CC0) okunarak; kod kopyalanmadı.

const TOWER_HP := 1500 # dalga 10'da kuleye ulaşan bir boss ~35 hasar/sn vurur: tek başına ~40 sn dayanır
const TOWER_REPAIR := 0.1 # her dalga sonunda kule canının bu oranı onarılır (hata telafisi, kartopu etkisini kırar)
const BREAK_TIME := 25.0 # alışveriş + stat + yerleştirme için yeter; herkes hazırsa 3 sn'ye iner
const WAVE_COUNT := 10
const RESPAWN_TIME := 8.0
const START_MONEY := 40 # ilk molada bir duvar ya da tuzak alınabilsin
const MAX_ALIVE := 40 # aynı anda canlı yaratık üst sınırı (performans); fazlası sırada bekler
const MAX_BUILDS := 40
const SPAWN_SPAN := 32.0 # bir dalganın grupları en çok bu sürede doğar (sn)
const BATCH := 5 # bir doğma noktasından tek seferde çıkan yaratık

# Merkezden 26 m uzakta 8 nokta (harita yarı kenarı 30 m).
const SPAWN_POINTS: Array[Vector3] = [Vector3(26, 0, 0), Vector3(18.4, 0, 18.4), Vector3(0, 0, 26), Vector3(-18.4, 0, 18.4),
	Vector3(-26, 0, 0), Vector3(-18.4, 0, -18.4), Vector3(0, 0, -26), Vector3(18.4, 0, -18.4)]

# Tür tablosu. target: "tower" kuleye yürür, "player" en yakın canlı oyuncuyu kovalar.
# hp / dmg dalga 1 değerleri (wave() çarpanlarıyla büyür); rate = iki vuruş arası sn; range = vuruş menzili (m).
# Ek alanlar: armor = her isabetten düşen sabit hasar (hızlı zayıf silahı cezalandırır, en az 1 hasar geçer),
# explode = hedefe varınca patlama yarıçapı (kendi de ölür, ödül vermez: yolda vurmak kârlı), anim = vuruş animasyonu.
# Hız kuralı: oyuncudan (7) hızlı yaratık yok -> kaçarak oynanabilir; kuleciler yavaş -> 26 m'yi 8–13 sn'de alır.
const ENEMIES := {
	"grunt": {"name": "Hortlak", "hp": 55, "speed": 3.2, "dmg": 8, "rate": 1.1, "range": 1.5, "target": "tower",
		"scale": 1.0, "money": 5, "xp": 4, "model": "zombie_male", "tint": Color(0.75, 1.0, 0.7)},
	"runner": {"name": "Koşucu", "hp": 28, "speed": 6.2, "dmg": 7, "rate": 0.9, "range": 1.3, "target": "player",
		"scale": 0.72, "money": 4, "xp": 3, "model": "goblin_male", "tint": Color(1.0, 1.0, 0.8)},
	"spitter": {"name": "Tükürükçü", "hp": 45, "speed": 3.0, "dmg": 10, "rate": 2.2, "range": 11.0, "target": "player",
		"scale": 0.95, "money": 8, "xp": 7, "model": "witch", "tint": Color(0.7, 1.0, 0.45), "anim": "Shoot_OneHanded"},
	"bomber": {"name": "Patlak", "hp": 40, "speed": 5.0, "dmg": 45, "rate": 1.0, "range": 0.6, "target": "tower",
		"scale": 0.85, "money": 7, "xp": 6, "model": "zombie_female", "tint": Color(1.0, 0.6, 0.4), "explode": 3.2},
	"knight": {"name": "Zırhlı", "hp": 170, "speed": 2.8, "dmg": 16, "rate": 1.3, "range": 1.7, "target": "player",
		"scale": 1.15, "money": 12, "xp": 10, "model": "knight_golden_male", "tint": Color(1.0, 0.95, 0.85), "armor": 4, "anim": "SwordSlash"},
	"brute": {"name": "Azman", "hp": 240, "speed": 2.2, "dmg": 24, "rate": 1.6, "range": 1.8, "target": "tower",
		"scale": 1.5, "money": 14, "xp": 12, "model": "viking_male", "tint": Color(1.0, 0.6, 0.55)},
	"ogre": {"name": "Dev Goblin", "hp": 1100, "speed": 2.4, "dmg": 40, "rate": 1.8, "range": 2.2, "target": "tower",
		"scale": 2.3, "money": 80, "xp": 60, "model": "goblin_female", "tint": Color(0.85, 1.0, 0.75)},
	"boss": {"name": "Kara Şövalye", "hp": 3000, "speed": 2.0, "dmg": 60, "rate": 2.0, "range": 2.6, "target": "tower",
		"scale": 3.0, "money": 300, "xp": 200, "model": "knight_male", "tint": Color(0.8, 0.55, 1.0), "armor": 3, "anim": "SwordSlash"},
}

# Tek oyunculu taban sayılar. Her dalga bir şey öğretir: 1–2 temel, 3 uzaktan vuran, 4 patlayan (duvar yıkar),
# 5 ara boss, 6 zırhlı, 7 oyuncu avı, 8 kule baskını, 9 hepsi, 10 boss + kalabalık.
const WAVES := [
	{"grunt": 4, "runner": 3}, # ilk dalga hafif (kule ~1 dk dayanır) ama 25 XP: dalga sonunda seviye atlanır
	{"grunt": 8, "runner": 4},
	{"grunt": 8, "runner": 6, "spitter": 2},
	{"grunt": 10, "runner": 6, "bomber": 4, "spitter": 2},
	{"grunt": 10, "runner": 8, "brute": 2, "boss": "ogre"},
	{"grunt": 10, "bomber": 6, "spitter": 4, "knight": 2, "brute": 2},
	{"runner": 12, "knight": 4, "spitter": 4, "brute": 3},
	{"grunt": 14, "bomber": 8, "knight": 5, "brute": 4},
	{"runner": 12, "spitter": 6, "knight": 6, "bomber": 6, "brute": 5},
	{"grunt": 12, "runner": 10, "knight": 6, "bomber": 6, "brute": 4, "boss": "boss"},
]

# Mağaza. Para: tek oyuncu dalga 1'de ~38 + 25 bonus kazanır -> her molada en az bir duvar/tuzak,
# 2.–3. molada ilk taret. Fiyatlar etki / dayanıklılıkla orantılı; taret kalıcı hasar olduğu için en pahalı.
# Ek alanlar: dmg, rate (sn), range (m), slow (hız çarpanı), slow_t (sn). Tuzakta hp = kalan şarj.
const SHOP := [
	{"id": "wall", "name": "Duvar", "desc": "Yolu keser. Yaratıklar yıkmak için durur.", "price": 25, "kind": "build",
		"hp": 260, "color": Color(0.62, 0.45, 0.28)},
	{"id": "spike", "name": "Dikenli Duvar", "desc": "Yolu keser, dokunana 0,5 sn'de 8 hasar verir.", "price": 45, "kind": "build",
		"hp": 180, "color": Color(0.45, 0.4, 0.4), "dmg": 8, "rate": 0.5},
	{"id": "trap", "name": "Tuzak", "desc": "Üstüne basanlara 30 hasar verir ve yavaşlatır. 8 şarj.", "price": 30, "kind": "build",
		"hp": 8, "color": Color(0.8, 0.25, 0.2), "dmg": 30, "rate": 1.0, "range": 1.4, "slow": 0.5, "slow_t": 2.5},
	{"id": "turret", "name": "Taret", "desc": "12 m içindeki en yakın yaratığa ateş eder (17 hasar/sn).", "price": 90, "kind": "build",
		"hp": 120, "color": Color(0.35, 0.55, 0.75), "dmg": 12, "rate": 0.7, "range": 12.0},
	{"id": "frost", "name": "Buz Totemi", "desc": "6 m içindeki yaratıkları %45 yavaşlatır.", "price": 70, "kind": "build",
		"hp": 100, "color": Color(0.5, 0.85, 1.0), "range": 6.0, "slow": 0.55, "slow_t": 0.8},
]


## Oyuncu sayısı çarpanı: sayı x(1 + 0,55 x fazla oyuncu), can x(1 + 0,15 x fazla oyuncu).
## 4 oyuncu: 2,65 x 1,45 = 3,84 kat toplam can, 4 kat ateş gücüne karşı -> kişi başı yük solo ile aynı düzeyde,
## ama yaratık sayısı arttığı için kule daha çok yönden sıkışır (kolaylaşmaz). Ödüller sayıyla birlikte büyür.
static func crowd(players: int) -> float:
	return 1.0 + 0.55 * (clampi(players, 1, 4) - 1)


## n: 1..WAVE_COUNT. Can dalga başına +%10 (dalga 10: x1,9), hasar +%6 (x1,54): oyuncunun kart ve statlarla
## büyümesinin biraz altında; zorluk asıl olarak tür karışımı ve sayıdan gelir.
static func wave(n: int, players: int) -> Dictionary:
	n = clampi(n, 1, WAVE_COUNT)
	var p := clampi(players, 1, 4)
	var w: Dictionary = WAVES[n - 1]
	var groups := []
	for type in w:
		if type != "boss":
			groups.append({"type": type, "count": ceili(w[type] * crowd(p))})
	return {"groups": groups, "hp_mult": (1.0 + 0.1 * (n - 1)) * (1.0 + 0.15 * (p - 1)),
		"dmg_mult": (1.0 + 0.06 * (n - 1)) * (1.0 + 0.05 * (p - 1)), "boss": w.get("boss", ""),
		"boss_hp": 1.0 + 0.5 * (p - 1)} # boss tek gelir: sayı çarpanı yerine canı büyür (4 oyuncu: x2,5 x1,45)


## O seviyeden sonrakine gereken havuz XP'si: 25, 40, 55... (doğrusal). Tek oyuncu 10 dalgada ~1500 XP
## toplar -> ~13 seviye (dalga başına 1–2 kart). Havuz ortak olduğu için eşik oyuncu sayısıyla aynı
## oranda büyür (crowd): kaç kişi olursa olsun herkes aynı sayıda seviye atlar.
static func xp_for(level: int, players := 1) -> int:
	return roundi((25 + 15 * (maxi(level, 1) - 1)) * crowd(players))


## Dalga bitirme parası: 25, 30, ... (öldürme parasının ~yarısı; kötü geçen dalgadan sonra da alışveriş olur).
static func wave_bonus(n: int, players := 1) -> int:
	return roundi((20 + 5 * n) * crowd(players))


static func shop(id: String) -> Dictionary:
	for s in SHOP:
		if s.id == id:
			return s
	return {}
