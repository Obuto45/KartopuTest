# Açık Dünya: karanlık 1 km haritaya taşıma

## Amaç
Açık Dünya modu (evler, kutular, envanter, 48 muhafız, yaratıklar) kendi 180 m'lik düz ormanı yerine world.gd'nin 1 km'lik karanlık dünyasında oynansın. İçerik biyomlara yayılsın; oyuncu keşfettikçe zorlaşan bölgelerde ganimet toplasın.

## Hedefler
- Zemin, gökyüzü, sis, biyom geçişleri world.gd'den gelir; forest.gd'nin `open_world` haritası bu modda kullanılmaz.
- Evler, kamplar, karakollar 4 biyoma yayılır; her şey `world.height(x, z)` üstüne oturur, yol ve ev çevresi ağaçsız kalır.
- Zorluk merkezden uzaklıkla artar: merkez (köy, kolay) → orman kenarı → bataklık/harabeler → kül dağları (boss).
- Biyoma göre muhafız grupları: lanetli orman = ninjalar/elfler, bataklık = cadı/büyücü/zombi, kül dağları = viking/şövalye, harabeler = korsan/asker. Her biyomda bir elit lider.
- Yüklenmemiş chunk'taki muhafız ve yaratıklar uyur (fizik ve AI kapalı, düşmez); chunk yüklenince uyanır.
- Envanter, kutu, XP, gece/gündüz aynen kalır.

## Hedef dışı
- Yeni ev modelleri, iç mekan, çok katlı yapı.
- Co-op Açık Dünya (şimdiki gibi tek kişilik).
- Ölüm kuralını değiştirmek (şimdiki yeniden doğma aynen).

## Yaklaşımlar
1. Yalnız zemini değiştir, içerik merkezde kalsın: hızlı ama dünya boş kalır.
2. **Seçilen:** içeriği 1 km'ye biyomlara göre yay, uzak düşmanları uyut. Keşif ve ganimet döngüsünü gerçekten kurar.

## Benim kararlarım (düzeltilebilir)
- Ev/kamp yerleri sabit tablo yerine tohumla (SEED) üretilir: her biyomda 2 ev + 1–2 kamp, yollara yakın, birbirinden en az 60 m uzak. Her oyunda aynı dünya.
- Menüdeki ayrı "Karanlık Dünya" kartı kaldırılır; Açık Dünya kartı tek giriş olur.
- Muhafız sayısı 48 kalır; biyomlara bölünür.

## Doğrulama
- Yeni test: tüm evler/kamplar zeminde (|y - height| < 0.5), dünya sınırı içinde, birbirine 60 m'den yakın değil; yüklenmemiş chunk'taki muhafız uyuyor, yüklenince uyanıyor.
- Mevcut world_test, td_test, weapons_test geçer.
- world_shots ile her biyomda bir ev/kamp ekran görüntüsü ve FPS.
