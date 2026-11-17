# Kendi gözünden eller, tutuşlar ve iksir: tasarım

## Amaç
Oyuncu kendi gözünden baktığında eller, silah tutuşları, iksir şişesi ve içme animasyonu "kutu" görünümden çıkıp
iskelete uygun, inandırıcı bir görünüme kavuşsun. Kullanıcı mevcut halleri beğenmiyor (iki tur ayar yapıldı, yetmedi).

## Seçilen yaklaşım (kullanıcı seçti): karışık
- **Kol**: karakterin kendi glb modeli (`models/chars/<model>.glb`) viewmodel katmanına (2) kopyalanır.
  Head/Neck/UpperLeg bacakları ve Fist.L/R kemikleri sıfıra ölçeklenir; gövde kameranın arkasında/altında, görüş dışında kalır.
  Bir SkeletonModifier3D, UpperArm/LowerArm'ı **iki kemikli IK** ile (kosinüs yasası + dirsek aşağı-dışa ipucu)
  HandR/HandL bilek noktalarına uzatır. Kollar elleri izler: mevcut bütün silah klipleri değişmeden çalışır.
- **El**: her karakterde aynı, parmaklı eldiven (`hands.gd` baştan). Bilekte manşet koldaki küçük boşluğu örter.

Elenenler: A (yalnız karakter kolu, eller yumruk kalır; tutuş inandırıcı olmaz), B (yalnız eldiven; karakterle tutarsız).

## Parçalar
1. **El (`hands.gd`)**: yuvarlatılmış ağlar (kapsül boğumlar, basık küre/yuvarlak avuç, eklem çıkıntısı, manşet).
   Her parmakta 3 boğum, başparmakta karşıt eksenli 3 boğum, parmak açıklığı. API aynı kalır:
   `make(color, left)`, `pose(hand, name)`, düğüm adları palm/wrist/thumb/f0..f3 (test bunlara bakıyor).
   Pozlar parmak başına eklem dizisi; yeni pozlar: `bottle` (şişeyi saran), `cork` (tıpayı çimdikleyen).
   `pose(..., blend)` ile pozlar ~0.08 sn'de yumuşak geçer (testteki anlık okuma bozulmaz).
2. **Kol IK'sı (`viewmodel.gd`, `player.gd`)**: `setup(color, model_path)`; kol kopyası, IK modifier'ı, katman 2, gölgesiz.
   Godot 4.7'de hazır `TwoBoneIK3D` varsa o, yoksa elle kosinüs yasası.
3. **İksir modeli (yeni `potion.gd`)**: yuvarlak gövdeli cam şişe (küre gövde + boyun + ağız halkası),
   saydam cam malzemesi (düşük pürüz, kenar parlaması), içinde ışıyan sıvı. Sıvı shader'ı `fill` (1→0) ile azalır;
   yüzey dünya yukarısına göre düz kalır (şişe eğilince sıvı yamulmaz). Ayrı `cork` düğümü (mantar tıpa), `muzzle`.
4. **İçme klibi (`weapon_anims.gd`)**: ~1.7 sn. Kaldır → sol el tıpayı çeker (tıpa sol elde kalır) → ağza götür, eğ →
   2–3 yudum (küçük eğme darbeleri, sıvı azalır) → indir, şişe kaybolur. `gulp` olayı ana yudumda, `done` sonda.
   Klip biçimine küçük ek: `"props": [[t, yol:özellik, değer]]` değer izi (sıvı seviyesi için).
5. **Tutuş ayarı**: yeni el ve kollarla bütün silahların HAND_R / sol el dinlenmeleri `fp_*` karelerine bakılarak yeniden ayarlanır.

## Kısıtlar
- Sahnesiz, her şey koddan. Dış model/doku eklenmez.
- Testler yeşil kalır: weapons 130/130, skills 52/52, td_test 20/20, td_net.
- Uzak oyuncular (parts_only klipleri) etkilenmez; yeni `props` izi yalnız `Rig/Weapon/` yollarında parts_only'ye girer.
- `tests/shots.gd` iksir karesi yeni zamanlamaya göre güncellenir (tıpa ve yudum anları).

## Hedef dışı
Uzak oyuncuların 3. şahıs görünümü, ses efektleri, yeni silah modelleri.

## İş bölümü (aynı dosyaya iki ajan yazmaz)
- Ajan 1: `hands.gd` · Ajan 2: `viewmodel.gd` + `player.gd` · Ajan 3: `potion.gd` (yeni)
- Sonra Ajan 4: `weapon_anims.gd` + `tests/shots.gd` (klip, tutuş ayarı, görsel doğrulama)
- Son: `gdscript-reviewer` incelemesi, bütün testler.
