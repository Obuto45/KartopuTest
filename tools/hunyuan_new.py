"""Yeni nesne: Hunyuan3D çıktısını (renksiz) eski model olmadan oyuna hazırlar.
Tek parça yüzey yapar, dik oturtur, hedef boya ölçekler, sadeleştirir; renkleri girdi görselinden yansıtıp
birkaç düz renge indirir (low-poly görünüm).

  python tools/hunyuan_new.py art/hunyuan/sandik/hunyuan.glb art/hunyuan/sandik/three_quarter.png models/chest.glb --boy 0.6
Gerekenler: trimesh numpy scipy fast-simplification scikit-image pillow
"""
import argparse

import fast_simplification
import numpy as np
import trimesh
from PIL import Image, ImageDraw
from scipy.cluster.vq import kmeans2

from hunyuan_fit import remesh

RES = 256 # siluet karşılaştırma çözünürlüğü


def mask_of(img):
    """Beyaz (açık) zemin dışındaki pikseller: nesne."""
    a = np.asarray(img.convert("RGB"), dtype=np.float32)
    return a.min(axis=2) < 235


def view_basis(az, el):
    """Kameranın sağ / yukarı / ileri vektörleri (dünya Y yukarı). az: Y etrafında, el: yukarıdan bakış."""
    f = np.array([np.sin(az) * np.cos(el), -np.sin(el), -np.cos(az) * np.cos(el)]) # kameradan nesneye
    r = np.cross(f, [0, 1, 0])
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    return r, u, f


def project(verts, az, el, box):
    """Ortografik izdüşüm; box: hedef görüntüdeki nesne kutusu (x0, y0, x1, y1) piksel."""
    r, u, f = view_basis(az, el)
    p = np.stack([verts @ r, -(verts @ u)], axis=1)
    lo, hi = p.min(0), p.max(0)
    s = min((box[2] - box[0]) / max(hi[0] - lo[0], 1e-6), (box[3] - box[1]) / max(hi[1] - lo[1], 1e-6))
    off = np.array([(box[0] + box[2]) / 2, (box[1] + box[3]) / 2]) - (lo + hi) / 2 * s
    return p * s + off, verts @ f


def silhouette(mesh, xy, size):
    im = Image.new("L", size, 0)
    d = ImageDraw.Draw(im)
    for tri in mesh.faces:
        d.polygon([tuple(xy[i]) for i in tri], fill=255)
    return np.asarray(im) > 0


def find_view(mesh, img):
    """Görseldeki siluete en iyi uyan bakış açısı (IoU ile kaba tarama)."""
    small = img.convert("RGB").resize((RES, RES))
    target = mask_of(small)
    ys, xs = np.nonzero(target)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    best = (-1, 0, 0)
    low = mesh.simplify_quadric_decimation(face_count=1500) if len(mesh.faces) > 1500 else mesh
    for az in np.radians(np.arange(0, 360, 10)):
        for el in np.radians([0, 10, 20, 30, 40, 50]):
            xy, _ = project(low.vertices, az, el, box)
            sil = silhouette(low, xy, (RES, RES))
            iou = (sil & target).sum() / max((sil | target).sum(), 1)
            if iou > best[0]:
                best = (iou, az, el)
    return best, box


def colorize(mesh, img, az, el, box, k):
    """Kameraya bakan yüzlere görselden renk al, gerisini en yakın boyanmış yüzden doldur; k renge indir."""
    W, H = img.size
    sb = (box[0] * W / RES, box[1] * H / RES, box[2] * W / RES, box[3] * H / RES)
    xy, depth = project(mesh.vertices, az, el, sb)
    _, _, f = view_basis(az, el)
    rgb = np.asarray(img.convert("RGB"), dtype=np.float32) / 255.0
    centers = xy[mesh.faces].mean(axis=1)
    facing = mesh.face_normals @ f < -0.15
    # Görünürlük: yüz merkezinin derinliği, o pikseldeki en öndeki derinliğe yakın mı (z-buffer yerine nokta testi)
    zbuf = np.full((H, W), np.inf)
    fd = depth[mesh.faces].mean(axis=1)
    order = np.argsort(-fd)
    zim = Image.new("I", (W, H), 0)
    d = ImageDraw.Draw(zim)
    for i in order: # uzaktan yakına çiz: en son yazılan en öndeki
        d.polygon([tuple(xy[j]) for j in mesh.faces[i]], fill=int(i) + 1)
    top = np.asarray(zim)
    cx = np.clip(centers[:, 0].astype(int), 0, W - 1)
    cy = np.clip(centers[:, 1].astype(int), 0, H - 1)
    visible = facing & (top[cy, cx] == np.arange(len(mesh.faces)) + 1)
    visible &= rgb[cy, cx].min(axis=1) < 235 / 255 # siluet kenarında zemine düşen örnekler sayılmasın
    col = np.zeros((len(mesh.faces), 3))
    col[visible] = rgb[cy[visible], cx[visible]]
    if visible.sum() == 0:
        raise SystemExit("Hiçbir yüz görselde görünmüyor; bakış açısı bulunamadı")
    from scipy.spatial import cKDTree
    _, near = cKDTree(mesh.triangles_center[visible]).query(mesh.triangles_center[~visible])
    col[~visible] = col[visible][near]
    pal, lab = kmeans2(col[visible], k, seed=1, minit="++")
    _, lab_all = cKDTree(pal).query(col)
    return pal, lab_all, visible.mean()


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("hunyuan")
    ap.add_argument("gorsel")
    ap.add_argument("cikti")
    ap.add_argument("--boy", type=float, default=0.6, help="en uzun kenar (m)")
    ap.add_argument("--ucgen", type=int, default=2500)
    ap.add_argument("--renk", type=int, default=6, help="düz renk sayısı")
    a = ap.parse_args(argv)
    m = trimesh.load(a.hunyuan, force="mesh")
    if not m.is_watertight:
        m = remesh(m)
    m.apply_translation(-m.bounds.mean(0))
    m.apply_scale(a.boy / m.extents.max())
    red = 1.0 - min(1.0, a.ucgen / len(m.faces))
    v, f = fast_simplification.simplify(m.vertices.astype(np.float32), m.faces.astype(np.int32), target_reduction=red)
    m = trimesh.Trimesh(v, f, process=True)
    trimesh.repair.fix_normals(m)
    img = Image.open(a.gorsel)
    (iou, az, el), box = find_view(m, img)
    print(f"bakış: azimut {np.degrees(az):.0f}°, yükseklik {np.degrees(el):.0f}°, siluet uyumu {iou:.2f}")
    pal, lab, seen = colorize(m, img, az, el, box, a.renk)
    print(f"görselden boyanan yüz oranı: {seen:.0%}")
    m.apply_translation([0, -m.bounds[0][1], 0]) # tabanı y=0'a
    scene = trimesh.Scene()
    for i, c in enumerate(pal):
        sel = np.nonzero(lab == i)[0]
        if len(sel):
            part = m.submesh([sel], append=True)
            lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4) # görsel sRGB, glTF rengi doğrusal
            mat = trimesh.visual.material.PBRMaterial(baseColorFactor=list((np.clip(lin, 0, 1) * 255).round().astype(int)) + [255],
                                                      roughnessFactor=0.7, metallicFactor=0.0, name=f"renk{i}")
            part.visual = trimesh.visual.TextureVisuals(material=mat)
            scene.add_geometry(part, geom_name=f"renk{i}")
    scene.export(a.cikti)
    print(f"yazıldı: {a.cikti} ({len(m.faces)} üçgen, {len(scene.geometry)} renk, boy {m.extents.max():.2f} m)")
    return iou


if __name__ == "__main__":
    main()
