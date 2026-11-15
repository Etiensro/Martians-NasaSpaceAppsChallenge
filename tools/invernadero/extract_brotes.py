"""Extrae el brote como sprite con transparencia, restando el fondo vacio al fondo con brotes.

Uso: python extract_brotes.py <carpeta_imagenes> <carpeta_salida>
Salida: brote.png (recorte del brote, resolucion original), brote_info.json, _brotes_check.png
"""
import json
import pathlib
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

SRC = pathlib.Path(sys.argv[1])
OUT = pathlib.Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)

E_im = Image.open(SRC / "Gemini_Generated_Image_ddi3dpddi3dpddi3.jpg").convert("RGB")
A_im = Image.open(SRC / "Gemini_Generated_Image_rop7dnrop7dnrop7 (1).jpg").convert("RGB")
E = np.asarray(E_im).astype(int)
A = np.asarray(A_im).astype(int)

# huecos (mismo criterio que antes)
lab, n = ndi.label(E.sum(axis=2) < 45)
holes = []
for i in range(1, n + 1):
    yy, xx = np.where(lab == i)
    if 2500 <= len(yy) <= 9000:
        w, h = xx.max() - xx.min() + 1, yy.max() - yy.min() + 1
        if max(w, h) / min(w, h) <= 1.4 and 230 < xx.mean() < 2500 and 300 < yy.mean() < 1250:
            holes.append((xx.mean(), yy.mean(), i))
assert len(holes) == 24

d = np.abs(A - E).max(axis=2)
mask = d > 32
mask = ndi.binary_opening(mask, iterations=1)            # quita ruido del JPG
mask = ndi.binary_closing(mask, iterations=2)
mask = ndi.binary_fill_holes(mask)
mlab, mn = ndi.label(mask)
comps = {}
for i in range(1, mn + 1):
    ys, xs = np.where(mlab == i)
    if len(ys) > 3000:
        comps[i] = (xs.mean(), ys.mean(), len(ys), xs.min(), xs.max(), ys.min(), ys.max())
print("componentes:", len(comps))

cov = []
for hx, hy, hi in holes:
    k = min(comps, key=lambda c: (comps[c][0] - hx) ** 2 + (comps[c][1] - hy) ** 2)
    core = lab == hi
    cov.append(float(mlab[core].astype(bool).mean() if False else (mlab[core] == k).mean()))
print("cobertura del hueco por la mascara: min %.3f media %.3f" % (min(cov), np.mean(cov)))

# sprite de referencia: el brote de la cama 1, fila 1, columna 1 (el hueco mas arriba a la izquierda)
holes.sort(key=lambda h: (h[0] // 600, h[1], h[0]))
hx, hy, hi = min(holes, key=lambda h: (h[0] + h[1]))
k = min(comps, key=lambda c: (comps[c][0] - hx) ** 2 + (comps[c][1] - hy) ** 2)
_, _, area, x0, x1, y0, y1 = comps[k]
pad = 3
x0, y0, x1, y1 = int(x0) - pad, int(y0) - pad, int(x1) + pad + 1, int(y1) + pad + 1
alpha = (mlab[y0:y1, x0:x1] == k)
alpha = ndi.binary_erosion(alpha, iterations=1) | (ndi.binary_erosion(alpha, iterations=1) & alpha)
rgba = np.dstack([A[y0:y1, x0:x1].clip(0, 255).astype(np.uint8), (alpha * 255).astype(np.uint8)])
spr = Image.fromarray(rgba, "RGBA")
spr.save(OUT / "brote.png")
info = {"tamano_original": [spr.width, spr.height],
        "centro_hueco_en_sprite": [round(hx - x0, 1), round(hy - y0, 1)],
        "nota": "Coordenadas en px de la imagen original 2752x1536; escalar por 0.46870"}
(OUT / "brote_info.json").write_text(json.dumps(info, indent=2), encoding="utf-8")
print(info)

# comprobacion: el brote sobre un fondo de color y sobre el fondo vacio
chk = Image.new("RGBA", (spr.width * 2 + 30, spr.height + 20), (255, 0, 255, 255))
chk.alpha_composite(spr, (10, 10))
tile = E_im.crop((x0, y0, x1, y1)).convert("RGBA")
tile.alpha_composite(spr)
chk.alpha_composite(tile, (spr.width + 20, 10))
chk.convert("RGB").save(OUT / "_brote_check.png")
print("sprite:", spr.size)
