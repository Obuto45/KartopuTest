#!/usr/bin/env python3
"""Görünen Türkçe metinleri toplayıp locale/en.po iskeletini üretir / günceller.

Kaynak dil Türkçe: msgid Türkçe metnin kendisidir. Var olan msgstr'ler korunur, yeni dizgeler boş msgstr ile eklenir,
koddan kalkanlar "#~" ile değil, doğrudan silinir (git geçmişi yeter).
  python3 tools/extract_strings.py            # locale/en.po'yu günceller
  python3 tools/extract_strings.py --check    # boş msgstr sayısını yazar, varsa 1 ile çıkar
Kaynaklar:
  * kod dosyaları (CODE): bütün dizge sabitleri; teknik olanlar (id, yol, düğüm/animasyon adı) süzülür
  * veri tabloları (DATA): yalnız görünen alanlar (name, desc, role, skill_name, skill_desc, quote)
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PO = os.path.join(ROOT, "locale", "en.po")
CODE = ["main.gd", "td_ui.gd", "player.gd", "net.gd", "settings.gd", "updater.gd"]
DATA = ["characters.gd", "weapons.gd", "balance.gd"]
DATA_KEYS = ("name", "desc", "role", "skill_name", "skill_desc", "quote")
LIT = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
# Görünmeyen ama harf içeren sabitler (düğüm, sınıf, animasyon, tuş adları, Steam / HTTP alanları).
STOP = {
    "WorldEnvironment", "DirectionalLight3D", "MeshInstance3D", "AnimationPlayer", "Skeleton3D", "Label3D", "Node3D",
    "Idle", "Run", "Walk", "Jump", "Death", "Head", "Master", "Button", "PanelContainer", "OptionButton", "BigButton",
    "Control", "Label", "Crew", "World", "Players", "TD", "LIST", "RARITY", "STATS", "ITEMS", "EQUIPS", "SHOP",
    "WAVE_COUNT", "RESPAWN_TIME", "Steam", "B", "G", "H", "Q", "R", "TAB", "Impact", "Arial Black", "Sans-Serif",
    "Rig", "Rig/Weapon", "HandL", "HandR", "Shoot_OneHanded", "SwordSlash", "Weapon", "UpperArm.L", "UpperArm.R",
    "Interact", "Hit_A", "Hit_B", "Sword", "Accept: application/vnd.github+json", "User-Agent: KartopuTest-Updater",
    "UPS", "EVOS", "CHAR_UPS", "LowerArm.R", "LowerArm.L", "Windows", "_Windows.zip", "Obuto45/KartopuTest", "●  Steam: ",
    "Türkçe", "English", "Steam başlatılamadı: %s", # dil adları kendi dilinde; push_warning görünmez
}


def unescape(s):
    return s.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")


def visible(s):
    if not re.search(r"[A-Za-zÇĞİÖŞÜçğıöşü]", s) or s in STOP:
        return False
    if "://" in s or s.startswith("/") or s.startswith("ACH_") or s.startswith("--") or "shader_type" in s or "\\d" in s:
        return False
    if len(re.findall(r"[A-Za-zÇĞİÖŞÜçğıöşü]", re.sub(r"%[-+]?\d*(\.\d+)?[sdf%]", "", s))) < 2: # yalnız biçim + tek harf
        return False
    if "%" not in s and re.fullmatch(r"[a-z0-9_:./#\-*{}\[\]]+", s): # id, anahtar, eylem, yol
        return False
    if re.fullmatch(r"[A-Za-z][A-Za-z0-9]*([_%][A-Za-z0-9]+)+", s): # SABİT_ADI, Anim_Adı, W%d_%d
        return False
    if re.fullmatch(r"(font|outline|shadow|margin|h|v)_[a-z_]+|[a-z_]+_(color|size|separation)", s):
        return False
    return True


def strip_comments(line):
    # '#' dizge içinde değilse yorumdur
    out, q = [], False
    i = 0
    while i < len(line):
        c = line[i]
        if c == "\\" and q:
            out.append(line[i:i + 2]); i += 2; continue
        if c == '"':
            q = not q
        if c == "#" and not q:
            break
        out.append(c); i += 1
    return "".join(out)


def collect():
    found = {} # msgid -> [konum, ...] (sıra korunur)
    def add(s, where):
        found.setdefault(s, []).append(where)
    for f in CODE:
        text = open(os.path.join(ROOT, f), encoding="utf-8").read()
        # çok satırlı dizgeler (main.gd'de "%d\n\n%s") de yakalansın diye satır satır değil, yorumlar atılıp toplu
        lines = [strip_comments(l) for l in text.split("\n")]
        joined = "\n".join(lines)
        for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', joined):
            s = unescape(m.group(1))
            if s.startswith('""') or '"""' in m.group(0):
                continue
            if visible(s) or joined[max(0, m.start() - 3):m.start()] == "tr(": # tr("%%%d") gibi harfsizler de
                add(s, "%s:%d" % (f, joined.count("\n", 0, m.start()) + 1))
    key_re = re.compile(r'"(%s)":\s*"((?:[^"\\]|\\.)*)"' % "|".join(DATA_KEYS))
    for f in DATA:
        for n, line in enumerate(open(os.path.join(ROOT, f), encoding="utf-8"), 1):
            if line.lstrip().startswith("#"):
                continue
            for m in key_re.finditer(line):
                s = unescape(m.group(2))
                if re.search(r"[A-Za-zÇĞİÖŞÜçğıöşü]", s):
                    add(s, "%s:%d" % (f, n))
    return found


def po_escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")


def po_unescape(s):
    return re.sub(r'\\(.)', lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), s)


def read_po(path):
    """msgid -> msgstr (başlık hariç)."""
    out = {}
    if not os.path.exists(path):
        return out
    cur, key = {"msgid": None, "msgstr": None}, None
    def flush():
        if cur["msgid"]:
            out[cur["msgid"]] = cur["msgstr"] or ""
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        if line.startswith("msgid "):
            flush()
            cur = {"msgid": po_unescape(line[7:-1]), "msgstr": None}
            key = "msgid"
        elif line.startswith("msgstr "):
            cur["msgstr"] = po_unescape(line[8:-1])
            key = "msgstr"
        elif line.startswith('"') and key:
            cur[key] = (cur[key] or "") + po_unescape(line[1:-1])
    flush()
    return out


def write_po(path, found, tr):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write('# Bazuka Savaşı / Bazooka Buddies: İngilizce çeviri. Kaynak dil Türkçe (msgid = Türkçe metin).\n')
        f.write('# İskelet: python3 tools/extract_strings.py (var olan çeviriler korunur).\n')
        f.write('msgid ""\nmsgstr ""\n"Content-Type: text/plain; charset=UTF-8\\n"\n"Language: en\\n"\n')
        for s, where in found.items():
            f.write("\n#: %s\n" % " ".join(where[:4]))
            f.write('msgid "%s"\nmsgstr "%s"\n' % (po_escape(s), po_escape(tr.get(s, ""))))


def main():
    found = collect()
    old = read_po(PO)
    if "--check" in sys.argv:
        empty = [s for s in found if not old.get(s)]
        for s in empty:
            print("ÇEVRİLMEMİŞ:", repr(s))
        print("dizge: %d, çevrilmemiş: %d" % (len(found), len(empty)))
        sys.exit(1 if empty else 0)
    write_po(PO, found, old)
    print("%s: %d dizge, %d çevrili" % (os.path.relpath(PO, ROOT), len(found), sum(1 for s in found if old.get(s))))


if __name__ == "__main__":
    main()
