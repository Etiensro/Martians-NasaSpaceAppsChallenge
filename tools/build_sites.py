"""Zonas de investigación AP-8 y AP-9: suelo propio de cada una + excavadora, paneles pequeños y el carro.

Cada zona tiene SOLO tres cosas: la excavadora (taladro de la muestra), los paneles pequeños que le dan
energía (unidos con un cable) y el carro explorador con el que llega el jugador.

Lo que las hace distintas (sale del mapa general, assets/world/world_sites.json):
  - AP-8 "Knobby terrain and craters": cráteres grandes (no se puede pasar), rocas y suelo accidentado.
  - AP-9 "Pingos and mounds: ice under the ground": montículos con hielo arriba, manchas de escarcha.

Entrada:  assets/zones/ap8_ground.png, ap9_ground.png  (tools/build_zones.py)
          assets/mars/mars_tiles.png                    (fila 3 = cráteres, fila 4 = hielo)
          tools/data/buildings/zona_paneles_gemini.jpg + zona_paneles_sucios_gemini.webp (paneles pequeños)
          assets/buildings/excavadora.png, vehiculo.png  (tools/build_colony.py)
Salida:   assets/zones/<zona>_site_ground.png, <zona>_blocked.png
          assets/buildings/zona_paneles.png (+ _sucios.png)
          assets/zones/sites.json  (posición, puerta, efectos y destellos de todo; lo lee scripts/expedition_site.gd)

Unidades: 1 píxel del suelo = 3 px de mundo en Godot (igual que AP-1).

Uso:  python tools/build_sites.py
"""
import json
import pathlib

import numpy as np
from PIL import Image

from build_colony import DATA, Ground, base_footprint, load
from imgutil import downscale_masked
from build_zones import TILE, VARIANTS, soft_atlas

ROOT = pathlib.Path(__file__).resolve().parent.parent
ZONES = ROOT / "assets" / "zones"
BLD = ROOT / "assets" / "buildings"
CELL = 3
CRATER_ROW, ICE_ROW = 3, 4

# Paneles pequeños (versión de 1 módulo): 8 paneles + módulo + baterías. Misma imagen de Gemini limpia
# (fondo verde) y sucia (fondo transparente), con el mismo encuadre: se recortan con la misma caja.
PANELS_CLEAN = "buildings/zona_paneles_gemini.jpg"
PANELS_DIRTY = "buildings/zona_paneles_sucios_gemini.webp"
PANELS_WIDTH = 240          # px del suelo (los paneles quedan del tamaño de los de AP-1)
PANELS_DOOR = (1180, 1215)  # delante de la rampa del módulo, en px de la imagen original

# zona -> posiciones (px del suelo, punto donde tocan el suelo, abajo al centro)
SITES = {
    "AP-8": {
        "ground": "ap8", "seed": 8,
        "excavator": (760, 600), "panels": (1100, 380), "vehicle": (250, 470),
        # cráteres: (x, y, radio x, radio y)
        "craters": [(420, 190, 95, 52), (1180, 600, 80, 44), (180, 660, 70, 38), (640, 330, 46, 26), (1240, 160, 60, 32)],
        "rocks": 70,
    },
    "AP-9": {
        "ground": "ap9", "seed": 9,
        "excavator": (620, 610), "panels": (300, 380), "vehicle": (1090, 470),
        # pingos (montículos con hielo dentro): (x, y, radio x, radio y)
        "pingos": [(820, 210, 92, 50), (160, 560, 74, 40), (1220, 640, 68, 36), (560, 160, 52, 28), (1010, 380, 44, 24)],
        "frost": 0.22,
    },
}


def rgba(path):
    return np.asarray(Image.open(path).convert("RGBA"))


def small_panels():
    """Sprites de los paneles pequeños (limpio y sucio, misma caja) y la puerta en px del sprite."""
    rgb_c, m_c = load(PANELS_CLEAN)
    rgba_d = np.asarray(Image.open(DATA / PANELS_DIRTY).convert("RGBA")).astype(float)
    rgb_d, m_d = rgba_d[..., :3], rgba_d[..., 3] > 128
    ys, xs = np.nonzero(m_c | m_d)
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    k = PANELS_WIDTH / (x1 - x0)
    size = (PANELS_WIDTH, round((y1 - y0) * k))
    clean = downscale_masked(rgb_c[y0:y1, x0:x1], m_c[y0:y1, x0:x1], size)
    # restos del fondo verde entre las patas (las luces verdes de las baterías, abajo a la derecha, se quedan)
    r, g, b = (clean[..., i].astype(int) for i in range(3))
    yy, xx = np.mgrid[0:size[1], 0:size[0]]
    leftover = (g > r + 40) & (g > b + 30) & ~((xx > size[0] * 0.78) & (yy > size[1] * 0.68))
    clean[leftover, 3] = 0
    dirty = downscale_masked(rgb_d[y0:y1, x0:x1], m_d[y0:y1, x0:x1], size)
    door = (round((PANELS_DOOR[0] - x0) * k), round((PANELS_DOOR[1] - y0) * k))
    return clean, dirty, door


def tile_patches(ground_img, atlas, row, share, seed):
    """Cambia una parte (`share`) de los tiles del suelo por los de la fila `row` del atlas, en manchas."""
    H, W = ground_img.shape[:2]
    rows, cols = H // TILE, W // TILE
    rng = np.random.default_rng(seed)
    low = rng.random((rows // 4 + 2, cols // 4 + 2))
    big = np.asarray(Image.fromarray((low * 255).astype(np.uint8)).resize((cols, rows), Image.BICUBIC)) / 255.0
    sel = big > np.quantile(big, 1 - share)
    tiles = np.asarray(atlas.convert("RGB")).astype(float)
    for y in range(rows):
        for x in range(cols):
            if sel[y, x]:
                v = (x * 5 + y * 11) % VARIANTS
                ground_img[y * TILE:(y + 1) * TILE, x * TILE:(x + 1) * TILE] = \
                    tiles[row * TILE:(row + 1) * TILE, v * TILE:(v + 1) * TILE]


def dome(g, thr, cx, cy, rx, ry, base, top=None, top_share=0.0, inward=False):
    """Montículo (o cráter si inward) sombreado con luz de arriba a la izquierda, en 4 tonos tramados."""
    H, W = g.shape[:2]
    yy, xx = np.mgrid[0:H, 0:W]
    nx, ny = (xx - cx) / rx, (yy - cy) / ry
    d = nx ** 2 + ny ** 2
    inside = d < 1.0
    light = -(nx + ny) * 0.5  # -1 .. 1 (positivo = mira a la luz)
    if inward:
        light = -light
    shade = 1.0 + 0.32 * light
    shade = np.round(shade * 4 + thr * 0.9) / 4  # cuantizar con tramado
    col = np.array(base, float)
    g[inside] = (col * shade[..., None])[inside]
    # borde: sombra al sur-este (montículo) o labio claro (cráter)
    ring = (d >= 0.82) & (d < 1.12)
    if inward:
        g[ring & (ny < 0.2)] = g[ring & (ny < 0.2)] * 0.7
        g[ring & (ny >= 0.2)] = np.minimum(g[ring & (ny >= 0.2)] * 1.25, 255)
    else:
        g[ring & (ny + nx > 0)] = g[ring & (ny + nx > 0)] * 0.72
    if top is not None:  # hielo asomando en la cima (pingos)
        cap = (((xx - cx + rx * 0.12) / (rx * top_share)) ** 2 + ((yy - cy + ry * 0.2) / (ry * top_share)) ** 2) < 1.0
        crack = cap & (((xx + yy * 2) % 9) == 0)
        g[cap] = np.array(top, float) * (0.92 + 0.12 * thr[cap][:, None])
        g[crack] = np.array(top, float) * 0.7
    return inside


def rocks(g, blocked, n, rng, keep_out):
    """Rocas sueltas del terreno accidentado de AP-8 (las grandes bloquean el paso)."""
    H, W = g.shape[:2]
    placed = 0
    while placed < n:
        x, y = int(rng.integers(30, W - 30)), int(rng.integers(30, H - 20))
        if any(x0 <= x <= x1 and y0 <= y <= y1 for x0, y0, x1, y1 in keep_out):
            continue
        r = int(rng.integers(3, 9))
        yy, xx = np.mgrid[-r:r + 1, -r:r + 1]
        body = (xx / r) ** 2 + (yy / (r * 0.7)) ** 2 < 1
        for (oy, ox) in zip(*np.nonzero(body)):
            py, px = y + oy - r, x + ox - r
            if 0 <= py < H and 0 <= px < W:
                k = 1.15 if (ox - r) + (oy - r) < -r * 0.4 else (0.7 if (ox - r) + (oy - r) > r * 0.4 else 0.92)
                g[py, px] = np.array([92, 62, 50]) * k
        g[y + int(r * 0.7):y + int(r * 0.7) + 2, x - r + 2:x + r + 2] *= 0.7  # sombra
        if r >= 6:
            blocked[y - 2:y + int(r * 0.6), x - r + 1:x + r] = True
        placed += 1


def put_sprite(blocked, ground, sprite, pos, depth, shadow=True):
    sh, sw = sprite.shape[:2]
    x0, y0 = pos[0] - sw // 2, pos[1] - sh
    sm = sprite[..., 3] > 0
    if shadow:
        ground.shadow(sm, x0, y0)
    foot = base_footprint(sm, depth)
    for _ in range(5):
        foot = foot | np.roll(foot, 1, 0)
    ys, xs = np.nonzero(foot)
    ok = (ys + y0 < blocked.shape[0]) & (xs + x0 < blocked.shape[1]) & (ys + y0 >= 0) & (xs + x0 >= 0)
    blocked[ys[ok] + y0, xs[ok] + x0] = True
    return x0, y0


def glint_points(sprite, x0, y0, n=30, seed=7):
    r, g, b = (sprite[..., i].astype(int) for i in range(3))
    panel = (sprite[..., 3] > 0) & (b > r + 40) & (b > 90) & (r < 90)
    ys, xs = np.nonzero(panel)
    pick = np.random.default_rng(seed).choice(len(ys), size=min(n, len(ys)), replace=False)
    return [[int((xs[i] + x0) * CELL), int((ys[i] + y0) * CELL)] for i in pick]


def world(p):
    return [round(p[0] * CELL), round(p[1] * CELL)]


def main():
    atlas = soft_atlas()
    clean, dirty, pdoor = small_panels()
    Image.fromarray(clean, "RGBA").save(BLD / "zona_paneles.png")
    Image.fromarray(dirty, "RGBA").save(BLD / "zona_paneles_sucios.png")
    exc = rgba(BLD / "excavadora.png")
    veh = rgba(BLD / "vehiculo.png")
    meta = {}

    for site, cfg in SITES.items():
        rng = np.random.default_rng(cfg["seed"])
        g0 = np.asarray(Image.open(ZONES / f"{cfg['ground']}_ground.png").convert("RGB")).astype(float)
        ground = Ground(g0.copy())
        g = ground.g
        H, W = g.shape[:2]
        blocked = np.zeros((H, W), bool)
        ex, pa, ve = cfg["excavator"], cfg["panels"], cfg["vehicle"]
        keep_out = [(ex[0] - 190, ex[1] - 150, ex[0] + 190, ex[1] + 30),
                    (pa[0] - 150, pa[1] - 200, pa[0] + 150, pa[1] + 30),
                    (ve[0] - 90, ve[1] - 60, ve[0] + 90, ve[1] + 50)]
        features = []

        if site == "AP-8":
            tile_patches(g, atlas, CRATER_ROW, 0.28, cfg["seed"])  # suelo lleno de crateritos
            for cx, cy, rx, ry in cfg["craters"]:
                inside = dome(g, ground.thr, cx, cy, rx, ry, (120, 70, 52), inward=True)
                # el fondo del cráter no se pisa (el borde sí)
                yy, xx = np.mgrid[0:H, 0:W]
                blocked |= ((xx - cx) / (rx * 0.8)) ** 2 + ((yy - cy) / (ry * 0.75)) ** 2 < 1
                features.append({"type": "crater", "at": world((cx, cy)), "r": [rx * CELL, ry * CELL]})
            rocks(g, blocked, cfg["rocks"], rng, keep_out)
        else:
            tile_patches(g, atlas, ICE_ROW, cfg["frost"], cfg["seed"])  # escarcha en el suelo
            # la escarcha se mezcla un poco con el color del suelo para que no sea blanco puro
            g[:] = g * 0.82 + g0 * 0.18
            for cx, cy, rx, ry in cfg["pingos"]:
                dome(g, ground.thr, cx, cy, rx, ry, (176, 104, 74), top=(214, 236, 248), top_share=0.45)
                yy, xx = np.mgrid[0:H, 0:W]
                blocked |= ((xx - cx) / (rx * 0.85)) ** 2 + ((yy - cy) / (ry * 0.8)) ** 2 < 1
                features.append({"type": "pingo", "at": world((cx - rx * 0.12, cy - ry * 0.2)), "r": [rx * CELL, ry * CELL]})

        # explanadas bajo la excavadora, los paneles y el carro, y el cable de los paneles a la excavadora
        ground.pad(ex[0], ex[1] - 60, 170, 80)
        ground.pad(pa[0], pa[1] - 60, 140, 80)
        ground.pad(ve[0], ve[1] - 10, 52, 28)
        ex_cable = (ex[0] + (90 if pa[0] > ex[0] else -120), ex[1] - 40)
        ground.cable((pa[0] + (-70 if pa[0] > ex[0] else 70), pa[1] - 4), ex_cable, "v")
        ground.path([(ve[0], ve[1] + 6), (ve[0], ex[1] + 24), (ex[0] - 120, ex[1] + 24)], half=6)

        ex0 = put_sprite(blocked, ground, exc, ex, 0.32)
        pa0 = put_sprite(blocked, ground, clean, pa, 0.30)
        vx0 = put_sprite(blocked, ground, veh, ve, 0.45, shadow=False)
        # puertas: excavadora en su escotilla (igual que AP-1), paneles y carro por delante
        ex_door = (ex0[0] + 73, ex[1] + 5)  # igual que en AP-1 (colony.json)
        pa_door = (pa0[0] + pdoor[0], pa0[1] + pdoor[1] + 4)
        ve_door = (ve[0], ve[1] + 4)
        for dx, dy in (ex_door, pa_door, ve_door):
            blocked[dy - 2:dy + 8, max(0, dx - 10):dx + 11] = False

        name = cfg["ground"]
        Image.fromarray(g.clip(0, 255).astype(np.uint8)).save(ZONES / f"{name}_site_ground.png")
        Image.fromarray((blocked * 255).astype(np.uint8)).save(ZONES / f"{name}_blocked.png")
        es, ps, vs = exc.shape, clean.shape, veh.shape
        meta[site] = {
            "cell": CELL,
            "spawn": world((ve[0] + 60, ve[1] + 10)),
            "excavator": {
                "name": "Ice drill", "texture": "res://assets/buildings/excavadora.png",
                "pos": world(ex), "size": [es[1] * CELL, es[0] * CELL], "door": world(ex_door),
                # broca (punta del taladro) y luces, en px del suelo -> mundo
                "drill_tip": world((ex0[0] + 242, ex0[1] + 168)),
                "fx": [{"type": "beacon", "at": world((ex0[0] + 230, ex0[1] + 6)), "color": "ff3b2f"},
                       {"type": "door_light", "at": world((ex0[0] + 58, ex0[1] + 175)), "color": "ffd84a"}],
            },
            "panels": {
                "name": "Small solar panels", "texture": "res://assets/buildings/zona_paneles.png",
                "dirty_texture": "res://assets/buildings/zona_paneles_sucios.png",
                "pos": world(pa), "size": [ps[1] * CELL, ps[0] * CELL], "door": world(pa_door),
                "glints": glint_points(clean, *pa0, n=40),
            },
            "vehicle": {"texture": "res://assets/buildings/vehiculo.png", "pos": world(ve),
                        "size": [vs[1] * CELL, vs[0] * CELL], "door": world(ve_door)},
            "features": features,
        }
        print(site, "listo")

    (ZONES / "sites.json").write_text(json.dumps(meta, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
