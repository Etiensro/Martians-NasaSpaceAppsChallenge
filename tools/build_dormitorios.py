"""Dormitorios (Crew Quarters) de la Estación Ares 1 y el reloj para elegir cuántas horas dormir.

Fuentes (imágenes del equipo) en tools/data/interiores/dormitorios/:
  dormitorio_gemini.jpg   el cuarto con 4 literas (2752x1536)
  reloj_gemini.jpg        esfera del reloj sin manecillas sobre fondo de estrellas (2752x1536)
  manecillas_gemini.jpg   7 posiciones de las manecillas sobre fondo verde: se usa la 5.ª (forma de L)
                          para recortar la manecilla larga, la corta y el eje

Genera en assets/interiores/estacion_ares1/dormitorios/:
  room.png, clock.png             fondos a 1280x720 (recorte tipo "cover")
  hand_minute.png, hand_hour.png  manecillas apuntando hacia ARRIBA (el eje en "pivot" de dorm.json)
  hand_hub.png                    eje que tapa la unión de las dos manecillas
  dorm.json                       litera (zona de clic), efectos, flecha de salida y reloj

Uso:  python tools/build_dormitorios.py [--preview]   (--preview dibuja las zonas en ../_previews)
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "tools/data/interiores/dormitorios"
OUT = ROOT / "assets/interiores/estacion_ares1/dormitorios"
W, H = 1280, 720

# ---- dormitorio (px de dormitorio_gemini.jpg)
BUNK = [234, 1011, 963, 1232]          # litera de abajo a la izquierda: la del jugador (zona de clic)
EXIT = [1376, 1459]
FX = {
    # [x, y, "rrggbb", tamaño]: halos que laten (luces del techo, barra amarilla, lamparitas de las literas)
    "lamps": [[688, 52, "cfe8ff", 2.0], [1376, 52, "cfe8ff", 2.0], [2064, 52, "cfe8ff", 2.0],
              [1562, 599, "fff27a", 1.6], [482, 842, "fff3c0", 1.3], [2270, 842, "fff3c0", 1.3]],
    # [x, y, "rrggbb"]: lucecitas que parpadean
    "blink": [[812, 475, "4cff7a"], [750, 750, "4cff7a"], [1906, 750, "4cff7a"], [2690, 516, "4cff7a"],
              [2676, 599, "ff3b30"], [1236, 625, "ff3b30"], [1300, 625, "ffb020"]],
    # [x0, y0, x1, y1, tipo]: "heart" (latido), "text" (líneas que aparecen), "stars" (monitor apagado)
    "screens": [[1211, 530, 1342, 619, "heart"], [2635, 488, 2697, 564, "heart"],
                [1211, 709, 1342, 812, "text"], [1445, 705, 1672, 846, "stars"]],
}

# ---- reloj (px de reloj_gemini.jpg): centro y radio de la cara blanca
CLOCK_CENTER = [1375.5, 772]
CLOCK_RADIUS = 455

# ---- manecillas (px de manecillas_gemini.jpg, 5.ª posición: larga hacia arriba, corta a la derecha)
HANDS_FRAME = [600, 20, 740, 245]      # zona de esa posición
HUB = [641, 193]                       # centro del eje
HUB_R = 23
MINUTE_COLS = [624, 658]               # columnas de la manecilla larga
HOUR_ROWS = [182, 211]                 # filas de la manecilla corta
HAND_SCALE = 1.17                      # tamaño final respecto a la fuente


def cover(src):
    im = Image.open(src).convert("RGB")
    s = max(W / im.width, H / im.height)
    nw, nh = round(im.width * s), round(im.height * s)
    ox, oy = (nw - W) / 2, (nh - H) / 2
    img = im.resize((nw, nh), Image.LANCZOS).crop((round(ox), round(oy), round(ox) + W, round(oy) + H))
    return img, (lambda p: [round(p[0] * s - ox), round(p[1] * s - oy)]), s


def keyed_hands():
    """RGBA de la 5.ª posición sin el fondo verde (y sin el borde verdoso de la compresión)."""
    a = np.asarray(Image.open(SRC / "manecillas_gemini.jpg").convert("RGB")).astype(np.int16)
    green = (a[..., 1] > 150) & (a[..., 0] < 140) & (a[..., 2] < 140)
    rgba = np.zeros(a.shape[:2] + (4,), np.uint8)
    rgb = a.copy()
    rgb[..., 1] = np.minimum(rgb[..., 1], rgb[..., 2])  # quita el verde que se cuela en los bordes
    rgba[..., :3] = np.clip(rgb, 0, 255)
    rgba[..., 3] = np.where(green, 0, 255)
    x0, y0, x1, y1 = HANDS_FRAME
    keep = np.zeros(green.shape, bool)
    keep[y0:y1, x0:x1] = True
    rgba[~keep, 3] = 0
    return rgba


def piece(rgba, mask):
    out = rgba.copy()
    out[~mask, 3] = 0
    return out


def save_hand(rgba, pivot, name, rotate=0):
    """Recorta, gira (múltiplos de 90°), escala y guarda. Devuelve el pivote en el PNG final."""
    img = Image.fromarray(rgba, "RGBA")
    x0, y0, x1, y1 = img.getbbox()
    img = img.crop((x0, y0, x1, y1))
    px, py = pivot[0] - x0, pivot[1] - y0
    if rotate == 90:  # 90° en sentido antihorario: lo que apuntaba a la derecha ahora apunta arriba
        w = img.width
        img = img.transpose(Image.ROTATE_90)
        px, py = py, w - 1 - px
    size = (round(img.width * HAND_SCALE), round(img.height * HAND_SCALE))
    img = img.resize(size, Image.LANCZOS)
    a = np.asarray(img).copy()
    a[..., 3] = np.where(a[..., 3] > 140, 255, 0)  # bordes nítidos (pixel art)
    Image.fromarray(a, "RGBA").save(OUT / name)
    return [round(px * HAND_SCALE, 1), round(py * HAND_SCALE, 1)]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    room, pt, _ = cover(SRC / "dormitorio_gemini.jpg")
    room.save(OUT / "room.png")
    clock, cpt, cs = cover(SRC / "reloj_gemini.jpg")
    clock.save(OUT / "clock.png")

    rgba = keyed_hands()
    hh, ww = rgba.shape[:2]
    yy, xx = np.mgrid[0:hh, 0:ww]
    in_hub = (xx - HUB[0]) ** 2 + (yy - HUB[1]) ** 2 <= HUB_R ** 2
    minute = (xx >= MINUTE_COLS[0]) & (xx <= MINUTE_COLS[1])
    hour = (yy >= HOUR_ROWS[0]) & (yy <= HOUR_ROWS[1]) & ~minute
    pivots = {
        "minute": save_hand(piece(rgba, minute), HUB, "hand_minute.png"),
        "hour": save_hand(piece(rgba, hour | (in_hub & ~minute)), HUB, "hand_hour.png", rotate=90),
        "hub": save_hand(piece(rgba, in_hub), HUB, "hand_hub.png"),
    }

    rect = lambda r: pt(r[:2]) + pt(r[2:4]) + list(r[4:])
    data = {
        "bunk": rect(BUNK),
        "exit": pt(EXIT),
        "lamps": [pt(l[:2]) + l[2:] for l in FX["lamps"]],
        "blink": [pt(l[:2]) + l[2:] for l in FX["blink"]],
        "screens": [rect(r) for r in FX["screens"]],
        "clock": {"center": cpt(CLOCK_CENTER), "radius": round(CLOCK_RADIUS * cs), "pivots": pivots},
    }
    (OUT / "dorm.json").write_text(json.dumps(data, indent=1), encoding="utf-8")
    print("dormitorios ->", OUT)

    if "--preview" in sys.argv:
        prev = ROOT.parent / "_previews"
        prev.mkdir(exist_ok=True)
        pv = room.copy()
        d = ImageDraw.Draw(pv)
        d.rectangle(data["bunk"], outline="yellow", width=3)
        for r in data["screens"]:
            d.rectangle(r[:4], outline="cyan")
        for p in data["lamps"] + data["blink"] + [data["exit"]]:
            d.ellipse([p[0] - 5, p[1] - 5, p[0] + 5, p[1] + 5], outline="magenta", width=2)
        pv.save(prev / "dormitorios_room.png")
        cv = clock.copy().convert("RGBA")
        c, r = data["clock"]["center"], data["clock"]["radius"]
        ImageDraw.Draw(cv).ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], outline="red", width=2)
        for name, ang in (("hand_hour.png", 90), ("hand_minute.png", 0), ("hand_hub.png", 0)):
            hand = Image.open(OUT / name)
            piv = pivots[name[5:-4]]
            # 3:00 con la corta a las 3 (girada 90° en sentido horario)
            if ang:
                w0 = hand.height
                hand = hand.transpose(Image.ROTATE_270)
                piv = [w0 - 1 - piv[1], piv[0]]
            cv.alpha_composite(hand, (round(c[0] - piv[0]), round(c[1] - piv[1])))
        cv.save(prev / "dormitorios_clock.png")


if __name__ == "__main__":
    main()
