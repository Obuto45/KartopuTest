"""relief_colors için küçük kontrol: python tools/test_hunyuan_new.py"""
import numpy as np
import trimesh

from hunyuan_new import relief_colors

# Ortasından kabartma kuşak geçen küre (köşesiz, kabartma yalnız kuşak): kuşak yüzleri ikinci renge boyanmalı
body = trimesh.creation.icosphere(subdivisions=4)
v = body.vertices.copy()
band = np.abs(v[:, 1]) < 0.2
v[band] *= 1.08
m = trimesh.Trimesh(v, body.faces)
pal, lab = relief_colors(m, "8c552d", "ebb432")
on_band = band[m.faces].all(1)
assert lab[on_band].mean() > 0.6 and lab[~on_band].mean() < 0.2, (lab[on_band].mean(), lab[~on_band].mean())
assert np.allclose(pal[1], [0xeb / 255, 0xb4 / 255, 0x32 / 255])
print("HUNYUAN_NEW_TEST: OK")
