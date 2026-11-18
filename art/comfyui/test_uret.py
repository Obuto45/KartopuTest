"""uret.py için sahte ComfyUI sunucusuyla uçtan uca test: python art/comfyui/test_uret.py"""
import http.server
import io
import json
import os
import tempfile
import threading

from PIL import Image, ImageDraw

import uret


def fake_png():
    # magenta zemin; ortada içi mor (magentaya yakın) halkalı sarı bir disk: iç mor silinmemeli
    im = Image.new("RGB", (1024, 1024), (255, 0, 255))
    d = ImageDraw.Draw(im)
    d.ellipse((300, 300, 724, 724), fill=(20, 20, 20))
    d.ellipse((320, 320, 704, 704), fill=(240, 200, 40))
    d.ellipse((460, 460, 564, 564), fill=(230, 20, 230))
    out = io.BytesIO()
    im.save(out, "PNG")
    return out.getvalue()


class H(http.server.BaseHTTPRequestHandler):
    prompts = []

    def log_message(self, *a):
        pass

    def _send(self, body, ctype="application/json"):
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/object_info/"):
            self._send(json.dumps({"CheckpointLoaderSimple": {"input": {"required": {"ckpt_name": [["a.ckpt", "myXL.safetensors"]]}}}}).encode())
        elif self.path.startswith("/history/"):
            pid = self.path.rsplit("/", 1)[1]
            self._send(json.dumps({pid: {"outputs": {"9": {"images": [{"filename": "x.png", "subfolder": "", "type": "output"}]}}}}).encode())
        elif self.path.startswith("/view"):
            self._send(fake_png(), "image/png")

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        H.prompts.append(body["prompt"])
        self._send(json.dumps({"prompt_id": str(len(H.prompts))}).encode())


def main():
    srv = http.server.HTTPServer(("127.0.0.1", 0), H)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    with tempfile.TemporaryDirectory() as tmp:
        uret.OUT = tmp
        n = uret.main(["--sunucu", f"http://127.0.0.1:{srv.server_port}", "--sadece", "stat_hp,mod_night"])
        assert n == 2, n
        g = H.prompts[0]
        assert g["4"]["inputs"]["ckpt_name"] == "myXL.safetensors" # istenen yoksa XL olana düşer
        assert "a big shiny red heart" in g["6"]["inputs"]["text"] and "{konu}" not in g["6"]["inputs"]["text"]
        im = Image.open(os.path.join(tmp, "stat_hp.png"))
        assert im.size == (256, 256) and im.mode == "RGBA"
        assert im.getpixel((2, 2))[3] == 0, "köşe saydam olmalı"
        c = im.getpixel((128, 128))
        assert c[3] == 255 and c[0] > 200 and c[2] > 200, f"nesnenin içindeki mor korunmalı: {c}"
        assert uret.main(["--sunucu", f"http://127.0.0.1:{srv.server_port}", "--sadece", "stat_hp"]) == 0 # var olanı ezmez
    srv.shutdown()
    print("URET_TEST: OK")


if __name__ == "__main__":
    main()
