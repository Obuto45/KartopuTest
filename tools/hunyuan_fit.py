"""Hunyuan3D çıktısını (renksiz, yüksek poligon) eski modelin yerine oturtur:
yönü ve boyutu eski modele göre bulur, sadeleştirir, her yüzün rengini eski modelin en yakın yüzeyinden alır.

  python tools/hunyuan_fit.py models/bazooka.glb art/hunyuan/bazooka/hunyuan.glb art/hunyuan/bazooka/bazooka_hunyuan.glb --ucgen 3000
Gerekenler: trimesh numpy scipy fast-simplification scikit-image
"""
import argparse
import itertools

import fast_simplification
import numpy as np
import trimesh
from scipy.spatial import cKDTree


def load_reference(path):
    """Eski model: dünya uzayında birleşik ağ + yüz başına malzeme no + malzeme listesi."""
    scene = trimesh.load(path, force="scene")
    parts, mats, face_mat = [], [], []
    for m in scene.dump(concatenate=False):
        mat = getattr(m.visual, "material", None)
        if mat not in mats:
            mats.append(mat)
        parts.append(m)
        face_mat.append(np.full(len(m.faces), mats.index(mat)))
    ref = trimesh.util.concatenate([trimesh.Trimesh(p.vertices, p.faces, process=False) for p in parts])
    return ref, np.concatenate(face_mat), mats


def rotations():
    """Eksen değiştiren 24 dik dönüş (yalnız ±1 ve 0, determinant +1)."""
    out = []
    for perm in itertools.permutations(range(3)):
        for signs in itertools.product([1, -1], repeat=3):
            r = np.zeros((3, 3))
            for i, (p, s) in enumerate(zip(perm, signs)):
                r[i, p] = s
            if np.isclose(np.linalg.det(r), 1.0):
                out.append(r)
    return out


def remesh(m, cells=180):
    """Kopuk / küp küp ağı (VoxelToMeshBasic çıktısı) hacme çevirip içini doldurur, tek parça pürüzsüz yüzey çıkarır."""
    vox = m.voxelized(pitch=m.extents.max() / cells).fill()
    out = vox.marching_cubes
    out.apply_transform(vox.transform)
    trimesh.smoothing.filter_taubin(out, iterations=10) # basamakları yumuşatır, hacmi korur
    return max(out.split(only_watertight=False), key=lambda b: len(b.faces)) # kopuk artıklar boyutu bozmasın


def fit(ref, src):
    """src'yi ref'e en iyi oturan dönüş + tekdüze ölçek + kayma ile taşır; (dönüştürülmüş src, ortalama uzaklık)."""
    ref_pts = ref.sample(20000)
    tree = cKDTree(ref_pts)
    ref_c, ref_ext = ref.bounds.mean(0), ref.extents
    best = None
    for r in rotations():
        v = (src.vertices - src.bounds.mean(0)) @ r.T
        ext = v.max(0) - v.min(0)
        v = v * (ref_ext.max() / ext.max()) + ref_c
        if np.any(np.abs((v.max(0) - v.min(0)) - ref_ext) > ref_ext.max() * 0.15):
            continue # eksenler uyuşmuyor (ör. uzun eksen yanlış)
        cand = trimesh.Trimesh(v, src.faces, process=False)
        d1, _ = tree.query(cand.sample(20000))
        d2, _ = cKDTree(cand.sample(20000)).query(ref_pts)
        err = (d1.mean() + d2.mean()) / 2 # iki yönlü chamfer
        if best is None or err < best[1]:
            best = (cand, err)
    if best is None:
        raise SystemExit("Hiçbir yönde eski modelin oranlarına uymadı")
    return best


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("eski")
    ap.add_argument("hunyuan")
    ap.add_argument("cikti")
    ap.add_argument("--ucgen", type=int, default=3000)
    a = ap.parse_args(argv)
    ref, ref_face_mat, mats = load_reference(a.eski)
    src = trimesh.load(a.hunyuan, force="mesh")
    print(f"eski: {len(ref.faces)} üçgen, {len(mats)} malzeme | hunyuan: {len(src.faces)} üçgen")
    if not src.is_watertight:
        src = remesh(src)
        print(f"yeniden yüzeylendi: {len(src.faces)} üçgen, tek parça={src.is_watertight}")
    src, err = fit(ref, src)
    print(f"oturma hatası: {err * 1000:.1f} mm (eski model boyu {ref.extents.max():.2f} m)")
    red = 1.0 - min(1.0, a.ucgen / len(src.faces))
    v, f = fast_simplification.simplify(src.vertices.astype(np.float32), src.faces.astype(np.int32), target_reduction=red)
    new = trimesh.Trimesh(v, f, process=True)
    trimesh.repair.fix_normals(new) # Hunyuan / voksel ağları içe dönük çıkabiliyor: yüzler dışa baksın (yoksa görünmez)
    if new.volume < 0:
        new.invert()
    # Renk: her yüzün merkezine en yakın eski yüzeyin malzemesi
    pts, fid = trimesh.sample.sample_surface(ref, 200000)
    _, near = cKDTree(pts).query(new.triangles_center)
    face_mat = ref_face_mat[fid[near]]
    scene = trimesh.Scene()
    for i, mat in enumerate(mats):
        sel = np.nonzero(face_mat == i)[0]
        if len(sel):
            part = new.submesh([sel], append=True)
            part.unmerge_vertices() # yüz başına normal: low-poly yontulmuş görünüm
            part.visual = trimesh.visual.TextureVisuals(material=mat)
            scene.add_geometry(part, geom_name=f"mat{i}")
    scene.export(a.cikti, include_normals=True) # normalsiz GLB'de Godot ışığı düz çizer
    print(f"yazıldı: {a.cikti} ({len(new.faces)} üçgen, {len(scene.geometry)} malzeme grubu)")
    return err


if __name__ == "__main__":
    main()
