# Bazuka Savaşı (KartopuTest)

Godot 4 ile yapılmış, Steam üzerinden 2–4 kişilik, 1. şahıs bazuka savaşı. 52 animasyonlu karakter, her birinin kendine has yeteneği.

## Sadece oynamak için (Windows)

1. [Releases](https://github.com/Obuto45/KartopuTest/releases/latest) sayfasından son zip'i indir.
2. Zip'i bir klasöre aç. Tüm dosyalar aynı klasörde kalmalı.
3. Steam'i aç ve giriş yap.
4. `KartopuTest.exe`'yi çalıştır. Windows uyarı verirse **Ek bilgi → Yine de çalıştır**.
5. Bir kişi **Steam Lobisi Kur**, diğerlerini **Arkadaşlar → Davet et** ile çağırır. Herkes aynı sürümü kullanmalı.

Steam'de "Spacewar oynuyor" görünmen normal (test App ID'si 480).

## Gereksinimler (geliştirme)

- **Godot 4.7.2** (standart ya da .NET/mono sürümü; kod tamamen GDScript)
- **Steam** açık ve giriş yapılmış olmalı
- GodotSteam 4.24 GDExtension `addons/godotsteam` içinde hazır gelir, ayrıca kurulum gerekmez

## Çalıştırma

1. Godot'da `project.godot` dosyasını aç.
2. F5 ile çalıştır.
3. Arkadaşınla oynamak için: biri **Steam Lobisi Kur**, sonra **Arkadaşlar → Davet et**. Diğeri gelen daveti menüde **Daveti Kabul Et** ile ya da **Arkadaşlar → ▶ Lobisine katıl** ile kabul eder. Host **Oyunu Başlat**'a basar.
4. Tek PC'de test: iki pencere aç, birinde **Yerel Host**, diğerinde **Yerel Katıl**.

Steam App ID olarak test ID'si `480` (Spacewar) kullanılıyor. Steam'de "Spacewar oynuyor" görünmen normal.

## Kontroller

| Tuş | İşlev |
|---|---|
| WASD | Yürü |
| Boşluk | Zıpla, havada tekrar basınca çift zıplama |
| Shift + WASD | Dash (havada da çalışır) |
| 1 | Bazuka (roket atar, 0,8 sn'de bir) |
| 2 | Kalkan (tek saldırıyı ya da tek etkiyi emer) |
| 3 | Duvar (önüne 3 m'lik duvar, 8 sn durur, 6 sn bekleme) |
| 4 | Kılıç (yakın dövüş, 2,3 m, önündekine 20 hasar) |
| Q | Karakterin özel yeteneği |
| Sol tık | Seçili eşyayı kullan |
| ESC | Ayarlar (ses, ekran modu, çözünürlük) / oyuna dön |
| F10 | Lobiden çık |

Can çoğu karakterde 100. Roket ve kılıç 20 hasar verir. Üzerindeki etkiler (yavaşladın, yanıyorsun, kör oldun...) ekranın altında süresiyle yazar. İsimlerin altında can barı görünür. Ölen oyuncu yaşayanları 3. şahıs kameradan izler; sol tık / sağ tık izlenen oyuncuyu değiştirir. Tek kişi kalınca kazanan yazılır, 3 sn sonra yeni tur başlar. Her oyuncunun kafasının üstünde Steam adı görünür.

## Karakterler

Menüdeki **Karakter: … – değiştir** butonundan seçilir: portre ızgarasından birine tıkla, sağda 3D önizlemesini ve ayrıntılarını gör, **SEÇ**'e bas. Lobideki herkes seçimini görür.

Modeller: [Quaternius – Ultimate Animated Character Pack](https://quaternius.com/packs/ultimatedanimatedcharacter.html), bazuka ve kılıç: Quaternius (hepsi CC0).

| # | Karakter | Can | Pasif | Q yeteneği |
|---|---|---|---|---|
| 1 | **Keloğlan** (Şanslı Kel) | 100 | %15 şansla hasardan sıyrılır | **KAFA PARLATMA** (12 sn): 8 m içinde sana bakanların ekranı 1,5 sn bembeyaz olur. |
| 2 | **Terlikli Anne** (Ev Hanımı) | 100 | roketleri %25 hızlı | **GÜDÜMLÜ TERLİK** (8 sn): Terlik en yakın düşmanı kovalar: 30 hasar. Kaçmak mümkün... belki. |
| 3 | **Pazarcı Abi** (Semt Pazarı) | 110 | 110 can | **GEL ABLA GEL** (10 sn): 8 m içindekileri kendine çeker (10 hasar), 4 sn boyunca roketlerin 30 hasar verir. |
| 4 | **Kahvehane Dayısı** (Okey Ustası) | 100 | 2 sn durunca kendiliğinden kalkan alır | **TAŞ AT!** (9 sn): Okey taşı en yakın düşmana gider, 3 kişiye kadar seker: her birine 20 hasar. |
| 5 | **Gün Kadını Nermin** (Altın Günü) | 100 | saniyede 1.0 can yeniler | **KISIR MOLASI** (16 sn): 4 sn boyunca saniyede 12 can yeniler. |
| 6 | **Fenomen Selin** (Influencer) | 100 | +5% hız | **SELFİ FLAŞI** (12 sn): Nişan aldığın yerde flaş patlar: 4 m içindekiler 2 sn kör olur (25 m menzil). |
| 7 | **Motokurye Emre** (Paket Servis) | 90 | 90 can • +12% hız | **SON SÜRAT** (11 sn): 4 sn boyunca %80 daha hızlı koşar. |
| 8 | **Dedikoducu Komşu** (Karşı Daire) | 105 | 105 can | **DUYDUN MU?** (13 sn): 10 m içindekiler lafa dalar: 3 sn silah ve yetenek kullanamaz. |
| 9 | **Halı Saha Kaptanı** (Mahalle Ligi) | 100 | %15 yüksek zıplar | **ŞUT** (7 sn): Falsolu top en yakın düşmana gider: 25 hasar ve sert savurma. |
| 10 | **Vitrin Mankeni** (Cansız Manken) | 100 | Dengeli: zaafı da yok, üstünlüğü de. | **KIPIRDAMA** (14 sn): 5 sn boyunca görünmez olur. |
| 11 | **Komiser Ayşe** (Asayiş) | 100 | kalkan 6 sn'de dolar | **DÜDÜK** (13 sn): 9 m içindeki herkes 1,2 sn olduğu yerde kalır. |
| 12 | **Bekçi Murtaza** (Gece Bekçisi) | 100 | kılıç hasarı 30 | **COP DARBESİ** (8 sn): Önündeki 3,5 m'lik yaya cop iner: 35 hasar, uçurur. |
| 13 | **Mantıcı Teyze** (Kayseri Usulü) | 100 | %11 seri ateş | **MANTI YAĞMURU** (9 sn): Yelpaze şeklinde 5 roket birden atar. |
| 14 | **Kebapçı Usta** (Acılı Adana) | 110 | 110 can | **ACI SOS** (10 sn): Önündeki 6 m'lik yayı acıya boğar: 4 sn boyunca saniyede 8 hasar. |
| 15 | **Dönerci Baba** (Yaprak Döner) | 100 | kılıç hasarı 28 | **DÖNER DÖNÜŞÜ** (8 sn): Kendi etrafında döner: 3,5 m içindeki herkese 30 hasar. |
| 16 | **Şantiye Şefi Zehra** (Baret Şart) | 110 | 110 can | **TAZE BETON** (12 sn): Nişan aldığın yere 6 sn'lik beton döker: içindekiler %65 yavaşlar. |
| 17 | **İnşaat Ustası** (Yarın Biter) | 115 | 115 can • -4% hız • duvar 4 sn'de dolar | **DUVAR ÖR** (14 sn): Önüne ve iki yanına aynı anda 3 duvar çıkarır. |
| 18 | **Plaza Müdiresi** (Kurumsal) | 100 | kalkan 6 sn'de dolar | **PERFORMANS NOTU** (12 sn): Nişan aldığın yerdekileri işaretler: 5 sn boyunca %50 fazla hasar alırlar. |
| 19 | **Emlakçı Cengiz** (Komisyoncu) | 105 | 105 can | **TORPİL** (20 sn): Kalkan, duvar, atılma ve roket bekleme sürelerini anında sıfırlar, 10 can verir. |
| 20 | **Başhekim Hanım** (Dahiliye) | 95 | 95 can • saniyede 1.5 can yeniler | **SERUM** (18 sn): Anında 45 can yeniler. |
| 21 | **Asistan Doktor** (36 Saat Nöbet) | 100 | +6% hız | **ACİL MÜDAHALE** (16 sn): Eksik canının yarısını yeniler ve 3 sn %30 hızlanır. Can azken daha değerli. |
| 22 | **Operatör Doktor** (Anestezi) | 100 | kalkan 7 sn'de dolar | **NARKOZ** (13 sn): Nişan aldığın yerdekilerin 3 sn boyunca yön tuşları ters çalışır. |
| 23 | **Stajyer Doktor** (İlk Günü) | 100 | %10 şansla hasardan sıyrılır | **YANLIŞ İĞNE** (9 sn): Uzaktan iğne vurur: 4 sn saniyede 6 hasar ve 3 sn %50 yavaşlık. |
| 24 | **Topçu Teğmen** (Koordinat Ver) | 100 | %11 seri ateş | **HAVA DESTEĞİ** (14 sn): Nişan aldığın bölgeyi 3 sn döver: yarım saniyede bir 8 hasar. |
| 25 | **Acemi Er Mehmet** (Usta Birliği) | 110 | 110 can | **TARAMA** (12 sn): 4 sn boyunca her atışta 3 roket birden çıkar. |
| 26 | **Teksaslı Fadime** (Rodeo) | 100 | roketleri %15 hızlı | **KEMENT** (10 sn): Nişan aldığın yerdekileri kementle yanına çeker (25 m menzil, 10 hasar). |
| 27 | **Yeşilçam Kovboyu** (Dublajlı) | 100 | %18 seri ateş | **ALTIPATLAR** (12 sn): 3 sn boyunca roketleri üç kat hızlı ateşler. |
| 28 | **Şerif Tommiks** (Hızlı Silah) | 95 | 95 can • roketleri %30 hızlı | **DÜELLO** (9 sn): Nişangâhın gösterdiği yere anında isabet eden kurşun: 35 hasar, 60 m menzil. |
| 29 | **Kaptan Mavi** (Korsan Reisi) | 95 | 95 can • roket hasarı 23 | **GÜLLE** (10 sn): Dev bir gülle atar: 4,5 m'lik patlama, 40 hasar. |
| 30 | **Tayfa Rıza** (Rom Tayını) | 115 | 115 can | **ROM FIÇISI** (15 sn): 40 can yeniler ama 2,5 sn kafası güzel olur: yön tuşları ters çalışır. |
| 31 | **Valkür Helga** (Kalkan Kızı) | 115 | 115 can • %10 yüksek zıplar | **VALKÜR SIÇRAYIŞI** (11 sn): Göğe fırlar; indiği yerde 4 m içindekilere 30 hasar verip havaya savurur. |
| 32 | **Kızıl Sakal** (Berserker) | 120 | 120 can • -3% hız • kılıç hasarı 30 | **ÖFKE NÖBETİ** (14 sn): 5 sn boyunca roketleri 40 hasar verir ama kendisi %30 fazla hasar alır. |
| 33 | **Boynuzlu Kask** (Kafası Sağlam) | 135 | 135 can • -10% hız | **DEMİR KAFA** (15 sn): 2,5 sn boyunca hiçbir hasar almaz. |
| 34 | **Altın Şövalye Aylin** (Saray Muhafızı) | 115 | 115 can • -4% hız | **ALTIN KALKAN** (13 sn): Bekleme süresine bakmadan kalkan açar ve 4 sn yarı hasar alır. |
| 35 | **Altın Dev** (Zırhlı Dev) | 125 | 125 can • -7% hız | **DEVLEŞ** (16 sn): 6 sn boyunca devleşir: %40 az hasar alır ama vurması da kolaylaşır. |
| 36 | **Kara Şövalye** (Turnuva Şampiyonu) | 120 | 120 can • -5% hız • kılıç hasarı 25 | **KALKAN DARBESİ** (10 sn): Önündeki 3 m'lik yaya vurur: 15 hasar ve 1,5 sn sersemletme. |
| 37 | **Orman Elfi** (Rüzgâr Çağıran) | 90 | 90 can • havada 2 kez zıplar | **RÜZGÂR GİRDABI** (10 sn): Nişan aldığın yerdekileri göğe fırlatır (10 hasar, 28 m menzil). |
| 38 | **Cadaloz Goblin** (Ufak Tefek) | 85 | 85 can • +10% hız | **UFAL** (13 sn): 5 sn boyunca yarı boyuna iner ve %30 hızlanır: vurması çok zor. |
| 39 | **Tuzakçı Goblin** (Kapancı) | 90 | 90 can • +5% hız • %8 şansla hasardan sıyrılır | **AYI KAPANI** (9 sn): Ayağının dibine kapan kurar; ilk basan 35 hasar alır ve 1 sn kıpırdayamaz. |
| 40 | **Kazan Cadısı** (Üç Harfli Dostu) | 100 | havada 2 kez zıplar | **KARA KAZAN** (13 sn): Nişan aldığın yerde 3 sn'lik girdap açar: içine çeker, yarım saniyede 5 hasar verir. |
| 41 | **Ulu Büyücü** (Sakalı Uzun) | 90 | 90 can • roketleri %20 hızlı | **METEOR** (13 sn): Nişan aldığın yere 1 sn sonra meteor düşer: 4,5 m içinde 50 hasar. |
| 42 | **Zombi Gelin** (Damat Kaçtı) | 100 | -8% hız • saniyede 2.0 can yeniler | **SALGIN** (11 sn): 6 m içindekilere bulaştırır: 5 sn boyunca saniyede 6 hasar. |
| 43 | **Beyinsiz Zombi** (Aklı Açıkta) | 125 | 125 can • -12% hız • saniyede 1.0 can yeniler | **CAN EMME** (10 sn): 6 m içindeki herkesten 15 can emer; emdiği kadar iyileşir. |
| 44 | **Sakura Hanım** (Kiraz Çiçeği) | 100 | %20 yüksek zıplar | **SÜZÜLÜŞ** (11 sn): 4 sn boyunca tüy gibi süzülür ve %40 hızlanır. |
| 45 | **Çay Ustası** (Demli Olsun) | 100 | saniyede 1.0 can yeniler | **ÇAY SEREMONİSİ** (16 sn): 5 sn'lik çay halkası kurar: içinde durdukça saniyede 12 can yeniler, düşmanlar yavaşlar. |
| 46 | **Gölge Ninja** (Suikastçı) | 85 | 85 can • +10% hız • kılıç hasarı 28 | **ARKADAN DOLAN** (11 sn): En yakın düşmanın arkasına ışınlanır ve 25 hasarlık darbe indirir (25 m). |
| 47 | **Sis Ninja** (Duman Ustası) | 90 | 90 can • +8% hız | **SİS BOMBASI** (13 sn): 4 sn'lik sis bırakır: içindeki düşmanlar göremez, kendisi 2 sn görünmez olur. |
| 48 | **Rüzgâr Ninja** (Göz Açıp Kapayana) | 90 | 90 can • havada 2 kez zıplar | **IŞINLAN** (6 sn): Baktığı yöne 12 m ışınlanır. |
| 49 | **Kum Ninja** (Çöl Faresi) | 100 | +6% hız • %6 şansla hasardan sıyrılır | **KUM FIRTINASI** (12 sn): 9 m içindekiler 3 sn %55 yavaşlar ve kısa süre göremez. |
| 50 | **Serap Ninja** (Yanılsama) | 90 | 90 can • +8% hız | **YER DEĞİŞ** (12 sn): En yakın düşmanla anında yer değiştirir (30 m). |
| 51 | **Sarıkız Hanım** (Kurbanlık Kaçağı) | 130 | 130 can • -8% hız | **TOSLAMA** (9 sn): İleri atılır; durduğu yerde 3,5 m içindekilere 25 hasar verip savurur. |
| 52 | **Paşa Bey** (Kravatlı Pug) | 80 | 80 can • +15% hız | **HAVLAMA** (8 sn): 7 m içindeki herkesi korkutup uzağa savurur (5 hasar). |

Q basınca karakterin kafasında repliği çıkar ("Gel buraya!", "Gel abla gel, domates bunlar!").

Yeni karakter eklemek için `characters.gd` listesinin **sonuna** ekle (sıra ağda numara olarak gider). Yetenekler veriden çalışır: `sk` alanındaki anahtarlar (`self`, `area`, `homing`, `volley`...) dosyanın başında açıklanır. Tablo bu dosyadan üretildi.

## Dışa aktarma (exe)

```bash
Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Windows Desktop" build/KartopuTest.exe
```

Export şablonları kurulu olmalı. `steam_appid.txt` dosyasını exe'nin yanına kopyala.

## Yeni sürüm yayınlama (otomatik güncelleme)

Oyun açılışta GitHub'daki son Release'e bakar. Sürümü daha yeniyse zip'i indirir, kendini günceller ve yeniden başlar. Bunun çalışması için:

1. `project.godot` içinde `config/version` değerini artır (ör. `"0.3"` → `"0.4"`).
2. Exe'yi dışa aktar, `KartopuTest.exe`, iki `.dll` ve `steam_appid.txt` dosyasını `KartopuTest_vX.Y_Windows.zip` adıyla zip'le.
3. GitHub'da `vX.Y` etiketiyle Release oluştur ve zip'i ekle. Dosya adı `_Windows.zip` ile bitmeli.

```bash
gh release create v0.4 KartopuTest_v0.4_Windows.zip --title "v0.4" --notes "Değişiklikler"
```

## Kod yapısı

| Dosya | Görev |
|---|---|
| `net.gd` (autoload `Net`) | Steam başlatma, lobi kurma/katılma, davet, `SteamMultiplayerPeer` (Valve relay) ve test için ENet |
| `main.gd` | Menü, HUD, envanter çubuğu, test haritası, tur yönetimi (kararları host verir) |
| `player.gd` | Karakter, animasyon, hareket fiziği, bazuka, kalkan, hasar ve veri odaklı yetenek motoru |
| `rocket.gd` | Roket uçuşu ve çarpışma |
| `slipper.gd` | Güdümlü mermiler: terlik, seken okey taşı, futbol topu |
| `zone.gd` | Yerde duran etki alanları: meteor, beton, sis, girdap, kapan |
| `models/chars/` | 52 iskeletli, animasyonlu karakter modeli (`characters.gd` içindeki `model` alanı) |
| `models/bazooka.glb`, `models/sword.glb` | Silah modelleri |
| `icons/` | Seçim ekranındaki portreler |
| `explosion.gd` | Patlama efekti |
| `sfx.gd` (autoload `Sfx`) | Ses efektlerini koddan üretir (ses dosyası yok) |
| `settings.gd` (autoload `Settings`) | Ses ve ekran ayarları, `user://settings.cfg` |
| `wall.gd` | Geçici duvar |
| `characters.gd` | Karakter listesi: renk, can, hız, pasif, Q yeteneği |
| `forest.gd` | Ormanlık harita: ağaçlar, kayalar, çimen, çiçekler (sabit tohum, herkeste aynı) |
| `updater.gd` (autoload `Updater`) | GitHub Release'ten otomatik güncelleme |
| `tests/autotest.tscn` | İki örnekli uçtan uca ağ testi |
| `tests/skills.tscn` | 52 yeteneğin hepsini kurban ve atan gözünden dener |
| `tests/shots.tscn` | Ekran görüntüleri (menü, seçim ekranı, silahlar, yetenekler) |

Ağ modeli:
- Her oyuncu kendi hareketinin sahibi. Konumunu 60 Hz unreliable RPC ile gönderir, diğer tarafta yumuşatılır.
- Roket çarpışmasına atanın makinesi karar verir ve patlamayı herkese yayınlar.
- Hasarı her makine yalnızca kendi oyuncusu için uygular.

Uçtan uca test (iki ayrı terminalde, önce host):

```bash
godot --headless --path . res://tests/autotest.tscn -- host
```

```bash
godot --headless --path . res://tests/autotest.tscn -- join
```

Sinan'ı çok seviyom ❤️

---

_Test güncellemesi: Sinan, 15.11.2026_

Nihat'ı çok seviyorum.
