# Steam başarımları ve istatistikleri

34 başarım ve 16 istatistik. Çoğu oyuncunun ilk saatte açacağı kolay başarımlar ile uzun vadede açılacak nadir olanlar karışık tutuldu. Yaklaşık üçte biri komik ya da sosyal. Kod yerleri bu daldaki (`claude/awesome-rubin-cogyc1`) duruma göre yazıldı. **(plan)** işaretli satırlar, `docs/oynanis-plani.md` 2. aşamasında gelecek özelliklere (zorluk, sonsuz mod, silah evrimi, maç özeti) bağlı.

## Bağlantı noktaları (kodda zaten olanlar)

| Olay | Nerede | Hangi makinede |
|---|---|---|
| Dalga başladı | `td.wave_started(n)` sinyali. n ≥ 2 ise önceki dalga temizlenmiş demektir | Hepsinde (`_state` rpc'si) |
| Takım seviyesi | `td.leveled(level)` | Hepsinde |
| Maç bitti | `td.run_ended(won)`. **(plan)** `td.summary_ready(d)`: `won, wave, difficulty, endless, players{peer: {dmg, kills, crits, builds, deaths}}, mvp` | Hepsinde |
| Yaratık öldü | `td._hit(id, hp, n, crit)`: `hp <= 0` ve `e.type` (`"ogre"`, `"boss"`...) | Hepsinde (call_local) |
| Kart seçildi | `player.choose_card(i)`: `cards[i].rarity`, `cards[i].type` | Kartı seçen oyuncu |
| Tavuk vuruldu | `player._hunt(c)` | Atan oyuncu |
| Q yeteneği | `player._use_skill()` | Kullanan oyuncu |
| Kalkan roketi emdi | `player.apply_blast()` → `me.shield_on` dalı | Kurban |
| İzleyici modu | `player._spectate(dt)` | Ölen oyuncu |
| Lobiye katıldı | `net._on_lobby_joined()` (sahibi kendisi değilse davetle gelmiştir) | Katılan |
| Arena turu bitti | `main.end_round(winner)` | Hepsinde |

**Eksik küçük kancalar** (kodu başka ajanlar düzenliyor, bu belge yalnızca öneriyor):
1. **Arena'da kim öldürdü?** Hasar kurbanın makinesinde uygulanıyor ve `take_hit` kimin vurduğunu bilmiyor. `apply_blast`, `swing` ve `hit_local` içinde `self` atan oyuncudur. Öneri: `take_hit`'ten önce `me.last_by = get_multiplayer_authority()` ve `me.last_src = "rocket"|"sword"|"skill"` ata. Ölümde `credit_kill.rpc_id(last_by, last_src, rocket_name)` gönder.
2. **Arena kazananı:** `end_round(winner: String)` görünen adı taşıyor ve iki oyuncu aynı adı kullanabilir. Öneri: `report_death` içinde kazananın peer numarasını da gönder.
3. **(isteğe bağlı) TD'de son darbe:** `damage_enemy` içinde `multiplayer.get_remote_sender_id()` alınıp (host için 1) `_hit`'e 5. argüman olarak geçirilebilir.

## Başarım listesi

Oran, hedeflenen açılma oranıdır: Y = yaygın (>%40), O = orta (%10–40), N = nadir (<%10).

### Tower Defense: ilerleme
| API adı | TR | EN | Açıklama (EN) | Tetikleyici | Oran |
|---|---|---|---|---|---|
| ACH_TD_WAVE1 | İlk Dalga | First Wave Down | Clear your first wave. | `wave_started(n)` ile n == 2 | Y |
| ACH_TD_GIANT | Dev Devrildi | Giant Slayer | Defeat the Giant Goblin of wave 5. | `_hit`: `hp <= 0 and e.type == "ogre"` | Y |
| ACH_TD_WIN | Rapunzel Güvende | Tower Saved | Survive all 10 waves. | `run_ended(true)` | O |
| ACH_TD_WIN_HARD | Zor Zamanlar | Hard Times | Win on Hard. | **(plan)** `summary_ready`: `won and difficulty in ["hard","nightmare"]` | O |
| ACH_TD_WIN_NIGHTMARE | Kâbus Bitti | Nightmare's Over | Win on Nightmare. | **(plan)** `difficulty == "nightmare"` | N |
| ACH_TD_SOLO | Tek Kişilik Ordu | One-Man Army | Win a run alone. | `run_ended(true)`, o anda `players` düğümünde 1 çocuk var | N |
| ACH_TD_SQUAD | Tam Kadro | Full Squad | Win a run with 4 players. | Aynı koşul, 4 çocuk | O |
| ACH_TD_FLAWLESS | Saçına Dokunulmadı | Not a Hair Harmed | Clear a wave without the tower taking damage. | Her makinede: `wave_started` anındaki `tower_hp`'yi sakla. Durum `"break"`e döndüğünde değer aynıysa aç | O |
| ACH_TD_CLUTCH | Son Tel | Hanging by a Hair | Win with the tower under 10% health. | `run_ended(true)` ve `tower_hp <= tower_max * 0.1` | N |
| ACH_TD_ENDLESS20 | Saç Uzadıkça Uzar | Endless Hair | Reach wave 20 in Endless. | **(plan)** `endless and wave_started(n)` ile n == 21 | N |

### Tower Defense: kişisel
| API adı | TR | EN | Açıklama (EN) | Tetikleyici | Oran |
|---|---|---|---|---|---|
| ACH_TD_KILLS_100 | Hortlak Avcısı | Ghoul Hunter | Defeat 100 monsters. | `STAT_TD_KILLS ≥ 100` (maç sonunda `players[me].kills` eklenir) | Y |
| ACH_TD_KILLS_2500 | Orman Temizlendi | Clear-Cut | Defeat 2,500 monsters. | `STAT_TD_KILLS ≥ 2500` | N |
| ACH_TD_MVP | Maçın Yıldızı | MVP | Be the MVP of a won run. | **(plan)** `summary_ready`: `won and mvp == multiplayer.get_unique_id()` | O |
| ACH_TD_LEVEL10 | Dolu El | Full Hand | Reach team level 10 in one run. | `leveled(level)` ile level ≥ 10 | O |
| ACH_TD_LEGENDARY | Efsane Çekiliş | Legendary Pull | Pick a Legendary card. | `choose_card`: `cards[i].rarity == "legendary"` | O |
| ACH_TD_EVOLVE | Evrim | Evolution | Evolve a weapon. | **(plan)** `Weapons.EVOS` uygulandığı yer | O |
| ACH_TD_BUILDER | Müteahhit | Contractor | Place 10 structures in one run. | **(plan)** `players[me].builds ≥ 10`; şimdilik `td.place()` içinde yerel sayaç | O |
| ACH_TD_ARSENAL | Cephanelik | Arsenal | Win with all 10 starting weapons. | `STAT_TD_WEAPON_WINS` bit maskesi: zaferde `1 << Net.my_weapon`. 10 bit dolunca aç | N |

### Arena
| API adı | TR | EN | Açıklama (EN) | Tetikleyici | Oran |
|---|---|---|---|---|---|
| ACH_ARENA_FRAG | İlk Roket | First Frag | Take out a player in the Arena. | `credit_kill` (yukarıdaki kanca 1) | Y |
| ACH_ARENA_WIN | Son Ayaktaki | Last One Standing | Win an Arena round. | `end_round`: kazanan peer == ben (kanca 2) | Y |
| ACH_ARENA_WINS_50 | Arena Efsanesi | Arena Legend | Win 50 Arena rounds. | `STAT_ARENA_WINS ≥ 50` | N |
| ACH_ARENA_DOUBLE | Bir Roket İki Kafa | Two for One | Take out 2 players with a single rocket. | `credit_kill` aynı `rocket_name` ile 2 kez | N |
| ACH_ARENA_SHIELD | Bugün Olmaz | Not Today | Block 25 rockets with your shield. | `apply_blast`, `me.shield_on` dalı → `STAT_SHIELD_BLOCKS` | O |

### Komik ve karakter
| API adı | TR | EN | Açıklama (EN) | Tetikleyici | Oran |
|---|---|---|---|---|---|
| ACH_CHICKEN | Tavuk Avcısı | Poultry in Motion | Blow up a chicken. | `player._hunt()` | Y |
| ACH_CHICKEN_100 | Tavuk Döner | Rotisserie | Blow up 100 chickens. *(gizli)* | `STAT_CHICKENS ≥ 100` | N |
| ACH_METEOR | Gökten Ne Yağıyor? | What's Falling From the Sky? | Take out a player with the Archmage's meteor. | `credit_kill` ile `last_src == "skill"`, karakter Ulu Büyücü (`characters.gd` sıra 40) | O |
| ACH_HIC | Hık! | Hic! | As the Deckhand, score a takedown while tipsy from your own rum. | Tayfa (sıra 29), `buffs`'ta `confuse` varken `credit_kill` | N |
| ACH_MANNEQUIN | Ben Hiç Kıpırdamadım ki! | I Never Moved! | As the Mannequin, score a takedown while invisible. | Manken (sıra 9), `invis` aktifken `credit_kill` | N |
| ACH_PUG | Kravatlı Bela | Good Boy | Win an Arena round as the Pug. | `ACH_ARENA_WIN` koşulu ve `Net.my_char == 51` | O |
| ACH_ALL_CHARS | Kimlik Krizi | Identity Crisis | Play a match with all 52 heroes. | Maç başında `STAT_CHARS_LO/HI` bit maskesi. `STAT_CHARS_PLAYED` = bit sayısı, 52'de aç | N |

### Sosyal
| API adı | TR | EN | Açıklama (EN) | Tetikleyici | Oran |
|---|---|---|---|---|---|
| ACH_HOST4 | Ev Sahibi | Party Host | Host a full 4-player game. | `main.start_game` / `start_td` host'ta, `ids.size() == 4` | O |
| ACH_INVITE | Davetli | Plus One | Join a friend's lobby. | `net._on_lobby_joined`: başarılı ve `getLobbyOwner(id) != getSteamID()` | Y |
| ACH_SPECTATOR | Koltuk Yorumcusu | Backseat Gamer | Spend 10 minutes spectating your friends. | `_spectate(dt)` içinde süre biriktir → `STAT_SPECTATE_SEC ≥ 600` | O |
| ACH_SKILL_500 | Q'ya Âşık | Q Enthusiast | Use your hero ability 500 times. | `_use_skill()` → `STAT_SKILLS_USED` | O |

Önce açılan sıra numaralarını (`characters.gd` LIST indeksleri: Manken 9, Tayfa 29, Ulu Büyücü 40, Pug 51) bir kez daha doğrula. Liste yalnızca sona eklenerek büyüdüğü sürece sıralar sabit kalır.

## İstatistikler (Steamworks → Stats)

Hepsi `INT`, "Set By: Client". Sayaçlar "Increment Only" olarak işaretlenir. ★ olanlar "Aggregated" (global toplam) işaretlenir. Global toplamlar topluluk etkinliği malzemesidir: "Steam'deki herkes 1 milyon tavuk patlattı".

| API adı | Ne sayar | Başarım |
|---|---|---|
| STAT_TD_KILLS ★ | TD'de öldürülen yaratık | KILLS_100 / 2500 |
| STAT_TD_RUNS | Başlatılan TD maçı | |
| STAT_TD_WINS | Kazanılan TD maçı | |
| STAT_TD_BEST_WAVE | En iyi dalga (sonsuz mod; yalnız büyürse yaz) | ENDLESS20 |
| STAT_TD_WEAPON_WINS | 10 bitlik maske: hangi başlangıç silahıyla kazanıldı | ARSENAL |
| STAT_ARENA_ROUNDS | Oynanan arena turu | |
| STAT_ARENA_WINS | Kazanılan arena turu | ARENA_WINS_50 |
| STAT_ARENA_KILLS ★ | Arena'da indirilen oyuncu | |
| STAT_SHIELD_BLOCKS | Kalkanla emilen roket | ARENA_SHIELD |
| STAT_CHICKENS ★ | Patlatılan tavuk | CHICKEN_100 |
| STAT_SKILLS_USED | Q kullanımı | SKILL_500 |
| STAT_SPECTATE_SEC | İzleyicide geçen saniye | SPECTATOR |
| STAT_CHARS_LO / STAT_CHARS_HI | 26+26 bitlik karakter maskesi (int32'ye sığar) | |
| STAT_CHARS_PLAYED | Maskedeki bit sayısı, ilerleme çubuğu için | ALL_CHARS |
| STAT_ROCKETS_FIRED ★ | Atılan roket (eğlence, global) | |

İlerlemeli başarımlarda Steamworks'te **Progress Stat** alanını ilgili istatistiğe bağla (ör. ACH_TD_KILLS_2500 → STAT_TD_KILLS, 0–2500). Böylece Steam istemcisi ilerleme çubuğunu kendisi gösterir.

## GodotSteam 4.24 ile bağlama

### Doğrulanan API adları
`addons/godotsteam/linux64/libgodotsteam...so` içindeki sembollere `strings` ile bakıldı:

| Var | Yok |
|---|---|
| `setAchievement`, `getAchievement`, `clearAchievement`, `storeStats`, `setStatInt`, `getStatInt`, `setStatFloat`, `getStatFloat`, `indicateAchievementProgress`, `getAchievementAndUnlockTime`, `getAchievementProgressLimitsInt`, `resetAllStats`, `requestUserStats`, `requestGlobalAchievementPercentages`, `getAchievementAchievedPercent`, `requestGlobalStats`, `getGlobalStatInt`, `getNumAchievements`, `getAchievementName`, `getAchievementDisplayAttribute`, `setRichPresence`, `getCurrentGameLanguage`; sinyaller `user_stats_received`, `user_stats_stored`, `user_achievement_stored`, `global_achievement_percentages_ready` | `requestCurrentStats` ve `current_stats_received` (Steamworks SDK 1.61'de kaldırıldı: istatistikler Steam başlatılırken kendiliğinden yüklenir), `setGlobalStatInt` |

`Net._ready` içindeki `Steam.steamInitEx(APP_ID, true)` çağrısının ikinci argümanı callback'leri otomatik çalıştırır. Ayrıca `run_callbacks` çağırmaya gerek yok. Dönüş tipleri (`getAchievement` → `{ret, achieved}`) GodotSteam belgelerinden alındı. İlk testte `print` ile doğrula.

### Nereye yazılır
`profile.gd` zaten `achieve(id)` ve `stat_add(key, n)` iskeletlerini içeriyor ("Steam başarımları gerçek App ID gelince achieve() içinden bağlanır"). Steam çağrıları yalnızca orada olsun. Oyun kodu yalnızca `Profile.achieve("ACH_...")` ve `Profile.stat_add("STAT_...")` çağırsın.

```gdscript
static func achieve(id: String) -> void:
	# (yerel profil kaydı burada: Steam yokken de "başarımlar" ekranı çalışsın)
	if not Net.steam_ok:
		return
	var a: Dictionary = Steam.getAchievement(id)
	if a.get("ret", false) and not a.get("achieved", false):
		Steam.setAchievement(id)
		Steam.storeStats() # bildirim hemen görünsün


static func stat_add(key: String, n := 1) -> void:
	if not Net.steam_ok or n == 0:
		return
	Steam.setStatInt(key, Steam.getStatInt(key) + n)
	# storeStats burada çağrılmaz: add_run() maç sonunda bir kez çağırır (Valve sık çağrıyı kısıtlar)


## Eşikli başarım: stat_add'ten sonra çağır. Ara bildirim yalnız %25'lik adımlarda çıkar.
static func check(key: String, ach: String, goal: int, added: int) -> void:
	if not Net.steam_ok:
		return
	var v: int = Steam.getStatInt(key)
	if v >= goal:
		achieve(ach)
	elif v * 4 / goal > (v - added) * 4 / goal:
		Steam.indicateAchievementProgress(ach, v, goal)
```

Kurallar:
- **Ağ:** Steam API her zaman yerel kullanıcı adına çalışır. Her makine yalnızca kendi oyuncusunun başarımını açar. Host'ta hesaplanan olaylar zaten herkese yayılıyor (`_state`, `_hit`, `summary_ready`). Arena öldürmeleri için kanca 1'deki `rpc_id` gerekir.
- **storeStats** şu anlarda çağrılır: başarım açılınca, maç sonunda (`Profile.add_run`) ve oyundan çıkarken (`NOTIFICATION_WM_CLOSE_REQUEST`). Kare başına çağırma.
- **Hile/test:** Başarımlar istemci tarafında açılır. Yerel ENet testinde (`host_local`) `Net.steam_ok` true kalabilir. Gerekirse `achieve` başına `if multiplayer.multiplayer_peer is ENetMultiplayerPeer: return` ekle.
- **480 ile test:** Spacewar'ın başarımları farklı adlarla tanımlı (`ACH_WIN_ONE_GAME` vb.). Bizim adlarla `getAchievement` `ret=false` döner. Bağlantıyı denemek için geçici olarak `Steam.setAchievement("ACH_WIN_ONE_GAME")` çağır, sonra `Steam.resetAllStats(true)` ile sıfırla. Asıl test gerçek App ID ile yapılır.

### Steamworks kurulum sırası
1. App Admin → Stats & Achievements → önce **Stats**, sonra **Achievements** (API adı, görünen ad ve açıklama, TR+EN; "Hidden" yalnızca ACH_CHICKEN_100 için).
2. Her başarıma 2 ikon: **256×256 JPG**, açık ve kapalı (gri). Kapalı ikonu elle tasarla, otomatik grileştirme sönük durur.
3. **Publish** (yayınlanmayan tanımı istemci görmez).
4. Geliştirici hesabıyla dene, sonra `Steam.resetAllStats(true)`. Bu çağrı yalnızca bir debug menüsünden yapılmalı.

## Kaynaklar
- API adları: yerel `addons/godotsteam` 4.24 ikili dosyası (`strings`). Belgeler: [godotsteam.com](https://godotsteam.com)
- `profile.gd` iskeleti ve `td.summary_ready` sözleşmesi: bu daldaki `a9bd3d7` commit'i
