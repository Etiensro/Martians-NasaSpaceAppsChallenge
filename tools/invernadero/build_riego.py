"""Assets del minijuego REGAR (vista cenital, mismo estilo y paleta que las camas de Gemini).

Todo se dibuja en una cuadricula pequena y se exporta x2 (vecino mas cercano): 1 pixel de arte = 2x2 px
en la pantalla de 1280x720.

Uso: python build_riego.py <carpeta_de_salida> <huecos_layout.json> <fondo_vacio.png> <brote.png> <brote_info.json>

Salida:
  regadera.png            4 frames (celda 76x64)
  efectos_riego.png       fila 1: lluvia (4), fila 2: ondas (4)  (celda 80x64)
  tierra_mojada.png       humeda / empapada / encharcada (celda 96x80)
  burbujas.png            sed / perfecto / ahogada (celda 40x40)
  medidor_marco.png  medidor_brillo.png  medidor_agua.png (nine-patch)  medidor_zona_verde.png
  medidor_zona_roja.png (nine-patch)  medidor_flecha.png
  brote_1280.png          el brote suelto a la escala de 1280x720
  riego_layout.json       rectangulos de cada frame, anclas y datos del medidor
  _preview.png            solo para revisar
"""
import json
import math
import pathlib
import random
import sys

from PIL import Image, ImageDraw

S = 2
OUT = pathlib.Path(sys.argv[1])
HUECOS = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding="utf-8"))
BG = Image.open(sys.argv[3]).convert("RGBA")
BROTE = Image.open(sys.argv[4]).convert("RGBA")
BINFO = json.loads(pathlib.Path(sys.argv[5]).read_text(encoding="utf-8"))
OUT.mkdir(parents=True, exist_ok=True)
rng = random.Random(3)

OUTLINE = (13, 18, 46)
FRAME = (112, 120, 140)
FRAME_L = (156, 164, 182)
FRAME_D = (72, 78, 96)
BODY = (88, 100, 132)
BODY_D = (62, 72, 102)
WATER = (74, 150, 220)
WATER_L = (140, 206, 244)
WATER_D = (36, 84, 132)
GREEN = (80, 190, 100)
GREEN_L = (150, 240, 160)
RED = (240, 90, 80)
RED_L = (255, 170, 150)
CLEAR = (0, 0, 0, 0)


def new(w, h):
    im = Image.new("RGBA", (w, h), CLEAR)
    return im, ImageDraw.Draw(im)


def up(im):
    return im.resize((im.width * S, im.height * S), Image.NEAREST)


def sheet(frames, cols, cw, ch):
    rows = -(-len(frames) // cols)
    im = Image.new("RGBA", (cols * cw, rows * ch), CLEAR)
    for i, f in enumerate(frames):
        im.alpha_composite(f, ((i % cols) * cw, (i // cols) * ch))
    return im


def rects(n, cols, cw, ch, names):
    return [{"nombre": names[i], "x": (i % cols) * cw * S, "y": (i // cols) * ch * S, "w": cw * S, "h": ch * S}
            for i in range(n)]


# ============================================================================ REGADERA (vista cenital)
CAN_W, CAN_H = 38, 32
CAN_SHIFT = [(0, 0), (0, 1), (1, 0), (0, 0)]
CAN_GLINT = [((19, 14), (20, 14), (18, 15)), ((21, 15), (22, 15), (20, 16)),
             ((23, 14), (24, 14), (22, 15)), ((21, 13), (22, 13), (20, 14))]
CAN_DROPS = [(), ((2, 15), (5, 16)), ((3, 16), (6, 15), (1, 17)), ((2, 14), (4, 17), (6, 16))]


def watering_can(f):
    im, d = new(CAN_W, CAN_H)
    # asa (detras del cuerpo)
    d.ellipse((27, 8, 36, 25), fill=OUTLINE)
    d.ellipse((28, 9, 35, 24), fill=FRAME_D)
    d.ellipse((30, 11, 34, 22), fill=CLEAR)
    d.arc((30, 11, 34, 22), 0, 360, fill=OUTLINE)
    d.line([(29, 11), (33, 9)], fill=FRAME)
    # pico
    d.polygon([(13.4, 15.6), (10.6, 18.4), (4.6, 12.4), (7.4, 9.6)], fill=FRAME, outline=OUTLINE)
    d.line([(10, 15), (6, 11)], fill=FRAME_L)
    # cuerpo
    d.ellipse((11, 6, 33, 28), fill=BODY_D, outline=OUTLINE)
    d.ellipse((11, 6, 31, 26), fill=BODY)
    d.ellipse((12, 7, 32, 27), outline=OUTLINE)
    d.ellipse((13, 8, 31, 26), fill=FRAME_L)
    d.ellipse((14, 9, 30, 25), fill=(24, 34, 60), outline=OUTLINE)
    d.ellipse((15, 11, 29, 24), fill=WATER_D)
    d.ellipse((15, 11, 28, 22), fill=WATER)
    for p in CAN_GLINT[f]:
        d.point(p, fill=WATER_L)
    d.arc((14, 9, 30, 25), 200, 300, fill=(214, 220, 232))
    # roseta
    d.ellipse((0, 6, 8, 14), fill=FRAME_L, outline=OUTLINE)
    d.arc((1, 7, 7, 13), 180, 270, fill=(236, 240, 250))
    hole = WATER_L if f else OUTLINE
    for p in ((3, 9), (5, 9), (4, 11), (2, 11), (6, 11)):
        d.point(p, fill=hole)
    d.line([(1, 12), (7, 12)], fill=FRAME_D)
    for p in CAN_DROPS[f]:
        d.point(p, fill=WATER_L)
        d.point((p[0], p[1] - 1), fill=WATER)
    out = Image.new("RGBA", (CAN_W, CAN_H), CLEAR)
    out.alpha_composite(im, CAN_SHIFT[f])
    return out


CAN_NAMES = ["reposo", "vertiendo_1", "vertiendo_2", "vertiendo_3"]
CAN_ROSE = (4, 10)               # centro de la roseta (px de arte)

# ============================================================================ EFECTOS
FX_W, FX_H = 40, 32


def rain(f):
    im, d = new(FX_W, FX_H)
    for k in range(12):
        dx = (k - 5.5) * 1.6
        y = (f * 7 + k * 5) % 28
        x = round(20 + dx * (y / 26 + 0.15))
        if y >= 24:
            d.point((x - 1, 27), fill=WATER_L)
            d.point((x + 1, 27), fill=WATER_L)
            d.point((x, 26), fill=(236, 250, 255))
        else:
            d.point((x, y), fill=WATER)
            d.point((x, y + 1), fill=WATER_L)
            d.point((x, y + 2), fill=(236, 250, 255) if k % 2 == 0 else WATER_L)
    return im


def ripple(f):
    im, d = new(FX_W, FX_H)
    r = (3, 7, 11, 15)[f]
    a = (255, 210, 150, 90)[f]
    d.ellipse((20 - r, 16 - r * 0.7, 20 + r, 16 + r * 0.7), outline=WATER_L + (a,))
    if r - 6 > 2:
        r2 = r - 6
        d.ellipse((20 - r2, 16 - r2 * 0.7, 20 + r2, 16 + r2 * 0.7), outline=(236, 250, 255, int(a * .6)))
    for ang in (30, 100, 160, 220, 290, 340):
        px_ = 20 + math.cos(math.radians(ang)) * (r + 1)
        py_ = 16 + math.sin(math.radians(ang)) * (r + 1) * 0.7
        if f < 3:
            d.point((round(px_), round(py_ - (1 if f == 1 else 0))), fill=(236, 250, 255, a))
    return im


FX_NAMES = [f"lluvia_{i + 1}" for i in range(4)] + [f"ondas_{i + 1}" for i in range(4)]
RAIN_PLANT = (20, 28)             # punto donde cae la lluvia (px de arte)

# ============================================================================ TIERRA MOJADA
WT_W, WT_H = 48, 40


def blob(rx, ry, shade, seed):
    im, d = new(WT_W, WT_H)
    r2 = random.Random(seed)
    cx, cy = WT_W / 2 - 0.5, WT_H / 2 - 0.5
    for y in range(WT_H):
        for x in range(WT_W):
            r = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if r + r2.uniform(-0.14, 0.14) <= 1:
                c = shade(x, y, r, cx, cy, rx, ry)
                if c:
                    d.point((x, y), fill=c)
    return im


def shade_humeda(x, y, r, *_):
    return (68, 30, 20, int(150 + (1 - min(r, 1)) * 60))


def shade_empapada(x, y, r, *_):
    base = (62, 28, 20, int(150 + (1 - min(r, 1)) * 70))
    if r < 0.4:
        base = (46, 20, 16, 225)
    if r > 0.55 and (x * 7 + y * 13) % 29 == 0:
        base = (110, 60, 44, 150)
    return base


def shade_encharcada(x, y, r, cx, cy, rx, ry):
    if r > 0.66:
        return (58, 26, 20, 220)
    t = ((x - cx) / rx - (y - cy) / ry) * 0.5 + 0.5
    t = max(0.0, min(1.0, t))
    c = (int(60 + 50 * (1 - t)), int(118 + 58 * (1 - t)), int(172 + 52 * (1 - t)), 220)
    if (x, y) in ((16, 15), (17, 15), (16, 16), (17, 14), (30, 25)):
        c = (240, 250, 255, 240)
    if 0.28 < r < 0.34 and x < cx:
        c = (150, 214, 248, 230)
    return c


WT_NAMES = ["humeda", "empapada", "encharcada"]

# ============================================================================ BURBUJAS
BU = 20


def bubble(fill):
    im, d = new(BU, BU)
    d.polygon([(6, 13), (10, 19), (13, 13)], fill=OUTLINE)
    d.rounded_rectangle((1, 1, 18, 14), radius=3, fill=fill, outline=OUTLINE)
    d.polygon([(8, 13), (10, 16), (11, 13)], fill=fill)
    d.line([(3, 2), (16, 2)], fill=(255, 255, 255, 140))
    return im, d


def b_sed():
    im, d = bubble((236, 240, 250, 255))
    d.polygon([(10, 3), (7, 8), (7, 10), (8, 12), (12, 12), (13, 10), (13, 8)], fill=WATER, outline=WATER_D)
    d.point((9, 9), fill=WATER_L)
    d.point((9, 10), fill=WATER_L)
    return im


def b_ok():
    im, d = bubble((166, 236, 170, 255))
    d.line([(6, 8), (9, 11), (14, 4)], fill=(30, 110, 50), width=2)
    for p in ((18, 0), (1, 0), (19, 4)):
        d.point(p, fill=(255, 240, 150))
    return im


def b_bad():
    im, d = bubble((244, 160, 150, 255))
    d.line([(6, 4), (13, 11)], fill=(150, 30, 30), width=2)
    d.line([(13, 4), (6, 11)], fill=(150, 30, 30), width=2)
    for p in ((3, 12), (16, 12), (4, 10)):
        d.point(p, fill=WATER)
    return im


BU_NAMES = ["sed", "perfecto", "ahogada"]
BU_TAIL = (10, 19)

# ============================================================================ MEDIDOR
G_W, G_H = 18, 76
WIN = (4, 10, 10, 58)             # x, y, ancho, alto (px de arte)


def gauge_frame():
    im, d = new(G_W, G_H)
    d.rounded_rectangle((0, 0, 17, 75), radius=3, fill=FRAME, outline=OUTLINE)
    d.line([(2, 1), (15, 1)], fill=FRAME_L)
    d.rectangle((1, 68, 16, 74), fill=FRAME_D)
    d.line([(1, 68), (16, 68)], fill=OUTLINE)
    d.rectangle((3, 9, 14, 68), fill=(24, 34, 60), outline=OUTLINE)
    for i, y in enumerate(range(WIN[1], WIN[1] + WIN[3] + 1, 6)):
        d.point((15, y), fill=FRAME_L)
        d.point((16, y), fill=FRAME_L if i % 3 == 0 else FRAME)
        if i % 3 == 0:
            d.point((14, y), fill=FRAME_L)
    d.polygon([(9, 1), (7, 4), (7, 5), (8, 6), (10, 6), (11, 5), (11, 4)], fill=WATER, outline=WATER_D)
    d.point((8, 4), fill=WATER_L)
    for p in ((2, 71), (15, 71)):
        d.point(p, fill=FRAME_L)
    return im


def gauge_glass():
    im, d = new(G_W, G_H)
    for y in range(WIN[1] + 1, WIN[1] + WIN[3] - 2):
        d.point((5, y), fill=(255, 255, 255, 80))
        d.point((6, y), fill=(255, 255, 255, 34))
    d.line([(WIN[0], WIN[1]), (WIN[0] + WIN[2] - 1, WIN[1])], fill=(0, 0, 0, 90))
    d.line([(WIN[0], WIN[1] + 1), (WIN[0] + WIN[2] - 1, WIN[1] + 1)], fill=(0, 0, 0, 45))
    d.point((12, 12), fill=(255, 255, 255, 90))
    return im


def gauge_water():
    im, d = new(10, 12)
    d.rectangle((0, 0, 9, 11), fill=WATER)
    d.rectangle((0, 0, 9, 1), fill=WATER_L)
    d.rectangle((0, 2, 9, 2), fill=(110, 176, 230))
    d.line([(0, 3), (0, 11)], fill=(116, 184, 236))
    d.line([(1, 3), (1, 11)], fill=(96, 168, 228))
    d.line([(9, 2), (9, 11)], fill=(56, 120, 190))
    return im


def gauge_zone(base, light):
    im, d = new(14, 12)
    d.rectangle((0, 0, 13, 11), fill=base + (105,))
    d.rectangle((0, 0, 13, 1), fill=light + (235,))
    d.rectangle((0, 10, 13, 11), fill=light + (235,))
    for y in range(4, 8):
        d.point((0, y), fill=light + (235,))
        d.point((1, y), fill=light + (235,))
        d.point((12, y), fill=light + (235,))
        d.point((13, y), fill=light + (235,))
    return im


def gauge_arrow():
    im, d = new(8, 8)
    d.polygon([(7, 0), (7, 7), (0, 4)], fill=(255, 236, 120), outline=OUTLINE)
    return im


# ============================================================================ EXPORTAR
can_frames = [watering_can(i) for i in range(4)]
fx_frames = [rain(i) for i in range(4)] + [ripple(i) for i in range(4)]
wt_frames = [blob(15, 11, shade_humeda, 11), blob(18, 14, shade_empapada, 12), blob(20, 15, shade_encharcada, 13)]
bu_frames = [b_sed(), b_ok(), b_bad()]

sheets = {
    "regadera": (sheet(can_frames, 4, CAN_W, CAN_H), 4, CAN_W, CAN_H, CAN_NAMES),
    "efectos_riego": (sheet(fx_frames, 4, FX_W, FX_H), 4, FX_W, FX_H, FX_NAMES),
    "tierra_mojada": (sheet(wt_frames, 3, WT_W, WT_H), 3, WT_W, WT_H, WT_NAMES),
    "burbujas": (sheet(bu_frames, 3, BU, BU), 3, BU, BU, BU_NAMES),
}
layout = {"escala_arte": S, "pantalla": [1280, 720], "hojas": {}}
for name, (im, cols, cw, ch, names) in sheets.items():
    up(im).save(OUT / f"{name}.png")
    layout["hojas"][name] = {"archivo": f"{name}.png", "celda": [cw * S, ch * S], "columnas": cols,
                             "frames": rects(len(names), cols, cw, ch, names)}

up(gauge_frame()).save(OUT / "medidor_marco.png")
up(gauge_glass()).save(OUT / "medidor_brillo.png")
up(gauge_water()).save(OUT / "medidor_agua.png")
up(gauge_zone(GREEN, GREEN_L)).save(OUT / "medidor_zona_verde.png")
up(gauge_zone(RED, RED_L)).save(OUT / "medidor_zona_roja.png")
up(gauge_arrow()).save(OUT / "medidor_flecha.png")

K = 1280 / (2752 - 21)
bw, bh = round(BROTE.width * K), round(BROTE.height * K)
brote_s = BROTE.resize((bw, bh), Image.LANCZOS)
brote_s.save(OUT / "brote_1280.png")
b_anchor = (round(BINFO["centro_hueco_en_sprite"][0] * K, 1), round(BINFO["centro_hueco_en_sprite"][1] * K, 1))

layout["anclas"] = {
    "regadera_roseta": [CAN_ROSE[0] * S + 1, CAN_ROSE[1] * S + 1],
    "regadera_nota": "Poner la roseta sobre la planta: position = planta - roseta. Se puede rotar el nodo.",
    "lluvia_planta": [RAIN_PLANT[0] * S, RAIN_PLANT[1] * S],
    "lluvia_nota": "El punto 'lluvia_planta' de la celda va sobre el centro del hueco; la lluvia cae desde arriba.",
    "ondas_centro": [FX_W * S // 2, FX_H * S // 2],
    "tierra_mojada_centro": [WT_W * S // 2, WT_H * S // 2],
    "burbuja_punta": [BU_TAIL[0] * S, BU_TAIL[1] * S],
    "burbuja_nota": "Poner la punta de la burbuja ~22 px arriba del centro del hueco.",
    "brote_centro_hueco": list(b_anchor),
    "brote_tamano": [bw, bh],
}
layout["medidor"] = {
    "tamano": [G_W * S, G_H * S],
    "ventana_agua": {"x": WIN[0] * S, "y": WIN[1] * S, "w": WIN[2] * S, "h": WIN[3] * S},
    "agua_nine_patch": {"archivo": "medidor_agua.png", "margen_arriba": 6, "margen_abajo": 0,
                        "nota": "Estirar en vertical dentro de la ventana, pegada al fondo."},
    "zona_nine_patch": {"archivos": ["medidor_zona_verde.png", "medidor_zona_roja.png"], "tamano": [28, 24],
                        "margen_arriba": 4, "margen_abajo": 4,
                        "nota": "Centrar horizontalmente en la ventana (sobresale 4 px a cada lado)."},
    "flecha": {"archivo": "medidor_flecha.png", "tamano": [16, 16], "punta": [0, 8]},
    "orden_de_capas": ["marco", "agua", "zona", "brillo", "flecha"],
}
layout["tierra_mojada_estados"] = {
    "humeda": "poca agua", "empapada": "cantidad correcta", "encharcada": "demasiada agua",
    "nota": "Va DEBAJO del brote_1280.png (el brote ya no esta pintado en el fondo vacio)."}
(OUT / "riego_layout.json").write_text(json.dumps(layout, indent=2, ensure_ascii=False), encoding="utf-8")

# ============================================================================ VISTA PREVIA
HOLES = {h["id"]: (h["x"], h["y"]) for c in HUECOS["camas"] for h in c["huecos"]}
pv = BG.copy()


def put(img, cx, cy, ax, ay):
    pv.alpha_composite(img, (round(cx - ax), round(cy - ay)))


wet = {"c1_f1_1": 0, "c1_f1_2": 1, "c1_f2_1": 2, "c1_f3_2": 0, "c1_f4_1": 2, "c3_f2_1": 1}
wt_up = [up(f) for f in wt_frames]
for hid, st in wet.items():
    put(wt_up[st], *HOLES[hid], WT_W, WT_H)
for hid, (x, y) in HOLES.items():
    put(brote_s, x, y, *b_anchor)
bu_up = [up(f) for f in bu_frames]
for hid, st in (("c1_f3_1", 0), ("c1_f3_2", 1), ("c1_f4_1", 2)):
    x, y = HOLES[hid]
    put(bu_up[st], x, y - 22, BU_TAIL[0] * S, BU_TAIL[1] * S)
# regadera vertiendo sobre c3_f2_1
px_, py_ = HOLES["c3_f2_1"]
put(up(ripple(2)), px_, py_, FX_W * S // 2, FX_H * S // 2)
put(up(rain(1)), px_, py_, RAIN_PLANT[0] * S, RAIN_PLANT[1] * S)
put(up(can_frames[2]), px_, py_ - 56, CAN_ROSE[0] * S + 1, CAN_ROSE[1] * S + 1)

# medidor
GX, GY = 1196, 60
g = up(gauge_frame())
wx, wy, ww, wh = WIN[0] * S, WIN[1] * S, WIN[2] * S, WIN[3] * S
level = 0.62
fill_h = round(wh * level)
w_img = up(gauge_water())
top = w_img.crop((0, 0, ww, 6))
body = w_img.crop((0, 6, ww, w_img.height)).resize((ww, max(fill_h - 6, 1)), Image.NEAREST)
w_full = Image.new("RGBA", (ww, fill_h), CLEAR)
w_full.alpha_composite(top, (0, 0))
w_full.alpha_composite(body, (0, 6))
g.alpha_composite(w_full, (wx, wy + wh - fill_h))
z = up(gauge_zone(GREEN, GREEN_L))
zt, zb = round(wh * (1 - 0.75)), round(wh * (1 - 0.55))     # desde el borde superior de la ventana
zh = zb - zt
zone = Image.new("RGBA", (z.width, zh), CLEAR)
zone.alpha_composite(z.crop((0, 0, z.width, 4)), (0, 0))
zone.alpha_composite(z.crop((0, z.height - 4, z.width, z.height)), (0, zh - 4))
zone.alpha_composite(z.crop((0, 4, z.width, z.height - 4)).resize((z.width, zh - 8), Image.NEAREST), (0, 4))
g.alpha_composite(zone, (wx + ww // 2 - z.width // 2, wy + zt))
g.alpha_composite(up(gauge_glass()))
g.alpha_composite(up(gauge_arrow()), (wx + ww + 0, wy + wh - fill_h - 8))
pv.alpha_composite(g, (GX, GY))
pv.convert("RGB").save(OUT / "_preview.png")
print("ok", OUT, "brote a 1280:", (bw, bh), "ancla:", b_anchor)
