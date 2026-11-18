# Oyun içi simgeler (ComfyUI)

46 simge tek stilde (low-poly, kalın hatlı, parlak, saydam arka plan) yerel ComfyUI ile üretilir:
stat, mağaza yapıları, eşyalar, dalga modifikatörleri, kalıcı yükseltmeler, zorluklar, Altın Saç ve başarımlar.
Silah simgeleri 3D modelden otomatik çizildiği için listede yok.

## Çalıştırma

1. ComfyUI'yi aç (varsayılan adres `http://127.0.0.1:8188`). `models/checkpoints` içinde bir SDXL modeli olmalı.
2. Proje kökünde, ComfyUI'nin Python'u ile:
   ```
   python art/comfyui/uret.py
   ```
   Çıktı: `icons/ui/<id>.png` (256x256). Var olan simgelerin üzerine yazmaz.

Seçenekler:
- `--sadece stat_hp,item_bomb`: yalnız bunlar
- `--tohum 7`: farklı varyasyon (beğenmediğin simgeyi `--sadece ... --tohum N --ustune-yaz` ile yeniden üret)
- `--model <dosya>`: belirli checkpoint (yoksa yüklü ilk SDXL modeli seçilir)
- `--adim 30`: örnekleme adımı

## Düzenleme

- Konu metinleri ve ortak stil: `simgeler.json` (`stil` içindeki `{konu}` her simgenin konusuyla değişir).
- Düğüm ayarları (çözünürlük, sampler, cfg): `workflow_api.json`. ComfyUI'de **Load** ile açıp değiştirebilirsin.
- Arka plan magenta üretilir ve köşelerden bağlı kısmı silinir; nesnenin içindeki mor renkler kalır.

Test (sahte ComfyUI ile): `python art/comfyui/test_uret.py`
