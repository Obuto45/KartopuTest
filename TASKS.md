# Tasks

Bazuka Savaşı: iki mod. **Arena** (PvP, olduğu gibi kalıyor) + **Hikaye Modu** (co-op, dalga savunması, yapılacak). Son sürüm: v1.0.
Kural: işe başlamadan görevin yanına adını yaz (`[Sinan]`, `[Arkadaş]`), aynı dosyada ikiniz aynı anda çalışmayın, işe başlamadan `git pull` yapın.

## Active

### Aşama 1: Hikaye Modu prototipi (eğlenceli mi?)
Menüde "HİKAYE MODU" kartı şu an "YAKINDA" olarak kapalı; bu aşama bitince açılacak.
- [ ] **Dalga sistemi** - dalga sayacı, 60–90 sn dalga, 15 sn mola, ekranda "Dalga 3/10"
- [ ] **İlk düşman: Sürüngen** - yavaş, kalabalık, tek roketle ölür; duvar dışındaki ormandan gelir
  - Yapay zekâ: en yakın oyuncuya yürü, yakındaysa vur
  - Ağ: düşmanları yalnızca lobiyi kuran oyuncu yönetir, diğerlerine konum gönderir
  - Model: Quaternius ücretsiz canavar paketi (CC0)
- [ ] **Dalga arası güçlendirme seçimi** - 3 kart, 1 seçim; ilk sürüm mevcut etkilerden: +1 roket, hız, yanan patlama, büyük patlama, can yenileme, 3. zıplama
- [ ] **Yere düşme ve kaldırma** - düşen oyuncu 15 sn yerde, arkadaşı E'ye basılı tutarak kaldırır; herkes düşerse koşu biter
- [ ] **Koşu sonu ekranı** - kazandınız / kaybettiniz, ulaşılan dalga, öldürülen düşman
- [ ] **İlk oyun testi** - ikiniz 3 koşu oynayın, neyin sıkıcı neyin eğlenceli olduğunu buraya not edin

## Waiting On

Birlikte karar verilecekler:
- [ ] **Dost ateşi** - açık mı (düşük hasar, komik) kapalı mı?
- [ ] **Koşu süresi** - 10 dalga ≈ 20–25 dk uygun mu?
- [ ] **Oyunun adı** - "Bazuka Savaşı" co-op'a uyuyor mu, Steam adı ne olacak?
- [ ] **Steam** - uygulama kaydı (Steamworks, 100 $), şu an test AppID'si kullanılıyor

## Someday

### Aşama 2: Dikey dilim
- [ ] **Yeni düşmanlar** - Koşucu (hızlı), Atıcı (uzaktan), Kalkanlı (önden hasar almaz), Patlayan (yanına gelip patlar)
- [ ] **Bosslar** - 5. dalgada ara boss, 10. dalgada final boss (evreler, parlayan zayıf nokta)
- [ ] **Güçlendirmeleri genişlet** - nadirlik (sıradan/nadir/efsanevi), sinerjiler, takım güçlendirmeleri
- [ ] **Karakter sınıfları** - 52 karakteri Tank / Hasar / Destek / Kontrol / Hareketli olarak grupla; başlangıçta 6–8 karakter açık
- [ ] **Kalıcı ilerleme** - koşulardan para, karakter açma, küçük kalıcı bonuslar, kayıt dosyası
- [ ] **Zorluk seviyeleri** - final boss yenilince sonraki seviye açılır
- [ ] **Tek kişilik oyun** - zorluk oyuncu sayısına göre ayarlansın
- [ ] **Zorluk dengesi** - oyuncu sayısı ve dalgaya göre düşman sayısı/canı

### Aşama 3: Steam'e hazırlık
- [ ] **Steam sayfası** - kapak görselleri, ekran görüntüleri, açıklama, etiketler
- [ ] **Fragman** - 30–60 sn, en kaotik anlar
- [ ] **Demo** - ilk 3 dalga + 4 karakter, Steam Next Fest'e başvur
- [ ] **Yakın mesafe sesli sohbet**
- [ ] **Yeni haritalar** - kar, çöl, mağara
- [ ] **Erken Erişim çıkışı** - 5–10 $

### Bilinen sorunlar (v1.0)
- [ ] **Replik miğfere biniyor** - dev karakterlerde yazı başın içinde kalıyor
- [ ] **Duvar dokusu** - taş duvardaki çatlak çizgileri yapay duruyor
- [ ] **Performans** - 4 oyunculu gerçek maçta ve orta seviye ekran kartında denenmedi; kasarsa hacimsel sis ve çimen sayısı düşürülecek
- [ ] **Denenmedi** - gerçek Steam maçı, eski sürümden otomatik güncelleme

## Done
- [x] ~~Mevcut PvP "Arena" modu olarak kalıyor, co-op "Hikaye Modu" olarak eklenecek~~ (2026-11-16, karar)
- [x] ~~Yeni ana menü: canlı 3D giriş ekranı, ana menü, mod seçimi (Arena / Hikaye yakında), Arena lobisi~~ (2026-11-16)
- [x] ~~v1.0: görsel yenileme (orman, efektler, karakter hareketi)~~ (2026-11-16)
- [x] ~~v0.9: karakterler yeniden adlandırıldı~~ (2026-11-16)
- [x] ~~v0.8: 52 karakter, bazuka, karakter seçim ekranı~~ (2026-11-16)
