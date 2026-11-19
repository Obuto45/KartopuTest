# Ses dosyaları

Biçim: `.ogg` (Vorbis). Dosya yoksa oyun prosedürel sese düşer; müzik ve ortam yoksa sessiz kalır.
Dosyayı koyup Godot'ta bir kez içe aktar (`godot --headless --path . --import`); kod değişikliği gerekmez.
Varyant: `<ad>.ogg`, `<ad>_1.ogg`, `<ad>_2.ogg` ... (1'den boşluksuz sayılır, her çalışta rastgele biri seçilir).
Efektler kısa, mono, -3 dB tepe; müzik ve ortam sorunsuz döngü yapmalı.

## Efektler (bus: SFX) - `audio/<ad>.ogg`
fire (ateş), boom (patlama), hurt (hasar), whoosh (savurma/atış), shield_up, shield_break,
thunder, rumble (yapı/yıkıntı), tick (isabet), kill (yaratık öldü)

## Arayüz (bus: UI)
ui_click.ogg, ui_hover.ogg (her menü düğmesi)

## Ayak sesi / hareket (bus: SFX) - `audio/foley/`
step.ogg veya step_1.ogg, step_2.ogg ... ; jump.ogg ; land.ogg

## Silah (bus: SFX) - `audio/weapons/<id>_<olay>.ogg`
Olay: fire, reload, empty (boş şarjörde tetik). Silah id'leri:
bazooka, pistol, shotgun, smg, sniper, bow, boomerang, flame, sword, grenade
Örn. `audio/weapons/pistol_fire.ogg`, `pistol_fire_1.ogg`, `pistol_reload.ogg`, `pistol_empty.ogg`.
fire yoksa genel `fire`/`whoosh` sesi çalar; reload ve empty yoksa sessiz.

## Müzik (bus: Music, döngü, 1,5 sn çapraz geçiş) - `audio/music/`
menu.ogg (menü), battle.ogg (maç)

## Ortam (bus: Ambient, döngü) - `audio/ambient/`
forest.ogg (orman haritası)

## Önerilen CC0 kaynaklar (indirme yok; lisansı kontrol et)
- Kenney (kenney.nl/assets): Impact Sounds, Interface Sounds, UI Audio, Digital Audio, Sci-Fi Sounds. Hepsi CC0.
- Sonniss GDC Game Audio Bundle (sonniss.com/gameaudiogdc): silah, patlama, ortam. Ücretsiz, telifsiz ticari kullanım; lisans metnini oku.
- OpenGameArt.org: yalnızca "CC0" süzgeciyle (ör. "100 CC0 SFX", "CC0 Music" koleksiyonları).
- freesound.org: yalnızca CC0 etiketliler; her dosyanın lisansını tek tek doğrula.
- Müzik için: Kevin MacLeod (incompetech) CC-BY'dir, CC0 değildir; kullanırsan künye ekle.

Kullanılan her dosyanın kaynağını ve lisansını aşağıya yaz:

| Dosya | Kaynak | Lisans |
|---|---|---|
| Tüm dosyalar | Kenney.nl / OpenGameArt.org (ayrıntı: audio/LISANS.md) | CC0 |
