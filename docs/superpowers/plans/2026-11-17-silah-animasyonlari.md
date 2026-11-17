# Silah Hissi (Eller, Şarjör, Animasyonlar) Uygulama Planı

> **Ajanlar için:** GEREKLİ ALT BECERİ: Görev görev uygulamak için superpowers:subagent-driven-development (önerilen) ya da superpowers:executing-plans kullan. Adımlar onay kutulu (`- [ ]`).

**Amaç:** Kendi gözünden eller, gerçek boyutta silah, şarjör ve doldurma, silaha özel mekanikler (pim, germe, dürbün, pompa, yakalama, kombo) ve iksir içme dahil bütün animasyonlar.

**Mimari:**
- Silah modelleri üreticide adlı parçalara bölünür.
- Kendi gözünden görünen kısım (`viewmodel.gd`) eller, silah ve bir `AnimationPlayer`'dan oluşur, ayrı bir görüntü alanında çizilir.
- Klipler `weapon_anims.gd` içinde veri olarak tanımlanır ve koddan `Animation` kaynağına çevrilir.
- Kliplerdeki olay noktaları (`ready`, `mag_in`, `release`, `gulp`…) `player.gd`'deki oyun mantığını sürer.
- Şarjör mantığı `weapons.gd` içinde, sahneye bağımsız saf fonksiyonlardır.

**Teknoloji:** Godot 4.7.2, GDScript, `AnimationPlayer` + koddan üretilen `Animation`, `SubViewport`.

**Tasarım:** `docs/superpowers/specs/2026-11-17-silah-animasyonlari-design.md`

## Genel Kısıtlar

- Cephane: şarjörlü, **yedek sınırsız**. Şarjör yalnızca Tower Defense'te; **Arena'da şarjör yok** (eller ve animasyonlar var).
- Şarjör ve doldurma değerleri (başlangıç):

| id | mag | reload |
|---|---|---|
| pistol | 12 | 1.3 (boşsa `reload_empty` 1.6) |
| shotgun | 6 | fişek başı 0.45 (`shell`) |
| smg | 30 | 1.8 |
| sniper | 5 | 2.4 |
| bazooka | 1 | 2.0 |
| flame | 100 yakıt | 2.2 |
| bow | 1 | 0.35 (ok takma) |
| grenade | 1 | 0.8 |
| boomerang | yok | — |
| sword | yok | — |

- Doldurma süresi `reload / st("attack")`. Bazukadaki `reload` kartı (`mul rate 0.85`) artık `mul reload 0.85` olur.
- El bombası: 3 sn sigorta. Bırakınca kalan süre sonra patlar. Elde biterse elde patlar: yaratıklara hasar verir, sahibine `dmg * 0.5` hasar verir.
- Yay: güç ve hız gerginliğe göre %40→%100, tam germe 0.6 sn. Germe sırasında yürüme ×0.8.
- Dürbün: yalnız keskin nişancı, sağ tık; görüş açısı 20, yürüme ×0.65.
- İksir: ~1.0 sn; iyileşme `gulp` olayında; içerken yürünür, ateş edilmez.
- `draw` ~0.35 sn; bitene (`ready`) kadar ateş yok. Silah değişince süren klip kesilir; doldurma yarıda kaldıysa şarjör dolmaz (pompalıda takılan fişekler kalır).
- Eldiven rengi `ch.color`, bilek koyu.
- Yeni giriş eylemleri: `reload` = R, `aim` = sağ fare (`main.gd:107-120`'deki tablolara).
- Testler başsız: `"C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/weapons_test.tscn`; satır `WEAPONS_TEST: x/y`, hata satırı `[HATA]`.
- Model üretimi ve içe aktarma: `... --headless --path . -s res://tools/weapon_models.gd`, ardından `... --headless --path . --import`.

## İnceleme Odağı

1. **Doldururken silah değiştirmek:** geri gelince şarjör eski sayıda kalmalı, animasyon sıfırdan `draw` ile başlamalı. Test: Görev 6.
2. **Ağ:** istemcinin doldurması host ekranında kliple görünmeli; hasar yine yalnız atanın makinesinde hesaplanmalı (çifte hasar yok). Test: Görev 10 (`tests/td_net`'e ekleme).
3. **Ölüm sırasında doldurma, germe veya pim:** ölünce iptal edilmeli; elde pimli bomba ölünce yere düşüp patlamalı, kaybolmamalı. Test: Görev 7.
4. **Boş şarjörle basılı tutmak (makineli):** tek `dry` çalıp kendiliğinden doldurmalı; her karede `dry` sesi spam olmamalı. Test: Görev 6.
5. **Saldırı Hızı statı çok yüksekken:** doldurma ve animasyon hızlanmalı, olaylar yine sırayla gelmeli (`mag_in` atlanmamalı). Test: Görev 6.

---

### Görev 1: Şarjör verisi ve saf mantık

**Dosyalar:**
- Değiştir: `weapons.gd` (LIST alanları, UPS bazuka `reload`, yeni statik fonksiyonlar)
- Test: `tests/weapons_test.gd`

**Arayüzler:**
- Üretir:
  - LIST alanları: `mag: int` (0 = şarjörsüz), `reload: float`, `reload_empty: float` (yalnız tabanca), `per_shell: bool` (pompalı), `fuse: float` (el bombası 3.0), `charge: float` (yay 0.6).
  - `static func mag_of(w: Dictionary) -> int`
  - `static func reload_time(w: Dictionary, attack: float, empty: bool) -> float`
  - `static func full_ammo(id: String) -> int`: envanter öğesine yeni silah konunca `ammo` alanı bu değeri alır.

- [ ] **Adım 1: Başarısız testleri yaz** (`Net.set_weapon` kontrolünden önce):

```gdscript
var p := Weapons.tuned("pistol", {})
chk("tabanca şarjörü 12", Weapons.mag_of(p) == 12)
chk("tabanca doldurma 1.3 / boş 1.6", is_equal_approx(Weapons.reload_time(p, 1.0, false), 1.3) and is_equal_approx(Weapons.reload_time(p, 1.0, true), 1.6))
chk("saldırı hızı x2 doldurmayı yarılar", is_equal_approx(Weapons.reload_time(p, 2.0, false), 0.65))
chk("bazuka hızlı dolum 2 seviye", is_equal_approx(Weapons.tuned("bazooka", {"bazooka:reload": 2}).reload, 2.0 * 0.85 * 0.85))
chk("kılıç ve bumerang şarjörsüz", Weapons.mag_of(Weapons.tuned("sword", {})) == 0 and Weapons.mag_of(Weapons.tuned("boomerang", {})) == 0)
chk("yeni silahın şarjörü dolu", Weapons.full_ammo("smg") == 30 and Weapons.full_ammo("sword") == 0)
```

- [ ] **Adım 2: Çalıştır, HATA görmelisin.**
- [ ] **Adım 3: Uygula.** `DEF` içine `mag: 0, reload: 0.0`. Tablodaki değerler LIST'e eklenir. `reload_time` boşken `reload_empty` varsa onu kullanır, sonucu `attack`'a böler. Bazuka UPS `reload`: `"mul": {"reload": 0.85}`, açıklaması "%15 hızlı doldurma". `player.add_item` silah eklerken öğeye `"ammo": Weapons.full_ammo(id)` yazar; `_td_init`'teki başlangıç silahı da.
- [ ] **Adım 4: Çalıştır, hepsi OK.**
- [ ] **Adım 5: Commit** — `feat: silah şarjör verisi ve doldurma süresi`

### Görev 2: Üretici — adlı parçalar ve işaret noktaları

**Dosyalar:**
- Değiştir: `tools/weapon_models.gd`, `models/*.glb` (yeniden üretilir)
- Test: `tests/weapons_test.gd`

**Arayüzler:**
- Üretir: Her glb'de kök altında `MeshInstance3D` düğümleri. `body` her zaman var; hareket edenler kendi dönme noktalarında. İsimler:

| id | parçalar |
|---|---|
| pistol | `slide`, `mag`, `trigger`, `hammer` |
| shotgun | `pump`, `trigger`, `shell` (eldeki yedek fişek, başta gizli) |
| smg | `mag`, `charging`, `trigger` |
| sniper | `bolt` (sürgü + kol + topuz), `mag`, `trigger` |
| bazooka | `rocket` (ağızdaki başlık) |
| flame | `tank`, `pilot` (ışıyan küre), `trigger` |
| bow | `string_top`, `string_bot` (ipin iki yarısı, kiriş noktasında birleşir), `arrow` |
| grenade | `pin`, `ring`, `spoon` |
| boomerang, sword | yalnız `body` |

  - `Marker3D` `muzzle`: namlu ağzı; yay ve el bombası için çıkış noktası.
  - `Marker3D` `grip_l`: sol elin tuttuğu yer.
  - Üreticide yeni çağrı: `part(name: String, pivot: Vector3)` sonraki parçaları o düğüme yazar (pivot kadar kaydırılmış yerel koordinatta); `marker(name, pos)`.

- [ ] **Adım 1: Başarısız test yaz** (Görev 1 testlerinin ardına):

```gdscript
const PARTS := {"pistol": ["slide", "mag"], "shotgun": ["pump"], "smg": ["mag"], "sniper": ["bolt", "mag"], "bazooka": ["rocket"],
	"flame": ["tank"], "bow": ["string_top", "string_bot", "arrow"], "grenade": ["pin", "ring", "spoon"]}
for w in Weapons.LIST:
	var m := Weapons.make_prop(w)
	var need: Array = ["body", "muzzle", "grip_l"] + PARTS.get(w.id, [])
	chk("%s parçaları" % w.id, need.all(func(n): return m.find_child(n, true, false) != null), need)
	m.free()
```

- [ ] **Adım 2: Çalıştır, HATA görmelisin.**
- [ ] **Adım 3: Uygula.**
  - `surf` yapısı `{düğüm: {malzeme: köşeler}}` olur; `_save` her düğüm için bir `MeshInstance3D` kurar ve konumunu pivot yapar.
  - Mevcut parça çizimleri, tablodaki adlara göre `part(...)` çağrılarıyla bölünür; görünüş değişmez.
  - Pompalıda eldeki `shell` parçası: tek bir kırmızı fişek, başta `visible = false` (glb'de görünür dışa aktarılır, `viewmodel` gizler).
- [ ] **Adım 4: Üret, içe aktar, testi çalıştır; OK.** Ek olarak önizleme betiğiyle (geçici) bakış: görünüş öncekiyle aynı olmalı.
- [ ] **Adım 5: Commit** — `feat: silah modelleri hareketli parçalara bölündü`

### Görev 3: Eller

**Dosyalar:**
- Oluştur: `hands.gd`
- Test: `tests/weapons_test.gd`

**Arayüzler:**
- Üretir:
  - `static func make(color: Color, left: bool) -> Node3D`: el kökü bilekte; çocuk düğümler `palm`, `thumb`, `f0..f3` (her parmak iki boğum: `f0/a`, `f0/a/b`) ve `wrist` (koyu manşet, kola doğru 12 cm).
  - `static func pose(hand: Node3D, name: String) -> void`, `name` ∈ `"grip"`, `"support"`, `"open"`, `"pinch"`: parmak boğumlarının dönüşlerini ayarlar.
  - Ölçü: avuç 8×3×9 cm. El, avuç içi -X (sağ el) / +X (sol el) bakacak, parmaklar -Z yönünde.

- [ ] **Adım 1: Başarısız test yaz:**

```gdscript
var hR: Node3D = load("res://hands.gd").make(Color.RED, false)
chk("el parçaları", ["palm", "thumb", "f0", "f3", "wrist"].all(func(n): return hR.find_child(n, true, false) != null))
load("res://hands.gd").pose(hR, "grip")
var a: float = hR.find_child("f1", true, false).rotation.x
load("res://hands.gd").pose(hR, "open")
chk("kavrama parmakları büker, açık düzeltir", a < -0.8 and absf(hR.find_child("f1", true, false).rotation.x) < 0.2, a)
hR.free()
```

- [ ] **Adım 2: Çalıştır, HATA.**
- [ ] **Adım 3: Uygula.**
  - Mesh'ler `BoxMesh` + pahsız düz renkli `StandardMaterial3D`. Eldiven `color`, manşet `color.darkened(0.55)`, gölge atmaz.
  - Pozlar: kavrama: parmaklar −1.2 / −1.1 rad, başparmak içe. Destek: −0.6 / −0.5. Açık: 0. Kıstırma: başparmak ve f0 −0.9, diğerleri −1.3.
- [ ] **Adım 4: OK.**
- [ ] **Adım 5: Commit** — `feat: koddan low-poly eller`

### Görev 4: Animasyon klipleri

**Dosyalar:**
- Oluştur: `weapon_anims.gd`
- Test: `tests/weapons_test.gd`

**Arayüzler:**
- Üretir:
  - `const CLIPS := {id: {clip: {"len": float, "tracks": {yol: [[t, pos: Vector3, rot: Vector3], ...]}, "poses": [[t, "L"|"R", poz]], "events": [[t, ad]]}}}`.
  - Yollar viewmodel ağacına göre: `"Rig"` (silah + sağ el), `"Rig/Weapon/<parça>"`, `"HandL"`.
  - `"item:potion"` ve `"item:bomb"` da `id` olarak bulunur.
  - `static func build(id: String, clip: String, parts_only := false) -> Animation`:
    - konum ve dönüş izleri (`TYPE_POSITION_3D`, `TYPE_ROTATION_3D` Euler'den Quaternion),
    - `poses` ve `events` için `"."` yoluna yöntem izi (`_pose(side, name)`, `_ev(name)`),
    - `parts_only` ise yalnız `Rig/Weapon/...` izleri, yol öneki `Rig/Weapon/` atılarak.
  - `static func has(id: String, clip: String) -> bool`
  - Olay adları:
    - `ready`: çıkarma bitti
    - `fired`
    - `mag_in`: şarjör doldu
    - `shell`: pompalıya +1 fişek
    - `chamber`
    - `release`: fırlat / ok çık
    - `pin`: pim çekildi
    - `gulp`: iyileş
    - `caught`
    - `done`: klip bitti, boşta duruşa dön
  - Zorunlu klipler:

| id | klipler |
|---|---|
| hepsi | `draw`, `idle` (1 kare) |
| pistol, smg, sniper, bazooka, flame, shotgun | `fire`, `dry`, `reload` |
| pistol | `reload_empty` |
| shotgun | `reload_start`, `shell` (0.45, olay `shell`), `reload_end` |
| sniper | `fire` içinde sürgü (olay `chamber`) |
| bow | `draw_string` (0.6, ip ve ok geri), `release`, `reload` (ok takma, 0.35, `mag_in`) |
| grenade, item:bomb | `prime` (olay `pin`), `throw` (olay `release`), `reload` (0.8, `mag_in`) |
| boomerang | `throw` (`release`, sonra gövde gizli), `catch` (`caught`) |
| sword | `swing1`, `swing2`, `swing3` (her birinde isabet anı olayı `fired`) |
| item:potion | `drink` (~1.0, `gulp` 0.55'te) |

  - Doldurma kliplerinde `mag_in`, `reload` süresinin %85'inde olur.

- [ ] **Adım 1: Başarısız test yaz:**

```gdscript
const WA := preload("res://weapon_anims.gd")
for id in ["pistol", "shotgun", "smg", "sniper", "bazooka", "flame", "bow", "grenade", "boomerang", "sword", "item:potion", "item:bomb"]:
	chk("%s draw" % id, WA.has(id, "draw"))
var a := WA.build("pistol", "reload")
chk("tabanca reload süresi 1.3", is_equal_approx(a.length, 1.3), a.length)
var ev := []
for t in a.get_track_count():
	if a.track_get_type(t) == Animation.TYPE_METHOD:
		for k in a.track_get_key_count(t):
			var v: Dictionary = a.track_get_key_value(t, k)
			if v.method == "_ev":
				ev.append([a.track_get_key_time(t, k), v.args[0]])
chk("mag_in %85'te", ev.any(func(e): return e[1] == "mag_in" and is_equal_approx(e[0], 1.3 * 0.85)), ev)
chk("iksir gulp", WA.has("item:potion", "drink"))
var po := WA.build("pistol", "reload", true)
chk("parts_only: yalnız parça izleri", range(po.get_track_count()).all(func(t): return po.track_get_type(t) == Animation.TYPE_METHOD or not str(po.track_get_path(t)).begins_with("HandL")))
```

- [ ] **Adım 2: HATA.**
- [ ] **Adım 3: Uygula.**
  - Klip süreleri Genel Kısıtlar tablosundan.
  - Hareketler:
    - doldurma: silahı 25° içe yatır, şarjörü aşağı düşür, sol el cepten yeni şarjörü getirip tak, tokat;
    - tabanca boş doldurma: sonda sürgü bırakma;
    - makineli: kurma kolu;
    - keskin nişancı: sürgü yukarı-geri-ileri-aşağı;
    - bazuka: sol el roketi arkadan sür;
    - alev: tankı çıkar-tak;
    - yay: sol el ok tut, ip çek;
    - el bombası: sağ el kavrar, sol el halkayı çeker, kol geri gerilir, öne savrulur;
    - iksir: şişe ağza, 50° eğ, yutkun, şişe yana atılır (gizlenir);
    - kılıç: üç farklı yönde savuruş.
  - Eğriler `Animation.INTERPOLATION_CUBIC`.
- [ ] **Adım 4: OK.**
- [ ] **Adım 5: Commit** — `feat: silah animasyon klipleri`

### Görev 5: Görüş modeli (viewmodel) ve oyuncuya bağlama

**Dosyalar:**
- Oluştur: `viewmodel.gd`
- Değiştir: `player.gd` (199-245 kurulum, 972-983 elde tutma, 1087-1092 `_feel`, 1227-1237 `_td_init`, 1346 `_muzzle`)
- Test: `tests/weapons_test.gd`, `tests/shots.gd`

**Arayüzler:**
- Tüketir: `Hands.make/pose` (Görev 3), `WeaponAnims.build/has` (Görev 4), `Weapons.make_prop` (Görev 2 parçalarıyla).
- Üretir (`viewmodel.gd`, `extends Node3D`):
  - `signal event(name: String)`
  - `func setup(color: Color) -> void`
  - `func equip(id: String) -> void`: silahı değiştirir ve `draw` oynatır; `id == ""` ise eller iner.
  - `func play(clip: String, speed := 1.0) -> void`: klip yoksa sessizce `idle`.
  - `func current() -> String`
  - `func muzzle() -> Vector3`: `muzzle` işaretinin genel konumu.
  - `func show_part(name: String, on: bool) -> void`
  - `var sway_offset: Vector3`, `var sway_tilt: Vector3`: `_feel` yazar.
  - Çizim: kendi `SubViewport`'unda, saydam arka plan, kendi `Camera3D`'si (fov 62). Ana ekranın üstünde tam ekran `TextureRect` olarak (CanvasLayer -1, fare olaylarını yok sayar). Viewmodel düğümleri `layers = 2`, ana kamera `cull_mask` 2'yi hariç tutar; kamera konumu her karede ana kameraya eşitlenir.
  - Silah duruşu: `Weapons` LIST'teki yeni `view: [pos: Vector3, rot: Vector3]` alanı (her silah için; tabanca `Vector3(0.16, -0.17, -0.38)` başlangıç, uzun silahlar daha sağ ve geride).
- `player.gd`:
  - `var vm: Node3D` (yalnız `is_multiplayer_authority()` olana).
  - Yerel oyuncuda `gun`, `sword` ve `hand` görünmez olur; Arena ve TD'de `vm.equip(_held())` slot değişiminde.
  - `_muzzle()` = `vm.muzzle()` (vm varsa).

- [ ] **Adım 1: Başarısız test yaz:**

```gdscript
var vm: Node3D = load("res://viewmodel.gd").new()
add_child(vm)
vm.setup(Color.BLUE)
var got := []
vm.event.connect(func(n): got.append(n))
vm.equip("pistol")
await _wait(0.5)
chk("viewmodel çıkarma bitti -> ready", got.has("ready") and vm.current() == "pistol", got)
chk("namlu ileride", vm.to_local(vm.muzzle()).z < -0.2, vm.to_local(vm.muzzle()))
vm.queue_free()
```

- [ ] **Adım 2: HATA.**
- [ ] **Adım 3: Uygula** (yukarıdaki arayüz). `player.gd` tarafında: yerel oyuncu için `vm` kurulur (`look`'un altına değil kendi görüntü alanına); `_animate` slot değişince `vm.equip`; `_feel` salınım ve geri tepmeyi `vm.sway_offset/tilt`'e yazar.
- [ ] **Adım 4: Testleri ve `tests/shots.tscn`'i çalıştır.** `forest.png` ve `hud.png`'de el ve silah gerçek büyüklükte, sağ altta; duvar dibinde silah duvara girmiyor.
- [ ] **Adım 5: Commit** — `feat: kendi gözünden eller ve silah (viewmodel)`

### Görev 6: Şarjör, doldurma ve ateş akışı

**Dosyalar:**
- Değiştir: `player.gd` (`_td_use`, `_td_shoot`, `_local`, yeni yöntemler), `main.gd:107-120` (`reload`, `aim` eylemleri), `td_ui.gd:512-530` (slot sayacı)
- Test: `tests/weapons_test.gd`

**Arayüzler:**
- Tüketir: `Weapons.mag_of/reload_time/full_ammo` (Görev 1), `vm.play/event` (Görev 5).
- Üretir (`player.gd`):
  - `var reloading := false`, `var busy := ""` (animasyonun ateşi kilitlediği durum: `"draw"`, `"reload"`, `"drink"`, `"prime"`, `"charge"`, `""`).
  - `func start_reload() -> void`
  - `func _on_vm_event(name: String) -> void`: `mag_in` → `inv[slot-1].ammo = mag`, `shell` → `+1` (dolunca `reload_end`), `ready`/`done` → `busy = ""`.
  - `@rpc("authority", "call_remote", "unreliable_ordered") func td_anim(clip: String) -> void`: diğer makinelerde elde tutulan prop'un parça klibini oynatır (Görev 10 doldurur; burada boş gövde + çağrı).
  - Test kancası: `vm` yoksa (başsız diğer oyuncu ya da testte `vm == null`) olaylar `WeaponAnims` klip süresi ve olay zamanlarıyla `SceneTreeTimer` üzerinden tetiklenir. Mantık hep aynı yoldan geçer.

- [ ] **Adım 1: Başarısız testleri yaz:**

```gdscript
await _fire("pistol", 0.1)
chk("atış şarjörden düşer", me.inv[0].ammo == 11, me.inv[0])
me.inv[0].ammo = 0
me.cd = 0.0
td.hits.clear()
me._td_use(true)
chk("boş şarjör ateşlemez, doldurma başlar", td.hits.is_empty() and me.reloading)
await _wait(1.7)
chk("1.6 sn sonra dolu", me.inv[0].ammo == 12 and not me.reloading, me.inv[0])
me.inv[0].ammo = 3
me.start_reload()
await _wait(0.5)
me._set_slot(2); await _wait(0.1); me._set_slot(1)
await _wait(1.5)
chk("doldururken silah değişirse dolmaz", me.inv[0].ammo == 3, me.inv[0])
me.inv[0] = {"kind": "weapon", "id": "shotgun", "count": 1, "lvl": 1, "ammo": 2}
me.start_reload()
await _wait(1.0)
me.cd = 0.0
me._td_use(true)
chk("pompalı: fişek fişek dolar, ateş kesmez", me.inv[0].ammo >= 2 and not me.reloading, me.inv[0])
me.stats.attack = 2.0
me.inv[0] = {"kind": "weapon", "id": "smg", "count": 1, "lvl": 1, "ammo": 0}
me.start_reload()
await _wait(0.95)
chk("saldırı x2: makineli 0.9 sn'de dolar", me.inv[0].ammo == 30, me.inv[0])
me.stats.attack = 1.0
var dry := 0
me.inv[0].ammo = 0
for i in 10:
	me.cd = 0.0
	me._td_use(i == 0)
	dry += int(me.busy == "reload")
chk("boşken basılı tutmak tek doldurma başlatır", me.reloading and dry == 10)
```

- [ ] **Adım 2: HATA.**
- [ ] **Adım 3: Uygula.**
  - `_td_use` "weapon": `busy != ""` ise çık. `mag > 0` ve `ammo <= 0` ise `start_reload()`, `vm.play("dry")`, çık. Ateşte `ammo -= 1` (alev püskürtücü atış başı 1 yakıt).
  - `start_reload`: dolu ya da `mag == 0` ise çık; `reload_empty` (ammo 0 ve klip varsa) ya da `reload`/`reload_start`; hız = `klip_süresi / reload_time(...)`.
  - R → `start_reload()`. Arena'da (`td == null`) şarjör yok: ammo ve reload atlanır.
  - Alev püskürtücü: ateşlerken `pilot` parçası ×1.8 büyür, bırakınca 0.2 sn'de geri döner (`fire` klibinde).
  - `td_ui`: `count` etiketi, şarjörlü silahta `"%d / ∞"`. `ammo <= mag/4` turuncu, 0'da kırmızı yanıp söner. Doldururken `cd` çubuğu doldurma ilerlemesi. Alev püskürtücüde sayı yerine yüzde.
- [ ] **Adım 4: OK; mevcut 59 test de OK.**
- [ ] **Adım 5: Commit** — `feat: şarjör ve doldurma (R), HUD sayacı`

### Görev 7: El bombası ve bomba eşyası — pim, bekletme, fırlatma

**Dosyalar:**
- Değiştir: `player.gd` (`_td_use` "weapon" grenade + "item" bomb, `_local` bırakma algısı, ölüm), `rocket.gd` (sigorta)
- Test: `tests/weapons_test.gd`

**Arayüzler:**
- Tüketir: klipler `prime/throw/reload` (Görev 4), `busy` (Görev 6).
- Üretir:
  - `var fuse_left := 0.0` (pim çekildikten sonra kalan).
  - `td_fire(id, origin, dirs, n, fuse := 0.0)`: yeni son argüman; roket `w.fuse = fuse` ile kurulur.
  - `rocket.gd`: `w.get("fuse", 0.0) > 0` ise çarpınca patlamaz, yere değince seker (hız ×0.4, yansır) ve sigorta bitince `td_explode` yayınlar.
  - `func _cook_out() -> void`: elde patlama.
  - `func _release_throw() -> void`: basılı tutulan atışı bırakır (el bombası, bomba eşyası; Görev 8'de yay da kullanır).

- [ ] **Adım 1: Başarısız testleri yaz:**

```gdscript
me.inv[0] = {"kind": "weapon", "id": "grenade", "count": 1, "lvl": 1, "ammo": 1}
me._td_use(true)   # bas: pim
await _wait(0.4)
chk("basılı: pim çekildi, henüz atılmadı", me.busy == "prime" and me.fuse_left < 3.0 and me.fuse_left > 2.4, me.fuse_left)
me._release_throw()
await _wait(3.0)
chk("bırakınca atılır, sigortayla patlar", _names(td.hits).has("E1"))
me.inv[0].ammo = 1
me.busy = ""
me.hp = me.max_hp
me._td_use(true)
await _wait(3.3)
chk("elde patlarsa sahibine yarım hasar", me.hp == me.max_hp - int(Weapons.tuned("grenade", {}).dmg * 0.5), me.hp)
me.inv[0].ammo = 1; me.busy = ""; me.hp = me.max_hp
me._td_use(true)
await _wait(0.5)
me.td_hit(1000)
await _wait(3.0)
chk("pimliyken ölünce bomba yere düşüp patlar", me.fuse_left == 0.0 and get_tree().get_nodes_in_group("rockets").is_empty())
```

- [ ] **Adım 2: HATA.**
- [ ] **Adım 3: Uygula.**
  - Tutuş ve bırakma: `_local`'de `throw` bırakılınca `_release_throw()`.
  - Pim `prime` klibi `pin` olayıyla `fuse_left = w.fuse`, sonra her karede azalır; ≤ 0 ise `_cook_out()`.
  - `_release_throw()` → `vm.play("throw")`; `release` olayında `_td_shoot(id, w)` (`fuse_left` ile), `ammo = 0`, ardından `reload` (yeni bomba).
  - Ölüm (`td_hit` ile hp ≤ 0) pimliyken bombayı kalan sigortayla ayağa bırakır.
  - Bomba eşyası aynı akış, sonunda `_take`.
  - Roketler `"rockets"` grubuna eklenir (test sayımı için).
- [ ] **Adım 4: OK.**
- [ ] **Adım 5: Commit** — `feat: el bombası pim çek, beklet, at`

### Görev 8: Yay, keskin nişancı, bumerang, kılıç

**Dosyalar:**
- Değiştir: `player.gd`, `slipper.gd` (dönüşte `thrower.caught()`), `main.gd` (dürbün çerçevesi, Arena HUD), `td_ui.gd` (germe göstergesi)
- Test: `tests/weapons_test.gd`

**Arayüzler:**
- Üretir (`player.gd`):
  - `var draw_k := 0.0` (yay gerginliği 0..1)
  - `var scoped := false`
  - `var thrown := 0` (havadaki bumerang sayısı)
  - `var combo := 0`
  - `func caught() -> void`
  - `func _can_fire() -> bool`: `busy == ""`, `cd <= 0`, şarjör > 0 (şarjörlüyse), bumerangda `thrown < w.n`.
  - Yürüme çarpanı `_speed()` içine: germe ×0.8, dürbün ×0.65.

- [ ] **Adım 1: Başarısız testleri yaz:**

```gdscript
me.inv[0] = {"kind": "weapon", "id": "bow", "count": 1, "lvl": 1, "ammo": 1}
me.busy = ""
me._td_use(true)
await _wait(0.3)
td.hits.clear()
me._release_throw()
await _wait(0.6)
var weak: Array = td.hits.duplicate()
me.inv[0].ammo = 1; me.busy = ""
me._td_use(true)
await _wait(0.7)
td.hits.clear()
me._release_throw()
await _wait(0.6)
chk("yay: tam gerili güçlü, yarım gerili zayıf", weak.size() == 1 and td.hits.size() == 1 and td.hits[0][1] > weak[0][1], [weak, td.hits])
me.inv[0] = {"kind": "weapon", "id": "sniper", "count": 1, "lvl": 1, "ammo": 5}
me.scoped = true
chk("dürbün yürümeyi yavaşlatır", is_equal_approx(me._speed(), me.SPEED * me.ch.get("speed", 1.0) * 0.65), me._speed())
me.scoped = false
me.inv[0] = {"kind": "weapon", "id": "boomerang", "count": 1, "lvl": 1}
await _fire("boomerang", 0.05)
chk("bumerang havadayken yeniden atılmaz", me.thrown == 1 and not me._can_fire())
await _wait(6.0)
chk("dönünce yakalanır", me.thrown == 0)
me.inv[0] = {"kind": "weapon", "id": "sword", "count": 1, "lvl": 1}
var dm := []
for i in 3:
	me.cd = 0.0; me.busy = ""; td.hits.clear()
	me._td_use(true)
	await _wait(0.3)
	dm.append(td.hits[0][1] if td.hits else 0)
chk("kılıç 3'lü seri, üçüncü daha güçlü", dm[2] > dm[0] and me.combo == 0, dm)
```

- [ ] **Adım 2: HATA.**
- [ ] **Adım 3: Uygula.**
  - **Yay:** basınca `draw_string`, `draw_k` 0.6 sn'de 1'e çıkar. Bırakınca güç ve hız `lerp(0.4, 1.0, draw_k)` ile çarpılır. `release`, ardından `reload`.
  - **Keskin nişancı:**
    - `aim` basılıyken `scoped = true`;
    - `vm` gizlenir, kamera fov 20, `main` ortada dürbün çerçevesi gösterir;
    - `fire` klibindeki `chamber` sırasında dürbün kısa süre kapanır.
  - **Bumerang:** `td_fire` homing'de `thrown += 1`, `vm.show_part("body", false)`. `slipper.gd` dönüşte `thrower.caught()` → `thrown -= 1`, `catch` klibi. `_can_fire()`: bumerangda `thrown < w.n`.
  - **Kılıç:**
    - `combo` 0→1→2 arası döner, son vuruştan 0.6 sn sonra sıfırlanır;
    - klipler `swing1..3`, `fired` olayında `_td_arc`;
    - üçüncü vuruş hasar ×1.5 ve itme ×1.5; seriden sonra 0.35 sn toparlanma.
  - **Arena** (`td == null`): kılıç aynı serileri oynar, hasar Arena `SWORD_DMG` ile.
  - **Germe göstergesi** (`td_ui` ve Arena HUD'u): nişangâhın çevresinde `draw_k` kadar dolan ince yay; tam gerilince beyaz parlar.
- [ ] **Adım 4: OK.**
- [ ] **Adım 5: Commit** — `feat: yay germe, dürbün, bumerang yakalama, kılıç serisi`

### Görev 9: Eşyalar — iksir içme ve yapı yerleştirme

**Dosyalar:**
- Değiştir: `player.gd` (`_td_use` "item" potion, "build")
- Test: `tests/weapons_test.gd`

**Arayüzler:**
- Tüketir: `item:potion` `drink` (`gulp`), `busy`.
- Üretir: içerken `busy == "drink"`; `gulp` olayında `gain(d.heal)` ve `_take`.

- [ ] **Adım 1: Başarısız test yaz:**

```gdscript
me.inv[3] = {"kind": "item", "id": "potion", "count": 2, "lvl": 1}
me.slot = 4; me.busy = ""
me.hp = 20
me._td_use(true)
await _wait(0.2)
chk("iksir: hemen iyileştirmez, içiyor", me.hp == 20 and me.busy == "drink")
await _wait(0.5)
chk("yudumda +50 ve bir şişe eksilir", me.hp == 70 and me.inv[3].count == 1, [me.hp, me.inv[3]])
await _wait(0.5)
chk("içme bitti", me.busy == "")
```

- [ ] **Adım 2: HATA.**
- [ ] **Adım 3: Uygula.**
  - Yapı slotunda `vm.equip("")`: eller aşağıda.
  - Kurulunca `vm.play("place")`: iki el öne doğru kısa itiş, 0.25 sn. Bu klip Görev 4 verisine `"place"` id'siyle eklenir.
  - İksir ve bomba eşyası `vm.equip("item:potion")` ile şişe veya bombayı ele alır. Şişe modeli koddan kurulur: `viewmodel.gd` içinde `item:potion` için cam gövde (`glass` renk kırmızı) + mantar tıpa.
- [ ] **Adım 4: OK.**
- [ ] **Adım 5: Commit** — `feat: iksir içme ve yerleştirme animasyonu`

### Görev 10: Diğer oyuncuların gördüğü — parça klipleri ve sol kol

**Dosyalar:**
- Değiştir: `player.gd` (`td_anim`, `_pose` sol kol, prop'lara `AnimationPlayer`), `tests/td_net.gd`
- Test: `tests/td_net.gd`, `tests/shots.gd`

**Arayüzler:**
- Tüketir: `WeaponAnims.build(id, clip, true)` (Görev 4), parça adları (Görev 2), `grip_l`.
- Üretir:
  - Yerelde her `vm.play(clip)` çağrısı ayrıca `td_anim.rpc(clip)` yollar (Arena'da da). Uzak makinede prop'un `AnimationPlayer`'ı aynı klibi parts_only oynatır.
  - `_pose`: `b_larm`, `b_lfore` (sol kol kemikleri, `_load_model`'de sağ kolla aynı yolla bulunur) `grip_l` noktasına uzanır.
  - Bumerang havadayken uzaktaki prop da gizlenir.

- [ ] **Adım 1: Başarısız test yaz** (`tests/td_net.gd`'de host + istemci kurulu düzeneğe):

```gdscript
client_player.start_reload()
await _wait(0.4)
var prop: Node3D = host_view_of_client.props.get("pistol")
var ap: AnimationPlayer = prop.find_child("AnimationPlayer", true, false) if prop else null
chk("istemcinin doldurması host'ta oynuyor", ap != null and ap.current_animation == "reload", ap.current_animation if ap else "-")
chk("doldurma hasar yollamadı", td_host.hits.is_empty())
```

- [ ] **Adım 2: HATA.**
- [ ] **Adım 3: Uygula** (arayüz). Uzaktaki prop'lar `make_prop` ile geldiği için `AnimationPlayer`'ı `player.gd` ekler; animasyon kütüphanesi ilk kullanımda klip başına kurulur ve önbelleğe alınır.
- [ ] **Adım 4: `td_net` ve `shots` çalıştır.** `side.png`'de bir karakter sol eliyle silahı destekliyor.
- [ ] **Adım 5: Commit** — `feat: diğer oyunculara silah animasyonları ve sol kol`

### Görev 11: Görsel doğrulama ve son kontrol

**Dosyalar:**
- Değiştir: `tests/shots.gd` (yeni kareler)

- [ ] **Adım 1:** `shots.gd`'ye kareler ekle:
  - `fp_reload` (tabanca doldurma ortası, `mag_in` öncesi),
  - `fp_potion` (`gulp` anı),
  - `fp_bow` (tam gerili),
  - `fp_grenade` (pim çekik),
  - `fp_scope` (dürbün),
  - `fp_shotgun` (fişek sürme),
  - `fp_wall` (duvar dibinde silah, duvara girmemeli).

  Her kare `vm.play(...)` sonrası uygun beklemeyle.
- [ ] **Adım 2:** `tests/shots.tscn`'i çalıştır, her kareye bak. Eller karaktere bağlı görünmeli ve silah ekranın ~%30'unu kaplamalı.
- [ ] **Adım 3:** Bütün başsız testler (`weapons_test`, `skills`, `td_test`, `td_net`, `version_test`) OK.
- [ ] **Adım 4:** Dışa aktar, exe `-- --selftest` hatasız.
- [ ] **Adım 5: Commit** — `test: silah animasyonları ekran görüntüleri`
