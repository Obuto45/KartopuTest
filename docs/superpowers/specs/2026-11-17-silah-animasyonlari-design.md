# Silah hissi: eller, şarjör ve animasyonlar — tasarım

Tarih: 2026-11-17 · Dal: `hikaye-modu` · Durum: onay bekliyor

## Amaç ve neden

Kullanıcıya göre silahlarda "saçmalıklar" var:
- silahlar kendi gözünden küçük görünüyor,
- el bombasında "pimi çek, at" yok,
- diğer silahların mekanikleri de inandırıcı değil.

Hedef, silahların profesyonel bir FPS gibi hissettirmesi. Bunun için:
- kendi gözünden iki el görünür,
- her silahın kendine has atış, doldurma ve kullanım animasyonu olur,
- ateşli silahlarda şarjör ve R ile doldurma gelir.

Can iksiri içmek ve eşya kullanmak da animasyonlu olur.

## Kullanıcının verdiği kararlar

- **Şarjör ve doldurma olacak.** Cephane şarjörlü, yedek mermi sınırsız. Şarjör biter, R ile (ya da boşalınca kendiliğinden) doldurulur.
- **Eller olacak.** Kendi gözünden iki low-poly el; şarjör değiştirme, pompa, ip germe, iksir içme gibi hareketleri eller yapar.
- **Kapsam geniş.** Yapılabilecek bütün animasyonlar yapılacak.
- **Kapsam dışı (bu tasarımda değil):** Tower Defense haritasını büyütmek. Bu iş, silahlar bittikten sonra ayrı olarak ele alınacak.

## Hedefler

1. Kendi gözünden silah ve eller ekranda doğru büyüklükte; silah duvara girmiyor.
2. Her silahın şu animasyonları var:
   - çıkarma,
   - atış (silaha özgü hareketle),
   - boş tetik,
   - doldurma.
3. Silaha özel mekanikler:
   - el bombası: tut, pimi çek, bırakınca at; elde bekletme;
   - yay: ger, bırak (gerdikçe güçlenir);
   - keskin nişancı: her atışta sürgü çekme ve sağ tıkla dürbün;
   - pompalı: her atışta pompa, fişekleri tek tek doldurma;
   - bumerang: fırlatınca elden kaybolur, dönünce yakalanır;
   - kılıç: art arda vuruş serisi.
4. Eşyalar animasyonlu:
   - can iksiri içilir (iyileşme yudum anında),
   - bomba eşyası el bombası gibi kullanılır.
5. HUD'da şarjördeki mermi ve doldurma ilerlemesi görünür.
6. Diğer oyuncular seni üçüncü şahıstan gördüğünde de doldurmayı, germeyi ve fırlatmayı görür.

## Hedef olmayanlar

- Sınırlı yedek cephane, mermi düşürme, mermi satın alma.
- Yeni silah türleri ya da yeni yükseltme kartları. Mevcut kartlar yeni sisteme uyarlanır, yenisi eklenmez.
- Blender veya dışarıdan hazır animasyon. Her şey kodla ve üreticiyle yapılır.
- Karakter modellerinin kendi animasyon dosyalarına dokunmak.

## Başarısızlık sayılacaklar (çalışsa bile)

- Tempo ölürse: doldurma süreleri yaratık sürüsünde oyuncuyu çaresiz bırakacak kadar uzunsa.
- Ağ oyununda biri doldururken diğerinin ekranında silah hareketsiz duruyorsa ya da animasyonlar kopuksa.
- Eller karakterden kopuk, ucube görünüyorsa. Eldiven rengi karakterin renginden gelmeli.
- Kare hızı belirgin düşerse.

## Kısıtlar

- Godot 4.7.2, GDScript, sahnesiz; her şey koddan kurulur.
- Silah modelleri `tools/weapon_models.gd` üreticisinden `models/<id>.glb` olarak gelir. Blender yok.
- Ağ: atış kararı yerelde verilir, `td_fire` RPC'siyle yayılır. Yaratığa hasarı yalnızca atanın makinesi hesaplar.
- Arena (PvP) modunda bazuka ve kılıç var; Arena'nın dengesi bozulmamalı.
- Testler: `tests/weapons_test.gd` (başsız). Görsel kontrol `tests/shots.gd` ile.

## Yaklaşımlar

| Yol | Ne | Artı | Eksi |
|---|---|---|---|
| A. Elsiz parça animasyonu | Silahın parçaları (şarjör, pompa) kendi hareket eder | Hızlı | Havada süzülen silah; "profesyonel" değil |
| **B. Elli, koddan animasyon (seçilen)** | Low-poly eller + parçalara ayrılmış modeller; animasyonlar kodda tanımlı `Animation` kaynakları, `AnimationPlayer` oynatır | Gerçek FPS hissi; ayarlanabilir; ek araç yok | İş miktarı ~2 kat |
| C. Blender'da elle animasyon | Hazır animasyonlu glb | En serbest | Blender yok, her silah için elle çizim |

Seçilen: **B**. Kullanıcı elleri istedi. C, araç olmadığı için elendi.

## Nasıl (tasarım)

### 1. Parçalı silah modelleri

- Üretici (`tools/weapon_models.gd`), hareket eden parçaları ayrı ve adlı düğümler olarak dışa aktarır. Her düğümün kendi dönme noktası olur. Örnek adlar:
  - `mag` (şarjör), `slide` (sürgü), `pump` (pompa), `bolt` (mekanizma),
  - `string` (yay ipi), `arrow` (ok), `rocket` (roket), `tank` (yakıt tankı),
  - `pin`, `ring`, `spoon` (el bombası pimi, halkası, mandalı), `trigger` (tetik).
- Her modelde iki işaret noktası olur:
  - `muzzle`: mermi, iz ve alev buradan çıkar.
  - `grip_l`: sol elin tutacağı yer.
- Kabza üstü yine başlangıç noktası, namlu yine -Z yönünde.

### 2. Eller

- İki low-poly el (avuç, parmak boğumları, bilek ve kol ucu) koddan kurulur.
- Eldiven rengi karakterin `color` değerinden, bilekler koyu.
- İki el pozu var: kavrama ve destek.
- Sağ el kabzada sabittir. Sol el animasyona göre `grip_l` noktası, şarjör ya da cep arasında hareket eder.
- Eller ve silah birlikte "görüş modeli" oluşturur. Yalnızca kendi gözünden görünür.

### 3. Görüş modeli (kendi gözünden)

- Silah artık 0,6 kat küçültülmez. Gerçek ölçüde ve kameraya yakın durur.
- Her silah kendi duruş konumunu ve dönüşünü tanımlar (`weapons.gd` içinde `view` alanı).
- Görüş modeli ayrı bir katmanda, duvara girmeyecek şekilde çizilir; görüş açısı ana kameradan bağımsızdır.
- Eldeki salınım, adım sallantısı ve geri tepme (`_feel`) korunur; görüş modeline uygulanır.

### 4. Animasyon sistemi

- Her silahın klipleri `weapons.gd` içinde veri olarak tanımlanır. Bir klip, anahtar karelerden oluşur: zaman, el ve parça hedefleri, yumuşatma. Koddan `Animation` kaynağına çevrilir ve görüş modelindeki `AnimationPlayer` ile oynatılır.
- Ortak klipler:
  - `draw` (çıkarma, ~0,35 sn; bu sürede ateş edilemez),
  - `fire`,
  - `dry` (boş tetik),
  - `reload`,
  - `reload_empty` (gerekiyorsa sürgü bırakma dahil).
- Kliplerin içindeki olay noktaları mekaniğe bağlanır: "şarjör takıldı → mermi dolu", "yudum → iyileş", "bırak → fırlat". Mekanik zamanı animasyondan okunur, böylece ikisi kaymaz.
- Silah değişince eski klip kesilir ve `draw` başlar. Doldurma yarıda kalırsa şarjör dolmaz. Pompalıda takılan fişekler kalır.

### 5. Şarjör ve doldurma

- Her ateşli silahın şarjör boyu ve doldurma süresi olur. Yedek mermi sınırsız.
- Doldurma tuşu R (projeye yeni `reload` giriş eylemi; ayarlar menüsündeki tuş atamalarında görünür).
- Şarjör boşken ateş edilirse `dry` klibi çalar ve doldurma kendiliğinden başlar.
- Mermi sayısı envanter öğesinde tutulur (`ammo`). Silah değiştirip geri gelince sayı korunur.
- Doldurma süresi "Saldırı Hızı" statı (`attack`) ile kısalır.
- Bazukadaki "Hızlı Dolum" kartı artık doldurma süresine etki eder.

Başlangıç değerleri (oynanarak ayarlanacak):

| Silah | Şarjör | Doldurma | Özel |
|---|---|---|---|
| Tabanca | 12 | 1,3 sn (boşsa 1,6) | Boşalınca sürgü geride kalır |
| Pompalı | 6 | fişek başı 0,45 sn | Ateş edince doldurma kesilir; her atışta pompa |
| Makineli | 30 | 1,8 sn | Kurma kolu çekilir |
| Keskin nişancı | 5 | 2,4 sn | Her atışta sürgü (atış aralığına dahil); sağ tık dürbün |
| Bazuka | 1 | 2,0 sn | Arkadan roket sürülür; doluyken tüpün ağzında roket ucu görünür, atınca kaybolur |
| Alev püskürtücü | 100 yakıt (~10 sn) | 2,2 sn tank değişimi | Pilot alevi |
| Yay | 1 ok | germe 0,6 sn tam güç | Bırakınca tirkeşten yeni ok (0,35 sn) |
| El bombası | 1 | yeni bomba 0,8 sn | Tut → pim; bırak → at |
| Bumerang | — | — | Geri dönene kadar yeni atış yok |
| Kılıç | — | — | 3 vuruşluk seri, seriler arası kısa ara |

### 6. Silaha özel mekanikler

- **El bombası ve bomba eşyası:**
  - Basınca pim çekilir (ring + pin animasyonu) ve elde geri sayım başlar (3 sn).
  - Bırakınca fırlatılır; kalan süre kadar sonra patlar (çarpınca değil).
  - Uzun tutarsan elde patlar: çevresindeki yaratıklara hasar verir, oyuncuya da hasar verir.
- **Yay:**
  - Basılı tutunca ip gerilir: güç ve mermi hızı %40'tan %100'e çıkar.
  - Tam gerilmişken nişan hafif titrer.
  - Bırakınca ok fırlar. Germe sırasında yürüme hızı %20 düşer.
- **Keskin nişancı:**
  - Sağ tık dürbün: görüş açısı daralır ve dürbün çerçevesi gelir; dürbünde yürüme yavaşlar.
  - Atıştan sonra sürgü çekilir; sürgü sırasında dürbün kısa süre açılır.
- **Bumerang:** Fırlatınca elden kaybolur; döndüğünde elle yakalama animasyonu oynar.
- **Kılıç:** Art arda tıklamada üç farklı savuruş (sağdan sola, soldan sağa, yukarıdan aşağı). Üçüncü vuruş biraz daha güçlü. Seriden sonra kısa toparlanma.
- **Alev püskürtücü:** Ateşlerken pilot alevi büyür. Yakıt göstergesi azalır (HUD).

### 7. Eşyalar

- **Can iksiri:** şişe sağ elde ağza gelir, eğilir, yudum. İyileşme yudum anında verilir. Toplam ~1,0 sn; bu sürede yürünür ama ateş edilmez. Sonunda boş şişe atılır.
- **Bomba eşyası:** el bombasıyla aynı akış.
- **Yapı kurma:** yapı slotundayken eller hafif aşağıda ve boş. Kurunca kısa bir "yerleştir" hareketi.

### 8. Üçüncü şahıstan görünüm (diğer oyuncular)

- Diğer oyuncular silahı karakterin elinde görür. Silah parçaları aynı kliplerle oynar (şarjör çıkar, pompa kayar).
- Karakterin sağ kolu bugünkü gibi silaha uzanır. Doldururken sol kol da silahın `grip_l` noktasına uzanır.
- Animasyon yayını: silahın kendi atışı zaten `td_fire` ile gidiyor. Ek olarak "şu klibi oynat" bilgisi gönderilir: doldur, ger, pim, iç, çıkar. Bu, isabet bilgisi değil, yalnızca görüntü.

### 9. HUD

- Slot çubuğunda seçili silahın altında şarjör sayısı (ör. `12 / ∞`) ve doldurma ilerleme çizgisi. Mevcut bekleme çizgisi bunun için kullanılır.
- Şarjör azalınca sayı turuncu, boşken kırmızı yanıp söner; "R" ipucu çıkar.
- Alev püskürtücüde sayı yerine yakıt çubuğu.
- Dürbün çerçevesi ve yay germe göstergesi ekranın ortasında.

### 10. Arena (PvP)

- Arena'daki bazuka ve kılıç da eller ve animasyonlarla oynar.
- Arena'da şarjör sistemi kapalıdır; bugünkü atış aralığı kalır. Arena dengesine dokunulmaz.

## Uygulayıcıya bırakılanlar

- Animasyon eğrileri, süre ince ayarı, el parmak geometrisi.
- Görüş modelini duvara girmeyecek şekilde çizme yöntemi: ayrı görüntü alanı ya da derinlik ayarı. Hangisi daha temiz çalışıyorsa.
- `weapons.gd` veri alanlarının tam adları.
- Test kapsamı:
  - şarjör, doldurma ve olay noktası mantığı `weapons_test`'e eklenir;
  - görünüm `shots.gd`'ye yeni karelerle eklenir (doldurma ortası, iksir içme, yay gerili, el bombası pimi çekilmiş, dürbün).

## Benim verdiğim kararlar (kullanıcının onayına açık)

1. Elde fazla tutulan el bombası elde patlar ve oyuncuya da hasar verir.
2. Arena'da şarjör yok, yalnızca eller ve animasyonlar var.
3. Şarjör boyları ve doldurma süreleri yukarıdaki tablodaki gibi.
4. Doldurma süresi "Saldırı Hızı" statıyla kısalır.
5. İksir içerken yürünür ama ateş edilmez; iyileşme yudum anında gelir.
6. Yay gerilirken yürüme %20, dürbünde %35 yavaşlar.
