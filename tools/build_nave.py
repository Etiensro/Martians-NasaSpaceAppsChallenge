"""Nave de AP-1 separada de su plataforma (para que el despegue del final se vea bien).

Antes la nave venía en una sola imagen con la plataforma: la plataforma se pintaba en el suelo y la
sombra del cohete quedaba también pintada encima. Al despegar (scripts/finales/despegue.gd) el cohete se
iba pero su sombra se quedaba en la plataforma, y las luces de la plataforma subían con él.

Ahora, con tools/data/buildings/nave_plataforma_gemini.jpg (plataforma y cohete por separado, fondo blanco):
  - la plataforma se pinta en el suelo (assets/zones/ap1_colony_ground.png), en el mismo sitio de antes;
  - se quita del suelo la sombra vieja del cohete (el suelo se había oscurecido ×0.62: se deshace);
  - el cohete solo -> assets/buildings/nave.png y nave_vuelo.png (el del despegue; ya no trae sombra);
    su sombra la dibuja colony.gd y se va con él;
  - colony.json: la nave con su tamaño nuevo y solo sus luces (baliza y tobera); las luces de la
    plataforma pasan a "ground_fx" (se quedan en el suelo).
No toca nada más de la colonia (no hace falta volver a correr build_colony.py, que sobrescribiría los
cambios hechos a mano en colony.json y en los paneles).

Uso:  python tools/build_nave.py
"""
import json
import pathlib

import numpy as np
from PIL import Image

from imgutil import downscale_masked

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "tools/data/buildings/nave_plataforma_gemini.jpg"
GROUND = ROOT / "assets/zones/ap1_colony_ground.png"
COLONY = ROOT / "assets/buildings/colony.json"
OUT = ROOT / "assets/buildings"
CELL = 3

# Sitio de la nave en el suelo (px del suelo, como en build_colony.py): abajo al centro de la plataforma.
POS = (1100, 662)
PLATFORM_W = 230                 # ancho de la plataforma en el suelo (el de antes)
ROCKET_W = 105                   # ancho del cohete en el suelo
SPLIT_X = 1250                   # en la imagen: a la izquierda la plataforma, a la derecha el cohete
# Puntos en px de la imagen original
PAD_CENTER = (645, 905)          # centro de la parte de arriba de la plataforma
ROCKET_BASE = (1545, 1215)       # centro de la tobera, donde el cohete toca la plataforma
ROCKET_TIP = (1570, 140)         # antena (baliza roja)
NOZZLE = (1545, 1180)            # brillo de la tobera
PAD_LIGHTS = [(640, 615), (282, 700), (1000, 705), (100, 935), (1185, 935), (1045, 1125), (645, 1215)]
# Sombra vieja del cohete en el suelo (build_colony.py: sprite viejo de 230x237 en (985, 425), +10/+6, ×0.62)
OLD_SPRITE = OUT / "nave.png"
OLD_X0, OLD_Y0, OLD_SHADOW = 985, 425, (10, 6)
OLD_FACTOR = 0.62


def cut(rgb, mask, x0, x1, width):
    m = mask[:, x0:x1]
    ys, xs = np.nonzero(m)
    box = (xs.min() + x0, ys.min(), xs.max() + x0 + 1, ys.max() + 1)
    k = width / (box[2] - box[0])
    size = (width, round((box[3] - box[1]) * k))
    sprite = downscale_masked(rgb[box[1]:box[3], box[0]:box[2]], mask[box[1]:box[3], box[0]:box[2]], size)
    return sprite, box, k


def main():
    rgb = np.asarray(Image.open(SRC).convert("RGB")).astype(float)
    mask = np.abs(rgb - 255.0).sum(2) > 60  # fondo blanco
    plat, pbox, pk = cut(rgb, mask, 0, SPLIT_X, PLATFORM_W)
    rocket, rbox, rk = cut(rgb, mask, SPLIT_X, rgb.shape[1], ROCKET_W)

    ground = np.asarray(Image.open(GROUND).convert("RGB")).astype(float)
    # 1) quitar la sombra vieja del cohete (antes de sobrescribir nave.png)
    old = np.asarray(Image.open(OLD_SPRITE).convert("RGBA"))
    if old.shape[:2] == (237, 230):  # solo la primera vez (la imagen vieja con la plataforma)
        ys, xs = np.nonzero(old[..., 3] > 0)
        ys, xs = ys + OLD_Y0 + OLD_SHADOW[1], xs + OLD_X0 + OLD_SHADOW[0]
        ground[ys, xs] = np.minimum(ground[ys, xs] / OLD_FACTOR, 255)

    # 2) plataforma pintada en el suelo (abajo al centro en POS)
    ph, pw = plat.shape[:2]
    px0, py0 = POS[0] - pw // 2, POS[1] - ph
    a = plat[..., 3] > 0
    ys, xs = np.nonzero(a)
    ground[ys + py0, xs + px0] = plat[ys, xs, :3]
    Image.fromarray(ground.clip(0, 255).astype(np.uint8)).save(GROUND)

    def on_pad(p):  # punto de la imagen de la plataforma -> px del suelo
        return (px0 + (p[0] - pbox[0]) * pk, py0 + (p[1] - pbox[1]) * pk)

    # 3) cohete: su tobera sobre el centro de la plataforma
    rh, rw = rocket.shape[:2]
    cx, cy = on_pad(PAD_CENTER)
    rx0 = round(cx - (ROCKET_BASE[0] - rbox[0]) * rk)
    ry0 = round(cy - (ROCKET_BASE[1] - rbox[1]) * rk)
    Image.fromarray(rocket, "RGBA").save(OUT / "nave.png")
    Image.fromarray(rocket, "RGBA").save(OUT / "nave_vuelo.png")

    def on_rocket(p):
        return [round((rx0 + (p[0] - rbox[0]) * rk) * CELL), round((ry0 + (p[1] - rbox[1]) * rk) * CELL)]

    meta = json.loads(COLONY.read_text(encoding="utf-8"))
    nave = meta["buildings"]["nave"]
    nave["pos"] = [(rx0 + rw / 2) * CELL, (ry0 + rh) * CELL]
    nave["size"] = [rw * CELL, rh * CELL]
    nave["fx"] = [
        {"type": "beacon", "at": on_rocket(ROCKET_TIP), "color": "ff3b2f"},
        {"type": "glow", "at": on_rocket(NOZZLE), "color": "ff9a3c", "size": 1.6},  # tobera aún tibia
    ]
    meta["ground_fx"] = [{"type": "blink", "at": [round(v * CELL) for v in on_pad(p)], "color": "ffd84a", "period": 1.2}
                         for p in PAD_LIGHTS]
    COLONY.write_text(json.dumps(meta, indent="\t", ensure_ascii=False), encoding="utf-8")
    print("nave:", rw, "x", rh, "px del suelo en", (rx0, ry0), "· plataforma en", (px0, py0))


if __name__ == "__main__":
    main()
