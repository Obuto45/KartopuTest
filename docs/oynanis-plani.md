# Oynanış güncellemesi: plan ve durum

Hedef: Steam çıkışında oyuncu çekecek ve tutacak bir oynanış güncellemesi. Çalışma dalı: `claude/awesome-rubin-cogyc1` (`hikaye-modu` üzerine).

Bu dosya, oturum kullanım sınırına takılıp yenilendiğinde işe kaldığı yerden devam etmek için de kullanılıyor. Her aşama bitince **Durum** bölümü güncellenir.

## Tasarım denetiminin bulguları (özet)

- Tek başına oynamak "Yerel Host" adlı geliştirici düğmesinin arkasında gizli; herkese açık lobi yok.
- İlk molada ne yapılacağı öğretilmiyor; maç sonu ekranı sadece 3 sayı gösteriyor.
- Maçlar arası ilerleme (meta progression), zorluk seviyesi, sonsuz mod ve başarım yok.
- Kart havuzunun yaklaşık yarısı düz stat kartı; "build kurdum" anı yok.
- Dalga 5'teki ara boss tanıtılmıyor; boss can barı yok.

## Özellikler

| No | Özellik | Sahip ajan | Dosyalar |
|---|---|---|---|
| F1 | Tek tıkla oyna, açık lobi, lobi bul | Giriş | `main.gd`, `net.gd` |
| F2 | İlk maç rehberi | Arayüz (Faz 2) | `td_ui.gd` |
| F3 | Kalıcı ilerleme: Altın Saç, silah kilitleri, Kule Taşları | Profil + Giriş | `profile.gd`, `main.gd` |
| F4 | Zorluk: Kolay / Normal / Zor / Kabus | Dalga + Giriş | `balance.gd`, `td.gd`, `main.gd` |
| F5 | Boss davranışları ve dalga modifikatörleri | Dalga | `balance.gd`, `td.gd`, `enemy.gd` |
| F6 | Yaratıktan düşen eşyalar ve sandık | Dalga | `td.gd`, `enemy.gd` |
| F7 | Silah evrimleri ve sinerji | Silah | `weapons.gd`, `player.gd` (TD bölümü) |
| F8 | Maç sonu özeti ve MVP | Dalga (sayaçlar) + Arayüz (ekran) | `td.gd`, `td_ui.gd` |
| F9 | Sonsuz mod | Dalga | `balance.gd`, `td.gd` |
| F10 | Başarımlar (yerel; gerçek App ID gelince Steam) | Profil (+ tetik satırları) | `profile.gd` |
| — | Silah tutuşları ve silahın düz durması (kullanıcı isteği) | Tutuş | `hands.gd`, `weapon_anims.gd`, `viewmodel.gd` |

Faz 0 sözleşmeleri (commit `a9bd3d7`): `start_td(ids, opts)`, `td.gd` durum dizisi indeks 11-14, `Balance.DIFFS` / `wave(n, players, diff, mods)` / `roll_mods`, `Weapons.EVOS`, `profile.gd` iskeleti.

## Durum

- [x] Aşama 1: tasarım denetimi bitti; Steam paketi ve denge simülasyonu ajanları çalışıyor (`docs/steam/`, `tests/balance_sim.gd`)
- [x] Faz 0: sözleşmeler commit'lendi ve push'landı
- [x] Faz 1 birleşti: Profil (PROFILE_TEST 32/32), Silah evrimleri (EVO_TEST 15/15), Dalga sistemi (WAVES_TEST 10/10). Ana dalda tüm testler geçti.
- [ ] Faz 1 süren: Giriş/lobi (main.gd, net.gd), Silah tutuşu (hands/weapon_anims/viewmodel), Denge simülasyonu (tests/balance_sim.*). 23:30 UTC kullanım sınırına takıldılar, devam ettirildi.
- [ ] Faz 2 süren: Arayüz ajanı (td_ui.gd: rehber, maç sonu özeti, boss barı, modifikatör afişi, reroll/banish, evrim kartı görünümü; profil bağlantıları)
- [x] Steam paketi bitti: `docs/steam/` (mağaza sayfası, 34 başarım, pazarlama planı, görsel/fragman brifi)
- [ ] Faz 3 (birleştirmeden sonra, çakışmasın diye): İngilizce yerelleştirme (`tr()` + çeviri dosyası). Steam ajanının 1 numaralı önerisi.
- [ ] Aşama 3: worktree dallarını birleştir; tüm testler, ekran görüntüleri, iki süreçli ağ testi
- [ ] Aşama 4: commit, push, rapor

Devam ederken: `git worktree list` ve `git branch` ile ajan dallarını gör. Bitmiş dalları sırayla birleştir: profil, dalga, silah, giriş, tutuş. Yarım kalan ajanların işini aynı sahiplik kurallarıyla yeniden başlat.
