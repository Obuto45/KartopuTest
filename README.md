# Roket Savaşı (KartopuTest)

Godot 4 ile yapılmış, Steam üzerinden 2–4 kişilik, 1. şahıs roket savaşı test oyunu.

## Gereksinimler

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
| 1 | Roketatar |
| 2 | Kalkan (tek roketi emer, 8 sn bekleme) |
| Sol tık | Seçili eşyayı kullan |
| ESC / F10 | Fareyi serbest bırak / lobiden çık |

Her isabet 20 hasar, 5 isabette ölüm. Biri ölünce kazanan yazılır, 3 sn sonra yeni tur başlar.

## Dışa aktarma (exe)

```bash
Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Windows Desktop" build/KartopuTest.exe
```

Export şablonları kurulu olmalı. `steam_appid.txt` dosyasını exe'nin yanına kopyala.

## Kod yapısı

| Dosya | Görev |
|---|---|
| `net.gd` (autoload `Net`) | Steam başlatma, lobi kurma/katılma, davet, `SteamMultiplayerPeer` (Valve relay) ve test için ENet |
| `main.gd` | Menü, HUD, envanter çubuğu, test haritası, tur yönetimi (kararları host verir) |
| `player.gd` | Karakter, hareket fiziği, roket atışı, kalkan, hasar |
| `rocket.gd` | Roket uçuşu ve çarpışma |
| `explosion.gd` | Patlama efekti |
| `sfx.gd` (autoload `Sfx`) | Ses efektlerini koddan üretir (ses dosyası yok) |
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
