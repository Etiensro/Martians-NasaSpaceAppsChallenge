"""Distribuye los edificios de la colonia (AP-1) integrados en el suelo pixel art.

Entrada:  assets/zones/ap1_ground.png                (suelo de build_zones.py; ejecútalo antes)
          tools/data/buildings/<id>_gemini.jpg       (edificios de Gemini, fondo naranja liso)
          tools/data/vehicles/vehiculo_sheet_gemini.jpg
Salida:   assets/buildings/<id>.png                  (edificio recortado, sin borde naranja)
          assets/zones/ap1_colony_ground.png          (suelo con explanadas de tierra, caminos y sombras)
          assets/zones/ap1_blocked.png                (blanco = no se puede caminar)
          assets/buildings/colony.json                (posición, puerta e interior de cada edificio)

Unidades: 1 píxel del suelo = 3 px de mundo en Godot (igual que los tiles).

Uso:  python tools/build_colony.py             (genera los recursos del juego)
      python tools/build_colony.py --preview   (solo una imagen de prueba en ../_previews/)
"""
import json
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw

from imgutil import crop_to_mask, downscale_masked, find_sprites, object_mask

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = ROOT / "tools" / "data"
ZONES = ROOT / "assets" / "zones"
OUT = ROOT / "assets" / "buildings"
PREVIEW = ROOT.parent / "_previews"
CELL = 3  # px de mundo por píxel del suelo

# "pos" = punto donde el edificio toca el suelo (abajo al centro), en píxeles del suelo (1344x736).
# "door" = puerta en la imagen ORIGINAL de Gemini (px). "width" = ancho en píxeles del suelo.
BUILDINGS = {
    "estacion": {
        "name": "Ares 1 Station",
        "src": "buildings/estacion_gemini.jpg",
        "width": 520, "pos": (400, 385),
        "door": (135, 1150),
        "cable": {"este": (1760, 1150), "sur": (900, 790), "oeste": (330, 1110)},   # pie de la rampa de la entrada principal (izquierda, con poste de luz)
        "interior": "res://scenes/interiores/estacion_ares1/estacion_ares1.tscn",
        "fx": [
            {"type": "door_light", "at": (240, 1030), "color": "ffd84a"},
            {"type": "door_light", "at": (160, 975), "color": "c8ff9a"},        # poste de luz
            {"type": "door_light", "at": (1220, 1010), "color": "ffb347"},      # puerta lateral iluminada
            {"type": "glow", "at": (1000, 660), "color": "ffd84a", "size": 3.0},  # luces del domo central
            {"type": "beacon", "at": (490, 225), "color": "ff3b2f"},
            {"type": "blink", "at": (300, 795), "color": "ff3b2f", "period": 1.6},
            {"type": "blink", "at": (470, 800), "color": "ffd84a", "period": 2.2},
        ],
    },
    "paneles_grande": {
        "name": "Solar panels",
        "src": "buildings/paneles_grande_gemini.jpg",
        "width": 380, "pos": (918, 341),
        "door": (885, 1045),
        "depth": 0.30,
        "cable": {"sur": (1900, 1000)},
        "interior": "res://scenes/interiores/paneles_solares/paneles_solares.tscn",
        "fx": [
            {"type": "door_light", "at": (960, 930), "color": "ffd84a"},
            {"type": "beacon", "at": (1775, 515), "color": "ff3b2f"},
            {"type": "glow", "at": (1840, 740), "color": "6bff7a", "size": 2.5},
            {"type": "blink", "at": (1150, 860), "color": "ffd84a", "period": 1.3},
        ],
        "glints": True,
    },
    "excavadora": {
        "name": "Ice excavator",
        "src": "buildings/excavadora_gemini.jpg",
        "width": 300, "pos": (561, 639),
        "door": (595, 1245),
        "depth": 0.22,
        "free": [(1200, 100, 1800, 1300)],  # la torre/antena del taladro no bloquea el paso
        "cable": {"norte": (1050, 930)},
        "interior": "res://scenes/interiores/excavadora/excavadora.tscn",
        "fx": [
            {"type": "door_light", "at": (700, 1040), "color": "ffd84a"},
            {"type": "beacon", "at": (1500, 140), "color": "ff3b2f"},
            {"type": "glow", "at": (800, 800), "color": "ffd84a", "size": 2.5},
            {"type": "ice", "at": (1520, 960)},
            {"type": "steam", "at": (1060, 830)},
        ],
    },
    "nave": {
        "name": "Spaceship",
        "src": "buildings/nave_gemini.png",
        "width": 230, "pos": (1100, 662),
        "door": (310, 540),          # pie de la escalera de la plataforma (no se entra: decoración)
        "enterable": False,
        "depth": 0.06,
        # El cohete es sólido; el resto de la imagen (plataforma y escalera) se pinta en el suelo
        # y se puede caminar encima. Polígono del cohete en px de la imagen original:
        "solid_poly": [(500, 15), (525, 15), (560, 100), (575, 250), (600, 320), (612, 418), (565, 420),
                       (540, 392), (485, 392), (445, 368), (405, 368), (412, 330), (455, 260), (460, 100)],
        # Plataforma: solo se camina sobre la parte de arriba y se sube solo por la escalera
        "walk_ellipse": (512, 365, 226, 104),   # cx, cy, rx, ry en px de la imagen original
        "walk_poly": [(280, 512), (325, 542), (418, 448), (405, 412), (355, 410)],  # escalera
        "interior": "",  # no se puede entrar
        "fx": [
            {"type": "beacon", "at": (512, 30), "color": "ff3b2f"},
            {"type": "glow", "at": (512, 375), "color": "ff9a3c", "size": 1.6},     # tobera aún tibia
            {"type": "blink", "at": (350, 268), "color": "ffd84a", "period": 1.2},
            {"type": "blink", "at": (676, 270), "color": "ffd84a", "period": 1.2},
            {"type": "blink", "at": (757, 372), "color": "ffd84a", "period": 1.2},
            {"type": "blink", "at": (690, 455), "color": "ffd84a", "period": 1.2},
            {"type": "blink", "at": (512, 488), "color": "ffd84a", "period": 1.2},
            {"type": "blink", "at": (267, 372), "color": "ffd84a", "period": 1.2},
        ],
    },
}
VEHICLE = {"src": "vehicles/vehiculo_sheet_gemini.jpg", "frame": (0, 1), "width": 70, "pos": (300, 480)}  # en el punto de reunión, donde aparece el personaje
# Cables de energía/datos sobre el suelo: (edificio.punto, edificio.punto)
# Cables: (desde, hasta[, "h"|"v"]). Cada extremo es "edificio.punto" (ver "cable" de BUILDINGS) o un punto
# (x, y) en px del mapa. "h" = primero en horizontal y luego en vertical; "v" = al revés; sin nada, automático.
CABLES = [
    ("paneles_grande.sur", "estacion.este"),         # energía de los paneles a la base
    ((548, 543), (753, 319), "h"),                   # excavadora (lado derecho del tanque) -> cable paneles-base
    ((1089, 322), (1140, 520), "h"),                 # paneles (módulo de control) -> nave
]
CABLE_OUT = np.array([12, 18, 46])
CABLE_CORE = np.array([38, 86, 190])
CABLE_LIGHT = np.array([96, 156, 240])

# Punto de reunión de los caminos (delante de la estación principal)
HUB = (300, 470)

PAD = np.array([182, 120, 92])        # tierra compactada
PAD_DARK = np.array([160, 102, 78])
PATH = np.array([206, 150, 116])      # camino pisado
PATH_DARK = np.array([190, 134, 104])
DUST = np.array([150, 92, 68])
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16


def cut(rgb, mask, width):
    """Recorta y reduce a `width` px de ancho sin dejar borde naranja. Devuelve (sprite, caja, escala)."""
    rgb, mask, box = crop_to_mask(rgb, mask)
    k = width / rgb.shape[1]
    return downscale_masked(rgb, mask, (width, round(rgb.shape[0] * k))), box, k


def load(src, erase=()):
    rgb = np.asarray(Image.open(DATA / src).convert("RGB")).astype(float)
    mask = object_mask(rgb)
    for x0, y0, x1, y1 in erase:  # borrar zonas sobrantes (cajas en px de la imagen original)
        mask[y0:y1, x0:x1] = False
    # Borde: quitar el tinte del fondo verde (despill) en los 4 px junto al fondo
    near = ~mask
    for _ in range(4):
        near = near | np.roll(near, 1, 0) | np.roll(near, -1, 0) | np.roll(near, 1, 1) | np.roll(near, -1, 1)
    edge = mask & near
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    spill = edge & (g > np.maximum(r, b))
    rgb[spill, 1] = np.maximum(r, b)[spill]
    # píxeles casi verdes del borde (mezcla con el fondo) fuera
    mask &= ~(edge & (g > r + 60) & (g > b + 60))
    return rgb, mask


def vehicle_frame(src, rc):
    rgb = np.asarray(Image.open(DATA / src).convert("RGB")).astype(np.int32)
    mask, rows = find_sprites(rgb)
    x0, y0, x1, y1 = rows[rc[0]][rc[1]]
    return empty_cabin(rgb[y0:y1, x0:x1].astype(float)), mask[y0:y1, x0:x1]


def empty_cabin(rgb):
    """Gemini dibujó un astronauta manejando: se repinta el parabrisas como cristal vacío
    (degradado azul con reflejo). Polígono en px del frame (0, 1) de la hoja del vehículo."""
    poly = [(52, 92), (96, 72), (150, 80), (172, 96), (160, 152), (66, 160), (44, 132)]
    pm = Image.new("L", (rgb.shape[1], rgb.shape[0]), 0)
    ImageDraw.Draw(pm).polygon(poly, fill=255)
    sel = (np.asarray(pm) > 0) & (rgb.sum(2) > 180) & (rgb[..., 2] > rgb[..., 0] + 20)
    yy, xx = np.mgrid[0:rgb.shape[0], 0:rgb.shape[1]]
    t = np.clip((yy - 70) / 90, 0, 1)[..., None]
    glass = np.array([120, 200, 230]) * (1 - t) + np.array([40, 110, 170]) * t
    stripe = (np.abs((xx + yy * 0.8) - 150) < 7) | (np.abs((xx + yy * 0.8) - 175) < 3)
    glass[stripe] = glass[stripe] * 0.4 + np.array([230, 250, 255]) * 0.6
    rgb[sel] = glass[sel]
    return rgb


class Ground:
    def __init__(self, img):
        self.g = img
        self.H, self.W = img.shape[:2]
        self.thr = np.tile(BAYER, (self.H // 4 + 1, self.W // 4 + 1))[:self.H, :self.W]
        self.noise = np.random.default_rng(4).random((self.H, self.W))
        self.yy, self.xx = np.mgrid[0:self.H, 0:self.W]

    def pad(self, cx, cy, rx, ry, strength=0.5):
        """Capa ligera de tierra (se mezcla con el terreno) con borde tramado."""
        d = ((self.xx - cx) / rx) ** 2 + ((self.yy - cy) / ry) ** 2
        sel = (d < 1.0) | ((d < 1.3) & (self.thr < (1.3 - d) / 0.3))
        col = np.where((self.noise[sel] < 0.12)[:, None], PAD_DARK, PAD)
        self.g[sel] = self.g[sel] * (1 - strength) + col * strength

    def path(self, pts, half=7):
        """Camino de tierra pisada siguiendo una línea quebrada."""
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            n = int(max(abs(bx - ax), abs(by - ay))) + 1
            for t in np.linspace(0, 1, n):
                px, py = ax + (bx - ax) * t, ay + (by - ay) * t
                for oy in range(-half - 2, half + 3):
                    for ox in range(-half - 2, half + 3):
                        x, y = int(px + ox), int(py + oy)
                        if not (0 <= x < self.W and 0 <= y < self.H):
                            continue
                        r = max(abs(ox), abs(oy))
                        if r <= half - 2 or (r <= half + 2 and self.thr[y, x] < (half + 2 - r) / 4):
                            self.g[y, x] = PATH if self.noise[y, x] > 0.1 else PATH_DARK

    def cable(self, a, b, first=""):
        """Cable sobre el suelo de a a b: tramo en L con esquina redondeada, contorno oscuro,
        núcleo azul, brillo y pequeñas cajas de conexión. first="h"/"v": por dónde empieza la L."""
        (ax, ay), (bx, by) = a, b
        horizontal_first = first == "h" or (first == "" and abs(bx - ax) > abs(by - ay))
        mid = (bx, ay) if horizontal_first else (ax, by)
        pts = []
        for (px0, py0), (px1, py1) in ((a, mid), (mid, b)):
            n = int(max(abs(px1 - px0), abs(py1 - py0))) + 1
            pts += [(px0 + (px1 - px0) * t, py0 + (py1 - py0) * t) for t in np.linspace(0, 1, n)]
        # suavizar la esquina con una media móvil
        arr = np.array(pts)
        k = 9
        if len(arr) > k:
            arr = np.vstack([arr[:k // 2], np.convolve(arr[:, 0], np.ones(k) / k, "valid")[:, None].repeat(2, 1) * [1, 0] +
                             np.convolve(arr[:, 1], np.ones(k) / k, "valid")[:, None].repeat(2, 1) * [0, 1], arr[-(k // 2):]])
        for layer, r, col in ((0, 3, CABLE_OUT), (1, 2, CABLE_CORE)):
            for x, y in arr:
                xi, yi = int(round(x)), int(round(y))
                self.g[max(0, yi - r + 1):yi + r, max(0, xi - r + 1):xi + r] = col
        for x, y in arr[::1]:
            xi, yi = int(round(x)), int(round(y))
            if 0 <= yi - 1 < self.H and 0 <= xi < self.W:
                self.g[yi - 1, xi] = CABLE_LIGHT
        # sombra suave debajo del cable
        for x, y in arr:
            xi, yi = int(round(x)), int(round(y)) + 3
            if 0 <= yi < self.H and 0 <= xi < self.W and not (self.g[yi, xi] == CABLE_OUT).all():
                self.g[yi, xi] *= 0.8
        # cajas de conexión
        for x, y in [arr[len(arr) // 3], arr[2 * len(arr) // 3]]:
            xi, yi = int(x), int(y)
            self.g[yi - 4:yi + 5, xi - 5:xi + 6] = CABLE_OUT
            self.g[yi - 3:yi + 4, xi - 4:xi + 5] = (150, 156, 172)
            self.g[yi - 3, xi - 4:xi + 5] = (210, 216, 228)
            self.g[yi, xi + 2] = (120, 255, 140)

    def shadow(self, sprite_mask, x0, y0, dx=10, dy=6, f=0.62):
        h, w = sprite_mask.shape
        sh = np.zeros((self.H, self.W), bool)
        ys, xs = np.nonzero(sprite_mask)
        ys, xs = ys + y0 + dy, xs + x0 + dx
        ok = (ys >= 0) & (ys < self.H) & (xs >= 0) & (xs < self.W)
        sh[ys[ok], xs[ok]] = True
        self.g[sh] *= f


def base_footprint(sm, depth):
    """Zona que bloquea el paso (vista 3/4): en cada columna, cada tramo vertical continuo del
    edificio bloquea solo su parte de abajo (lo que "toca el suelo"). Así cada módulo, fila de
    paneles o pata bloquea su base, y lo de arriba (techos, torres, antenas) no: el personaje
    puede pasar por detrás."""
    h, w = sm.shape
    d = max(4, int(h * depth))
    foot = np.zeros_like(sm)
    for x in range(w):
        col = sm[:, x]
        y = h - 1
        while y >= 0:
            if col[y]:
                end = y
                while y >= 0 and col[y]:
                    y -= 1
                start = y + 1
                if end - start >= 3:  # ignorar pelusas
                    foot[max(start, end - d):end + 1, x] = True
            y -= 1
    # cerrar huecos pequeños entre patas y soportes
    for _ in range(4):
        foot = foot | (np.roll(foot, 1, 1) & np.roll(foot, -1, 1)) | (np.roll(foot, 1, 0) & np.roll(foot, -1, 0))
    return foot


def dust_bottom(sprite, amount=0.35):
    h = sprite.shape[0]
    t = np.clip((np.arange(h)[:, None] - h * 0.78) / (h * 0.22), 0, 1) * amount
    s = sprite.astype(float)
    s[..., :3] = s[..., :3] * (1 - t[..., None]) + DUST * t[..., None]
    return s.astype(np.uint8)


def main():
    preview = "--preview" in sys.argv
    ground = Ground(np.asarray(Image.open(ZONES / "ap1_ground.png").convert("RGB")).astype(float))
    blocked = np.zeros((ground.H, ground.W), bool)
    meta = {"cell": CELL, "buildings": {}, "vehicle": {}}
    placed = []  # (sprite, x0, y0) para dibujarlos en la vista previa

    # 1) recortar y medir todo
    items = {}
    for bid, b in BUILDINGS.items():
        rgb, mask = load(b["src"], b.get("erase", ()))
        sprite, box, k = cut(rgb, mask, b["width"])
        sh, sw = sprite.shape[:2]
        px, py = b["pos"]
        x0, y0 = px - sw // 2, py - sh
        door = (round(x0 + (b["door"][0] - box[0]) * k), round(y0 + (b["door"][1] - box[1]) * k) + 14)  # delante de la rampa (fuera de la colisión)
        items[bid] = dict(sprite=dust_bottom(sprite), x0=x0, y0=y0, door=door, box=box, k=k,
                          src_size=(rgb.shape[1], rgb.shape[0]))
    vrgb, vmask = vehicle_frame(VEHICLE["src"], VEHICLE["frame"])
    vsprite, _, _ = cut(vrgb, vmask, VEHICLE["width"])
    vx, vy = VEHICLE["pos"]
    vx0, vy0 = vx - vsprite.shape[1] // 2, vy - vsprite.shape[0]

    # 2) explanadas de tierra bajo cada edificio y el estacionamiento del vehículo
    for it in items.values():
        sh, sw = it["sprite"].shape[:2]
        ground.pad(it["x0"] + sw / 2, it["y0"] + sh * 0.66, sw * 0.5, sh * 0.42)
    ground.pad(vx, vy - 10, 48, 26)

    # 3) caminos: de cada puerta al punto de reunión, y al vehículo
    hub = HUB
    for it in items.values():
        dx, dy = it["door"]
        ground.path([(dx, dy), (dx, hub[1]), hub] if abs(dy - hub[1]) > 20 else [(dx, dy), hub])
    ground.path([hub, (vx, hub[1]), (vx, vy - 10)])

    # 3b) cables entre edificios
    def cpoint(ref):
        if not isinstance(ref, str):
            return ref  # punto suelto en px del mapa
        bid, name = ref.split(".")
        it = items[bid]
        sx, sy = BUILDINGS[bid]["cable"][name]
        return (it["x0"] + (sx - it["box"][0]) * it["k"], it["y0"] + (sy - it["box"][1]) * it["k"])
    for c in CABLES:
        ground.cable(cpoint(c[0]), cpoint(c[1]), c[2] if len(c) > 2 else "")

    # 4) sombras, zona bloqueada y sprites
    OUT.mkdir(parents=True, exist_ok=True)
    for bid, it in items.items():
        s = it["sprite"]
        poly = BUILDINGS[bid].get("solid_poly")
        if poly:
            # parte "suelo" (plataforma): se pinta en el mapa y es caminable; queda solo el cohete
            pm = Image.new("L", (it["src_size"][0], it["src_size"][1]), 0)
            ImageDraw.Draw(pm).polygon(poly, fill=255)
            bx = it["box"]
            pm = pm.crop(bx).resize((s.shape[1], s.shape[0]), Image.NEAREST)
            solid = np.asarray(pm) > 0
            flat = (s[..., 3] > 0) & ~solid
            ys, xs = np.nonzero(flat)
            ok = (ys + it["y0"] < ground.H) & (xs + it["x0"] < ground.W) & (ys + it["y0"] >= 0) & (xs + it["x0"] >= 0)
            ground.g[ys[ok] + it["y0"], xs[ok] + it["x0"]] = s[ys[ok], xs[ok], :3]
            s = s.copy()
            s[flat, 3] = 0
            it["sprite"] = s
            # zonas caminables de la plataforma (arriba + escalera); el resto (borde, laterales) bloquea
            b_ = BUILDINGS[bid]
            if b_.get("walk_ellipse"):
                wm = Image.new("L", it["src_size"], 0)
                dw = ImageDraw.Draw(wm)
                ecx, ecy, erx, ery = b_["walk_ellipse"]
                dw.ellipse((ecx - erx, ecy - ery, ecx + erx, ecy + ery), fill=255)
                dw.polygon(b_["walk_poly"], fill=255)
                walk = np.asarray(wm.crop(bx).resize((s.shape[1], s.shape[0]), Image.NEAREST)) > 0
                wall = flat & ~walk
                ys, xs = np.nonzero(wall)
                ok = (ys + it["y0"] < ground.H) & (xs + it["x0"] < ground.W)
                blocked[ys[ok] + it["y0"], xs[ok] + it["x0"]] = True

        sm = s[..., 3] > 0
        ground.shadow(sm, it["x0"], it["y0"])
        foot = base_footprint(sm, BUILDINGS[bid].get("depth", 0.32))
        for fx0, fy0, fx1, fy1 in BUILDINGS[bid].get("free", ()):  # zonas sin colisión (px de la imagen original)
            k_, bx_ = it["k"], it["box"]
            foot[max(0, round((fy0 - bx_[1]) * k_)):round((fy1 - bx_[1]) * k_),
                 max(0, round((fx0 - bx_[0]) * k_)):round((fx1 - bx_[0]) * k_)] = False
        # extender la colisión unos píxeles hacia abajo: el personaje se para siempre
        # un poco DELANTE del edificio y se dibuja encima, sin "meterse" en él
        for _ in range(5):
            foot = foot | np.roll(foot, 1, 0)
        ys, xs = np.nonzero(foot)
        ok = (ys + it["y0"] < blocked.shape[0]) & (xs + it["x0"] < blocked.shape[1])
        blocked[ys[ok] + it["y0"], xs[ok] + it["x0"]] = True
        placed.append((s, it["x0"], it["y0"], it["door"]))
        if not preview:
            Image.fromarray(s, "RGBA").save(OUT / f"{bid}.png")
        b = BUILDINGS[bid]
        meta["buildings"][bid] = {
            "name": b["name"], "texture": f"res://assets/buildings/{bid}.png",
            "pos": [(it["x0"] + s.shape[1] / 2) * CELL, (it["y0"] + s.shape[0]) * CELL],
            "size": [s.shape[1] * CELL, s.shape[0] * CELL],
            "door": [it["door"][0] * CELL, it["door"][1] * CELL],
            "interior": b["interior"],
            "enterable": b.get("enterable", True),
            "fx": [],
        }
        to_world = lambda sx, sy: [round((it["x0"] + (sx - it["box"][0]) * it["k"]) * CELL),
                                   round((it["y0"] + (sy - it["box"][1]) * it["k"]) * CELL)]
        for f in b.get("fx", []):
            e = dict(f); e["at"] = to_world(*f["at"])
            meta["buildings"][bid]["fx"].append(e)
        if b.get("glints"):  # puntos al azar sobre los paneles (azul oscuro) para los destellos
            r_, g_, b_ = (s[..., i].astype(int) for i in range(3))
            panel = (s[..., 3] > 0) & (b_ > r_ + 40) & (b_ > 90) & (r_ < 90)
            ys, xs = np.nonzero(panel)
            pick = np.random.default_rng(7).choice(len(ys), size=min(80, len(ys)), replace=False)
            meta["buildings"][bid]["glints"] = [[int((xs[i] + it["x0"]) * CELL), int((ys[i] + it["y0"]) * CELL)] for i in pick]
    # Despejar la zona justo delante de cada puerta (la rampa) para que se pueda llegar a ella
    for it in items.values():
        dx, dy = it["door"]
        # la rampa también es sólida; solo se asegura que el punto de entrada quede libre
        blocked[dy - 2:dy + 8, max(0, dx - 10):dx + 11] = False
    vm = vsprite[..., 3] > 0
    # la sombra del vehículo NO se pinta en el suelo: la dibuja colony.gd y se va con él
    placed.append((vsprite, vx0, vy0, None))
    meta["vehicle"] = {"texture": "res://assets/buildings/vehiculo.png",
                       "pos": [vx * CELL, vy * CELL], "size": [vsprite.shape[1] * CELL, vsprite.shape[0] * CELL],
                       "door": [vx * CELL, (vy + 4) * CELL]}
    vfoot = base_footprint(vm, 0.45)
    ys, xs = np.nonzero(vfoot); blocked[ys + vy0, xs + vx0] = True
    meta["spawn"] = [(hub[0] + 55) * CELL, (hub[1] + 8) * CELL]  # junto al vehículo

    img = ground.g.clip(0, 255).astype(np.uint8)
    if preview:
        PREVIEW.mkdir(exist_ok=True)
        view = Image.fromarray(img).convert("RGBA")
        for s, x0, y0, door in sorted(placed, key=lambda p: p[2] + p[0].shape[0]):
            view.alpha_composite(Image.fromarray(s, "RGBA"), (x0, y0))
        astro = Image.open(ROOT / "assets/characters/astronaut.png").crop((0, 0, 96, 96)).resize((32, 32), Image.BOX)
        view.alpha_composite(astro, (hub[0] - 16, hub[1] - 30))
        d = ImageDraw.Draw(view)
        for _, _, _, door in placed:
            if door:
                d.ellipse((door[0] - 5, door[1] - 5, door[0] + 5, door[1] + 5), outline=(0, 255, 0), width=2)
        view.crop((32, 4, 1312, 724)).convert("RGB").save(PREVIEW / "ap1_colonia_distribucion.png")
        red = Image.new("RGBA", view.size, (255, 30, 30, 0))
        red.putalpha(Image.fromarray((blocked * 120).astype(np.uint8)))
        view.alpha_composite(red)
        view.crop((32, 4, 1312, 724)).convert("RGB").save(PREVIEW / "ap1_colonia_colisiones.png")
        print("vista previa:", PREVIEW / "ap1_colonia_distribucion.png")
        return
    Image.fromarray(img).save(ZONES / "ap1_colony_ground.png")
    Image.fromarray((blocked * 255).astype(np.uint8)).save(ZONES / "ap1_blocked.png")
    Image.fromarray(vsprite, "RGBA").save(OUT / "vehiculo.png")
    (OUT / "colony.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")
    print("colonia lista:", OUT)


if __name__ == "__main__":
    main()
