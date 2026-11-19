# Plan: Ses, Gelişim, Açık Dünya

## 1. Geri savrulma (YAPILDI, oyunda denenmedi)
- Silah başına azaltıldı: bazuka 4, el bombası 6, kılıç 3.5 (Titan +2), keskin nişancı 2, bumerang 1.5, pompalı saçma başına 0.5; tabanca/SMG/yay/alev 0.
- Görsel uzuv sarsıntısı `0.6 + knock*0.5` (önce `2 + knock`).

## 2. Ses güncellemesi (dosya tabanlı)
Öncelik: silah sesleri, müzik, ortam/ayak/arayüz. Yaratık sesleri sonraki adım.
1. Altyapı: `default_bus_layout.tres` → Master / SFX / Müzik / Arayüz / Ortam; ayarlarda 4 ayrı kaydırıcı.
   `Sfx`: `res://audio/` altındaki .ogg'leri ada göre yükle, dosya yoksa mevcut prosedürel sese düş; varyasyon için pitch ±%6; aynı sesin eşzamanlı sayısını sınırla (havuz).
2. Silahlar: her silah için `fire`, `reload`, `empty` (weapons.gd'ye `"snd"` alanı). Kılıç: savurma + isabet.
3. Müzik: menü teması; maç içinde sakin/çatışma katmanları (dalga başında geçiş, crossfade).
4. Ortam: orman rüzgârı/kuş döngüsü; ayak sesi (zemin türüne göre, adım zamanlaması animasyondan); iniş/zıplama.
5. Arayüz: hover, tıklama, satın alma, hata, bildirim (hurt yerine).
Kaynak: CC0 paketler (Kenney, Sonniss GDC vb.) — lisans `audio/KAYNAKLAR.md`'de listelenir.

## 3. Gelişim sekmesi (avantajsız)
- Kaldırılacak: Kule Zırhı, Başlangıç Altını (td.gd:102-103). Yeniden Çekme ve Eleme herkese eşit sabit hak olur ya da tamamen kalkar (karar bekliyor).
- Mevcut alımlar Altın Saç olarak iade edilir (profile.gd göç adımı).
- Yerine Altın Saç ile: karakter renk/kostüm varyantları, unvan/rozet (lobide ve skor tablosunda), silah kaplaması + namlu efekti rengi. Seçimler `net.gd` ile diğer oyunculara gönderilir.
- Silah/zorluk açılımları kalır (görev ödülü; güç değil seçenek).

## 4. Hikâyeli açık dünya — karanlık fantastik, 4 kişilik co-op
- Yeni mod: `MODES["world"]` + `start_world` rpc (main.gd yapısıyla aynı).
- Boyut: büyük, biyomlara bölünmüş (örn. Lanetli Orman, Sis Bataklığı, Kül Dağları, Yıkık Krallık). Chunk tabanlı yükleme + `visibility_range`; mevcut forest.gd 60 m'ye sabit, yeni `world.gd` gerekiyor.
- Host otoriteli dünya durumu; kayıt host'ta (`user://world_<slot>.cfg`).
- Yeni altyapı: NPC + diyalog sistemi, görev takibi, biyoma göre yaratık setleri.
- Açık sorular: hikâye/kahramanın amacı, ilerleme (oyuncu güçlenmesi açık dünyada olacak mı?), ölüm cezası, mevcut silahların kullanımı.

## Kararlar (kullanıcı)
- Yeniden Çekme ve Eleme kaldırılıyor.
- Açık dünya: önce harita (biyomlar), hikâye sonra.
- Açık dünyada silahlar canavar/kötü adam öldürerek elde edilir; NPC'ler: silah satıcıları, takasçılar vb.
- Sıra: Gelişim + ses altyapısı → push + yayın → açık dünya prototipi.
