# Oynanış güncellemesi: plan ve durum

Hedef: Steam çıkışında oyuncu çekecek ve tutacak bir oynanış güncellemesi. Çalışma dalı: `claude/awesome-rubin-cogyc1` (`hikaye-modu` üzerine).

Bu dosya, oturum kullanım sınırına takılıp yenilendiğinde işe kaldığı yerden devam etmek için de kullanılıyor. Her aşama bitince **Durum** bölümü güncellenir.

## Aşamalar

1. **İnceleme (paralel alt ajanlar)**
   - Oyun tasarımı denetimi: ilk 10 dakika, çekirdek döngü, öncelikli özellik listesi.
   - Steam çıkış paketi: `docs/steam/`.
   - Denge simülasyonu: `tests/balance_sim.gd`.
2. **Uygulama (paralel alt ajanlar, ayrı git worktree'lerinde, dosya sahipliğiyle bölünmüş)**: özellik listesi aşama 1'den sonra burada sabitlenir.
3. **Birleştirme ve doğrulama**: tüm testler, ekran görüntüleri (Vulkan + OpenGL), iki süreçli ağ testi.
4. **Teslim**: commit, push, kullanıcıya rapor.

## Durum

- [ ] Aşama 1: başladı (3 ajan çalışıyor)
- [ ] Aşama 2
- [ ] Aşama 3
- [ ] Aşama 4
