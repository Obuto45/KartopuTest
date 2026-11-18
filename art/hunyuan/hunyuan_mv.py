"""Yerel ComfyUI'deki Hunyuan3D-2mv ile dört açıdan (front/left/back/right.png) 3D model üretir.

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


def check_nodes(server, wf):
    """Eksik düğüm ya da model varsa çalıştırmadan söyler."""
    info = json.loads(_get(server + "/object_info"))
    missing = sorted({n["class_type"] for n in wf.values()} - set(info))
    if missing:
        sys.exit("ComfyUI'de eksik düğümler: " + ", ".join(missing) +
                 "\nComfyUI'yi güncelle (bu düğümler ComfyUI'nin kendi Hunyuan3D v2 desteği).")
    ckpts = info["ImageOnlyCheckpointLoader"]["input"]["required"]["ckpt_name"][0]
    want = wf["1"]["inputs"]["ckpt_name"]
    if want not in ckpts:
        mv = [c for c in ckpts if "hunyuan" in c.lower() and "mv" in c.lower()]
        if not mv:
            sys.exit(f"Hunyuan3D-2mv modeli bulunamadı ({want}). models/checkpoints içindekiler: {', '.join(ckpts)}")
        print(f"'{want}' yok; kullanılan: {mv[0]}")
        wf["1"]["inputs"]["ckpt_name"] = mv[0]


def run(server, folder, seed, res, wait=1800):
    wf = json.load(open(os.path.join(HERE, "workflow_mv_api.json"), encoding="utf-8"))
    check_nodes(server, wf)
    name = os.path.basename(os.path.normpath(folder))
    for view, node in VIEWS.items():
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
    a = ap.parse_args(argv)
    return run(a.sunucu.rstrip("/"), a.klasor, a.tohum, a.cozunurluk)


if __name__ == "__main__":
    main()
