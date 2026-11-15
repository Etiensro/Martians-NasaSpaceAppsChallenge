"""Sala eléctrica (POWER ROOM) del edificio de paneles solares (assets del equipo, generados con Gemini).

Fuentes (tools/data/interiores/paneles_solares/):
  control_de_energia.jpg     fondo de la sala (2576x1437)
  pastillas.jpg              interruptor encendido (izquierda) y apagado (derecha) sobre fondo gris
  pastillas_background.jpg   placa metálica donde van los interruptores
  info_de_pastilla.jpg       monitor pequeño con el estado de los sistemas
Genera (assets/interiores/paneles_solares/sala_electrica/):
  power_room.png      fondo a 1280x720 (recorte tipo "cover")
  breaker_on.png / breaker_off.png / breaker_plate.png / monitor.png   con fondo transparente
  power_room.json     zona de los interruptores en la pared (px de 1280x720)

Uso:  python tools/build_power_room.py [--preview]
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "tools/data/interiores/paneles_solares"
OUT = ROOT / "assets/interiores/paneles_solares/sala_electrica"
W, H = 1280, 720

# Zona de los interruptores en la pared del fondo (px de control_de_energia.jpg)
BREAKER_WALL = [895, 585, 1315, 745]
# Tamaños finales (px de pantalla)
BREAKER_SIZE = (96, 0)       # alto proporcional
PLATE_SIZE = (900, 0)
MONITOR_SIZE = (360, 0)


def cover(im):
    s = max(W / im.width, H / im.height)
    nw, nh = round(im.width * s), round(im.height * s)
    ox, oy = (nw - W) / 2, (nh - H) / 2
    out = im.resize((nw, nh), Image.LANCZOS).crop((round(ox), round(oy), round(ox) + W, round(oy) + H))
    return out, s, ox, oy


def cutout(im, x0=0, x1=None, tolerance=25, border=6):
    """Recorta el objeto de una imagen con fondo gris liso y deja el fondo transparente
    (solo el gris conectado al borde, así no se borran grises dentro del dibujo)."""
    rgb = np.asarray(im.convert("RGB")).astype(int)
    x1 = x1 or rgb.shape[1]
    rgb = rgb[:, x0:x1]
    bg = np.median(rgb[:10, :10].reshape(-1, 3), 0)
    obj = np.abs(rgb - bg).sum(2) > tolerance
    obj[:border] = obj[-border:] = False
    obj[:, :border] = obj[:, -border:] = False
    ys, xs = np.nonzero(obj)
    y0, y1, xa, xb = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgba = Image.fromarray(rgb[y0:y1, xa:xb].astype(np.uint8)).convert("RGBA")
    # fondo = gris conectado a los bordes del recorte
    seed = ImageDraw.floodfill
    for p in [(0, 0), (rgba.width - 1, 0), (0, rgba.height - 1), (rgba.width - 1, rgba.height - 1)]:
        seed(rgba, p, (0, 0, 0, 0), thresh=tolerance)
    return rgba


def fit(im, size):
    w = size[0]
    return im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    bg, s, ox, oy = cover(Image.open(SRC / "control_de_energia.jpg").convert("RGB"))
    bg.save(OUT / "power_room.png")
    r = BREAKER_WALL
    wall = [round(r[0] * s - ox), round(r[1] * s - oy), round(r[2] * s - ox), round(r[3] * s - oy)]

    sheet = Image.open(SRC / "pastillas.jpg")
    half = sheet.width // 2
    fit(cutout(sheet, 0, half), BREAKER_SIZE).save(OUT / "breaker_on.png")
    fit(cutout(sheet, half), BREAKER_SIZE).save(OUT / "breaker_off.png")
    fit(cutout(Image.open(SRC / "pastillas_background.jpg")), PLATE_SIZE).save(OUT / "breaker_plate.png")
    fit(cutout(Image.open(SRC / "info_de_pastilla.jpg"), border=2), MONITOR_SIZE).save(OUT / "monitor.png")

    (OUT / "power_room.json").write_text(json.dumps({"breaker_wall": wall}, indent=1), encoding="utf-8")
    if "--preview" in sys.argv:
        prev = ROOT.parent / "_previews"
        prev.mkdir(exist_ok=True)
        d = ImageDraw.Draw(bg)
        d.rectangle(wall, outline=(234, 254, 7), width=4)
        bg.save(prev / "power_room_preview.png")
    print("ok ->", OUT, "zona de interruptores", wall)


if __name__ == "__main__":
    main()
