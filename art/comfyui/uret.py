"""Oyun içi simgeleri yerel ComfyUI ile üretir: simgeler.json -> icons/ui/<id>.png (256x256, saydam arka plan).

Kullanım (ComfyUI açıkken, ComfyUI'nin Python'u ile; Pillow orada zaten var):
  python art/comfyui/uret.py                      # hepsi
  python art/comfyui/uret.py --sadece stat_hp,item_bomb --tohum 7
  python art/comfyui/uret.py --model juggernautXL.safetensors --adim 30
Yalnız standart kütüphane + Pillow. Var olan dosyanın üzerine yazmaz (--ustune-yaz ile yazar).
"""
import argparse
import io
import json
import os
import sys
import time
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "icons", "ui")
SIZE = 256


def _get(url):
    with urllib.request.urlopen(url, timeout=30) as r:
        return r.read()


def _post(url, body):
    req = urllib.request.Request(url, json.dumps(body).encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())


def pick_model(server, wanted):
    """İstenen checkpoint yoksa ComfyUI'deki ilk SDXL benzeri modele düşer."""
    info = json.loads(_get(server + "/object_info/CheckpointLoaderSimple"))
    names = info["CheckpointLoaderSimple"]["input"]["required"]["ckpt_name"][0]
    if not names:
        sys.exit("ComfyUI'de hiç checkpoint yok: models/checkpoints klasörüne bir SDXL modeli koy.")
    if wanted in names:
        return wanted
    xl = [n for n in names if "xl" in n.lower()]
    print(f"'{wanted}' yok; kullanılan: {(xl or names)[0]}  (seçenekler: {', '.join(names)})")
    return (xl or names)[0]


def make_icon(png_bytes):
    """Köşelerden bağlı magenta arka planı siler (nesnenin içindeki mor kalır), kırpar, 256 kareye oturtur."""
    from PIL import Image, ImageDraw
    im = Image.open(io.BytesIO(png_bytes)).convert("RGBA")
    w, h = im.size
    for corner in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        if im.getpixel(corner)[3] > 0:
            ImageDraw.floodfill(im, corner, (0, 0, 0, 0), thresh=90)
    box = im.getbbox() or (0, 0, w, h)
    im = im.crop(box)
    side = int(max(im.size) * 1.08) # kenarda biraz boşluk
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(im, ((side - im.size[0]) // 2, (side - im.size[1]) // 2))
    out = io.BytesIO()
    canvas.resize((SIZE, SIZE), Image.LANCZOS).save(out, "PNG")
    return out.getvalue()


def generate(server, wf, item, style, negative, seed, wait=600):
    g = json.loads(json.dumps(wf))
    g["6"]["inputs"]["text"] = style.replace("{konu}", item["konu"])
    g["7"]["inputs"]["text"] = negative
    g["3"]["inputs"]["seed"] = seed
    g["9"]["inputs"]["filename_prefix"] = "kartopu_" + item["id"]
    pid = _post(server + "/prompt", {"prompt": g})["prompt_id"]
    t0 = time.time()
    while time.time() - t0 < wait:
        hist = json.loads(_get(server + "/history/" + pid))
        if pid in hist:
            for node in hist[pid]["outputs"].values():
                for img in node.get("images", []):
                    q = urllib.parse.urlencode({"filename": img["filename"], "subfolder": img["subfolder"], "type": img["type"]})
                    return _get(server + "/view?" + q)
            raise RuntimeError("ComfyUI görüntü döndürmedi: " + json.dumps(hist[pid].get("status", {})))
        time.sleep(1.0)
    raise TimeoutError(item["id"] + " zaman aşımı")


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--sunucu", default="http://127.0.0.1:8188")
    ap.add_argument("--model", default="sd_xl_base_1.0.safetensors")
    ap.add_argument("--sadece", default="", help="virgülle id listesi")
    ap.add_argument("--tohum", type=int, default=1)
    ap.add_argument("--adim", type=int, default=28)
    ap.add_argument("--ustune-yaz", action="store_true")
    a = ap.parse_args(argv)
    server = a.sunucu.rstrip("/")
    spec = json.load(open(os.path.join(HERE, "simgeler.json"), encoding="utf-8"))
    wf = json.load(open(os.path.join(HERE, "workflow_api.json"), encoding="utf-8"))
    wf["4"]["inputs"]["ckpt_name"] = pick_model(server, a.model)
    wf["3"]["inputs"]["steps"] = a.adim
    only = {s.strip() for s in a.sadece.split(",") if s.strip()}
    items = [i for i in spec["simgeler"] if not only or i["id"] in only]
    os.makedirs(OUT, exist_ok=True)
    done = 0
    for n, item in enumerate(items, 1):
        path = os.path.join(OUT, item["id"] + ".png")
        if os.path.exists(path) and not a.ustune_yaz:
            print(f"[{n}/{len(items)}] {item['id']}: var, atlandı")
            continue
        raw = generate(server, wf, item, spec["stil"], spec["negatif"], a.tohum + n)
        open(path, "wb").write(make_icon(raw))
        done += 1
        print(f"[{n}/{len(items)}] {item['id']} -> {os.path.relpath(path, ROOT)}")
    print(f"Bitti: {done} simge üretildi.")
    return done


if __name__ == "__main__":
    main()
