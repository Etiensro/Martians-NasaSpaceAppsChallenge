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

from imgutil import background_color, crop_to_mask, downscale_masked, object_mask

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "tools" / "data" / "portraits"
OUT = ROOT / "assets" / "characters" / "portraits"
ROLES = ["engineer", "biologist", "medic", "astrophysicist"]
LABEL_TOP = 0.85   # todo lo que esté por debajo de este % del alto es la etiqueta del nombre
SIZE = 200         # alto final del retrato (px)
TOLERANCE = 110    # los retratos tienen bordes suaves: se pide más diferencia con el fondo


def cut(rgb, x0, x1, h_lim):
    part = rgb[:h_lim, x0:x1]
    mask = object_mask(part, background_color(rgb, corner=15), TOLERANCE)
    part, mask, _ = crop_to_mask(part, mask)
    k = SIZE / part.shape[0]
    return Image.fromarray(downscale_masked(part, mask, (round(part.shape[1] * k), SIZE)), "RGBA")


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
