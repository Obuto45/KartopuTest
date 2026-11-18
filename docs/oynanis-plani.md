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

- [x] Aşama 1: tasarım denetimi, Steam paketi (`docs/steam/`), denge simülasyonu (`tests/balance_sim.gd`)
- [x] Faz 0: sözleşmeler
- [x] Faz 1 birleşti: profil (32/32), silah evrimleri (15/15), dalga sistemi (10/10), giriş/lobi (tek başına oyna, açık lobi, zorluk, kilitler, GELİŞİM), tutuş 1. tur (silahlar düz, bilekler doğal; GRIP_TEST 76/120)
- [x] Faz 2 birleşti: TD arayüzü (rehber, maç sonu özeti, boss barı, modifikatör afişi, yeniden çek/ele, evrim kartı)
- [x] Denge: kule 3000 (+%35/oyuncu), yaratık hasarı x0.55, canı x0.85, kalabalık 0.4/0.25, zorluklar yumuşatıldı. Simde 1 oyuncu artık 10. dalgaya ulaşıyor/kazanıyor; 4 oyunculu ölçüm yeniden yapılıyor.
- [x] Faz 3 birleşti: İngilizce yerelleştirme (705 metin, I18N_TEST 853/853, Ayarlar > Dil), menü cilası
- [ ] Süren: tutuş 2. tur (parmaklar silah başına, sol kol açısı)
- [ ] Aşama 3: son birleştirme; tüm testler, Vulkan/OpenGL ekran görüntüleri, iki süreçli ağ testi
- [ ] Aşama 4: commit, push, rapor

Devam ederken: `git worktree list` ve `git branch` ile ajan dallarını gör. Bitmiş dalları sırayla birleştir: profil, dalga, silah, giriş, tutuş. Yarım kalan ajanların işini aynı sahiplik kurallarıyla yeniden başlat.
