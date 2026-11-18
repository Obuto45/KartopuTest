"""hunyuan_mv.py için sahte ComfyUI ile uçtan uca test: python art/hunyuan/test_hunyuan.py"""
import http.server
import json
import os
import shutil
import tempfile
import threading

import hunyuan_mv

GLB = b"glTF\x02\x00\x00\x00fake"


class H(http.server.BaseHTTPRequestHandler):
    uploads = []
    prompts = []

    def log_message(self, *a):
        pass

    def _send(self, body, ctype="application/json"):
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/object_info":
            wf = json.load(open(os.path.join(hunyuan_mv.HERE, "workflow_mv_api.json")))
            info = {n["class_type"]: {} for n in wf.values()}
            info["ImageOnlyCheckpointLoader"] = {"input": {"required": {"ckpt_name": [["sdxl.safetensors", "hunyuan3d-dit-v2-mv-fp16.safetensors"]]}}}
            self._send(json.dumps(info).encode())
        elif self.path.startswith("/history/"):
            pid = self.path.rsplit("/", 1)[1]
            self._send(json.dumps({pid: {"outputs": {"60": {"3d": [{"filename": "kartopu_00001_.glb", "subfolder": "mesh", "type": "output"}]}}}}).encode())
        elif self.path.startswith("/view"):
            assert "subfolder=mesh" in self.path
            self._send(GLB, "model/gltf-binary")

    def do_POST(self):
        body = self.rfile.read(int(self.headers["Content-Length"]))
        if self.path == "/upload/image":
            name = body.split(b'filename="', 1)[1].split(b'"', 1)[0].decode()
            H.uploads.append(name)
            self._send(json.dumps({"name": name, "subfolder": "", "type": "input"}).encode())
        else:
            H.prompts.append(json.loads(body)["prompt"])
            self._send(json.dumps({"prompt_id": "p1"}).encode())


def main():
    srv = http.server.HTTPServer(("127.0.0.1", 0), H)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    with tempfile.TemporaryDirectory() as tmp:
        d = os.path.join(tmp, "bazooka")
        os.makedirs(d)
        for v in hunyuan_mv.VIEWS:
            shutil.copy(os.path.join(hunyuan_mv.HERE, "bazooka", v + ".png"), d)
        out = hunyuan_mv.main([d, "--sunucu", f"http://127.0.0.1:{srv.server_port}", "--tohum", "5"])
        assert open(out, "rb").read() == GLB
        assert len(H.uploads) == 4 and "kartopu_bazooka_left.png" in H.uploads
        g = H.prompts[0]
        assert g["1"]["inputs"]["ckpt_name"] == "hunyuan3d-dit-v2-mv-fp16.safetensors" # adı farklı mv modeline düşer
        assert g["11"]["inputs"]["image"] == "kartopu_bazooka_left.png" and g["40"]["inputs"]["seed"] == 5
    srv.shutdown()
    print("HUNYUAN_TEST: OK")


if __name__ == "__main__":
    main()
