"""Imagen base del invernadero de la Base Ares 1 en vista de tercera persona (1280x720, pixel art).

La camara mira de frente al fondo del invernadero, como una habitacion en perspectiva:
techo con luces, pared del fondo con equipos, paredes laterales y suelo que se aleja.
Las camas de cultivo estan pegadas a la pared del fondo (3 camas x 8 espacios = 24 plantas);
el personaje camina por el suelo de abajo.

Se dibuja en una cuadricula de 320x180 y se escala x4 (vecino mas cercano), igual que el resto del juego.

Salida (carpeta pasada como argumento):
  invernadero_base.png    fondo 1280x720
  invernadero_layout.json posiciones en px de 1280x720 (camas, huecos de siembra, lamparas, salida, zona caminable)

Uso: python tools/build_greenhouse.py <carpeta_de_salida>
"""
import json
import pathlib
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

W, H, S = 320, 180, 4
OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
OUT.mkdir(parents=True, exist_ok=True)
rng = random.Random(11)

OUTLINE = (13, 18, 46)
FLOOR_A = (92, 97, 112)
FLOOR_B = (82, 87, 102)
SEAM = (64, 69, 86)
WALL = (58, 64, 88)
WALL_L = (82, 90, 114)
WALL_D = (40, 45, 64)
SIDE_L = (44, 49, 70)
SIDE_R = (40, 45, 64)
CEIL = (30, 34, 50)
FRAME = (112, 120, 140)
FRAME_L = (156, 164, 182)
FRAME_D = (72, 78, 96)
SOIL = (146, 78, 48)
SOIL_L = (170, 98, 60)
SOIL_D = (120, 62, 40)
SOIL_DD = (92, 46, 32)
HOLE = (80, 40, 28)
PIPE = (62, 130, 190)
PIPE_L = (140, 206, 244)
PIPE_D = (36, 84, 132)
GREEN = (80, 190, 100)

img = Image.new("RGBA", (W, H), (8, 8, 18, 255))
d = ImageDraw.Draw(img)


def rect(x0, y0, x1, y1, fill=None, outline=None):
    d.rectangle((x0, y0, x1, y1), fill=fill, outline=outline)


def px(x, y, c):
    d.point((x, y), fill=c)


def overlay(fn):
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    fn(ImageDraw.Draw(ov))
    img.alpha_composite(ov)


# ------------------------------------------------------------------ geometria de la sala
BACK = (14, 16, 305, 121)
FLOOR_Y = 122


def fx(xb, y):
    s = 0.9125 + (y - 122) * (1 - 0.9125) / (180 - 122)
    return 160 + (xb - 160) * s


d.polygon([(0, 0), (319, 0), (305, 16), (14, 16)], fill=CEIL)
d.polygon([(0, 0), (14, 16), (14, 122), (0, 180)], fill=SIDE_L)
d.polygon([(319, 0), (305, 16), (305, 122), (319, 180)], fill=SIDE_R)
rect(*BACK, fill=WALL)

for x in range(14, 306, 32):
    d.line([(x, 17), (x, 121)], fill=WALL_D)
    d.line([(x + 1, 17), (x + 1, 121)], fill=WALL_L)
d.line([(14, 17), (305, 17)], fill=WALL_L)
rect(14, 112, 305, 121, fill=WALL_D)
d.line([(14, 112), (305, 112)], fill=OUTLINE)

for y in (5, 10, 14):
    xl = y * 14 / 16
    d.line([(xl, y), (319 - xl, y)], fill=WALL_D)
for cx in (80, 160, 240):
    d.polygon([(cx - 26, 4), (cx + 26, 4), (cx + 22, 8), (cx - 22, 8)], fill=(244, 238, 206), outline=OUTLINE)
    d.line([(cx - 20, 6), (cx + 20, 6)], fill=(255, 255, 240))

YS = [122, 128, 135, 144, 155, 167, 180]
for r in range(len(YS) - 1):
    for i in range(-4, 4):
        xb0, xb1 = 160 + 40 * i, 160 + 40 * (i + 1)
        quad = [(fx(xb0, YS[r]), YS[r]), (fx(xb1, YS[r]), YS[r]),
                (fx(xb1, YS[r + 1]), YS[r + 1]), (fx(xb0, YS[r + 1]), YS[r + 1])]
        d.polygon(quad, fill=FLOOR_A if (i + r) % 2 == 0 else FLOOR_B, outline=SEAM)
d.line([(14, 122), (305, 122)], fill=OUTLINE)
d.line([(14, 16), (14, 122)], fill=OUTLINE)
d.line([(305, 16), (305, 122)], fill=OUTLINE)
d.line([(14, 122), (0, 180)], fill=OUTLINE)
d.line([(305, 122), (319, 180)], fill=OUTLINE)
d.line([(14, 16), (305, 16)], fill=OUTLINE)


def shadow_rect(x0, y0, x1, y1, dx=2, dy=2, a=80):
    overlay(lambda o: o.rectangle((x0 + dx, y0 + dy, x1 + dx, y1 + dy), fill=(0, 0, 0, a)))


# Tanque de agua
shadow_rect(28, 26, 66, 84, 3, 1)
rect(28, 26, 66, 84, fill=(96, 106, 130), outline=OUTLINE)
rect(29, 27, 65, 31, fill=(128, 138, 162))
for x in (34, 60):
    d.line([(x, 32), (x, 83)], fill=(78, 88, 112))
d.line([(29, 50), (65, 50)], fill=(78, 88, 112))
rect(40, 38, 54, 74, fill=(20, 28, 52), outline=OUTLINE)
rect(41, 52, 53, 73, fill=(74, 150, 220))
d.line([(41, 52), (53, 52)], fill=PIPE_L)
for yy in range(40, 74, 6):
    px(56, yy, (200, 206, 224))
rect(44, 84, 50, 92, fill=PIPE_D, outline=OUTLINE)

# Panel de control
shadow_rect(138, 26, 182, 66, 2, 1)
rect(138, 26, 182, 66, fill=(30, 34, 48), outline=OUTLINE)
rect(139, 27, 181, 29, fill=WALL_L)
for sx, bg, fg in ((142, (20, 60, 44), (80, 240, 160)),
                   (155, (14, 50, 60), (95, 243, 226)),
                   (168, (60, 44, 16), (255, 190, 60))):
    rect(sx, 32, sx + 11, 46, fill=bg, outline=OUTLINE)
    d.line([(sx + 1 + i * 2, 44 - ((i * 5 + sx) % 9)) for i in range(6)], fill=fg)
for i in range(8):
    c = (230, 70, 60) if i % 3 == 0 else ((80, 220, 120) if i % 3 == 1 else (120, 130, 160))
    rect(142 + i * 5, 50, 143 + i * 5, 51, fill=c)
    rect(142 + i * 5, 55, 144 + i * 5, 57, fill=(70, 76, 100))
rect(142, 60, 178, 62, fill=(20, 24, 36))
rect(142, 60, 160, 62, fill=(80, 220, 120))

# Unidad de composta
shadow_rect(252, 28, 292, 74, 3, 1)
rect(252, 28, 292, 74, fill=(86, 62, 44), outline=OUTLINE)
rect(253, 29, 291, 36, fill=(120, 88, 60))
d.line([(253, 36), (291, 36)], fill=OUTLINE)
rect(258, 42, 286, 66, fill=(40, 26, 18), outline=OUTLINE)
rect(259, 54, 285, 65, fill=(98, 68, 44))
for i in range(10):
    px(261 + i * 2, 55 + (i % 4) * 2, (132, 92, 58))
for dx, dy in ((0, 0), (1, 1), (2, 2), (3, 3), (4, 4), (2, 1), (3, 2), (4, 3), (1, 0)):
    px(268 + dx, 44 + dy, GREEN)
px(272, 44, (150, 230, 160))
for i in range(4):
    d.line([(254, 40 + i * 6), (256, 40 + i * 6)], fill=OUTLINE)
rect(262, 68, 282, 72, fill=(60, 44, 32), outline=OUTLINE)


def shelf_unit(x0, y0, x1, y1, cap):
    shadow_rect(x0, y0, x1, y1, 3, 1)
    rect(x0, y0, x1, y1, fill=(30, 34, 50), outline=OUTLINE)
    rect(x0, y0 + 4, x0 + 2, y1, fill=FRAME)
    rect(x1 - 2, y0 + 4, x1, y1, fill=FRAME)
    rect(x0, y0, x1, y0 + 3, fill=cap, outline=OUTLINE)
    for off in (18, 36, 52):
        rect(x0, y0 + off, x1, y0 + off + 1 + (1 if off == 52 else 0), fill=FRAME, outline=OUTLINE)
        d.line([(x0 + 1, y0 + off), (x1 - 1, y0 + off)], fill=FRAME_L)


def packet(x, base, w, h, c):
    rect(x, base - h, x + w - 1, base, fill=c, outline=OUTLINE)
    rect(x + 1, base - h + 2, x + w - 2, base - h + 4, fill=(244, 240, 220))
    px(x + w // 2, base - 3, GREEN)
    px(x + w // 2, base - 2, GREEN)


def jar(x, base):
    rect(x, base - 9, x + 6, base, fill=(150, 196, 208), outline=OUTLINE)
    rect(x, base - 11, x + 6, base - 9, fill=(122, 92, 62), outline=OUTLINE)
    rect(x + 1, base - 5, x + 5, base - 1, fill=(200, 170, 100))
    px(x + 2, base - 6, (230, 204, 140))


def bucket(x, base):
    rect(x, base - 9, x + 9, base, fill=(96, 66, 44), outline=OUTLINE)
    rect(x, base - 9, x + 9, base - 8, fill=(134, 96, 62))
    rect(x + 1, base - 7, x + 8, base - 6, fill=(56, 38, 26))
    d.line([(x + 2, base - 10), (x + 7, base - 10)], fill=(170, 176, 196))


def sack(x, base):
    d.polygon([(x, base), (x + 1, base - 9), (x + 4, base - 12), (x + 8, base - 12), (x + 11, base - 9), (x + 12, base)],
              fill=(138, 108, 78), outline=OUTLINE)
    d.line([(x + 4, base - 11), (x + 8, base - 11)], fill=(96, 74, 52))
    rect(x + 3, base - 7, x + 8, base - 4, fill=(80, 190, 100))
    px(x + 5, base - 6, (220, 250, 220))


SX0, SY0, SX1, SY1 = 78, 30, 130, 84
shelf_unit(SX0, SY0, SX1, SY1, (160, 204, 80))
px(104, SY0 + 1, (30, 90, 40))
px(103, SY0 + 2, (30, 90, 40))
px(105, SY0 + 2, (30, 90, 40))
for i in range(3):
    jar(SX0 + 5 + i * 9, SY0 + 17)
for i, c in enumerate(((232, 200, 70), (120, 190, 100), (220, 130, 70))):
    packet(SX0 + 32 + i * 7, SY0 + 17, 6, 11, c)
for i in range(6):
    packet(SX0 + 5 + i * 7, SY0 + 35, 6, 12, ((232, 200, 70), (120, 190, 100), (220, 130, 70))[i % 3])
rect(SX0 + 5, SY0 + 41, SX1 - 5, SY0 + 51, fill=(120, 88, 56), outline=OUTLINE)
for k in range(3):
    d.line([(SX0 + 6, SY0 + 43 + k * 3), (SX1 - 6, SY0 + 43 + k * 3)], fill=(96, 68, 42))
for k, (cx, cy) in enumerate(((SX0 + 12, SY0 + 40), (SX0 + 21, SY0 + 39), (SX0 + 30, SY0 + 40), (SX0 + 39, SY0 + 39))):
    d.ellipse((cx - 3, cy - 2, cx + 3, cy + 2), fill=(176, 140, 90), outline=(110, 80, 50))
    px(cx - 1, cy, (120, 90, 56))

AX0, AY0, AX1, AY1 = 194, 30, 246, 84
shelf_unit(AX0, AY0, AX1, AY1, (196, 120, 60))
for dx, dy in ((0, 0), (1, 1), (2, 2), (1, 0), (2, 1)):
    px(218 + dx, AY0 + 1 + (dy if dy < 2 else 1), (90, 50, 20))
for i in range(3):
    bucket(AX0 + 5 + i * 12, AY0 + 17)
packet(AX0 + 42, AY0 + 17, 6, 11, (196, 120, 60))
sack(AX0 + 5, AY0 + 35)
sack(AX0 + 19, AY0 + 35)
sack(AX0 + 33, AY0 + 35)
rect(AX0 + 5, AY0 + 41, AX1 - 18, AY0 + 51, fill=(50, 56, 72), outline=OUTLINE)
rect(AX0 + 6, AY0 + 40, AX1 - 19, AY0 + 43, fill=(62, 42, 30))
for k in range(8):
    px(AX0 + 8 + k * 3, AY0 + 41 + (k % 2), (96, 66, 44))
d.line([(AX1 - 12, AY0 + 40), (AX1 - 6, AY0 + 50)], fill=(190, 160, 110))
rect(AX1 - 8, AY0 + 47, AX1 - 4, AY0 + 50, fill=(170, 176, 196), outline=OUTLINE)

# Tuberia principal
BED_X = (36, 126, 214)
BED_W = 72
rect(46, 84, 50, 93, fill=PIPE, outline=PIPE_D)
rect(46, 91, 300, 94, fill=PIPE, outline=PIPE_D)
d.line([(47, 92), (299, 92)], fill=PIPE_L)
for bx in BED_X:
    cx = bx + BED_W // 2
    overlay(lambda o, cx=cx: o.rectangle((cx - 1, 96, cx + 3, 101), fill=(0, 0, 0, 70)))
    rect(cx - 2, 95, cx + 2, 101, fill=PIPE, outline=PIPE_D)
    d.line([(cx - 1, 95), (cx - 1, 101)], fill=PIPE_L)
for x in (60, 100, 150, 200, 250, 290):
    rect(x, 89, x + 2, 96, fill=WALL_L, outline=OUTLINE)
for x in (88, 178, 268):
    d.ellipse((x - 3, 89, x + 3, 96), fill=(200, 60, 50), outline=OUTLINE)
    px(x, 92, (255, 190, 170))


def left_wall_y(x):
    return x * 16 / 14, 180 - x * 58 / 14


def door_pt(x, frac):
    yt, yb = left_wall_y(x)
    return (x, yt + (yb - yt) * frac)


xa, xb_ = 1.0, 13.0
door = [door_pt(xa, 0.30), door_pt(xb_, 0.30), door_pt(xb_, 0.99), door_pt(xa, 0.99)]
d.polygon(door, fill=(70, 82, 108), outline=OUTLINE)
inner = [door_pt(xa + 1.5, 0.37), door_pt(xb_ - 1.5, 0.37), door_pt(xb_ - 1.5, 0.99), door_pt(xa + 1.5, 0.99)]
d.polygon(inner, fill=(28, 52, 66))
d.polygon([door_pt(xa + 2.5, 0.42), door_pt(xb_ - 2.5, 0.42), door_pt(xb_ - 2.5, 0.60), door_pt(xa + 2.5, 0.60)],
          fill=(95, 243, 226))
d.line([door_pt(xa + 1.5, 0.93), door_pt(xb_ - 1.5, 0.93)], fill=(232, 190, 40))

overlay(lambda o: [o.ellipse((cx - 38, 154, cx + 38, 176), fill=(255, 244, 210, 26)) for cx in (80, 160, 240)])

# ------------------------------------------------------------------ camas de cultivo (8 espacios por cama: 4 izq + 4 der)
BED_TOP = 101
BED_FRONT = 138
BED_BOT = 152
HOLES = {}


def bed(i, x):
    w = BED_W
    overlay(lambda o: o.ellipse((x - 4, BED_BOT - 1, x + w + 5, BED_BOT + 7), fill=(0, 0, 0, 100)))
    for fx0 in (x + 1, x + w - 6):
        rect(fx0, BED_BOT, fx0 + 4, BED_BOT + 3, fill=FRAME_D, outline=OUTLINE)
    d.polygon([(x, BED_TOP - 1), (x + w - 1, BED_TOP - 1), (x + w + 3, BED_FRONT), (x - 4, BED_FRONT)],
              fill=FRAME_L, outline=OUTLINE)
    for yy in range(BED_TOP, BED_FRONT + 1):
        t = (yy - BED_TOP) / (BED_FRONT - BED_TOP)
        xl, xr = x + 3 - 4 * t, x + w - 4 + 4 * t
        d.line([(xl, yy), (xr, yy)], fill=SOIL if t > 0.12 else SOIL_D)
        for xx in range(int(xl), int(xr) + 1):
            r = rng.random()
            if r < 0.15:
                px(xx, yy, SOIL_L)
            elif r < 0.28:
                px(xx, yy, SOIL_D)
    d.line([(x + 3, BED_TOP), (x + w - 4, BED_TOP)], fill=SOIL_DD)
    # 2 columnas (izq y der de la tuberia central) x 4 filas = 8 espacios por cama
    pts = []
    for side in (-1, 1):
        for k in range(4):
            t = (k + 0.5) / 4
            row_y = int(BED_TOP + 3 + (BED_FRONT - BED_TOP - 6) * t)
            cx = x + w // 2 + side * (13 + int(2 * t))
            rect(cx - 2, row_y - 1, cx + 2, row_y + 1, fill=HOLE)
            pts.append((cx, row_y))
    HOLES[i] = pts
    # tubo de goteo vertical central
    cx_pipe = x + w // 2
    d.line([(cx_pipe, BED_TOP + 3), (cx_pipe, BED_FRONT - 3)], fill=PIPE)
    for k in range(4):
        px(cx_pipe, BED_TOP + 5 + k * 8, PIPE_L)
    # cara frontal
    rect(x - 4, BED_FRONT + 1, x + w + 3, BED_BOT, fill=FRAME, outline=OUTLINE)
    d.line([(x - 3, BED_FRONT + 1), (x + w + 2, BED_FRONT + 1)], fill=FRAME_L)
    rect(x - 3, BED_BOT - 2, x + w + 2, BED_BOT - 1, fill=FRAME_D)


for i, bx in enumerate(BED_X):
    bed(i, bx)

# Lamparas LED colgantes
LAMPS = []
for bx in BED_X:
    lx0, lx1 = bx - 2, bx + BED_W + 1
    for cx in (lx0 + 6, lx1 - 6):
        d.line([(cx, 12), (cx, 22)], fill=(150, 156, 176))
        d.line([(cx + 1, 12), (cx + 1, 22)], fill=OUTLINE)
    rect(lx0, 22, lx1, 28, fill=(60, 64, 84), outline=OUTLINE)
    rect(lx0 + 2, 25, lx1 - 2, 27, fill=(150, 150, 172))
    LAMPS.append((lx0, 22, lx1 - lx0 + 1, 7))

# Props de primer plano
overlay(lambda o: [o.ellipse((x0, 168, x1, 176), fill=(0, 0, 0, 90)) for x0, x1 in ((280, 314), (8, 34))])
rect(11, 150, 27, 170, fill=(70, 120, 170), outline=OUTLINE)
rect(13, 146, 25, 150, fill=(60, 100, 150), outline=OUTLINE)
d.line([(12, 156), (26, 156)], fill=PIPE_L)
rect(16, 160, 22, 165, fill=(214, 220, 232))

big = img.resize((W * S, H * S), Image.NEAREST).convert("RGB")
arr = np.asarray(big).astype(np.float32)
yy, xx = np.mgrid[0:H * S, 0:W * S]
r = np.sqrt(((xx - W * S / 2) / (W * S / 2)) ** 2 + ((yy - H * S / 2) / (H * S / 2)) ** 2)
arr *= (1 - 0.30 * np.clip(r - 0.4, 0, 1) ** 1.6)[..., None]
Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(OUT / "invernadero_base.png")


def r4(x0, y0, w, h):
    return {"x": int(x0 * S), "y": int(y0 * S), "w": int(w * S), "h": int(h * S)}


layout = {
    "size": [W * S, H * S],
    "nota": "Coordenadas en px de 1280x720. Cada cama tiene 8 huecos (4 a la izquierda y 4 a la derecha de la tuberia central, 24 en total).",
    "camas": [
        {"id": f"cama_{i + 1}", "tierra": r4(bx, BED_TOP, BED_W, BED_FRONT - BED_TOP),
         "cara_frontal": r4(bx, BED_FRONT + 1, BED_W, BED_BOT - BED_FRONT),
         "huecos": [[px_ * S + S // 2, py_ * S + S] for px_, py_ in HOLES[i]]}
        for i, bx in enumerate(BED_X)
    ],
    "lamparas": [r4(*lp) for lp in LAMPS],
    "estaciones": {
        "tanque_agua": r4(28, 26, 39, 59),
        "panel_control": r4(138, 26, 45, 41),
        "composta": r4(252, 28, 41, 47),
        "semillas": r4(78, 30, 53, 55),
        "abono": r4(194, 30, 53, 55),
    },
    "salida": {"zona": r4(0, 40, 14, 120), "puerta_en_pared": "izquierda", "aparece_el_jugador": [160, 600]},
    "suelo_caminable": {"x": 40, "y": 616, "w": 1200, "h": 96,
                        "nota": "Franja sugerida para los pies del personaje frente a las camas (y entre 616 y 712)."},
}
(OUT / "invernadero_layout.json").write_text(json.dumps(layout, indent=2, ensure_ascii=False), encoding="utf-8")
print("ok", OUT)
