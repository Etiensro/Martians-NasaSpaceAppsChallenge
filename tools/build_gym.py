"""Gimnasio de la Estación Ares 1 y su minijuego de la caminadora.

Fuentes (imágenes del equipo) en tools/data/interiores/gimnasio/:
  GymEscenario.png        el gimnasio (1376x768)
  FondoMiniJuegoGym.jpg   vista desde la caminadora: de aquí solo se usan la pantalla y el medidor,
                          centrados sobre el gimnasio actual
  ObstaculosRocas.jpg     obstáculos sobre fondo magenta (se usan rocas, satélite y meteorito)
  PisoInfinito.jpg        suelo que se repite, sobre fondo rosa

Genera en assets/interiores/estacion_ares1/gimnasio/:
  gym.png, treadmill_view.png   fondos a 1280x720
  floor.png                     franja de suelo que se repite
  rock_m.png, rocks.png, meteor.png, satellite.png
  gym.json                      zonas (caminadora, pantalla de juego, suelo, barra de la consola)

Uso:  python tools/build_gym.py [--preview]   (--preview dibuja las zonas en ../_previews)
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from imgutil import downscale_masked, object_mask

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "tools/data/interiores/gimnasio"
OUT = ROOT / "assets/interiores/estacion_ares1/gimnasio"
W, H = 1280, 720

# Zonas en px de la imagen fuente
TREADMILL = [635, 355, 915, 555]              # GymEscenario: caminadora (zona de clic)
EXIT = [688, 730]                             # GymEscenario: flecha de salida (suelo libre)
PLAYFIELD = [250, 294, 2148, 1340]            # FondoMiniJuego: pantalla donde se juega
GROUND_Y = 1098                               # FondoMiniJuego: línea del suelo dentro de la pantalla
GAUGE = [1020, 1392, 1380, 1460]              # FondoMiniJuego: arco de colores de la consola
CONSOLE = [990, 1470, 1430, 1585]             # FondoMiniJuego: parte oscura de la consola (texto)
FLOOR_STRIP = [142, 26, 1376, 210]            # PisoInfinito: franja de suelo
# Efectos del gimnasio, ya en px de 1280x720 (gym.png)
GYM_FX = {
    "blink_lights": [[175, 132, "ff3b30"], [215, 150, "ffb020"], [232, 152, "ffb020"], [845, 185, "ff3b30"],
                     [628, 342, "4cff7a"], [946, 540, "4cff7a"], [962, 540, "ffb020"], [512, 524, "ff3b30"],
                     [1078, 388, "ffb020"], [1092, 388, "4cff7a"]],
    "glow_lights": [[355, 207, "fff3a0", 2.2], [540, 248, "ff4a3a", 1.6], [470, 42, "cfe8ff", 1.8],
                    [818, 42, "cfe8ff", 1.8], [535, 168, "cfe8ff", 1.1]],
    "displays": [[60, 335, 100, 370], [170, 335, 205, 370], [438, 298, 460, 318], [940, 52, 1000, 98],
                 [955, 385, 988, 410], [992, 393, 1035, 420]],
    "terminals": [[950, 258, 1028, 358], [1055, 238, 1145, 358]],
    "map_blip": [1098, 298],
}
# Obstáculos: nombre -> [zona en ObstaculosRocas.jpg, alto final en px] (el ancho sale de la proporción)
OBSTACLES = {
    "rock_m": [[408, 360, 804, 708], 56],
    "rocks": [[900, 336, 1416, 744], 52],
    "satellite": [[1488, 396, 1896, 696], 60],
    "meteor": [[1968, 372, 2292, 684], 68],
}


def cover(im, align_bottom=False):
    """Escala para cubrir 1280x720 y recorta (centrado o pegado abajo). Devuelve (img, escala, ox, oy)."""
    s = max(W / im.width, H / im.height)
    nw, nh = round(im.width * s), round(im.height * s)
    ox = (nw - W) // 2
    oy = nh - H if align_bottom else (nh - H) // 2
    return im.resize((nw, nh), Image.LANCZOS).crop((ox, oy, ox + W, oy + H)), s, ox, oy


def cut(rgb, mask, box, height):
    x0, y0, x1, y1 = box
    sub, m = rgb[y0:y1, x0:x1], mask[y0:y1, x0:x1]
    w = max(1, round((x1 - x0) * height / (y1 - y0)))
    out = downscale_masked(sub, m, (w, height))
    # quitar el borde rosa/magenta que deja el fondo: esos píxeles pasan a contorno oscuro
    r, g, bl = (out[..., i].astype(int) for i in range(3))
    spill = (out[..., 3] > 0) & (r - g > 70) & (bl - g > 40)
    out[spill, :3] = (34, 22, 30)
    return Image.fromarray(out, "RGBA")


# Minijuego: solo la pantalla (centrada) y el medidor (dentro de la pantalla, arriba a la izquierda)
# de FondoMiniJuegoGym, sobre el gimnasio actual.
SCREEN_CROP = [250, 294, 2148, 1336]          # FondoMiniJuego: interior de la pantalla (el marco se dibuja)
CONSOLE_CROP = [952, 1336, 1460, 1608]        # FondoMiniJuego: medidor (arco de colores) de la consola
SCREEN_W = 960                                # ancho de la pantalla en 1280x720 (centrada)
GAUGE_W = 170                                 # ancho del medidor
GAUGE_MARGIN = 12                             # dentro de la pantalla, en su esquina superior izquierda
GYM_BEHIND_DARKEN = 0.55  # el gimnasio de fondo más oscuro para que resalte la pantalla


def screen_over_gym(src, gym):
    """Pantalla centrada y medidor dentro de ella, arriba a la izquierda. Devuelve (imagen, mapa_pantalla, mapa_medidor):
    cada mapa convierte un punto de la imagen fuente a px de 1280x720."""
    k = SCREEN_W / (SCREEN_CROP[2] - SCREEN_CROP[0])
    back = Image.eval(gym, lambda v: int(v * GYM_BEHIND_DARKEN))
    shot = src.crop(SCREEN_CROP)
    shot = shot.resize((SCREEN_W, round(shot.height * k)), Image.LANCZOS)
    sx, top = (W - SCREEN_W) // 2, (H - shot.height) // 2
    con = src.crop(CONSOLE_CROP)
    kc = GAUGE_W / con.width
    con = con.resize((GAUGE_W, round(con.height * kc)), Image.LANCZOS)
    cx, cy = sx + GAUGE_MARGIN, top + GAUGE_MARGIN
    d = ImageDraw.Draw(back)
    d.rectangle([sx + 6, top + 8, sx + SCREEN_W + 6, top + shot.height + 8], fill=(8, 12, 22))  # sombra
    # marco de la pantalla (como el de la imagen original)
    d.rectangle([sx - 7, top - 7, sx + SCREEN_W + 6, top + shot.height + 6], fill=(20, 26, 42))
    d.rectangle([sx - 4, top - 4, sx + SCREEN_W + 3, top + shot.height + 3], fill=(122, 142, 168))
    back.paste(shot, (sx, top))
    # arriba del medidor asoma el borde rojo de la pantalla original: esos píxeles se quitan
    arr = np.asarray(con.convert("RGBA")).copy()
    edge = arr[: arr.shape[0] // 8]
    reddish = (edge[..., 0].astype(int) - edge[..., 2].astype(int) > 40)
    edge[reddish, 3] = 0
    con_rgba = Image.fromarray(arr, "RGBA")
    back.paste(con_rgba, (cx, cy), con_rgba)
    map_s = lambda p: [round(sx + (p[0] - SCREEN_CROP[0]) * k), round(top + (p[1] - SCREEN_CROP[1]) * k)]
    map_c = lambda p: [round(cx + (p[0] - CONSOLE_CROP[0]) * kc), round(cy + (p[1] - CONSOLE_CROP[1]) * kc)]
    return back, map_s, map_c


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    data = {}

    # Gimnasio
    gym, s, ox, oy = cover(Image.open(SRC / "GymEscenario.png").convert("RGB"))
    gym.save(OUT / "gym.png")
    tp = lambda p: [round(p[0] * s - ox), round(p[1] * s - oy)]
    data["treadmill"] = tp(TREADMILL[:2]) + tp(TREADMILL[2:])
    data["exit"] = tp(EXIT)
    data["fx"] = GYM_FX

    # Minijuego: pantalla y medidor sobre el gimnasio
    view, vp, cp = screen_over_gym(Image.open(SRC / "FondoMiniJuegoGym.jpg").convert("RGB"), gym)
    view.save(OUT / "treadmill_view.png")
    data["playfield"] = vp(PLAYFIELD[:2]) + vp(PLAYFIELD[2:])
    pf = data["playfield"]
    data["ground_y"] = vp([0, GROUND_Y])[1]
    data["gauge"] = cp(GAUGE[:2]) + cp(GAUGE[2:])
    data["console"] = cp(CONSOLE[:2]) + cp(CONSOLE[2:])
    # color del fondo de la pantallita de la consola (tapa la parte de la barra que falta)
    data["console_color"] = "%02x%02x%02x" % view.getpixel((data["gauge"][0] + 6, data["gauge"][3] + 4))

    # Suelo que se repite (alto = desde la línea del suelo hasta abajo de la pantalla)
    floor_rgb = np.asarray(Image.open(SRC / "PisoInfinito.jpg").convert("RGB")).astype(np.int32)
    fmask = object_mask(floor_rgb)
    x0, y0, x1, y1 = FLOOR_STRIP
    fh = pf[3] - data["ground_y"] + 20
    floor = cut(floor_rgb, fmask, FLOOR_STRIP, fh)
    floor.save(OUT / "floor.png")
    data["floor_top"] = round(fh * 18 / (y1 - y0))  # las piedritas de arriba sobresalen del suelo

    # Obstáculos
    rgb = np.asarray(Image.open(SRC / "ObstaculosRocas.jpg").convert("RGB")).astype(np.int32)
    mask = object_mask(rgb)
    data["obstacles"] = {}
    for name, (zone, height) in OBSTACLES.items():
        zx0, zy0, zx1, zy1 = zone
        ys, xs = np.nonzero(mask[zy0:zy1, zx0:zx1])
        box = (zx0 + xs.min(), zy0 + ys.min(), zx0 + xs.max() + 1, zy0 + ys.max() + 1)
        img = cut(rgb, mask, box, height)
        img.save(OUT / f"{name}.png")
        data["obstacles"][name] = list(img.size)
    (OUT / "gym.json").write_text(json.dumps(data, indent=1), encoding="utf-8")
    print("gimnasio:", data["obstacles"])

    if "--preview" in sys.argv:
        prev = ROOT.parent / "_previews"
        prev.mkdir(exist_ok=True)
        g = gym.copy()
        d = ImageDraw.Draw(g)
        d.rectangle(data["treadmill"], outline="yellow", width=3)
        d.ellipse([data["exit"][0] - 6, data["exit"][1] - 6, data["exit"][0] + 6, data["exit"][1] + 6], outline="yellow", width=3)
        g.save(prev / "gym_zonas.png")
        v = view.copy()
        d = ImageDraw.Draw(v)
        d.rectangle(pf, outline="cyan", width=3)
        d.line([pf[0], data["ground_y"], pf[2], data["ground_y"]], fill="yellow", width=2)
        d.rectangle(data["gauge"], outline="lime", width=2)
        d.rectangle(data["console"], outline="white", width=2)
        x = pf[0] + 40
        for name in OBSTACLES:
            sp = Image.open(OUT / f"{name}.png")
            v.paste(sp, (x, data["ground_y"] - sp.height), sp)
            x += sp.width + 20
        fl = Image.open(OUT / "floor.png")
        v.paste(fl, (pf[0], data["ground_y"] - data["floor_top"]), fl)
        v.save(prev / "gym_minijuego_zonas.png")
        print("preview:", prev)


if __name__ == "__main__":
    main()
