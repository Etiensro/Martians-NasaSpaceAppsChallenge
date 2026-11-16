"""Capturas del juego para las lecciones del robot A.R.I.A. (scripts/core/guide.gd).

Fuente: tools/data/guide/raw/*.png (las saca tools/capture_guide_shots.gd desde el juego).
Genera assets/ui/guide/<nombre>.png: recortes, etiquetas grandes y recuadros amarillos para que los
niños vean de qué habla el robot.

Uso:  python tools/build_guide_shots.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "tools/data/guide/raw"
OUT = ROOT / "assets/ui/guide"
FONT = ROOT / "assets/fonts/FiraSans-Black.ttf"
YELLOW = (234, 254, 7)
NAVY = (7, 23, 63)
W = 640  # ancho final de cada captura (se ve a 384 px en el globo, con margen para que no se pixele)

# nombre -> (captura, recorte [x0, y0, x1, y1] o None, [(texto, x, y)], [recuadros [x0, y0, x1, y1]])
SHOTS = {
    "hud": ("station", [960, 0, 1280, 200], [], [[976, 6, 1272, 190]]),
    "station": ("station", None, [("CLICK A DOOR", 640, 190), ("GO OUTSIDE", 640, 600)],
                [[540, 255, 745, 510], [585, 610, 695, 690]]),
    "ap1": ("ap1", None, [("STATION", 330, 120), ("SOLAR PANELS", 880, 90), ("ICE EXCAVATOR", 560, 640),
                          ("ROVER", 270, 395), ("ROCKET", 1060, 400), ("YOU", 320, 500)], []),
    "panels": ("panels", None, [("SOLAR FIELD", 340, 200), ("POWER ROOM", 960, 200)],
               [[180, 222, 500, 528], [798, 222, 1122, 518]]),
    "solar_field": ("solar_field", [0, 60, 1040, 720], [("BROKEN!", 410, 120)], []),
    "greenhouse": ("greenhouse", None, [("1. SEEDS", 418, 105), ("2. WATER", 190, 90)],
                   [[312, 120, 524, 340], [112, 104, 268, 340]]),
    "gym": ("gym", None, [], []),
    "world_map": ("world_map", None, [("YOUR BASE", 576, 520), ("DRIVE THERE", 350, 250), ("DRIVE THERE", 960, 480)],
                  [[270, 60, 430, 220], [880, 300, 1040, 460]]),
    "goal": ("world_map", None, [("3 RESEARCH ZONES", 640, 640)],
             [[270, 60, 430, 220], [880, 300, 1040, 460], [480, 350, 680, 500]]),
}


def label(d, text, x, y, size=34):
    font = ImageFont.truetype(str(FONT), size)
    l, t, r, b = d.textbbox((0, 0), text, font=font)
    w, h = r - l, b - t
    box = [x - w / 2 - 12, y - h / 2 - 10, x + w / 2 + 12, y + h / 2 + 12]
    d.rectangle(box, fill=NAVY, outline=YELLOW, width=4)
    d.text((x - w / 2 - l, y - h / 2 - t), text, font=font, fill=YELLOW)


def build(name, src, crop, labels, boxes):
    im = Image.open(RAW / f"{src}.png").convert("RGB")
    d = ImageDraw.Draw(im)
    for b in boxes:
        d.rectangle(b, outline=YELLOW, width=6)
    for text, x, y in labels:
        label(d, text, x, y)
    if crop:
        im = im.crop(crop)
    k = W / im.width
    im = im.resize((W, round(im.height * k)), Image.LANCZOS)
    im.save(OUT / f"{name}.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (src, crop, labels, boxes) in SHOTS.items():
        build(name, src, crop, labels, boxes)
        print("guía:", name)


if __name__ == "__main__":
    main()
