# Kendi Gözünden Eller, Kol IK ve İksir — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]`.

**Goal:** Karakterin kolu (IK) + parmaklı eldiven el, cam iksir şişesi ve tıpalı/yudumlu içme klibi.
**Architecture:** Eller animasyonla sürülür (HandR/HandL düğümleri, değişmez); kopyalanan karakter iskeleti TwoBoneIK3D ile bileklere uzanır. İksir ayrı betikte kurulur; sıvı seviyesi shader parametresi, klipte değer iziyle sürülür.
**Tech Stack:** Godot 4.7.2, GDScript, sahnesiz (her şey koddan). TwoBoneIK3D sınıfı motorda VAR (ClassDB ile doğrulandı).
**Spec:** `docs/superpowers/specs/2026-11-17-fp-eller-iksir-design.md`

## Global Constraints
- Godot: `"/c/Godot/Godot_v4.7.2-stable_win64_console.exe"`; testler: `--headless --path . res://tests/weapons_test.tscn` (130/130 + yeni kontroller), skills 52/52, td_test 20/20.
- Dış asset yok. Viewmodel düğümleri katman 2 (`1 << 1`), gölge atmaz/almaz.
- Türkçe metinli dosya düzenlemesi bash heredoc ile YAPILMAZ (Edit/Write aracı ya da `python -X utf8`).
- Günlükler `.superpowers/sdd/` altına. Commit/push yok (Stop hook'u yapıyor).
- İki ajan aynı dosyaya yazmaz.

## Review Focus
- Karakter değişince (farklı glb) kol kopyası yeniden kurulmalı / eski serbest bırakılmalı.
- El kola göre uzaktaysa (bomba fırlatma, bazuka) IK kolu düz uzatır, kopma/ters dirsek olmaz.
- Yere bakarken (kamera aşağı) gövde/kafa parçaları ekrana girmemeli.
- İksir ikinci kez kuşanılınca sıvı yeniden dolu (fill=1), tıpa yerinde.
- Uzak oyuncu `build(id, clip, true)` kliplerinde yeni değer izi yalnız `Rig/Weapon/` yollarından gelir.

---

### Task 1: Parmaklı eldiven el — `hands.gd`
**Files:** Modify `hands.gd`; Test `tests/weapons_test.gd` (yalnız el bölümü, ~498-503).
**Interfaces (Produces):** `static func make(color: Color, left: bool) -> Node3D` (kök = bilek, avuç -X sağ / +X sol, parmaklar -Z — mevcut koordinat sözleşmesi korunur); `static func pose(hand: Node3D, name: String, blend := false) -> void`; `static func update(hand: Node3D, dt: float) -> void` (blend hedefine ~0.08 sn'de yaklaştırır); poz adları `grip support open pinch bottle cork`. Düğüm adları `palm wrist thumb f0..f3` var; `f1.rotation.x` grip'te < -0.8, open'da |x|<0.2.
- [ ] Testi genişlet: `bottle` ve `cork` pozları var; f0'ın 3 boğumu (`f0/a/b`) var; `pose(h,"grip",true)` anında değiştirmez, `update(h,0.5)` sonrası hedefe ulaşır.
- [ ] Çalıştır → FAIL.
- [ ] Uygula: kapsül/küre tabanlı yuvarlak ağlar, 3 boğumlu parmaklar, karşıt başparmak, eklem çıkıntısı, bilekte ~8 cm manşet (kolla boşluğu örter), eldiven rengi `color`, manşet koyu. Ağlar paylaşılsın (aynı boyut = aynı Mesh).
- [ ] weapons_test PASS.

### Task 2: Kol IK — `viewmodel.gd`, `player.gd`
**Files:** Modify `viewmodel.gd` (setup + yeni `_arms()`), `player.gd:263` (`vm.setup(ch.color, "res://models/chars/%s.glb" % ch.model)`) ve karakter değişiminde yeniden kurma varsa onu.
**Interfaces:** `func setup(color: Color, model_path := "") -> void`; boş yol = kolsuz (testler/eski çağrılar). Consumes: Task 1 `Hands.update` (viewmodel `_process`'te iki el için çağrılır; `_pose` blend=true kullanır).
- Kemikler: `UpperArm.L/R`, `LowerArm.L/R`, `Fist.L/R`, `Head`, `Neck`, `UpperLeg.L/R`. Fist/Head/Neck/UpperLeg ölçeği ~0 (bone pose scale). MODEL_SCALE 0.72. Kopya viewmodel köküne (kamera uzayı) sabit ofsetle; omuzlar ekran kenarının hemen dışında.
- İki TwoBoneIK3D (ya da tek ayarlı) hedefleri HandR/HandL bilek noktasının biraz gerisi (manşetin içi); dirsek kutbu aşağı-dışa.
- [ ] weapons_test'e kontrol: `setup(c, "res://models/chars/casual2_male.glb")` sonrası viewmodel altında Skeleton3D var, katmanı 2, Fist.L ölçeği < 0.01.
- [ ] Uygula, test PASS; `tests/shots.tscn` ile fp_reload, fp_shotgun karelerine bak: kol elle birleşik, gövde görünmüyor.

### Task 3: İksir modeli — `potion.gd` (yeni)
**Interfaces (Produces):** `static func make() -> Node3D`; çocuklar: `glass`, `liquid` (ShaderMaterial, `fill` uniform 0..1), `cork`, `muzzle` (Marker3D, ağız). Kökte `fill` özelliği (setter shader'a yazar) — klip `Rig/Weapon:fill` değer izi kullanacak, bu yüzden kök bir betikli Node3D olmalı (`potion.gd` extends Node3D, `static func make()` `new()` döndürür ya da `_init`'te kurar).
- Şişe boyu ~0.13 m, küre gövde r≈0.045, boyun, ağız halkası. Cam: saydam, roughness≈0.05, metallic 0, rim/specular yüksek, `cull_disabled` değil. Sıvı: kırmızı, emission; shader dünya-yukarısına göre düz yüzey (vertex dünya Y'si < şişe tabanı + fill*yükseklik değilse discard), cam içinde biraz küçük. Tıpa: konik silindir, mantar rengi.
- [ ] weapons_test'e kontrol: `make()` çocukları var; `fill=0.3` atanınca shader parametresi 0.3.
- [ ] Uygula, PASS.

### Task 4 (Task 1-3 sonrası): İçme klibi + tutuş ayarı — `weapon_anims.gd`, `viewmodel.gd` (yalnız `_potion` → `Potion.make()` bağlama), `tests/shots.gd`
- Klip biçimine `"props": [[t, "yol:özellik", değer]]` (TYPE_VALUE, sürekli). parts_only'de yalnız `Rig/Weapon/` yolları.
- `drink` ~1.7 sn: 0–0.3 kaldır; 0.3–0.6 sol el tıpayı çeker (`Rig/Weapon/cork` HandL ile gider, sonra sol el aşağı); 0.65–0.8 ağza + eğ; 0.8–1.3 üç yudum darbesi, `fill` 1→0.05; `gulp` ≈1.05; 1.3–1.7 indir, `Rig/Weapon` gizlenir; `done` 1.7. El pozları: R `bottle`, L `cork`.
- Bütün silahların HAND_R/HandL dinlenmeleri yeni el + kolla fp_* karelerine bakarak ayarlanır.
- shots.gd: iksir için iki kare (`fp_potion_cork` ~0.45 sn, `fp_potion` ~1.0 sn).
- [ ] weapons_test: drink'te `gulp` < `done`, `props` izi var; parts_only'de HandL izi yok (mevcut kontrol).
- [ ] Bütün testler + shots; kareler incelenir.

### Task 5: İnceleme
- [ ] `gdscript-reviewer` ajanı; bulgular düzeltilir; skills, td_test, td_net yeşil.
