"""Yerel ComfyUI'deki Hunyuan3D ile 3D model üretir.
Hunyuan3D-2mv kuruluysa dört açıdan (front/left/back/right.png); yoksa tek görüntülü model (ör. 2.1) ile three_quarter.png'den.

Kullanım (ComfyUI açıkken; yalnız standart kütüphane):
  python art/hunyuan/hunyuan_mv.py art/hunyuan/bazooka
  python art/hunyuan/hunyuan_mv.py art/hunyuan/bazooka --tohum 3 --cozunurluk 384
Çıktı: <klasör>/hunyuan.glb (renksiz şekil; renkler oyuna alınırken eski modelden aktarılır).
Görüntüler tools/mv_render.gd ile modelden çizilir.
"""
import argparse
import json
import os
import sys
import time
import urllib.parse
import urllib.request
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
VIEWS = {"front": "10", "left": "11", "back": "12", "right": "13"}
SINGLE_VIEW = "three_quarter" # tek görüntülü modelde derinliği en iyi gösteren açı


def _get(url):
    with urllib.request.urlopen(url, timeout=60) as r:
        return r.read()


def _post_json(url, body):
    req = urllib.request.Request(url, json.dumps(body).encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())


def upload(server, path, name):
    """ComfyUI /upload/image (multipart); yüklenen dosyanın adını döner."""
    b = uuid.uuid4().hex
    data = open(path, "rb").read()
    body = (f"--{b}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"{name}\"\r\n"
            f"Content-Type: image/png\r\n\r\n").encode() + data + \
        f"\r\n--{b}\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n--{b}--\r\n".encode()
    req = urllib.request.Request(server + "/upload/image", body, {"Content-Type": "multipart/form-data; boundary=" + b})
    with urllib.request.urlopen(req, timeout=60) as r:
        res = json.loads(r.read())
    return (res.get("subfolder", "") + "/" if res.get("subfolder") else "") + res["name"]


def to_single(wf):
    """Dört açılı iş akışını tek görüntülü olana çevirir (Hunyuan3D 2.1 vb.): yalnız düğüm 11 / 21 kalır."""
    for n in ["10", "12", "13", "20", "22", "23"]:
        del wf[n]
    wf["30"] = {"class_type": "Hunyuan3Dv2Conditioning", "inputs": {"clip_vision_output": ["21", 0]}}
    wf["31"]["inputs"]["resolution"] = 4096 # shortcut: 2.1 şablonunun değeri varsayıldı; hata verirse --gizil 3072 dene
    return {SINGLE_VIEW: "11"}


def setup(server, wf):
    """Kurulu modele göre iş akışını hazırlar; eksik düğüm ya da model varsa çalıştırmadan söyler. Görüntü -> düğüm döner."""
    info = json.loads(_get(server + "/object_info"))
    loader = info.get("ImageOnlyCheckpointLoader")
    ckpts = loader["input"]["required"]["ckpt_name"][0] if loader else []
    want = wf["1"]["inputs"]["ckpt_name"]
    hy = [c for c in ckpts if "hunyuan" in c.lower()]
    mv = [c for c in hy if "mv" in c.lower()]
    views = VIEWS
    if want in ckpts:
        pass
    elif mv:
        wf["1"]["inputs"]["ckpt_name"] = mv[0]
    elif hy:
        wf["1"]["inputs"]["ckpt_name"] = hy[0]
        views = to_single(wf)
    else:
        sys.exit(f"Hunyuan3D modeli bulunamadı. models/checkpoints içindekiler: {', '.join(ckpts) or '(boş)'}")
    print("Model:", wf["1"]["inputs"]["ckpt_name"], "| mod:", "4 açı" if views is VIEWS else "tek görüntü (" + SINGLE_VIEW + ")")
    missing = sorted({n["class_type"] for n in wf.values()} - set(info))
    if missing:
        sys.exit("ComfyUI'de eksik düğümler: " + ", ".join(missing) +
                 "\nComfyUI'yi güncelle (bunlar ComfyUI'nin kendi Hunyuan3D desteği).")
    return views


def run(server, folder, seed, res, latent=0, wait=1800):
    wf = json.load(open(os.path.join(HERE, "workflow_mv_api.json"), encoding="utf-8"))
    views = setup(server, wf)
    if latent:
        wf["31"]["inputs"]["resolution"] = latent
    name = os.path.basename(os.path.normpath(folder))
    for view, node in views.items():
        wf[node]["inputs"]["image"] = upload(server, os.path.join(folder, view + ".png"), f"kartopu_{name}_{view}.png")
    wf["40"]["inputs"]["seed"] = seed
    wf["50"]["inputs"]["octree_resolution"] = res
    wf["60"]["inputs"]["filename_prefix"] = "mesh/kartopu_" + name
    pid = _post_json(server + "/prompt", {"prompt": wf})["prompt_id"]
    print("Kuyrukta:", pid, "(ilk çalıştırma model yüklendiği için birkaç dakika sürebilir)")
    t0 = time.time()
    while time.time() - t0 < wait:
        hist = json.loads(_get(server + "/history/" + pid))
        if pid in hist:
            for out in hist[pid].get("outputs", {}).values():
                for items in out.values():
                    for it in items if isinstance(items, list) else []:
                        if isinstance(it, dict) and str(it.get("filename", "")).endswith(".glb"):
                            q = urllib.parse.urlencode({"filename": it["filename"], "subfolder": it.get("subfolder", ""), "type": it.get("type", "output")})
                            dst = os.path.join(folder, "hunyuan.glb")
                            open(dst, "wb").write(_get(server + "/view?" + q))
                            print("Kaydedildi:", dst, f"({os.path.getsize(dst) // 1024} KB)")
                            return dst
            sys.exit("ComfyUI GLB döndürmedi: " + json.dumps(hist[pid].get("status", {}), ensure_ascii=False)[:500])
        time.sleep(2.0)
    sys.exit("Zaman aşımı")


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("klasor", help="front/left/back/right.png içeren klasör")
    ap.add_argument("--sunucu", default="http://127.0.0.1:8188")
    ap.add_argument("--tohum", type=int, default=1)
    ap.add_argument("--cozunurluk", type=int, default=256, help="octree çözünürlüğü (yüksek = daha detaylı, daha yavaş)")
    ap.add_argument("--gizil", type=int, default=0, help="EmptyLatentHunyuan3Dv2 çözünürlüğü (0 = moda göre)")
    a = ap.parse_args(argv)
    return run(a.sunucu.rstrip("/"), a.klasor, a.tohum, a.cozunurluk, a.gizil)


if __name__ == "__main__":
    main()
