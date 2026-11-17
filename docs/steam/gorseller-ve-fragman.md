# Görseller ve fragman

Oyuncu çoğu zaman bizi önce bir kapsül görselinde görür (arama, Keşif Kuyruğu, Next Fest listesi). Görsel tek bakışta "4 arkadaş, bazuka, kule, kaos" demeli. Ekran görüntüleri ve fragman **İngilizce arayüzle** çekilmeli. Şu anki `/tmp/vk_after/*.png` görüntüleri Türkçe, yalnızca referans olarak kullan.

## 1. Boyutlar

Valve 2025'te kapsül boyutlarını büyüttü ve eski boyutları artık kabul etmiyor. Aşağıdaki değerler güncel rehberlerden ve Steamworks sayfa özetlerinden. Yüklemeden önce Steamworks → Store Graphical Assets sayfasında bir kez daha kontrol et (bu oturumdan partner.steamgames.com'a doğrudan erişilemedi).

| Görsel | Boyut (px) | İçerik kuralı | Nerede görünür |
|---|---|---|---|
| **Header Capsule** | 920 × 430 | Sanat + logo | Mağaza sayfasının üstü, "Önerilenler", paketler |
| **Small Capsule** | 462 × 174 | Logo baskın | Arama sonuçları, listeler. **En çok görülen** görsel |
| **Main Capsule** | 1232 × 706 | Sanat + logo | Ana sayfa vitrini (öne çıkarılırsa) |
| **Vertical Capsule** | 748 × 896 | Sanat + logo | Mevsimlik indirim sayfaları, bazı vitrinler |
| Page Background | 1438 × 810 | Yalnızca sanat, düşük kontrast | Mağaza sayfası arka planı (isteğe bağlı) |
| **Ekran görüntüleri** | 1920 × 1080 (16:9), **en az 5** | Gerçek oyun görüntüsü | Sayfa galerisi. İlk 4'ü fare üzerine gelince önizlemede çıkar |
| **Library Capsule** | 600 × 900 | Sanat + logo | Kütüphane ızgarası |
| **Library Header** | 920 × 430 | Sanat + logo | Kütüphane listeleri |
| **Library Hero** | 3840 × 1240 PNG | **Yalnızca sanat, logo ve yazı yok** | Oyun sayfasının üst bandı. Ortadaki ~860 × 380'lik alan kırpılmaz |
| **Library Logo** | 1280 genişlik ve/veya 720 yükseklik, **şeffaf PNG** | Yalnızca logo | Hero'nun üstüne bindirilir |
| Etkinlik kapağı / başlığı | 800 × 450 / 1920 × 622 | Sanat + başlık | Haber ve etkinlik gönderileri (Next Fest yayını) |
| Topluluk ikonu | 184 × 184 JPG | Logo/karakter | Topluluk merkezi |
| Başarım ikonları | 256 × 256 JPG ×2 (açık / kapalı) | | Bkz. `basarimlar.md` |

**Kapsül kuralı (Valve):** Kapsüllerde yalnızca oyun sanatı, oyun logosu ve resmî alt başlık olabilir. "İndirim", "Yeni", ödül, inceleme puanı ya da alıntı yazısı **yasak**. Sayfa reddedilir.

## 2. Ana kompozisyon (key art)

Bütün kapsüller bu tek sahneden kırpılarak üretilir. Sahneyi oyunun **gerçek modelleriyle** (Quaternius, `models/chars/`) Godot ya da Blender'da kur, render al, üstünden boyayarak cilala. Oyundan farklı görünen kapsül, iade ve olumsuz inceleme getirir.

- **Merkez:** Rapunzel'in kulesi. Tepeden aşağı sallanan, rüzgârda dalgalanan altın saç (oyundaki gibi yüz görünmez, merak unsuru). Tower Defense'in tek bakışta okunan simgesi bu.
- **Ön plan, 4 karakter "takım" pozunda:** Ulu Büyücü (asa, meteor), **Pug** (kravat, sevimli yüz), **Boğa** (takım elbiseli inek, en çok güldüren siluet), Valkür ya da Kızıl Sakal (aksiyon). Biri bazukayı kameraya doğrultmuş, roketin duman izi kadrajı çaprazlıyor.
- **Mizah ayrıntısı:** Patlamada havaya uçan bir tavuk ve tüyleri. Karakterlerden biri yanlışlıkla arkadaşını vuruyor (Arena'ya gönderme).
- **Arka plan:** Ormandan çıkan Hortlaklar ve dev Goblin silueti. Kızıl doğma halkaları.
- **Renk:** Logo, menüdeki sıcak turuncu (`Color(1.0, 0.62, 0.18)`). Gökyüzü ve TD vurguları camgöbeği/mavi (mod kartındaki TD mavisi). Turuncu–mavi tamamlayıcı kontrast, küçük boyda bile okunur.
- **Logo:** Kalın, hafif eğik, siyah dış çizgili. "BAZOOKA" büyük, ikinci kelime küçük. Logonun "O" harfinde roket ucu ya da duman halkası olabilir. Logo kapsülün en az %40'ını kaplasın.

### Görsele göre kırpma briefleri
| Görsel | Bileşim |
|---|---|
| Header 920×430 | Solda logo (genişliğin ~%50'si), sağda kule ve 3 karakter. Roket izi logoya doğru akar |
| Small 462×174 | **Neredeyse yalnızca logo** ve sağda tek karakterin kafası (Pug ya da Boğa) ile bazuka ucu. %50 küçültüp okunurluğunu test et. Ayrıntı burada kaybolur |
| Main 1232×706 | Tam sahne: kule ortada, 4 karakter önde, logo üst-sol üçte birde |
| Vertical 748×896 | Dikey kompozisyonu en iyi taşıyan görsel bu: kule tepeden aşağı, saç dikey çizgi olarak karakterlere iner. Logo altta |
| Library Capsule 600×900 | Vertical'ın aynısı, logo üstte (kütüphanede alttan yazı bindirilebilir) |
| Library Hero 3840×1240 | Geniş orman panoraması. Sağda kule, solda arena duvarı. Ortadaki güvenli alan boş (logo oraya biner). Karakter yok ya da çok küçük |
| Library Logo | Logonun şeffaf PNG'si, başka bir şey yok |
| Page Background | Orman dokusu, %30 opaklık, koyu ton |

## 3. Ekran görüntüleri (sırasıyla, 10 adet)

İlk 4'ü önizlemede görünür, en güçlüler başa. Hepsi 1920×1080, en yüksek kalite ayarında. Ekranda "Steam bağlı değil" yazısı ya da test adları ("Oyuncu #1") olmamalı: eğlenceli Steam adları kullan. HUD açık olsun ama sade.

1. **TD aksiyon:** 4 oyuncu kulenin önünde Dev Goblin'e ateş ediyor, patlamalar, kule can barı yarıda.
2. **Arena kaosu:** meteor düşüyor, kafalarda replikler ("What's falling from the sky?"), birinin yanında yanık efekti (bkz. `meteor.png`).
3. **Seviye kartları:** 3 kart, biri EFSANEVİ (turuncu), biri DESTANSI (mor). Arka planda dalga sürüyor (bkz. `td_cards.png`).
4. **52 karakter seçim ekranı:** portre ızgarası ve 3D önizleme (bkz. `chars.png`).
5. **Dalga 10 boss'u:** Kara Şövalye kuleye kılıç indiriyor, kule %10 canda, ekran kırmızımsı.
6. **İnşa molası:** kulenin çevresinde duvar, dikenli duvar, 2 taret, buz totemi. Mağaza paneli açık.
7. **Silah çeşitliliği:** alev püskürtücü bir grubu yakıyor ya da keskin nişancı 3 yaratığı deliyor (birinci şahıs).
8. **Komik an:** Pug havlıyor, 3 oyuncu havada.
9. **Zafer ekranı:** "VICTORY", 4 kişilik istatistik ve MVP (özet ekranı gelince).
10. **Menü atmosferi:** karakterler ormanda dizili, logo büyük (bkz. `menu_main.png`).

## 4. Fragman (75 sn)

Steam fragmanları sayfada **sessiz** başlar. Hikâye ses olmadan, ekrandaki büyük yazılarla anlaşılmalı. Müzik ritmik ve komik olsun (rock/orkestral). Kesimler vuruşlara otursun. Müzik ya sana ait ya da yayın için lisanslı olmalı: yayıncıların videolarına telif gelmesin.

**İlk 5 saniye kancası:** Birinci şahıs, bazuka ateşlenir. Roket üç arkadaşın ortasına düşer, hepsi havaya uçar, bir tavuk tüy bulutuna dönüşür. Sert kesme ile siyah ekranda **"FRIENDS."** yazısı. Ardından Serap Ninja yer değiştirir ve arkadaşını meteorun altına bırakır: **"...FOR NOW."** Logo yok, açıklama yok, yalnızca "bu ne?" anı.

| Zaman | Görüntü | Ekran yazısı |
|---|---|---|
| 0:00–0:02 | Birinci şahıs bazuka atışı, 3 oyuncu havaya, tavuk patlar | |
| 0:02–0:05 | Siyah ekranda yazı, Serap Ninja yer değiştirir, meteor arkadaşa düşer | FRIENDS. → ...FOR NOW. |
| 0:05–0:07 | Logo (1 sn) | 1–4 PLAYER CO-OP |
| 0:07–0:13 | Kuleye yükselen yavaş kamera, sallanan saç. Ormanda kızıl halkalar, sürü çıkar | PROTECT RAPUNZEL'S TOWER |
| 0:13–0:23 | 4 kişi savunuyor. 1–1,5 sn'lik kesmeler: pompalı, alev, yay delip geçer, bumerang seker, el bombası | 10 WEAPONS |
| 0:23–0:29 | Seviye atlama: kartlar açılır, EFSANEVİ parlar, seçilir. Silah gözle görülür değişir (Çift Namlu) | LEVEL UP. PICK A CARD. |
| 0:29–0:35 | Mola: duvar dikilir, taret ateş eder, buz totemi sürüyü yavaşlatır, Hortlak dikenli duvarda takılır | BUILD. TRAP. TURRET. |
| 0:35–0:48 | Yetenek montajı, 8 × 1,5 sn: meteor, Pug havlaması, Boğa toslaması, Valkür sıçrayışı, Anestezist narkozu (herkes ters koşar), Tayfa'nın rom fıçısı, Mühendis betonu, Kızıl Sakal öfkesi | 52 HEROES. 52 TERRIBLE IDEAS. |
| 0:48–0:57 | Arena: duvarlar çıkar, kalkan roketi emer, kılıç, çift zıplama + atılma. Biri ölünce izleyici kamerası | OR TURN ON EACH OTHER. |
| 0:57–1:07 | Doruk: Dalga 10, dev Kara Şövalye kuleye vurur, kule barı kırmızı yanıp söner, 4 kişi son roketleri atar, boss devrilir, VICTORY | WAVE 10 |
| 1:07–1:09 | Espri: bir tavuk boss'un üstünden yürüyüp geçer | |
| 1:09–1:15 | Logo, çıkış penceresi, "Wishlist on Steam", Discord adresi | WISHLIST NOW |

Ek kesimler:
- **30 sn:** 0:00–0:07 + 0:13–0:23 + 0:35–0:48 + logo. Next Fest ve reklam için.
- **15 sn dikey (9:16):** kanca + 3 en komik yetenek + logo. TikTok/Shorts için.
- **GIF'ler** (uzun açıklamaya): kanca (3 sn), TD savunması (4 sn), arena (4 sn). 616 px genişlik, mümkün olduğunca küçük dosya. Steam'in GIF boyut sınırını yüklerken kontrol et.

## 5. Çekim için oyunda gerekenler

Bunlar küçük, hata ayıklama amaçlı eklemeler. Oyun kodunu başka ajanlar düzenliyor, sırayla iste:
- **HUD gizleme tuşu** (yalnızca debug derlemede).
- **Serbest kamera / fotoğraf modu:** izleyici kamerasının serbest uçan sürümü. Kule yükselişi ve drone çekimleri için.
- **Godot Movie Maker:** `godot --path . --write-movie cekim.avi --fixed-fps 60` ile kare atlamasız kayıt. Ağlı çekimde her oyuncu OBS ile 60 FPS kaydetsin, en iyi açı seçilsin.
- Çekimde 4 gerçek oyuncu kullan. Botla çekilen co-op fragmanı yapay durur.
- Fragman 1920×1080, 60 FPS, MP4 (H.264), yüksek bit hızı.

## Kaynaklar
- Boyutlar: [Steamworks: Store Graphical Assets](https://partner.steamgames.com/doc/store/assets), [Steamworks: Library Assets](https://partner.steamgames.com/doc/store/assets/libraryassets), [Steamworks: Asset rules](https://partner.steamgames.com/doc/store/assets/rules), [presskit.gg capsule guide](https://presskit.gg/field-guides/steam-capsule-art-guide), [Steam Page Analyzer: asset requirements](https://www.steampageanalyzer.com/blog/steam-page-asset-requirements), [virtuall.pro: 2026 asset guide](https://virtuall.pro/blog/steam-banner-sizes-capsule-and-asset-guide)
- Klip ve kanca mantığı: [AppMagic: Friendslop 2025](https://appmagic.rocks/blog/friendslop-steam-games-2025), [Spawn Point: content creators](https://spawnpointmarketing.substack.com/p/why-content-creators-beat-storefront)
