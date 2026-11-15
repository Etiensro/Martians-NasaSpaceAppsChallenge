"""Recorta los retratos de la tripulación (Gemini: personaje sin casco a la izquierda,
con casco a la derecha, fondo naranja y nombre abajo) para la pantalla de selección.

  tools/data/portraits/<rol>_gemini.png  ->  assets/characters/portraits/<rol>.png         (sin casco)
                                             assets/characters/portraits/<rol>_helmet.png  (con casco)

Se quita el fondo y la etiqueta con el nombre (la tarjeta ya lo muestra).

Uso:  python tools/build_portraits.py
"""
import pathlib

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "tools" / "data" / "portraits"
OUT = ROOT / "assets" / "characters" / "portraits"
ROLES = ["engineer", "biologist", "medic", "astrophysicist"]
LABEL_TOP = 0.85   # todo lo que esté por debajo de este % del alto es la etiqueta del nombre
SIZE = 200         # alto final del retrato (px)


def cut(rgb, x0, x1, h_lim):
    part = rgb[:h_lim, x0:x1]
    bg = np.median(rgb[:15, :15].reshape(-1, 3), axis=0)
    mask = np.abs(part - bg).sum(2) > 110
    ys, xs = np.nonzero(mask)
    part, mask = part[ys.min():ys.max() + 1, xs.min():xs.max() + 1], mask[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    k = SIZE / part.shape[0]
    size = (round(part.shape[1] * k), SIZE)
    m = mask.astype(np.float32)

    def down(a):
        return np.asarray(Image.fromarray(a.astype(np.float32), mode="F").resize(size, Image.BOX))

    a = down(m)
    col = np.stack([down(part[..., i] * m) for i in range(3)], -1) / np.maximum(a, 1e-6)[..., None]
    out = np.zeros((size[1], size[0], 4), np.uint8)
    out[..., :3] = col.clip(0, 255)
    out[..., 3] = np.where(a > 0.5, 255, 0)
    return Image.fromarray(out, "RGBA")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for role in ROLES:
        rgb = np.asarray(Image.open(SRC / f"{role}_gemini.png").convert("RGB")).astype(np.float32)
        h, w = rgb.shape[:2]
        lim = int(h * LABEL_TOP)
        cut(rgb, 0, w // 2, lim).save(OUT / f"{role}.png")
        cut(rgb, w // 2, w, lim).save(OUT / f"{role}_helmet.png")
        print(role, "ok")


if __name__ == "__main__":
    main()
