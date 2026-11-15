"""Prepara las imagenes del minijuego de sembrar a partir de las de Gemini.

Uso: python prep_siembra_imgs.py <carpeta_con_las_imagenes> <carpeta_de_salida>

Salida:
  fondo_vacio.png / fondo_brotes.png / fondo_plantas.png   (1280x720)
  semilla.png        papa recortada, transparente, resolucion original recortada
  semilla_32.png     la misma, 32 px de ancho
  huecos_layout.json 24 huecos (3 camas x 4 filas x 2 columnas) en px de 1280x720
  _preview.png       solo para revisar
"""
import json
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

SRC = pathlib.Path(sys.argv[1])
OUT = pathlib.Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)

F_EMPTY = SRC / "Gemini_Generated_Image_ddi3dpddi3dpddi3.jpg"
F_SPROUT = SRC / "Gemini_Generated_Image_rop7dnrop7dnrop7 (1).jpg"
F_PLANT = SRC / "Gemini_Generated_Image_ygolj7ygolj7ygol.jpg"
F_SEED = SRC / "Gemini_Generated_Image_li41sli41sli41sl.jpg"

# ------------------------------------------------------------------ semilla
s = np.asarray(Image.open(F_SEED).convert("RGB")).astype(int)
R, G, B = s[..., 0], s[..., 1], s[..., 2]
magentaness = np.minimum(R, B) - G
bg = magentaness > 45
alpha = (~bg).astype(np.uint8) * 255
alpha = ndi.binary_erosion(alpha > 0, iterations=1)           # corta el halo rosado del JPG
lab, n = ndi.label(alpha)                                      # se queda con la pieza principal
sizes = ndi.sum(alpha, lab, range(1, n + 1))
alpha = lab == (1 + int(np.argmax(sizes)))
alpha = ndi.binary_fill_holes(alpha)
rgba = np.dstack([s.clip(0, 255).astype(np.uint8), (alpha * 255).astype(np.uint8)])
ys, xs = np.where(alpha)
pad = 4
box = (max(xs.min() - pad, 0), max(ys.min() - pad, 0), xs.max() + pad + 1, ys.max() + pad + 1)
seed = Image.fromarray(rgba, "RGBA").crop(box)
seed.save(OUT / "semilla.png")
w32 = 32
seed32 = seed.resize((w32, round(seed.height * w32 / seed.width)), Image.LANCZOS)
seed32.save(OUT / "semilla_32.png")
sa = np.asarray(seed).astype(int)
vis = sa[..., 3] > 0
pink = int(((np.minimum(sa[..., 0], sa[..., 2]) - sa[..., 1]) > 25)[vis].sum())
print("semilla:", seed.size, "px; pixeles con tinte rosa restantes:", pink, "de", int(vis.sum()))

# ------------------------------------------------------------------ fondos
CROP_X = (2752 - round(1536 * 16 / 9)) / 2          # 10.5 px por lado -> 16:9 exacto
CW = 2752 - 2 * CROP_X
K = 1280 / CW                                      # factor de escala (0.4687)


def to_1280(path, name):
    im = Image.open(path).convert("RGB")
    c = im.crop((round(CROP_X), 0, round(CROP_X) + round(CW), 1536)).resize((1280, 720), Image.LANCZOS)
    c.save(OUT / name)
    return c


bg_empty = to_1280(F_EMPTY, "fondo_vacio.png")
to_1280(F_SPROUT, "fondo_brotes.png")
to_1280(F_PLANT, "fondo_plantas.png")

# ------------------------------------------------------------------ huecos
E = np.asarray(Image.open(F_EMPTY).convert("RGB")).astype(int)
lab, n = ndi.label(E.sum(axis=2) < 45)
holes = []
for i in range(1, n + 1):
    yy, xx = np.where(lab == i)
    a = len(yy)
    if 2500 <= a <= 9000:
        w, h = xx.max() - xx.min() + 1, yy.max() - yy.min() + 1
        if max(w, h) / min(w, h) <= 1.4 and 230 < xx.mean() < 2500 and 300 < yy.mean() < 1250:
            holes.append((xx.mean(), yy.mean(), (w + h) / 2))
assert len(holes) == 24, f"se esperaban 24 huecos y hay {len(holes)}"

holes.sort(key=lambda h: h[0])
xs_ = [h[0] for h in holes]
cuts = [i + 1 for i in range(23) if xs_[i + 1] - xs_[i] > 250]
assert len(cuts) == 2, cuts
groups = [holes[:cuts[0]], holes[cuts[0]:cuts[1]], holes[cuts[1]:]]

camas = []
for ci, grp in enumerate(groups, 1):
    assert len(grp) == 8, len(grp)
    grp = sorted(grp, key=lambda h: h[1])
    rows = [sorted(grp[r * 2:(r + 1) * 2], key=lambda h: h[0]) for r in range(4)]
    items = []
    for ri, row in enumerate(rows, 1):
        for cj, h in enumerate(row, 1):
            items.append({"id": f"c{ci}_f{ri}_{cj}", "fila": ri, "col": cj,
                          "x": round((h[0] - CROP_X) * K, 1), "y": round(h[1] * K, 1)})
    camas.append({"id": f"cama_{ci}", "huecos": items})

diam = float(np.mean([h[2] for h in holes])) * K
layout = {
    "pantalla": [1280, 720],
    "origen": "Imagenes de Gemini 2752x1536: recorte de 10.5 px por lado (16:9 exacto) y reescalado a 1280x720",
    "factor_escala_desde_original": round(K, 5),
    "huecos_total": 24,
    "diametro_nucleo_oscuro_px": round(diam, 1),
    "semilla_sugerida": {"archivo": "semilla_32.png", "ancho_px": 32, "alto_px": seed32.height,
                         "nota": "Centrar el sprite en (x, y) de cada hueco"},
    "brote_desfase_y_px": -9,
    "brote_nota": "En fondo_brotes el brote queda ~9 px por encima del centro del hueco (centroide del sprite).",
    "saco_semillas": "Esta pintado en el fondo, abajo a la derecha de la cama 3 (aprox. x 1190-1260, y 600-690)",
    "camas": camas,
}
(OUT / "huecos_layout.json").write_text(json.dumps(layout, indent=2, ensure_ascii=False), encoding="utf-8")

# ------------------------------------------------------------------ vista previa
pv = bg_empty.convert("RGBA")
for cama in camas:
    for h in cama["huecos"]:
        pv.alpha_composite(seed32, (round(h["x"] - seed32.width / 2), round(h["y"] - seed32.height / 2)))
d = ImageDraw.Draw(pv)
for cama in camas:
    for h in cama["huecos"]:
        r = diam / 2
        d.ellipse((h["x"] - r, h["y"] - r, h["x"] + r, h["y"] + r), outline=(255, 255, 0, 255))
pv.convert("RGB").save(OUT / "_preview.png")
print("huecos:", len(holes), "diametro a 1280:", round(diam, 1))
print({c["id"]: [(h["x"], h["y"]) for h in c["huecos"][:2]] for c in camas})
