extends RefCounted
## Tower Defense: silah, stat, eşya ve seviye kartı verisi + saf mantık (player.gd yorumlar).
## Kart çekme kalıbı esin: brannotaylor/SurvivorsClone_Complete (CC0), Player/player.gd::get_random_item.
##
## Envanter öğesi: {"kind": "weapon"|"equip"|"build"|"item", "id", "count", "lvl"}; 1–3 silah/ekipman, 4–5 yapı/eşya.
## Yaratıktan düşen / verilen eşyalar: player.add_item({"kind": "item", "id": <ITEMS anahtarı>}):
##   "potion" can iksiri (sol tık: 50 can)      "bomb" bomba (sol tık: fırlatılır, 6 m içinde 120 hasar)
## Ekipman (kart ile gelir): "shield" kalkan, "wall" duvar (arena ile aynı davranış ve bekleme süreleri).
## Yükseltme seviyeleri player.ups içinde: "<silah id>:<yükseltme id>" ve "char:<id>" -> seviye.

const ITEMS := {
	"potion": {"name": "Can İksiri", "desc": "50 can yeniler.", "color": Color(0.9, 0.2, 0.3), "heal": 50},
	"bomb": {"name": "Bomba", "desc": "Fırlatılır: 6 m içinde 120 hasar.", "color": Color(0.2, 0.2, 0.22),
		"w": {"kind": "rocket", "look": "ball", "dmg": 120, "speed": 17.0, "grav": 14.0, "blast": 6.0, "knock": 10.0, "kick": 0.6}},
}
const EQUIPS := {
	"shield": {"name": "Kalkan", "desc": "Sol tık: bir darbeyi emen kalkan.", "rarity": "rare"},
	"wall": {"name": "Duvar", "desc": "Sol tık: önüne geçici duvar çıkarır.", "rarity": "rare"},
}
const RARITY := {
	"common": {"name": "Sıradan", "color": Color(0.75, 0.78, 0.82), "weight": 60},
	"rare": {"name": "Nadir", "color": Color(0.3, 0.6, 1.0), "weight": 26},
	"epic": {"name": "Destansı", "color": Color(0.7, 0.35, 0.95), "weight": 10},
	"legendary": {"name": "Efsanevi", "color": Color(1.0, 0.75, 0.2), "weight": 4},
}
## jump/speed/shot_speed/shot_power/attack çarpan; armor hasar azaltma oranı; crit şans (kritik x2);
## bounce ek sekme sayısı; hp can üst sınırı (tabanı karakterin canı).
const STATS := [
	{"id": "jump", "name": "Zıplama", "base": 1.0, "step": 0.06, "max": 1.6},
	{"id": "speed", "name": "Hız", "base": 1.0, "step": 0.05, "max": 1.5},
	{"id": "shot_speed", "name": "Mermi Hızı", "base": 1.0, "step": 0.1, "max": 2.0},
	{"id": "shot_power", "name": "Mermi Gücü", "base": 1.0, "step": 0.1, "max": 3.0},
	{"id": "attack", "name": "Saldırı Hızı", "base": 1.0, "step": 0.08, "max": 2.2},
	{"id": "armor", "name": "Zırh", "base": 0.0, "step": 0.05, "max": 0.6},
	{"id": "crit", "name": "Kritik", "base": 0.05, "step": 0.03, "max": 0.5},
	{"id": "bounce", "name": "Mermi Sekmesi", "base": 0.0, "step": 1.0, "max": 3.0},
	{"id": "hp", "name": "Can", "base": 100.0, "step": 15.0, "max": 400.0},
]
const STAT_TIERS := [["common", 1], ["rare", 2], ["epic", 3]] # stat kartı: nadirlik -> kaç adım
const EVO_WEIGHT := 40.0 # evrim kartı ağırlığı (Efsanevi taban 4: hazırsa neredeyse her çekimde çıkar)
const OWN_BOOST := 2.5 # sahip olunan silahın yükseltmeleri bu kat sık çıkar (MegaBonk)
const BURN_T := 3.0 # silah yanığı süresi (sn)
const CHAIN_R := 9.0 # sekme: bu mesafedeki sıradaki yaratığa
const CHAIN_K := 0.75 # her sekmede hasar çarpanı
const ARENA_DMG := 20.0 # karakter pasifleri (rocket_dmg, power) bu tabana göre çarpana çevrilir

## Silah alanları (yoksa DEF): kind shot (anında isabet) | rocket (mermi; grav ile kavisli, blast ile patlar) |
## homing (güdümlü, döner) | cone (kısa yay) | melee. rate: atış arası sn; speed: mermi hızı; n: mermi adedi;
## spread: yelpaze/saçılma (rad); range; pierce: delip geçtiği yaratık; bounce; fire: yanık hasarı/sn;
## knock; cone: yay eşiği (dot, küçük = geniş); kick: geri tepme; view: kendi gözünden [konum, dönüş] (viewmodel). Model: models/<id>.glb (bazuka ve kılıç hariç
## tools/weapon_models.gd üretir; namlu -Z, kabza başlangıç noktasında).
const DEF := {"dmg": 0, "rate": 1.0, "n": 1, "spread": 0.0, "range": 60.0, "pierce": 0, "blast": 0.0, "grav": 0.0, "bounce": 0, "fire": 0.0,
	"knock": 0.0, "cone": 0.5, "speed": 0.0, "kick": 0.5, "color": Color(1.0, 0.9, 0.5),
	"mag": 0, "reload": 0.0} # mag 0 = şarjörsüz; reload: doldurma sn (saldırı hızına bölünür)
const LIST := [
	{"id": "bazooka", "name": "Bazuka", "desc": "Patlayan roket: 2,5 m alan hasarı.", "rarity": "rare",
		"dmg": 28, "rate": 0.8, "speed": 30.0, "kind": "rocket", "blast": 2.5, "knock": 6.0, "kick": 1.0, "model": "bazooka", "mag": 1, "reload": 2.0, "view": [Vector3(0.22, -0.12, -0.4), Vector3.ZERO]},
	{"id": "pistol", "name": "Tabanca", "desc": "Hızlı, isabetli tek atış.", "rarity": "common",
		"dmg": 9, "rate": 0.25, "kind": "shot", "range": 60.0, "kick": 0.35, "mag": 12, "reload": 1.3, "reload_empty": 1.6, "view": [Vector3(0.17, -0.08, -0.42), Vector3.ZERO]},
	{"id": "shotgun", "name": "Pompalı", "desc": "7 saçma birden: yakında ezer, uzakta dağılır.", "rarity": "common",
		"dmg": 5, "rate": 0.85, "kind": "shot", "n": 7, "spread": 0.085, "range": 18.0, "knock": 3.0, "kick": 1.1, "mag": 6, "reload": 0.45, "per_shell": true, "view": [Vector3(0.21, -0.035, -0.38), Vector3.ZERO]},
	{"id": "smg", "name": "Makineli", "desc": "Çok seri, düşük hasar, hafif saçılır.", "rarity": "common",
		"dmg": 4, "rate": 0.09, "kind": "shot", "spread": 0.035, "range": 40.0, "kick": 0.25, "mag": 30, "reload": 1.8, "view": [Vector3(0.19, -0.05, -0.36), Vector3.ZERO]},
	{"id": "sniper", "name": "Keskin Nişancı", "desc": "Yavaş ama dev hasar; 3 yaratığı delip geçer.", "rarity": "legendary",
		"dmg": 60, "rate": 1.5, "kind": "shot", "range": 120.0, "pierce": 3, "knock": 5.0, "kick": 1.4, "color": Color(0.6, 0.9, 1.0), "mag": 5, "reload": 2.4, "view": [Vector3(0.21, -0.015, -0.36), Vector3.ZERO]},
	{"id": "bow", "name": "Yay", "desc": "Kavisli uçan ok: bir yaratığı deler, sessiz ve güçlü.", "rarity": "rare",
		"dmg": 30, "rate": 0.7, "speed": 42.0, "kind": "rocket", "look": "arrow", "grav": 9.0, "pierce": 1, "kick": 0.3, "mag": 1, "reload": 0.35, "charge": 0.6, "view": [Vector3(-0.02, -0.1, -0.4), Vector3.ZERO]},
	{"id": "boomerang", "name": "Bumerang", "desc": "Yaratığı kovalar, 2 kez seker, sonra sana döner.", "rarity": "rare",
		"dmg": 16, "rate": 1.0, "speed": 20.0, "kind": "homing", "bounce": 2, "knock": 4.0, "range": 30.0, "kick": 0.3, "view": [Vector3(0.1, -0.2, -0.27), Vector3(0.35, 0, 0)]},
	{"id": "flame", "name": "Alev Püskürtücü", "desc": "Kısa menzilli alev yayı: önündeki herkesi yakar.", "rarity": "epic",
		"dmg": 3, "rate": 0.1, "kind": "cone", "range": 6.5, "cone": 0.8, "fire": 4.0, "kick": 0.12, "color": Color(1.0, 0.5, 0.1), "mag": 100, "reload": 2.2, "view": [Vector3(0.2, -0.08, -0.34), Vector3.ZERO]},
	{"id": "sword", "name": "Kılıç", "desc": "Yakın dövüş: önündeki yaydaki herkese vurur, savurur.", "rarity": "common",
		"dmg": 24, "rate": 0.45, "kind": "melee", "range": 2.7, "cone": 0.4, "knock": 7.0, "kick": 0.0, "model": "sword", "view": [Vector3(0.2, -0.24, -0.35), Vector3(0.9, 0.2, 0)]},
	{"id": "grenade", "name": "El Bombası", "desc": "Havadan atılır: 4 m'lik büyük patlama.", "rarity": "epic",
		"dmg": 42, "rate": 1.3, "speed": 17.0, "kind": "rocket", "look": "ball", "grav": 14.0, "blast": 4.0, "knock": 9.0, "kick": 0.4, "mag": 1, "reload": 0.8, "fuse": 3.0, "view": [Vector3(0.16, -0.17, -0.28), Vector3.ZERO]},
]
## Silaha özel yükseltmeler: add toplanır, mul çarpılır (seviye başına). Kart: "up:<silah>:<id>".
const UPS := {
	"bazooka": [{"id": "blast", "name": "Geniş Patlama", "desc": "Patlama yarıçapı +0,6 m", "max": 4, "rarity": "common", "add": {"blast": 0.6}},
		{"id": "multi", "name": "Çift Namlu", "desc": "+1 roket", "max": 2, "rarity": "epic", "add": {"n": 1, "spread": 0.05}},
		{"id": "reload", "name": "Hızlı Dolum", "desc": "%15 hızlı doldurma", "max": 4, "rarity": "common", "mul": {"reload": 0.85}}],
	"pistol": [{"id": "fmj", "name": "Zırh Delici", "desc": "+1 yaratık deler", "max": 3, "rarity": "rare", "add": {"pierce": 1}},
		{"id": "hair", "name": "Hassas Tetik", "desc": "%15 hızlı ateş", "max": 4, "rarity": "common", "mul": {"rate": 0.85}},
		{"id": "rico", "name": "Seken Kurşun", "desc": "+1 sekme", "max": 3, "rarity": "rare", "add": {"bounce": 1}},
		{"id": "cal", "name": "Büyük Kalibre", "desc": "+3 hasar", "max": 5, "rarity": "common", "add": {"dmg": 3}}],
	"shotgun": [{"id": "pellets", "name": "Ekstra Saçma", "desc": "+2 saçma", "max": 3, "rarity": "rare", "add": {"n": 2}},
		{"id": "choke", "name": "Şok Namlu", "desc": "Saçılma %25 az, menzil +4 m", "max": 3, "rarity": "common", "mul": {"spread": 0.75}, "add": {"range": 4.0}},
		{"id": "slug", "name": "Ağır Saçma", "desc": "Saçma başına +2 hasar", "max": 4, "rarity": "common", "add": {"dmg": 2}}],
	"smg": [{"id": "mag", "name": "Seri Mekanizma", "desc": "%12 hızlı ateş", "max": 4, "rarity": "common", "mul": {"rate": 0.88}},
		{"id": "stab", "name": "Dengeleyici", "desc": "Saçılma %40 az", "max": 2, "rarity": "common", "mul": {"spread": 0.6}},
		{"id": "hollow", "name": "Oyuk Uç", "desc": "+1 hasar", "max": 5, "rarity": "rare", "add": {"dmg": 1}},
		{"id": "burn", "name": "Yakıcı Mermi", "desc": "Yakar: +2 hasar/sn", "max": 3, "rarity": "epic", "add": {"fire": 2.0}}],
	"sniper": [{"id": "ap", "name": "Tungsten Çekirdek", "desc": "+2 yaratık deler", "max": 3, "rarity": "rare", "add": {"pierce": 2}},
		{"id": "cal", "name": "Anti-Materyal", "desc": "+15 hasar", "max": 4, "rarity": "rare", "add": {"dmg": 15}},
		{"id": "bolt", "name": "Yağlı Sürgü", "desc": "%18 hızlı ateş", "max": 3, "rarity": "common", "mul": {"rate": 0.82}}],
	"bow": [{"id": "multi", "name": "Çoklu Ok", "desc": "+1 ok", "max": 3, "rarity": "epic", "add": {"n": 1, "spread": 0.03}},
		{"id": "pierce", "name": "Sivri Uç", "desc": "+1 yaratık deler", "max": 3, "rarity": "common", "add": {"pierce": 1}},
		{"id": "poison", "name": "Zehirli Ok", "desc": "Zehirler: +3 hasar/sn", "max": 3, "rarity": "rare", "add": {"fire": 3.0}}],
	"boomerang": [{"id": "bounce", "name": "Usta Atış", "desc": "+1 sekme", "max": 4, "rarity": "common", "add": {"bounce": 1}},
		{"id": "edge", "name": "Keskin Kenar", "desc": "+5 hasar", "max": 4, "rarity": "common", "add": {"dmg": 5}},
		{"id": "twin", "name": "İkiz Bumerang", "desc": "+1 bumerang", "max": 2, "rarity": "epic", "add": {"n": 1}}],
	"flame": [{"id": "fuel", "name": "Basınçlı Tank", "desc": "Menzil +1,5 m", "max": 3, "rarity": "common", "add": {"range": 1.5}},
		{"id": "heat", "name": "Mavi Alev", "desc": "Yanık +2 hasar/sn", "max": 4, "rarity": "rare", "add": {"fire": 2.0}},
		{"id": "wide", "name": "Geniş Başlık", "desc": "Alev yayı genişler", "max": 3, "rarity": "common", "add": {"cone": -0.12}}],
	"sword": [{"id": "reach", "name": "Uzun Namlu", "desc": "Menzil +0,5 m", "max": 3, "rarity": "common", "add": {"range": 0.5}},
		{"id": "edge", "name": "Bilenmiş Çelik", "desc": "+6 hasar", "max": 5, "rarity": "common", "add": {"dmg": 6}},
		{"id": "spin", "name": "Dönen Savuruş", "desc": "Yay genişler (2. seviyede tam çevre)", "max": 2, "rarity": "rare", "add": {"cone": -0.7}},
		{"id": "swift", "name": "Hafif Kabza", "desc": "%15 hızlı savurma", "max": 3, "rarity": "common", "mul": {"rate": 0.85}}],
	"grenade": [{"id": "blast", "name": "Yüksek Patlayıcı", "desc": "Patlama yarıçapı +0,7 m", "max": 4, "rarity": "common", "add": {"blast": 0.7}},
		{"id": "cluster", "name": "Salkım", "desc": "+1 bomba", "max": 2, "rarity": "epic", "add": {"n": 1, "spread": 0.12}},
		{"id": "napalm", "name": "Napalm", "desc": "Yakar: +4 hasar/sn", "max": 3, "rarity": "rare", "add": {"fire": 4.0}}],
}
## Silah evrimleri: silah id -> {"name", "desc", "needs": {yükseltme id: en az seviye}, "stat": [stat id, eşik],
## "add"/"mul" (UPS gibi), "color", "fx": etki alanları}. Koşul tutunca havuza "evo" türünde Efsanevi kart girer
## (pool / apply_card imzaları değişmez); seçilince ups["evo:<silah>"] = 1 ve envanter öğesine "evo": true yazılır.
## fx: mini [adet, hasar oranı, yarıçap] patlama sonrası halka; crit_chain kritik vuruşa ek sekme;
## ignite yanık yayılma yarıçapı (m); death_blast [yarıçap, hasar oranı] yanarken ölen yaratık patlar.
## Seviye eşikleri bilerek max'ın altında (2): dalga 6-9'da erişilebilir kalsın (XP eğrisi: ~9-10 seviye).
const EVOS := {
	"bazooka": {"name": "Kıyamet Bazukası", "desc": "Her patlama 3 mini patlama bırakır (%40 hasar, 1,5 m).",
		"needs": {"blast": 2, "reload": 2}, "stat": ["shot_power", 1.3], "fx": {"mini": [3, 0.4, 1.5]}},
	"pistol": {"name": "Altıpatlar Lordu", "desc": "Kritik vuruş zincire 2 sekme ekler.",
		"needs": {"rico": 2, "hair": 2}, "stat": ["crit", 0.17], "color": Color(1.0, 0.35, 0.3), "fx": {"crit_chain": 2}},
	"shotgun": {"name": "Kıyım Pompalısı", "desc": "+4 saçma, saçmalar bir yaratık daha deler.",
		"needs": {"pellets": 2, "slug": 2}, "stat": ["attack", 1.24], "color": Color(1.0, 0.6, 0.2), "add": {"n": 4, "pierce": 1}},
	"smg": {"name": "Zincir Makinelisi", "desc": "Mermiler seker; yanığı da taşır.",
		"needs": {"mag": 2, "burn": 2}, "stat": ["attack", 1.24], "color": Color(1.0, 0.5, 0.15), "add": {"bounce": 1}},
	"sniper": {"name": "Ölüm Işını", "desc": "+4 delme ve 2 zincir sekme.",
		"needs": {"ap": 2, "cal": 2}, "stat": ["shot_power", 1.4], "color": Color(0.9, 0.3, 1.0), "add": {"pierce": 4, "bounce": 2}},
	"bow": {"name": "Avcı Yayı", "desc": "Zehirli / yanan yaratık ölünce 4 m patlar.",
		"needs": {"poison": 2, "pierce": 2}, "stat": ["shot_speed", 1.3], "fx": {"death_blast": [4.0, 0.8]}},
	"boomerang": {"name": "Kasırga Bumerangı", "desc": "+1 bumerang ve +2 sekme.",
		"needs": {"bounce": 2, "twin": 1}, "stat": ["attack", 1.16], "add": {"n": 1, "bounce": 2}},
	"flame": {"name": "Ejderha Nefesi", "desc": "Yanık 3 m'de yayılır.",
		"needs": {"heat": 2, "fuel": 2}, "stat": ["shot_power", 1.2], "fx": {"ignite": 3.0}},
	"sword": {"name": "Titan Kılıcı", "desc": "Menzil +1,8 m, +14 hasar, daha sert savurur.",
		"needs": {"edge": 2, "reach": 2}, "stat": ["speed", 1.15], "add": {"range": 1.8, "dmg": 14, "knock": 4.0}},
	"grenade": {"name": "Napalm Fırtınası", "desc": "Patlama +1,5 m ve +6 yanık hasarı/sn.",
		"needs": {"napalm": 2, "blast": 2}, "stat": ["shot_power", 1.3], "add": {"blast": 1.5, "fire": 6.0}},
}

## Karaktere özel yükseltmeler (Q yeteneği ve pasifler). need: yetenekte bu anahtar varsa sunulur. Kart: "char:<id>".
const CHAR_UPS := [
	{"id": "cd", "name": "Çabuk Toparlanma", "desc": "%s bekleme süresi −%%15", "max": 4, "rarity": "rare"},
	{"id": "power", "name": "Ustalık", "desc": "%s etkisi +%%25 (hasar, iyileşme)", "max": 4, "rarity": "rare"},
	{"id": "radius", "name": "Geniş Etki", "desc": "%s alanı +%%20", "max": 3, "rarity": "common", "need": "area"},
	{"id": "bounces", "name": "Seken Atış", "desc": "%s +1 kez seker", "max": 3, "rarity": "epic", "need": "homing"},
	{"id": "dur", "name": "Uzun Etki", "desc": "%s güç süresi +%%30", "max": 3, "rarity": "common", "need": "self"},
	{"id": "dodge", "name": "Çeviklik", "desc": "%s: +%%4 sıyrılma şansı", "max": 5, "rarity": "common", "passive": true},
	{"id": "regen", "name": "Dayanıklılık", "desc": "%s: +1 can/sn yenilenme", "max": 4, "rarity": "rare", "passive": true},
]


static func get_weapon(i: int) -> Dictionary:
	return LIST[clampi(i, 0, LIST.size() - 1)]


## id ile silah (ya da fırlatılan eşyanın silah verisi); yoksa {}.
static func find(id: String) -> Dictionary:
	for w in LIST:
		if w.id == id:
			return w
	return ITEMS.get(id, {}).get("w", {})


## Envanter öğesinin HUD'da görünecek adı.
static func item_name(it: Dictionary) -> String:
	match it.get("kind", ""):
		"weapon": return EVOS[it.id].name if it.get("evo", false) and EVOS.has(it.id) else find(it.id).get("name", it.id)
		"equip": return EQUIPS.get(it.id, {}).get("name", it.id)
		"item": return ITEMS.get(it.id, {}).get("name", it.id)
		"build": return str(it.id)
	return ""


## Yükseltmeleri uygulanmış silah (kopya): ateş anında her makine bundan okur.
static func tuned(id: String, ups: Dictionary) -> Dictionary:
	var w: Dictionary = DEF.duplicate()
	w.merge(find(id), true)
	w["id"] = id
	for u in UPS.get(id, []):
		var l: int = ups.get("%s:%s" % [id, u.id], 0)
		for k in u.get("add", {}):
			w[k] += u.add[k] * l
		for k in u.get("mul", {}):
			w[k] *= pow(u.mul[k], l)
	if evolved(id, ups):
		var ev: Dictionary = EVOS[id]
		for k in ev.get("add", {}):
			w[k] += ev.add[k]
		w.merge(ev.get("fx", {}), true)
		w["color"] = ev.get("color", w.color)
		w["evo"] = ev.name
	if w.fire > 0.0:
		w["burn"] = [w.fire, BURN_T] # yetenek motoruyla aynı etki anahtarı
	return w


static func evolved(id: String, ups: Dictionary) -> bool:
	return EVOS.has(id) and ups.get("evo:" + id, 0) > 0


## Şarjör kapasitesi (0 = şarjörsüz: kılıç, bumerang).
static func mag_of(w: Dictionary) -> int:
	return w.get("mag", 0)


## Doldurma süresi; tabanca boşken daha uzun (sürgü geri). Saldırı Hızı statı kısaltır.
static func reload_time(w: Dictionary, attack: float, empty: bool) -> float:
	return (w.get("reload_empty", w.reload) if empty else w.reload) / attack


## Envantere yeni giren silahın dolu şarjörü.
static func full_ammo(id: String) -> int:
	return mag_of(find(id))


## Yetenekten gelen patlayan roketin (yaylım, gülle) TD karşılığı; hasarı arena sayılarıyla aynı.
static func arena_rocket(big: bool) -> Dictionary:
	var w: Dictionary = DEF.duplicate()
	w.merge({"id": "", "kind": "rocket", "dmg": 40.0 if big else ARENA_DMG, "blast": 4.5 if big else 2.5, "knock": 7.0}, true)
	return w


# ---------- Statlar ----------

static func base_stats(ch: Dictionary) -> Dictionary:
	var s := {}
	for d in STATS:
		s[d.id] = d.base
	s["hp"] = float(ch.get("hp", 100))
	return s


static func stat_def(id: String) -> Dictionary:
	for d in STATS:
		if d.id == id:
			return d
	return {}


## Statı bir adım artırır; üst sınırdaysa (ya da id yanlışsa) false.
static func stat_up(stats: Dictionary, id: String) -> bool:
	var d := stat_def(id)
	if d.is_empty() or stats[id] >= d.max - 0.0001:
		return false
	stats[id] = snappedf(minf(stats[id] + d.step, d.max), 0.001)
	return true


## HUD için: "+%20", "%15", "2", "130".
static func stat_text(id: String, v: float) -> String:
	if id in ["hp", "bounce"]:
		return str(int(v))
	if id in ["armor", "crit"]:
		return "%%%d" % roundi(v * 100.0)
	return "%+d%%" % roundi((v - 1.0) * 100.0)


# ---------- Envanter ----------

## d öğesinin gireceği slot (0–4); yer yoksa -1. Silah/ekipman 0–2 (aynısı ikinci kez alınmaz),
## yapı/eşya 3–4 (aynı tür üst üste yığılır).
static func find_slot(inv: Array, d: Dictionary) -> int:
	var gear: bool = d.get("kind", "") in ["weapon", "equip"]
	if not gear and not d.get("kind", "") in ["build", "item"]:
		return -1
	var free := -1
	for i in (range(0, 3) if gear else range(3, 5)):
		var it: Dictionary = inv[i]
		if it.is_empty():
			if free < 0:
				free = i
		elif it.kind == d.kind and it.id == d.id:
			return -1 if gear else i
	return free


## Çanta: elde taşınan yedek slotlar (yalnız sahibinde). Birleşik indeks: 0–4 el slotu, 5.. çanta.
const BAG_SIZE := 15


static func empty_bag() -> Array:
	var b := []
	for i in BAG_SIZE:
		b.append({})
	return b


## d, birleşik i indeksli slota girebilir mi? (silah/ekipman yalnız 0–2, yapı/eşya yalnız 3–4; çantaya hepsi.)
static func slot_ok(i: int, d: Dictionary) -> bool:
	return d.is_empty() or i >= 5 or (d.get("kind", "") in ["weapon", "equip"]) == (i < 3)


## d için çantadaki slot (0..); yer yok / silah zaten elde ya da çantada ise -1. Yapı/eşya aynı türe yığılır.
static func bag_slot(inv: Array, bag: Array, d: Dictionary) -> int:
	var gear: bool = d.get("kind", "") in ["weapon", "equip"]
	if not gear and not d.get("kind", "") in ["build", "item"]:
		return -1
	if gear and (inv + bag).any(func(it): return it.get("kind", "") == d.kind and it.get("id", "") == d.id):
		return -1
	var free := -1
	for i in bag.size():
		if bag[i].is_empty():
			if free < 0:
				free = i
		elif not gear and bag[i].kind == d.kind and bag[i].id == d.id:
			return i
	return free


## El + çantada d'ye yer var mı (satın alma ön kontrolü).
static func has_room(inv: Array, bag: Array, d: Dictionary) -> bool:
	return find_slot(inv, d) >= 0 or bag_slot(inv, bag, d) >= 0


## a'daki öğeyi b'ye taşır (birleşik indeks); b doluysa yer değiştirir, aynı yapı/eşya ise yığar.
## Tür kuralı bozulacaksa hiçbir şey değişmez ve false döner. Öğe sözlüğü olduğu gibi taşınır (ammo, lvl korunur).
static func move_item(inv: Array, bag: Array, a: int, b: int) -> bool:
	var n := 5 + bag.size()
	if a == b or a < 0 or b < 0 or a >= n or b >= n:
		return false
	var x: Dictionary = inv[a] if a < 5 else bag[a - 5]
	var y: Dictionary = inv[b] if b < 5 else bag[b - 5]
	if x.is_empty() or not slot_ok(b, x) or not slot_ok(a, y):
		return false
	if not y.is_empty() and x.kind == y.kind and x.id == y.id and x.kind in ["build", "item"]:
		y.count = int(y.get("count", 1)) + int(x.get("count", 1))
		x = {}
	else:
		var t := x
		x = y
		y = t
	if a < 5: inv[a] = x
	else: bag[a - 5] = x
	if b < 5: inv[b] = y
	else: bag[b - 5] = y
	return true


# ---------- Kartlar ----------

static func _card(id: String, title: String, desc: String, rarity: String, type: String) -> Dictionary:
	return {"id": id, "title": title, "desc": desc, "rarity": rarity, "type": type}


## Oyuncuya şu an sunulabilecek bütün kartlar (p: player.gd; stats, ups, inv, ch, sk okunur).
static func pool(p: Object) -> Array:
	var out := []
	for s in STATS:
		if p.stats[s.id] < s.max - 0.0001:
			for t in STAT_TIERS:
				out.append(_card("stat:%s:%d" % [s.id, t[1]], s.name, "%s: %s → %s" % [s.name, stat_text(s.id, p.stats[s.id]),
					stat_text(s.id, minf(p.stats[s.id] + s.step * t[1], s.max))], t[0], "stat"))
	for u in CHAR_UPS:
		var l: int = p.ups.get("char:" + u.id, 0)
		if l < u.max and (not u.has("need") or p.sk.has(u.need)):
			out.append(_card("char:" + u.id, u.name, (u.desc % (p.ch.name if u.get("passive", false) else p.ch.skill_name)) + "  (sv. %d/%d)" % [l + 1, u.max], u.rarity, "char"))
	var owned := []
	var free := false
	for i in 3:
		if p.inv[i].is_empty():
			free = true
		else:
			owned.append(p.inv[i].id)
	for it in p.bag:
		if it.get("kind", "") in ["weapon", "equip"]:
			owned.append(it.id)
		elif it.is_empty():
			free = true # el dolu olsa da çantada yer var
	if free: # yeni silah / ekipman yalnızca boş slot varken
		for w in LIST:
			if not owned.has(w.id):
				out.append(_card("weapon:" + w.id, "YENİ SİLAH: " + w.name, w.desc, w.rarity, "weapon"))
		for id in EQUIPS:
			if not owned.has(id):
				out.append(_card("equip:" + id, "EKİPMAN: " + EQUIPS[id].name, EQUIPS[id].desc, EQUIPS[id].rarity, "weapon"))
	for id in owned:
		for u in UPS.get(id, []):
			var l: int = p.ups.get("%s:%s" % [id, u.id], 0)
			if l < u.max:
				out.append(_card("up:%s:%s" % [id, u.id], "%s: %s" % [find(id).name, u.name], "%s  (sv. %d/%d)" % [u.desc, l + 1, u.max], u.rarity, "weapon_up"))
		if can_evolve(id, p):
			out.append(_card("evo:" + id, "EVRİM: " + EVOS[id].name, EVOS[id].desc, "legendary", "evo"))
	return out


## Silah evrime hazır mı: iki yükseltme eşikte, stat eşikte, henüz evrilmemiş.
static func can_evolve(id: String, p: Object) -> bool:
	if not EVOS.has(id) or evolved(id, p.ups):
		return false
	var ev: Dictionary = EVOS[id]
	for u in ev.needs:
		if p.ups.get("%s:%s" % [id, u], 0) < ev.needs[u]:
			return false
	return p.stats[ev.stat[0]] >= ev.stat[1] - 0.0001


## Nadirlik ağırlığıyla n farklı kart çeker; aynı statın iki kademesi birlikte çıkmaz.
static func roll_cards(p: Object, n := 3) -> Array:
	var cards := pool(p)
	var out := []
	while out.size() < n and not cards.is_empty():
		var total := 0.0
		for c in cards:
			total += _weight(c)
		var r := randf() * total
		var pick: Dictionary = cards[-1]
		for c in cards:
			r -= _weight(c)
			if r <= 0.0:
				pick = c
				break
		out.append(pick)
		var key := _group(pick)
		cards = cards.filter(func(c): return _group(c) != key)
	return out


static func _weight(c: Dictionary) -> float:
	if c.type == "evo":
		return EVO_WEIGHT
	return RARITY[c.rarity].weight * (OWN_BOOST if c.type == "weapon_up" else 1.0)


static func _group(c: Dictionary) -> String:
	return c.id.get_slice(":", 0) + ":" + c.id.get_slice(":", 1) if c.type == "stat" else c.id


## Kartı oyuncuya uygular (yalnızca sahibinin makinesinde; yayını player.gd yapar).
static func apply_card(p: Object, c: Dictionary) -> void:
	var a: PackedStringArray = c.id.split(":")
	match c.type:
		"stat":
			for i in int(a[2]):
				stat_up(p.stats, a[1])
		"char":
			p.ups[c.id] = p.ups.get(c.id, 0) + 1
		"weapon":
			p.add_item({"kind": "equip" if a[0] == "equip" else "weapon", "id": a[1]})
		"evo":
			p.ups[c.id] = 1
			for it in p.inv + p.bag:
				if it.get("id", "") == a[1]:
					it["evo"] = true
		"weapon_up":
			var k := a[1] + ":" + a[2]
			p.ups[k] = p.ups.get(k, 0) + 1
			for it in p.inv + p.bag:
				if it.get("id", "") == a[1]:
					it.lvl += 1


# ---------- Yaratıklar (grup "enemies": hp, radius, height, global_position = ayak) ----------

static func e_r(e: Node) -> float:
	var v = e.get("radius")
	return v if v != null else 0.5


static func e_h(e: Node) -> float:
	var v = e.get("height")
	return v if v != null else 1.8


static func e_mid(e: Node3D) -> Vector3:
	return e.global_position + Vector3.UP * e_h(e) * 0.5


static func alive(tree: SceneTree) -> Array:
	return tree.get_nodes_in_group("enemies").filter(func(e): return is_instance_valid(e) and e.is_inside_tree() and e.get("hp") != null and e.hp > 0)


## Noktanın yaratığın gövde eksenine (dikey doğru parçası) uzaklığı, yarıçap düşülmüş.
static func dist(e: Node3D, p: Vector3) -> float:
	var a := e.global_position
	return Geometry3D.get_closest_point_to_segment(p, a + Vector3.UP * minf(e_r(e), e_h(e) * 0.5), a + Vector3.UP * maxf(e_h(e) - e_r(e), e_h(e) * 0.5)).distance_to(p) - e_r(e)


## from -> to doğru parçasının (kalınlık pad) değdiği yaratıklar, yakından uzağa: [[uzaklık, yaratık, nokta], ...].
static func ray(tree: SceneTree, from: Vector3, to: Vector3, pad := 0.0, skip := []) -> Array:
	var out := []
	for e in alive(tree):
		if skip.has(e):
			continue
		var a: Vector3 = e.global_position
		var h := e_h(e)
		var r := e_r(e)
		var pts := Geometry3D.get_closest_points_between_segments(from, to, a + Vector3.UP * minf(r, h * 0.5), a + Vector3.UP * maxf(h - r, h * 0.5))
		if pts[0].distance_to(pts[1]) < r + pad:
			out.append([from.distance_to(pts[0]), e, pts[0]])
	out.sort_custom(func(x, y): return x[0] < y[0])
	return out


static func nearest(tree: SceneTree, p: Vector3, max_d: float, skip := []) -> Node3D:
	var best: Node3D = null
	for e in alive(tree):
		var d := dist(e, p)
		if d < max_d and not skip.has(e):
			best = e
			max_d = d
	return best


## Yetenek / silah etkisini yaratık kancasının beklediği sade sözlüğe çevirir (hasar ve yanık hariç):
##   slow [çarpan, sn], stun sn, vuln [çarpan, sn], knock Vector3 (itme hızı).
## Oyunculara özgü etkiler (kör, sustur, ters yön) yaratıkta yarı süreli sersemletme olur.
static func enemy_fx(e: Dictionary, from: Vector3, at: Vector3, caster: Vector3) -> Dictionary:
	var out := {}
	for k in ["slow", "vuln"]:
		if e.has(k):
			out[k] = e[k]
	var stun: float = e.get("stun", 0.0)
	for k in ["blind", "silence", "confuse"]:
		stun = maxf(stun, e.get(k, 0.0) * 0.5)
	if stun > 0.0:
		out["stun"] = stun
	var away := at - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.05 else Vector3.ZERO
	var v: Vector3 = away * e.get("knock", 0.0) - away * e.get("pull", 0.0)
	if e.get("knock", 0.0) > 0.0 or e.has("up"):
		v.y += e.get("up", 3.0)
	if e.has("yank"):
		var to := caster - at
		v = to.normalized() * minf(to.length() * 2.2, e.yank) + Vector3.UP * 5.0
	if v != Vector3.ZERO:
		out["knock"] = v
	return out


# ---------- Görsel ----------

## Silahın elde tutulan modeli (namlu -Z); modeli yoksa boş düğüm.
static func make_prop(w: Dictionary) -> Node3D:
	var path := "res://models/%s.glb" % w.get("id", "")
	return load(path).instantiate() if ResourceLoader.exists(path) else Node3D.new()
