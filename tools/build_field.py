"""Campo solar (SOLAR FIELD) del edificio de paneles solares (assets del equipo, generados con Gemini).

Fuentes (tools/data/interiores/paneles_solares/), todas con fondo naranja liso salvo el suelo:
  field_panel_gemini.jpg          panel limpio visto desde arriba
  field_panel_broken_gemini.jpg   el mismo panel roto
  field_crate_gemini.jpg          caja con paneles de repuesto
  field_ground_gemini.jpg         suelo marciano (sin fondo que quitar)
  field_combiner_gemini.jpg       caja de conexiones de una fila
  field_brush_gemini.jpg          brocha (cursor para limpiar)
Genera (assets/interiores/paneles_solares/campo_solar/), con los nombres que busca campo_solar.gd:
  field_panel.png / field_panel_broken.png   180x100, solo el marco del panel (sin la cajita del cable,
                                             que la dibuja el juego en el punto donde sale el cable)
  field_crate.png      210x92 (la caja centrada, sin deformar)
  field_ground.png     1280x720
  field_combiner.png   caja de conexiones sin el poste (el cable principal lo dibuja el juego)
  field_brush.png      brocha
  field.json           punto de la brocha que va bajo el ratón (centro de las cerdas, px de field_brush.png)

Uso:  python tools/build_field.py [--preview]
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

from imgutil import background_color, components, downscale_masked, object_mask, quantize_rgba

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "tools/data/interiores/paneles_solares"
OUT = ROOT / "assets/interiores/paneles_solares/campo_solar"

PANEL_SIZE = (180, 100)
CRATE_SIZE = (210, 92)
GROUND_SIZE = (1280, 720)
COMBINER_H = 50
BRUSH_W = 60
COLORS = 40


def load(name):
    return np.asarray(Image.open(SRC / name).convert("RGB")).astype(int)


def largest_object(rgb):
    """Máscara del objeto más grande (sin chispas ni ruido sueltos)."""
    mask = object_mask(rgb, background_color(rgb, 40))
    small = np.asarray(Image.fromarray(mask.astype(np.uint8) * 255).resize(
        (mask.shape[1] // 8, mask.shape[0] // 8), Image.NEAREST)) > 0
    ys, xs = max(components(small), key=lambda c: len(c[0]))
    keep = np.zeros_like(small)
    keep[ys, xs] = True
    big = np.asarray(Image.fromarray(keep.astype(np.uint8) * 255).resize(
        (mask.shape[1], mask.shape[0]), Image.NEAREST)) > 0
    # la versión reducida pierde los bordes finos: se recupera el objeto real cerca de la zona
    big = np.asarray(Image.fromarray(big.astype(np.uint8) * 255).filter(
        ImageFilter.MaxFilter(17))) > 0
    return mask & big


def frame_box(mask, coverage=0.6):
    """Rectángulo del marco del panel: filas y columnas que el objeto cubre casi enteras.
    Así se quedan fuera la cajita del cable, las chispas y la esquina doblada."""
    cols = np.nonzero(mask.mean(0) > coverage * mask.mean(0).max())[0]
    rows = np.nonzero(mask.mean(1) > coverage * mask.mean(1).max())[0]
    return cols.min(), rows.min(), cols.max() + 1, rows.max() + 1


def to_png(arr, name, colors=COLORS):
    img = quantize_rgba(Image.fromarray(arr.astype(np.uint8), "RGBA"), colors)
    img.save(OUT / name)
    return img


def panel(src, name):
    rgb = load(src)
    x0, y0, x1, y1 = frame_box(largest_object(rgb))
    crop = rgb[y0:y1, x0:x1]
    return to_png(downscale_masked(crop, np.ones(crop.shape[:2], bool), PANEL_SIZE), name)


def fit_object(rgb, mask, height=None, width=None):
    """Recorta el objeto y lo reduce manteniendo la proporción (por alto o por ancho)."""
    ys, xs = np.nonzero(mask)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    w, h = x1 - x0, y1 - y0
    size = (round(w * height / h), height) if height else (width, round(h * width / w))
    return downscale_masked(rgb[y0:y1, x0:x1], mask[y0:y1, x0:x1], size)


def crate():
    rgb = load("field_crate_gemini.jpg")
    obj = fit_object(rgb, largest_object(rgb), height=CRATE_SIZE[1])
    if obj.shape[1] > CRATE_SIZE[0]:
        obj = fit_object(rgb, largest_object(rgb), width=CRATE_SIZE[0])
    out = np.zeros((CRATE_SIZE[1], CRATE_SIZE[0], 4), np.uint8)
    oy, ox = (CRATE_SIZE[1] - obj.shape[0]) // 2, (CRATE_SIZE[0] - obj.shape[1]) // 2
    out[oy:oy + obj.shape[0], ox:ox + obj.shape[1]] = obj
    return to_png(out, "field_crate.png")


def combiner():
    rgb = load("field_combiner_gemini.jpg")
    mask = largest_object(rgb)
    # quitar el poste de abajo: filas (desde abajo) donde el objeto es mucho más estrecho que la caja
    width = mask.sum(1)
    rows = np.nonzero(width)[0]
    bottom = rows.max()
    while bottom > rows.min() and width[bottom] < 0.4 * width.max():
        bottom -= 1
    mask[bottom + 1:] = False
    return to_png(fit_object(rgb, mask, height=COMBINER_H), "field_combiner.png")


def brush():
    rgb = load("field_brush_gemini.jpg")
    arr = fit_object(rgb, largest_object(rgb), width=BRUSH_W)
    img = to_png(arr, "field_brush.png", 24)
    # centro de las cerdas = píxeles casi blancos de la mitad inferior izquierda
    a = np.asarray(img).astype(int)
    h, w = a.shape[:2]
    white = (a[..., :3].min(2) > 205) & (a[..., 3] > 0)
    white[: h // 3] = False
    white[:, w // 2:] = False
    ys, xs = np.nonzero(white)
    return [round(float(xs.mean()), 1), round(float(ys.mean()), 1)]


def ground():
    im = Image.open(SRC / "field_ground_gemini.jpg").convert("RGB")
    s = max(GROUND_SIZE[0] / im.width, GROUND_SIZE[1] / im.height)
    nw, nh = round(im.width * s), round(im.height * s)
    ox, oy = (nw - GROUND_SIZE[0]) // 2, (nh - GROUND_SIZE[1]) // 2
    im = im.resize((nw, nh), Image.BOX).crop((ox, oy, ox + GROUND_SIZE[0], oy + GROUND_SIZE[1]))
    im.quantize(64, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB").save(OUT / "field_ground.png")
    return im


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    clean = panel("field_panel_gemini.jpg", "field_panel.png")
    broken = panel("field_panel_broken_gemini.jpg", "field_panel_broken.png")
    box = crate()
    comb = combiner()
    anchor = brush()
    bg = ground()
    (OUT / "field.json").write_text(json.dumps({"brush_anchor": anchor}, indent=1), encoding="utf-8")
    if "--preview" in sys.argv:
        prev = ROOT.parent / "_previews"
        prev.mkdir(exist_ok=True)
        pv = bg.convert("RGBA")
        for i in range(4):
            pv.alpha_composite(clean if i != 2 else broken, (110 + i * 216, 96))
        pv.alpha_composite(comb, (990 + 30 - comb.width // 2, 96 + 70 - comb.height // 2))
        pv.alpha_composite(box, (110, 612))
        pv.save(prev / "field_preview.png")
    print("ok ->", OUT, "| combiner", comb.size, "| brocha", anchor)


if __name__ == "__main__":
    main()
