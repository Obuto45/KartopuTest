# Tower Defense modu: tasarım, dosya sahipliği ve arayüz sözleşmesi

Oyunda iki mod var: **Arena** (mevcut PvP, davranışı DEĞİŞMEZ) ve **Tower Defense** (TD, 1–4 oyunculu co-op). Bu belge TD içindir.
Motor: Godot 4.7.2, GDScript, sahnesiz (her şey koddan). Referans depolar ve notlar: `_referans/NOTLAR.md` (yalnızca okunur, hiçbir şey çalıştırılmaz; kod kopyalanırsa lisans notu korunur).

## Oyun tarifi (kullanıcının isteği)
- Haritanın ortasında bir **kule**, tepesinde **yüzü görünmeyen, uzun saçlı Rapunzel**. Kulenin canı var; biterse **oyun biter**.
- Yaratıklar çevredeki belirli uzaklıktaki noktalardan gelir. Dalga ilerledikçe türleri, boyutları ve güçleri artar. İki davranış: **kuleye saldıranlar** ve **oyunculara saldıranlar**. Güçler **oyuncu sayısına** göre dengelenir (1–4).
- Ölen yaratık **XP** ve **para** verir. XP **ortak havuzda** toplanır; ekranın en altında **sayısız** XP çubuğu. Çubuk dolunca **her oyuncu** bir seviye atlar: kendi **3 kartından** birini seçer (stat yükseltme, karaktere özel güçlendirme, nadirliğe göre yeni silah, silaha özel yükseltme: MegaBonk tarzı) ve **stat puanı** kazanır.
- **Statlar**: zıplama, hız, mermi hızı, mermi gücü, saldırı (hızı), zırh, kritik, mermi sekmesi, can. **TAB** basılıyken stat paneli görünür. Stat puanları **dalga arası molada** harcanır.
- **Mağaza** (para ile): duvar, dikenli duvar, tuzak, taret gibi kuleyi koruyan **yapılar**.
- Oyuna girmeden önce **10 silahtan biri** seçilir (karakter silahla gelmez).
- **5 slotluk envanter**: 1–3 silah/ekipman, 4–5 mağazadan alınan kurulabilir yapılar veya yaratıklardan düşen eşyalar.

Yorumlar (ana ajan kararı): seviye takım için ortaktır ama kart seçimi ve stat puanı oyuncuya özeldir. Ölen oyuncu 8 sn sonra kule dibinde yeniden doğar (oyun yalnızca kule yıkılınca biter). 10 dalga, son dalga boss; bitince "kazandınız".

## Dosya sahipliği (bir dosyaya tek ajan dokunur)

| Ajan | Dosyalar |
|---|---|
| **A: çekirdek oynanış ve sayısal tasarım** | `td.gd`, `enemy.gd`, `tower.gd`, `build.gd`, `balance.gd` (hepsi yeni), `tests/td_test.gd/.tscn` (yeni) |
| **B: karakter / silah / stat / envanter** | `weapons.gd` (yeni), `player.gd`, `rocket.gd`, `slipper.gd`, `net.gd`, `tests/weapons_test.gd/.tscn` (yeni) |
| **C: mağaza ve arayüz** | `td_ui.gd` (yeni), `main.gd`, `tests/shots.gd` |
| **D: depo** | `_referans/`, `.gitignore`, dal, commit, push |
| Ana ajan | bu belge, birleştirme, `TASKS.md` |

Başka ajanın dosyasında eksik/hata görürsen DÜZELTME: kendi tarafında güvenli varsayılanla (`has_method`, `get(...)`) korun ve raporla. Diğer ajanlar aynı klasörde aynı anda çalışıyor; başkasının dosyasındaki geçici parse hatası için 30–60 sn bekleyip yeniden dene.

## Ağ kuralı
- **Host (peer 1) otoriterdir**: dalgalar, yaratık yapay zekâsı, kule canı, yapılar, para, XP/seviye. İstemciler isteği `rpc_id(1, ...)` ile gönderir, host sonucu herkese yayınlar.
- Oyuncu hareketi ve oyuncunun aldığı hasar eskisi gibi: herkes kendi oyuncusunun sahibi.
- Yaratığa hasar: mermiyi atan makine isabeti hesaplar, `td.damage_enemy.rpc_id(1, enemy_name, dmg, crit)` gönderir (host ise doğrudan çağırır).
- TD tespiti her yerde: `get_tree().get_first_node_in_group("td")` (null ise Arena). **Arena'da hiçbir TD kodu çalışmamalı**; mevcut rpc imzaları değişmez.

## Harita
- `forest.gd` aynen kullanılır (60x60 m, `HALF = 30`). C, TD maçında `forest.spawns = TD_CLEAR` verir; böylece orta alan ağaçsız/kayasız kalır:
  `TD_CLEAR := [Vector3(0,0,0), Vector3(6,0,0), Vector3(-6,0,0), Vector3(0,0,6), Vector3(0,0,-6)]`; oyuncu doğma noktaları `TD_SPAWNS := [Vector3(5,1,0), Vector3(-5,1,0), Vector3(0,1,5), Vector3(0,1,-5)]` (ikisi de `main.gd` sabiti).
- Kule merkezde `(0,0,0)`, çarpışma yarıçapı ≤ 2,2 m. Yaratık doğma noktaları: merkezden 26 m uzakta 8 nokta (`Balance.SPAWN_POINTS`).

## `balance.gd` (A): TD'nin tüm sayıları; `const Balance := preload("res://balance.gd")`
- `TOWER_HP: int`, `BREAK_TIME: float`, `WAVE_COUNT: int` (10), `SPAWN_POINTS: Array[Vector3]`, `RESPAWN_TIME := 8.0`
- `ENEMIES: Dictionary`: tür → `{"name", "hp", "speed", "dmg", "rate", "range", "target": "tower"|"player", "scale", "money", "xp", "model", "tint": Color}` (`model` = `models/chars/` içindeki glb adı; dış indirme yok)
- `static func wave(n: int, players: int) -> Dictionary`: `{"groups": [{"type", "count"}...], "hp_mult": float, "dmg_mult": float, "boss": String}`; oyuncu sayısı ölçeklemesi burada.
- `static func xp_for(level: int) -> int`: o seviyeden sonrakine gereken havuz XP'si.
- `SHOP: Array`: `{"id", "name", "desc", "price", "kind": "build", "hp", "color"}`; en az: `wall` (duvar), `spike` (dikenli duvar: dokunana hasar), `trap` (tuzak: üstünden geçeni yavaşlatır/hasar, tek kullanımlık ya da şarjlı), `turret` (taret: menzildeki yaratığa ateş eder).

## `td.gd` (A): `extends Node`, adı `"TD"`, `world`'ün çocuğu, `add_to_group("td")`
C şöyle kurar: dünya ve oyuncular eklendikten sonra `var t = preload("res://td.gd").new(); t.name = "TD"; world.add_child(t)`. Gerisini td.gd yürütür (kuleyi kurar, ilk molayı başlatır). Yaratıklar `world/Enemies`, yapılar `world/Builds` altında.

Her makinede güncel değişkenler: `wave: int`, `state: String` (`"break"|"fight"|"won"|"lost"`), `time_left: float`, `money: int` (takım parası), `level: int`, `xp: int`, `xp_next: int`, `tower_hp: int`, `tower_max: int`, `enemies_left: int`, `kills: int`, `ready: Dictionary` (peer → bool).
Sinyaller (her makinede): `changed()`, `wave_started(wave: int)`, `leveled(level: int)`, `run_ended(won: bool)`.
Fonksiyonlar:
- `damage_enemy(enemy_name: String, dmg: int, crit: bool)`: `@rpc("any_peer", "call_local", "reliable")`.
- `buy(id: String)`: çağıranın envanterine 1 adet kurulabilir yapı ekler (host parayı düşer, sonra o oyuncuda `player.add_item.rpc_id(peer, {"kind": "build", "id": id})` çağırır; envanter doluysa para düşmez).
- `place(id: String, pos: Vector3, yaw: float)`: yapıyı kurar (host doğrular, herkeste oluşturur). `can_place(id, pos) -> bool` yerel ön kontrol (harita içi, kuleye ≥ 3 m, başka yapıya ≥ 1,5 m).
- `ready_up()`: molayı bitirme oyu; herkes hazırsa ya da süre bitince dalga başlar.
- Seviye atlayınca host her oyuncuda `player.level_up.rpc_id(peer)` çağırır (B uygular).
- Yaratık oyuncuya vururken oyuncunun mevcut hasar yolunu kullanır (`take_hit` vb.; `player.gd`'yi OKU, değiştirme; gerekirse B'nin eklediği `td_hit(dmg)` rpc'sini kullan: aşağıda).

## `enemy.gd` (A)
`CharacterBody3D`, grup `"enemies"`, benzersiz `name`. B'nin mermileri için okunur alanlar: `hp: int`, `radius: float` (gövde yarıçapı), `height: float`, `global_position` (ayak noktası). Host simüle eder, konumları toplu ve güvenilmez rpc ile ~12 Hz yayınlar; istemcide yumuşatılır. Can çubuğu, hasar sayısı (kritik sarı), ölüm efekti A'da.

## `weapons.gd` (B): silah, stat ve kart verisi; `const Weapons := preload("res://weapons.gd")`
- `LIST: Array` (tam 10 silah): `{"id", "name", "desc", "rarity", "dmg", "rate", "speed", "kind", ...}`; `static func get_weapon(i: int) -> Dictionary`. Başlangıçta seçilebilenler bu 10 silahtır.
- `STATS: Array`: `{"id", "name", "base", "step", "max"}`; id'ler: `jump, speed, shot_speed, shot_power, attack, armor, crit, bounce, hp`.
- `RARITY: Dictionary`: `common|rare|epic|legendary` → `{"name", "color": Color, "weight"}`.
- Kartlar: `{"id", "title", "desc", "rarity", "type": "stat"|"char"|"weapon"|"weapon_up"}`.

## `player.gd` (B) eklemeleri (yalnız TD'de etkin)
- `stats: Dictionary` (stat id → değer), `stat_points: int`, `spend_point(stat_id: String)` (yalnız `td.state == "break"` iken), `level: int`.
- `inv: Array` (5 eleman; boş = `{}`; dolu = `{"kind": "weapon"|"equip"|"build"|"item", "id": String, "count": int, "lvl": int}`), `slot: int` (1–5 seçili). 1–3 silah/ekipman, 4–5 yapı/eşya. `add_item(d: Dictionary) -> bool` (`@rpc("any_peer", "call_local", "reliable")`, yer yoksa false), seçili yapı slotunda sol tık = yerleştirme (hayalet önizleme, `td.can_place` ile yeşil/kırmızı, sonra `td.place`).
- `cards: Array` (seçim bekleyen 3 kart; boşsa `[]`), `choose_card(i: int)`, `level_up()` rpc'si (host çağırır: kart çeker, stat puanı verir). Birden fazla seviye birikirse sırayla.
- `td_hit(dmg: int)`: `@rpc("any_peer", "call_local", "reliable")`, yaratık hasarı; zırh statı uygulanır. Ölünce `Balance.RESPAWN_TIME` sonra kule dibinde doğar; TD'de `main.report_death` ÇAĞRILMAZ.
- Mermiler yaratıklara (`"enemies"` grubu) isabet eder ve `td.damage_enemy` gönderir; TD'de oyuncular birbirine hasar veremez (dost ateşi kapalı). Statlar silah hasarına/hızına uygulanır.
- `net.gd`: `my_weapon: int`, `weapons: Dictionary` (peer → silah no), `set_weapon(i: int)` (karakter seçimiyle aynı eşitleme yolu; `register_name` imzası DEĞİŞMEZ, yeni rpc eklenir).

## `main.gd` + `td_ui.gd` (C)
- `var mode := "arena"`; mod kartında "HİKAYE MODU" yerine **"TOWER DEFENSE"** açık. Lobi sayfası seçilen modu gösterir; host modu seçer, TD'yi yeni rpc `start_td(ids)` ile başlatır (`start_game` DEĞİŞMEZ). TD'de tek kişi de başlatabilmeli (yerel host).
- **Silah seçimi**: TD lobisinde 10 silahlı seçim ekranı (`Weapons.LIST`, `Net.set_weapon`).
- Girdi eylemleri (`_setup_input`): `"slot5"` = 5, `"stats"` = TAB, `"shop"` = B, `"ready"` = G, `"interact"` = E.
- `td_ui.gd`: en altta **sayısız XP çubuğu**; kule can çubuğu (üst orta); dalga, kalan yaratık, para, mola sayacı ve "G: hazır"; **5 slotluk envanter çubuğu** (TD'de arena çubuğunun yerine); **TAB stat paneli** (molada puan harcama düğmeleri); **seviye kartları** (3 kart, nadirlik renkli, 1/2/3 tuşu ya da tıklama; savaş sürerken oyunu durdurmaz); **mağaza** (B tuşu, yalnız molada); oyun sonu ekranı (kazandınız/kule yıkıldı, dalga, öldürme; Menüye Dön).
- Fare: kart/mağaza/stat paneli açıkken imleç görünür; kapanınca yeniden yakalanır.

## Doğrulama
Her ajan kendi başsız (headless) testini yazar ve çalıştırır; `tests/skills.tscn` (52/52) ve Arena bozulmamalı. Ekran görüntüsü testini (`tests/shots.tscn`) yalnız C çalıştırır.
Godot: `"C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/<ad>.tscn`
