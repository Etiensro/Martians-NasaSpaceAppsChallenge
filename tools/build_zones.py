"""Genera el suelo de las zonas de pantalla única (p. ej. AP-1) con los tiles pixel art
del primer mapa (polvo, regolito, basalto), vistos de cerca como en AP-8.

La imagen real del sitio decide qué terreno va en cada tile según su brillo:
claro = polvo, medio = regolito, oscuro = basalto.

  tools/data/zones/ap1_source.png  ->  assets/zones/ap1_ground.png  (84x46 tiles de 16 px = 1344x736)

En Godot el suelo se amplía x3, igual que AP-8 (cada tile = 48 px de mundo), y el
astronauta y el rover van a su tamaño normal. La cámara fija a zoom 0.33 aleja la vista
para que el mapa entero quepa en la pantalla.

Uso:  python tools/build_zones.py
"""
import pathlib

import numpy as np
from PIL import Image, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC_DIR = ROOT / "tools" / "data" / "zones"
OUT = ROOT / "assets" / "zones"
ATLAS = ROOT / "assets" / "mars" / "mars_tiles.png"  # filas: 0 regolito, 1 polvo, 2 basalto, 3 accidentado, 4 hielo

TILE = 16
VARIANTS = 4
REGOLITO, POLVO, BASALTO = 0, 1, 2

# Colores más suaves solo para estas zonas (el mapa global conserva los originales):
# - el basalto pasa de morado oscuro a café oscuro
# - el contraste dentro de cada tile se reduce (SOFTEN) para que el grano sea más sutil
BASALTO_CAFE = {
    (96, 70, 72): (112, 78, 60),   # base
    (74, 54, 60): (94, 64, 50),    # sombra
    (122, 92, 90): (132, 96, 74),  # luz
    (58, 44, 50): (82, 56, 44),    # detalle / rocas
}
SOFTEN = 0.6  # 1 = contraste original, 0 = color plano

# zona -> (imagen, columnas, filas, recorte (x0, y0, x1, y1) o None, espejo horizontal)
# AP-8 y AP-9 reutilizan la misma imagen de AP-1, pero otras partes (y AP-9 en espejo)
# para no tener que generar más mapas.
ZONES = {
    "ap1": ("ap1_source.png", 84, 46, None, False),
    "ap8": ("ap1_source.png", 84, 46, (0, 0, 430, 235), False),       # arriba a la izquierda
    "ap9": ("ap1_source.png", 84, 46, (361, 184, 791, 419), True),    # abajo a la derecha, en espejo
}


def classify(src, cols, rows):
    s = np.asarray(src.filter(ImageFilter.GaussianBlur(1.5)).resize((cols, rows), Image.BOX)).astype(float)
    lum = s @ [0.299, 0.587, 0.114]
    lo, hi = np.quantile(lum, [0.25, 0.62])  # 25 % basalto, 38 % polvo, el resto regolito
    return np.where(lum >= hi, POLVO, np.where(lum <= lo, BASALTO, REGOLITO))


def soft_atlas():
    a = np.asarray(Image.open(ATLAS).convert("RGBA")).astype(float)
    rgb = a[..., :3]
    # basalto (fila 2) a café
    rows = slice(BASALTO * TILE, (BASALTO + 1) * TILE)
    for old, new in BASALTO_CAFE.items():
        m = np.all(rgb[rows] == old, axis=-1)
        rgb[rows][m] = new
    # bajar el contraste de cada fila hacia su color medio
    for k in range(rgb.shape[0] // TILE):
        block = rgb[k * TILE:(k + 1) * TILE]
        mean = block.reshape(-1, 3).mean(0)
        rgb[k * TILE:(k + 1) * TILE] = mean + (block - mean) * SOFTEN
    a[..., :3] = rgb
    return Image.fromarray(a.clip(0, 255).astype(np.uint8))


def bake(atlas, t):
    """Pinta todo el mapa: cada celda con el tile de su terreno (t[y, x])."""
    rows, cols = t.shape
    out = Image.new("RGBA", (cols * TILE, rows * TILE))
    for y in range(rows):
        for x in range(cols):
            v = (x * 7 + y * 13) % VARIANTS  # variante estable para que no se repita
            k = t[y, x]
            out.paste(atlas.crop((v * TILE, k * TILE, (v + 1) * TILE, (k + 1) * TILE)), (x * TILE, y * TILE))
    return np.asarray(out.convert("RGB")).astype(float)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    atlas = soft_atlas()
    for zone, (src_name, cols, rows, crop, mirror) in ZONES.items():
        src = Image.open(SRC_DIR / src_name).convert("RGB")
        if crop:
            src = src.crop(crop)
        if mirror:
            src = src.transpose(Image.FLIP_LEFT_RIGHT)
        t = classify(src, cols, rows)
        img = bake(atlas, t)
        Image.fromarray(img.clip(0, 255).astype(np.uint8)).save(OUT / f"{zone}_ground.png")
        print(zone, f"{cols}x{rows} tiles", {n: f"{100 * (t == k).mean():.0f}%" for k, n in
                                              [(POLVO, "polvo"), (REGOLITO, "regolito"), (BASALTO, "basalto")]})


if __name__ == "__main__":
    main()
