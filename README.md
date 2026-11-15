# Roket Savaşı (KartopuTest)

Godot 4 ile yapılmış, Steam üzerinden 2–4 kişilik, 1. şahıs roket savaşı test oyunu.

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
| 1 | Ateş asası (ateş topu fırlatır) |
| 2 | Kalkan (tek saldırıyı emer, 8 sn bekleme) |
| 3 | Yıldırım asası (nişan alınan yere, en fazla 25 m, 2.5 sn bekleme) |
| 4 | Duvar asası (önüne 3 m'lik duvar, 8 sn durur, 6 sn bekleme) |
| 5 | Kılıç (yakın dövüş, 2.3 m, önündekine 20 hasar) |
| Q | Karakterin özel yeteneği |
| Sol tık | Seçili eşyayı kullan |
| ESC | Ayarlar (ses, ekran modu, çözünürlük) / oyuna dön |
| F10 | Lobiden çık |

Can 100. Ateş topu ve kılıç 20, yıldırım 40 hasar verir. İsimlerin altında can barı görünür. Ölen oyuncu yaşayanları 3. şahıs kameradan izler; sol tık / sağ tık izlenen oyuncuyu değiştirir. Tek kişi kalınca kazanan yazılır, 3 sn sonra yeni tur başlar. Her oyuncunun kafasının üstünde Steam adı görünür.

## Karakterler

Menüdeki **Karakter: … – değiştir** butonundan seçilir; lobideki herkes seçimini görür.

| Karakter | Can | Pasif | Q yeteneği |
|---|---|---|---|
| Keloğlan (Şanslı Kel) | 100 | %15 şansla hasar kafadan seker | Kafa Parlatma: 8 m içinde ona bakanların ekranı 1,5 sn beyaz (12 sn) |
| Terlikli Anne (Ev Hanımı) | 100 | Ateş topları %25 hızlı/uzak | Güdümlü Terlik: en yakın düşmanı kovalar, 30 hasar (8 sn) |
| Pazarcı Abi (Semt Pazarı) | 110 | Q'dan sonra 4 sn ateş topu 30 hasar | Gel Abla Gel: 8 m içindekileri çeker, 10 hasar (10 sn) |
| Kaptan Dron (Dron Pilotu) | 120 | Fazladan can | Dron Bombası: 30 m'ye, 1 sn sonra 35 hasar (9 sn) |

Q basınca karakterin kafasında repliği çıkar ("Gel buraya!", "Gel abla gel, domates bunlar!").

Yeni karakter eklemek için `characters.gd` listesinin **sonuna** ekle (sıra ağda numara olarak gider).

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
| `player.gd` | Karakter, hareket fiziği, roket atışı, kalkan, hasar |
| `rocket.gd` | Roket uçuşu ve çarpışma |
| `slipper.gd` | Terlikli Anne'nin güdümlü terliği |
| `explosion.gd` | Patlama efekti |
| `sfx.gd` (autoload `Sfx`) | Ses efektlerini koddan üretir (ses dosyası yok) |
| `settings.gd` (autoload `Settings`) | Ses ve ekran ayarları, `user://settings.cfg` |
| `lightning.gd` | Yıldırım: uyarı halkası, şimşek efekti, alan hasarı |
| `wall.gd` | Duvar asasının geçici duvarı |
| `characters.gd` | Karakter listesi: renk, can, hız, pasif, Q yeteneği |
| `forest.gd` | Ormanlık harita: ağaçlar, kayalar, çimen, çiçekler (sabit tohum, herkeste aynı) |
| `updater.gd` (autoload `Updater`) | GitHub Release'ten otomatik güncelleme |
| `tests/autotest.tscn` | İki örnekli uçtan uca test |

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
