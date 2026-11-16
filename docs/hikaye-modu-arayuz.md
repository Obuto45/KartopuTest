# Hikaye Modu: dosya sahipliği ve arayüz sözleşmesi

Hikaye Modu = 1–4 oyunculu co-op **dalga savunması + kuleler**. Oyuncular bazuka/kılıç/yetenekle savaşır, dalga aralarında takım parasıyla kule diker ve mağazadan güçlendirme alır. Takım XP kazanır, seviye atlar. Arena modu **değişmeden** çalışmaya devam eder.

Motor: Godot 4.7.2, GDScript, sahnesiz (her şey koddan). Harita: mevcut `forest.gd` (60x60 m, ortada açık alan, taş duvarla çevrili, `SPAWNS` köşelerde ağaçsız).

## Dosya sahipliği (aynı dosyaya iki ajan dokunmaz)

| Ajan | Dosyalar |
|---|---|
| **A: oynanış ve sayısal tasarım** | `story.gd` (yeni), `enemy.gd` (yeni), `tower.gd` (yeni), `balance.gd` (yeni), `player.gd`, `rocket.gd` |
| **B: karakter/silah/mağaza/UI** | `story_ui.gd` (yeni), `main.gd`, `tests/shots.gd` |
| **C: depo** | `_referans/` (git'e girmez), `.gitignore`, dal ve commit'ler |
| Ana ajan | bu dosya, birleştirme, `TASKS.md` |

Başka ajanın dosyasında hata görürsen düzeltme, ana ajana raporla.

## Ağ kuralı
- **Host (peer 1) otoriterdir**: dalga, düşman yapay zekâsı, kuleler, para, XP, mağaza alımları host'ta karar verilir, diğerlerine rpc ile yayınlanır.
- İstemciler isteklerini `rpc_id(1, ...)` ile host'a gönderir.
- Oyuncu hareketi ve oyuncunun kendisine gelen hasar eskisi gibi kalır (herkes kendi oyuncusunun sahibi).
- Düşmana hasar: atış kimdeyse o makine hasarı hesaplar ve `story.damage_enemy.rpc_id(1, enemy_name, dmg, attacker_id)` ile host'a gönderir.

## `balance.gd` (A yazar, B okur): tüm sayılar burada
`const Balance := preload("res://balance.gd")` ile okunur. Değişmeyecek alan adları:
- `Balance.WAVES: Array`: her dalga `{"count": int, "types": {"zombie": ağırlık, ...}, "boss": String veya ""}`; toplam dalga = `WAVES.size()` (10).
- `Balance.ENEMIES: Dictionary`: tür → `{"name": String, "hp": int, "speed": float, "dmg": int, "money": int, "xp": int, "model": String}` (`model` = `models/chars/` içindeki glb adı).
- `Balance.TOWERS: Dictionary`: tür → `{"name": String, "desc": String, "price": int, "range": float, "dmg": int, "rate": float, "color": Color}`.
- `Balance.SHOP: Array`: güçlendirmeler `{"id": String, "name": String, "desc": String, "price": int, "max": int}` (aynı güçlendirme en çok `max` kez alınır).
- `Balance.BREAK_TIME: float`, `Balance.xp_for(level: int) -> int` (o seviyeden bir sonrakine gereken XP).

## `story.gd` (A yazar): `extends Node`, düğüm adı `"Story"`, `world`'ün çocuğu, `add_to_group("story")`
Okunabilir değişkenler (her makinede güncel):
`wave: int`, `total_waves: int`, `state: String` (`"break"` | `"fight"` | `"won"` | `"lost"`), `time_left: float` (mola süresi), `money: int` (takım parası), `level: int`, `xp: int`, `xp_next: int`, `enemies_left: int`, `kills: int`, `bought: Dictionary` (peer id → {güçlendirme id → adet}).

Sinyaller (her makinede yayılır): `changed()` (herhangi bir değer değişti, UI yenilesin), `wave_started(wave: int)`, `level_up(level: int)`, `run_ended(won: bool)`.

İstemci/UI'nin çağırdığı fonksiyonlar (içeride host'a rpc yapar, yetersiz parada sessizce reddeder):
- `buy(id: String)`: mağaza güçlendirmesi, alan oyuncuya uygulanır.
- `place_tower(kind: String, pos: Vector3, yaw: float)`: `pos` yerde bir nokta; geçersizse (duvar dışı, başka kuleye < 2 m) reddedilir.
- `can_place(kind: String, pos: Vector3) -> bool`: UI hayalet önizlemesi için yerel kontrol.
- `ready_up()`: molayı erken bitirme oyu; herkes hazırsa dalga başlar.
- `damage_enemy(enemy_name: String, dmg: int, attacker_id: int)`: `@rpc("any_peer", "call_local", "reliable")`.

`main.gd` (B) Hikaye Modu maçında: dünyayı kurar, oyuncuları ekler, sonra `var s = preload("res://story.gd").new(); s.name = "Story"; world.add_child(s)` yapar. `story.gd` gerisini kendi yürütür (ilk mola ile başlar).

## `player.gd` (A) eklemeleri
- Hikaye Modu tespiti: `get_tree().get_first_node_in_group("story") != null`.
- Hikaye Modunda ölmek yerine **yere düşer**: `var downed: bool`, `var downed_t: float` (15 sn; biterse ölür ve dalga sonuna kadar izler). Yakındaki (2 m) canlı arkadaş **"interact"** eylemini (E) basılı tutunca 3 sn'de kaldırır: `var revive_progress: float` (0–1, UI çubuğu için).
- Hikaye Modunda arena tur mantığı (`report_death` → tur sonu) çalışmaz.
- `apply_upgrade(id: String)`: `Balance.SHOP` güçlendirmelerinin oyuncuya etkisi.

## `main.gd` (B) eklemeleri
- `var mode := "arena"` (`"arena"` | `"story"`); mod seçim kartında Hikaye Modu açılır, lobi sayfası seçilen moda göre başlık gösterir.
- Hikaye maçını başlatan **yeni** rpc (ör. `start_story(ids)`); arena'nın `start_game(ids)` rpc'si **değişmez**.
- `_setup_input`: `"interact"` = E, `"shop"` = B (mağaza/kule menüsü), `"ready"` = G (molayı bitirmeye hazırım).
- `story_ui.gd`: dalga/para/XP/seviye göstergesi, mola sayacı, mağaza paneli, kule yerleştirme modu (hayalet önizleme, sol tık koy, sağ tık iptal), yerde olma ve kaldırma göstergesi, koşu sonu ekranı (Menüye Dön / Tekrar Oyna).

## Düşman modelleri
Dış indirme yok. Mevcut karakterlerden: Beyinsiz Zombi (42), Zombi Gelin (41), Minik Goblin (37), Tuzakçı Goblin (38), boss için Altın Dev (34) veya Boğa (50), renk tonu ile ayrılır. Model adları `characters.gd` içinde.
