# Steam mağaza sayfası

Oyunun bugünkü hâline göre yazıldı (sürüm 1.5: Arena + Tower Defense, 52 karakter, 10 silah). Oyunda olmayan bir özelliği (açık eşleştirme, kontrolcü, sesli sohbet) sayfaya yazma. Eklenince bu belgeyi güncelle.

## 1. Oyun adı

**Sorun:** "Bazuka Savaşı" Türkçe yazımla aranır. İngilizce oyuncu "bazooka" yazar, "bazuka" yazmaz. Ad Türkçe kalırsa Steam aramasında, YouTube'da ve TikTok'ta bulunmaz. `project.godot` içindeki `config/name="KartopuTest"` de değişmeli.

| Aday | Artı | Eksi |
|---|---|---|
| **Bazooka Buddies** (önerilen) | Co-op ve "arkadaşlarla" hissini verir, bu da 2025'in en çok satan co-op trendine ("friendslop") oturur. Aliterasyonlu, akılda kalır. Aramada başka bir oyun adıyla çakışma bulamadım | Arena'nın PvP yanını adı söylemez, ama "arkadaş mı düşman mı" esprisi bunu çözer |
| Bazooka Brawl | Kaos ve PvP'yi anlatır, aranır | Tower Defense ve co-op yanını hiç göstermez |
| Bazooka Bros | Kısa | "Bros" Mario çağrışımı yapar, kadın karakterler de var |
| Rapunzel Must Not Fall | Tower Defense'i anlatır, merak uyandırır | Arena'yı dışarıda bırakır, ad uzun |

**Öneri:** İngilizce ad **Bazooka Buddies**, alt başlıksız. Türkçe sayfada yerelleştirilmiş ad **Bazuka Savaşı** olabilir (Steamworks'te dil başına ad girme seçeneğini doğrula). Logoya slogan koy: "Friends. Bazookas. What could go wrong?" / "Arkadaşlık bazukayla sınanır."

Adı seçmeden önce:
- Steam'de, itch.io'da, mobil mağazalarda tam adı ara. "Team Buddies" adında eski bir PS1 oyunu var, ama ad farklı.
- Marka sorgusu yap: TÜRKPATENT, EUIPO, USPTO (sınıf 9 ve 41).
- `.com` alan adını ve TikTok, X, YouTube kullanıcı adlarını aynı gün al.

**SEO:** Steam aramada adı ve etiketleri kullanır. "Bazooka" kelimesi adda olsun. Kısa açıklamada "co-op", "tower defense", "4 players" geçsin. YouTube ve TikTok başlıklarında da aynı İngilizce adı kullan.

## 2. Kısa açıklama (≤300 karakter)

**EN (260 karakter):**
> Grab a bazooka, pick one of 52 ridiculous heroes and squad up with up to 3 friends. Defend Rapunzel's tower from 10 monster waves with roguelite cards, 10 weapons, traps and turrets, or turn on each other in chaotic arena PvP. The chickens are not safe either.

**TR (233 karakter):**
> Bazukanı kap, 52 komik karakterden birini seç, 3 arkadaşınla takım ol. Rapunzel'in kulesini roguelite kartlar, 10 silah, tuzak ve taretlerle 10 yaratık dalgasına karşı savun ya da arenada birbirinize girin. Tavuklar da güvende değil.

Steam Page Analyzer'ın verisine göre medyan kısa açıklama yaklaşık 230 karakter. Daha uzun açıklama daha iyi sonuç vermiyor, yani 200–260 karakter hedefi doğru.

## 3. Uzun açıklama ("Bu oyun hakkında"), Steam BBCode olarak yapıştırılabilir

En üste 3–5 sn'lik sessiz bir GIF ya da WebM koy (Steam editörü ikisini de kabul eder). Her başlığın altına bir GIF yerleştir. Ziyaretçi metni değil görüntüyü okur.

### EN
```
[img]{STEAM_APP_IMAGE}/extras/hook.gif[/img]
[h2]Friends. Bazookas. What could go wrong?[/h2]
Bazooka Buddies is a low-poly first-person party shooter for 1–4 players. Team up to save Rapunzel's tower, or blow each other off the map in the arena.

[h2]TOWER DEFENSE: Save Rapunzel[/h2]
[img]{STEAM_APP_IMAGE}/extras/td.gif[/img]
[list]
[*][b]10 waves, 8 monster types, 2 bosses:[/b] tower-smashers, player-hunters, exploding zombies, armored knights and a giant Black Knight.
[*][b]Roguelite level-ups:[/b] the whole team shares an XP bar. Every level, each player picks 1 of 3 cards: new weapons, weapon upgrades, stat boosts and hero-specific powers.
[*][b]10 weapons with 4 rarities:[/b] bazooka, shotgun, sniper, bow, boomerang, flamethrower, grenades and more, each with its own upgrade tree.
[*][b]Build between waves:[/b] walls, spike walls, traps, turrets and frost totems.
[*][b]Scales from solo to 4 players:[/b] waves grow with your squad.
[/list]

[h2]ARENA: Last one standing wins[/h2]
[img]{STEAM_APP_IMAGE}/extras/arena.gif[/img]
[list]
[*]Bazooka, shield, wall and sword. Double jump and air dash.
[*]Every round is a new mess of meteors, lassos, reversed controls and charging cows in business suits.
[/list]

[h2]52 heroes, 52 ridiculous abilities[/h2]
[list]
[*]A pirate whose rum barrel heals you and reverses your controls.
[*]A ninja who swaps places with the nearest enemy.
[*]A wizard calling down meteors, a pug that barks people away, a mannequin that "never moved".
[/list]

[h2]Built for friend groups[/h2]
[list]
[*]Steam lobbies and one-click friend invites.
[*]Peer-to-peer over Steam's relay network: no servers to go down.
[*]Watch your friends from third person while you wait to respawn.
[/list]
```

### TR
```
[img]{STEAM_APP_IMAGE}/extras/hook.gif[/img]
[h2]Arkadaşlık bazukayla sınanır.[/h2]
Bazuka Savaşı, 1–4 kişilik, low-poly, birinci şahıs bir parti nişancı oyunu. Ya birlikte Rapunzel'in kulesini kurtarın ya da arenada birbirinizi haritadan uçurun.

[h2]TOWER DEFENSE: Rapunzel'i kurtar[/h2]
[list]
[*][b]10 dalga, 8 yaratık türü, 2 boss:[/b] kuleye yürüyenler, oyuncu avlayanlar, patlayan zombiler, zırhlı şövalyeler ve dev Kara Şövalye.
[*][b]Roguelite seviye atlama:[/b] takım XP'yi ortak toplar. Her seviyede herkes 3 karttan birini seçer: yeni silah, silah yükseltmesi, stat ya da karaktere özel güç.
[*][b]4 nadirlikte 10 silah:[/b] bazuka, pompalı, keskin nişancı, yay, bumerang, alev püskürtücü, el bombası ve dahası. Her birinin kendi yükseltmeleri var.
[*][b]Dalga arasında inşa et:[/b] duvar, dikenli duvar, tuzak, taret, buz totemi.
[*][b]Tek kişiden 4 kişiye ölçeklenir.[/b]
[/list]

[h2]ARENA: Son ayakta kalan kazanır[/h2]
[list]
[*]Bazuka, kalkan, duvar, kılıç. Çift zıplama ve havada atılma.
[*]Meteorlar, kementler, ters çalışan tuşlar, takım elbiseli inekler.
[/list]

[h2]52 karakter, 52 saçma yetenek[/h2]
[list]
[*]Rom fıçısıyla can basan ama yön tuşlarını ters çeviren korsan.
[*]En yakın düşmanla yer değiştiren ninja.
[*]Meteor yağdıran büyücü, havlayıp herkesi savuran pug, "hiç kıpırdamayan" manken.
[/list]

[h2]Arkadaş grupları için[/h2]
[list]
[*]Steam lobisi, tek tıkla davet.
[*]Steam relay üzerinden eşler arası bağlantı: kapanacak sunucu yok.
[*]Ölünce arkadaşlarını 3. şahıstan izle.
[/list]
```

## 4. Etiketler (20, öncelik sırasıyla)

Steam, etiketleri oyunun hangi listelerde çıkacağını ve "Buna benzer" önerilerini belirlemek için kullanır. Rehberlere göre ilk 5 etiket en çok ağırlık taşır. Özel etiketler genellerin önüne gelmeli. "Indie" gibi herkesin kullandığı etiketler sona.

| # | Etiket | Neden |
|---|---|---|
| 1 | Online Co-Op | Ana satış noktası. 2025 co-op hitlerinin ortak paydası |
| 2 | Tower Defense | En belirgin alt tür. Orcs Must Die! izleyicisini getirir |
| 3 | FPS | Birinci şahıs nişancı türü |
| 4 | Party Game | Arena kaosu ve komik yetenekler. Friendslop alıcısı bu listeye bakar |
| 5 | Roguelite | Kart seçimi ve nadirlik sistemi (Megabonk benzeri) |
| 6 | Funny | Mağaza vitrininde ayrıştırıcı |
| 7 | PvP | Arena modu |
| 8 | Hero Shooter | 52 karakter, her birinin Q yeteneği |
| 9 | Arena Shooter | Arena modu |
| 10 | Co-op | Geniş co-op listesi |
| 11 | Multiplayer | Genel |
| 12 | Action Roguelike | Kart ve run yapısı |
| 13 | Low Poly | Görsel stil, aranır |
| 14 | Colorful | Görsel stil |
| 15 | Comedy | Ton |
| 16 | First-Person | Genel kamera |
| 17 | Shooter | Genel |
| 18 | Casual | Düşük öğrenme eğrisi |
| 19 | Team-Based | Co-op TD |
| 20 | Indie | Bilgi değeri düşük, en sonda |

Çıkışta etiketleri gözden geçir: oyuncular da etiket ekler. Benzer oyunların (Orcs Must Die! Deathtrap, R.E.P.O., Peak) etiketlerini SteamDB'den karşılaştır.

## 5. Türler (Steam "Genre" alanı)

Action (birincil), Casual, Indie, Strategy. "Free to Play" ve "Early Access" yalnızca o modelle çıkılırsa işaretlenir.

## 6. Yaş derecelendirmesi

- Steamworks'teki **İçerik Anketi**'ni doldur. Doldurmazsan oyun Almanya'da görünmez: 15 Kasım 2024'ten beri Steam, yaş derecesi olmayan oyunları Almanya'da göstermiyor. Anketten Valve'in ücretsiz IARC/USK derecesi çıkar, ayrıca USK başvurusu gerekmez.
- İşaretlenecek içerikler:
  - Karikatür/fantastik şiddet (patlamalar, kılıç, zombiler; kan yok).
  - **Alkol atfı:** Tayfa'nın "ROM FIÇISI" yeteneği, "kafası güzel olur" repliği ve "Yo ho ho... hık!".
  - Kullanıcı etkileşimi: Steam adları oyunda görünüyor, çevrim içi oyun var.
  - Kumar ya da gerçek parayla rastgele ödül yok. Kartlardaki nadirlik oyun içi, satın alma yok.
- Tahmin: PEGI 7–12, ESRB E10+–T arası. Alkol atfı dereceyi yükseltebilir. Daha geniş kitle istersen repliği "Yo ho ho... hık!" yerine meyve suyu esprisine çevirmeyi düşün. Kesin sonucu anket verir.
- Telif: "Rapunzel" Grimm masalıdır ve kamu malıdır. Disney'in "Tangled"ına benzeyen görsellerden (mor elbise, sarı örgü, fener) kaçın. Quaternius modelleri CC0, ticari kullanım serbest.

## 7. Sistem gereksinimleri (taslak, ölç sonra yaz)

Godot 4.7, Forward+ renderer (Vulkan ya da D3D12 gerekir). Aynı anda en çok 40 yaratık var (`Balance.MAX_ALIVE`). Değerleri düşük ve orta donanımda ölçmeden yayınlama. "Düşük" kalite ayarında 1080p 60 FPS hedefle.

| | Minimum | Önerilen |
|---|---|---|
| İşletim sistemi | Windows 10 64-bit | Windows 10/11 64-bit |
| İşlemci | 4 çekirdek, 2,5 GHz (i5-4460 / Ryzen 3 1200) | i5-8400 / Ryzen 5 2600 |
| Bellek | 4 GB RAM | 8 GB RAM |
| Ekran kartı | Vulkan 1.1 destekli, 2 GB (GTX 750 Ti / RX 460 / Intel UHD 620 düşük ayar) | GTX 1060 / RX 580 |
| Ağ | Geniş bant internet (çevrim içi oyun) | |
| Depolama | 500 MB | 500 MB |
| Not | Steam hesabı gerekli | |

Steam sürümünde yapılması gerekenler:
- `updater.gd` ile GitHub'dan kendini güncelleme kapatılmalı. Güncellemeler Steam deposundan gelir.
- `steam_appid.txt` dosyası pakete konmaz. 480 yerine gerçek App ID kullanılır.
- Linux derlemesi de çıkarsa Steam Deck testi kolaylaşır. Kontrolcü desteği eklenmeden Deck'te "Unsupported" görünür.

## Kaynaklar
- Kısa açıklama uzunluğu ve medyanı: [Steam Page Analyzer: short description guide](https://www.steampageanalyzer.com/blog/steam-short-description-guide), [Steamworks: description](https://partner.steamgames.com/doc/store/page/description)
- Etiketler: [Steamworks: Tags](https://partner.steamgames.com/doc/store/tags), [How To Market A Game: tagging](https://howtomarketagame.com/2020/11/12/steam-101-how-to-tag-your-game/), [presskit.gg tags strategy](https://presskit.gg/field-guides/steam-tags-strategy)
- Friendslop trendi: [AppMagic: Friendslop 2025](https://appmagic.rocks/blog/friendslop-steam-games-2025), [Alinea: co-op $4B H1'25](https://gamedevreports.substack.com/p/alinea-analytics-co-op-games-generated)
- Almanya yaş derecesi: [Steamworks: Germany content survey](https://partner.steamgames.com/doc/gettingstarted/contentsurvey/germany), [MP1st](https://mp1st.com/news/all-steam-games-must-have-a-rating-to-be-sold-in-germany-by-november)
- Ad çakışması araması: [BAZOOKA: Rhythm Game (Steam)](https://gamegeeker.com/games/bazooka-rhythm-game), [Team Buddies](https://www.mobygames.com/game/10984/team-buddies/)
