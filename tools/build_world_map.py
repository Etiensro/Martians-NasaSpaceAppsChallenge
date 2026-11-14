"""Genera los recursos del mapa general (selección de sitio):
  - assets/world/arcadia_map.png      fondo pixelado de la región (sin los puntos amarillos)
  - assets/world/icon_AP-*.png        icono de cada sitio (cápsula, rocas, hielo)
  - assets/world/title_AP-*.png       título pixel art de cada sitio
  - assets/world/world_sites.json     posiciones (en píxeles nativos del mapa) y textos

Todo se dibuja a resolución nativa y en Godot se escala x4 (vecino más cercano).

Uso:  python tools/build_world_map.py
"""
import json
import pathlib

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "tools" / "data" / "world" / "arcadia_region.png"
OUT = ROOT / "assets" / "world"
OUT.mkdir(parents=True, exist_ok=True)

NATIVE_W = 320          # ancho del mapa pixelado (x4 en Godot = 1280 px)
MAP_COLORS = 40

OL = (12, 18, 46)       # contorno, igual que el astronauta y el rover

# Sitios: posición del punto amarillo en la imagen original (791x419)
SITES = {
    "AP-1": {"dot": (356.4, 301.4), "title": "AP-1", "subtitle": "BASE ARES 1",
             "colors": ((255, 230, 90), (255, 150, 30)), "sub_color": (255, 255, 255), "icon": "capsule",
             "description": "Sitio de aterrizaje de la mision. Aqui empieza todo."},
    "AP-8": {"dot": (211.4, 128.4), "title": "AP-8", "subtitle": "ZONA DE INVESTIGACIÓN",
             "colors": ((255, 120, 80), (200, 40, 30)), "sub_color": (255, 214, 70), "icon": "rocks",
             "description": "Terreno nudoso y crateres. Peligroso para el rover."},
    "AP-9": {"dot": (584.4, 261.4), "title": "AP-9", "subtitle": "ZONA DE INVESTIGACIÓN",
             "colors": ((180, 240, 255), (70, 160, 240)), "sub_color": (255, 255, 255), "icon": "ice",
             "description": "Pingos y monticulos: indicios de hielo bajo el suelo."},
}

# ---------------------------------------------------------------- sprites (ASCII)
PAL = {
    "o": OL, "W": (236, 240, 246), "w": (196, 204, 218), "g": (146, 154, 172),
    "B": (44, 120, 230), "b": (24, 70, 160), "n": (16, 40, 100),
    "C": (120, 200, 255), "c": (200, 240, 255),
    "R": (220, 66, 30), "r": (150, 36, 18), "Y": (255, 214, 70), "y": (220, 150, 30),
    "k": (40, 40, 52), "D": (96, 64, 56), "M": (140, 96, 78), "L": (186, 136, 106),
    "I": (210, 245, 255), "i": (150, 215, 245), "j": (90, 160, 220), "F": (255, 140, 40),
}

CAPSULE = [
    "........RR........",
    "........oo........",
    "........og........",
    "......oooooo......",
    ".....oWWWWwgo.....",
    "....oWWWWWwwgo....",
    "....oWWoooowgo....",
    "...oWWocCCCown....",
    "...oWWoCCCCbon....",
    "...oWWoCCCbbon....",
    "..oWWWWoooowwgo...",
    "..oRRRRRRRRRrro...",
    ".oBBBBBBBBBBbbno..",
    ".oBBBBBBBBBbbbno..",
    "oBBBBBBBBBBBbbnno.",
    "oooooooooooooooo..",
    ".okko......okko...",
    "okko........okko..",
    "oo............oo..",
]

ROCKS = [
    "..............o.........",
    ".............oYo........",
    "......ooo....oYo........",
    ".....oLLMo..oYkYo.......",
    "....oLLMMDo.oYkYo.......",
    "...oLLLMMDooYYkYYo......",
    "...oLLMMMDDoYYYYYo..oo..",
    "..oLLMMMMDDoYYkYYYooLMo.",
    "..oLMMMMDDDooooooooLMMDo",
    ".oLLMMMMDDDDo..oLLMMMDDo",
    ".oLMMMMDDDDDo.oLLMMMDDDo",
    "oLMMMMMDDDDDDooLMMMDDDDo",
    "oooooooooooooooooooooooo",
]

ICE = [
    "........o...........",
    ".......oIo..........",
    "......oIIio.....o...",
    ".....oIIiijo...oIo..",
    "....oIIIiijo..oIijo.",
    "...oIIIiiijjooIIijo.",
    "...oIIiiijjjooIiijjo",
    "..oIIIiiijjjoIIiijjo",
    "..oIIiiijjjjoIiiijjo",
    ".oIIIiiijjjjjoiijjjo",
    ".oIIiiiijjjjjoijjjjo",
    "oooooooooooooooooooo",
]


def ascii_sprite(rows):
    w = len(rows[0])
    assert all(len(r) == w for r in rows), [len(r) for r in rows]
    im = np.zeros((len(rows), w, 4), np.uint8)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                im[y, x] = (*PAL[ch], 255)
    return Image.fromarray(im)


# ---------------------------------------------------------------- fuente pixel 5x7
FONT = {
    "A": ".###.#...##...#######...##...##...#", "B": "####.#...##...#####.#...##...#####.",
    "C": ".###.#...##....#....#....#...#.###.", "D": "####.#...##...##...##...##...#####.",
    "E": "######....#....####.#....#....#####", "F": "######....#....####.#....#....#....",
    "G": ".###.#...##....#.####...##...#.####", "H": "#...##...##...#######...##...##...#",
    "I": ".###...#....#....#....#....#...###.", "J": "..###...#....#....#....##..#..##..",
    "K": "#...##..#.#.#..##...#.#..#..#.#...#", "L": "#....#....#....#....#....#....#####",
    "M": "#...###.###.#.##.#.##...##...##...#", "N": "#...##...###..##.#.##..###...##...#",
    "O": ".###.#...##...##...##...##...#.###.", "P": "####.#...##...#####.#....#....#....",
    "Q": ".###.#...##...##...##.#.##..#..##.#", "R": "####.#...##...#####.#.#..#..#.#...#",
    "S": ".#####....#.....###.....#....#####.", "T": "#####..#....#....#....#....#....#..",
    "U": "#...##...##...##...##...##...#.###.", "V": "#...##...##...##...##...#.#.#...#..",
    "W": "#...##...##...##.#.##.#.##.#.#.#.#.", "X": "#...##...#.#.#...#...#.#.#...##...#",
    "Y": "#...##...#.#.#...#....#....#....#..", "Z": "#####....#...#...#...#...#....#####",
    "0": ".###.#...##..###.#.###..##...#.###.", "1": "..#...##....#....#....#....#...###.",
    "2": ".###.#...#....#...#...#...#...#####", "3": "####.....#....#.###.....#....#####.",
    "4": "...#...##..#.#.#..#.#####...#....#.", "5": "######....####.....#....##...#.###.",
    "6": ".###.#....#....####.#...##...#.###.", "7": "#####....#...#...#...#....#....#...",
    "8": ".###.#...##...#.###.#...##...#.###.", "9": ".###.#...##...#.####....#....#.###.",
    "Ó": "...#..###.#...##...##...##...#.###.",
    "-": "...............#####...............", " ": "." * 35,
}


def text_mask(text, scale=1, bold=False):
    cw = 5 + (1 if bold else 0)
    w = len(text) * (cw + 1) - 1
    m = np.zeros((7, w), bool)
    for i, ch in enumerate(text.upper()):
        g = np.array([c == "#" for c in FONT[ch]]).reshape(7, 5)
        x0 = i * (cw + 1)
        m[:, x0:x0 + 5] |= g
        if bold:
            m[:, x0 + 1:x0 + 6] |= g
    return np.kron(m, np.ones((scale, scale), bool))


def render_text(text, top, bottom, scale=1, bold=False):
    """Texto pixel con relleno degradado, contorno oscuro y sombra."""
    m = text_mask(text, scale, bold)
    h, w = m.shape
    pad = 2
    H, W = h + pad * 2 + 1, w + pad * 2
    canvas = np.zeros((H, W, 4), np.uint8)
    fill = np.zeros((H, W), bool)
    fill[pad:pad + h, pad:pad + w] = m
    outline = np.zeros_like(fill)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            outline |= np.roll(np.roll(fill, dy, 0), dx, 1)
    shadow = np.roll(outline, 1, 0) & ~outline
    canvas[shadow] = (0, 0, 0, 160)
    canvas[outline] = (*OL, 255)
    for y in range(H):
        t = (y - pad) / max(1, h - 1)
        c = [int(top[k] + (bottom[k] - top[k]) * min(max(t, 0), 1)) for k in range(3)]
        row = fill[y]
        canvas[y, row] = (*c, 255)
    # brillo en la primera fila de cada letra
    first = fill & ~np.roll(fill, 1, 0)
    canvas[first] = (255, 255, 255, 255)
    return Image.fromarray(canvas)


def stack(images, gap=1):
    w = max(i.width for i in images)
    h = sum(i.height for i in images) + gap * (len(images) - 1)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    y = 0
    for im in images:
        out.alpha_composite(im, ((w - im.width) // 2, y))
        y += im.height + gap
    return out


# ---------------------------------------------------------------- mapa
def build_map():
    src = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float32)
    h, w, _ = src.shape
    # borrar los puntos amarillos: rellenar con el color medio del anillo de alrededor
    yy, xx = np.mgrid[0:h, 0:w]
    for s in SITES.values():
        cx, cy = s["dot"]
        d = np.hypot(xx - cx, yy - cy)
        ring = (d > 8) & (d < 13)
        src[d <= 8] = src[ring].mean(axis=0)
    im = Image.fromarray(src.clip(0, 255).astype(np.uint8))
    nh = round(h * NATIVE_W / w)
    small = im.resize((NATIVE_W, nh), Image.BOX)
    small = small.quantize(MAP_COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    small.save(OUT / "arcadia_map.png")
    return w, h, NATIVE_W / w


TITLE_SCALE = 2          # los títulos se muestran x2 (la mitad que el mapa) para no saturar
GEMINI_ICON_WIDTH = 90   # ancho en pantalla (px) de los iconos hechos con Gemini


def gemini_icon(path):
    """Recorta un icono de Gemini (fondo naranja liso) y lo reduce a GEMINI_ICON_WIDTH px.
    Se muestra a escala 1 en Godot (no x4) para conservar el detalle."""
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.int32)
    bg = np.median(rgb[:20, :20].reshape(-1, 3), axis=0)
    mask = np.abs(rgb - bg).sum(2) > 90
    ys, xs = np.nonzero(mask)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgba = np.dstack([rgb, mask * 255]).astype(np.uint8)[y0:y1, x0:x1]
    im = Image.fromarray(rgba)
    k = GEMINI_ICON_WIDTH / im.width
    small = np.asarray(im.resize((GEMINI_ICON_WIDTH, round(im.height * k)), Image.BOX)).copy()
    small[..., 3] = np.where(small[..., 3] > 140, 255, 0)
    out = Image.fromarray(small)
    alpha = out.getchannel("A")
    out = out.convert("RGB").quantize(40, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
    out.putalpha(alpha)
    return out


def main():
    src_w, src_h, k = build_map()
    icons = {"capsule": ascii_sprite(CAPSULE), "rocks": ascii_sprite(ROCKS), "ice": ascii_sprite(ICE)}
    meta = {"native_width": NATIVE_W, "scale": 4, "title_scale": TITLE_SCALE, "sites": {}}
    for sid, s in SITES.items():
        # Si hay un icono hecho con Gemini (tools/data/world/icon_<ID>_gemini.png), se usa ese
        custom = SRC.parent / f"icon_{sid}_gemini.png"
        icon_scale = 4
        if custom.exists():
            gemini_icon(custom).save(OUT / f"icon_{sid}.png")
            icon_scale = 1
        else:
            icons[s["icon"]].save(OUT / f"icon_{sid}.png")
        # "|" en el subtítulo = salto de línea
        title = stack([render_text(s["title"], *s["colors"], scale=2, bold=True)] +
                      [render_text(line, s["sub_color"], s["sub_color"], scale=1) for line in s["subtitle"].split("|")])
        title.save(OUT / f"title_{sid}.png")
        meta["sites"][sid] = {
            "x": round(s["dot"][0] * k, 2), "y": round(s["dot"][1] * k, 2),
            "title": s["title"], "subtitle": s["subtitle"].replace("|", " "), "label": s.get("label", "above"), "description": s["description"], "icon_scale": icon_scale,
        }
    (OUT / "world_sites.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")
    print("mapa general listo:", OUT)


if __name__ == "__main__":
    main()
