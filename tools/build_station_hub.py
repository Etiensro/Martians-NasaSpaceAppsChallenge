"""Menú en primera persona de la Estación Ares 1 (centro de la base).

Fuente: tools/data/interiores/estacion_hub_gemini.jpg (imagen de Gemini, 2000x1116).
Genera:
  assets/interiores/estacion_ares1/hub.png   fondo a 1280x720 (recorte tipo "cover")
  assets/interiores/estacion_ares1/hub.json  puertas (zonas para hacer clic), luces, ventanas,
                                              pantallas y la flecha de salida, en px de 1280x720.
Las coordenadas de abajo están en px de la imagen fuente; si cambia la imagen, se ajustan aquí.

Uso:  python tools/build_station_hub.py [--preview]   (--preview dibuja las zonas en ../_previews)
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "tools/data/interiores/estacion_hub_gemini.jpg"
OUT_DIR = ROOT / "assets/interiores/estacion_ares1"
W, H = 1280, 720
MODULES = "res://scenes/interiores/estacion_ares1/modulos/%s/%s.tscn"

# Puertas: id, nombre (inglés, lo ve el jugador), color de su luz, hueco de la puerta [x0, y0, x1, y1]
DOORS = [
    ("sala_trabajo", "WORK ROOM", "5aa8ff", [45, 340, 345, 850]),
    ("invernadero", "GREENHOUSE", "5cf27a", [462, 395, 778, 800]),
    ("gimnasio", "GYM", "ffa640", [858, 410, 1165, 790]),
    ("enfermeria", "INFIRMARY", "ff4a4a", [1245, 395, 1560, 800]),
    ("dormitorios", "CREW QUARTERS", "ffc861", [1645, 340, 1955, 850]),
]
# Luces de color encima de cada puerta y luces de estado de los marcos
DOOR_LIGHTS = [[235, 245], [630, 310], [1010, 325], [1390, 312], [1782, 245]]
STATUS_LIGHTS = [[18, 600], [18, 630], [390, 590], [790, 600], [1180, 600], [1575, 590], [1980, 600], [1980, 630]]
# Ventanas del techo (se ve la tormenta)
WINDOWS = [[150, 30, 405, 135], [500, 95, 765, 200], [870, 135, 1145, 215],
           [1255, 95, 1515, 200], [1615, 30, 1860, 135]]
# Pantallas que parpadean: [x0, y0, x1, y1, tipo]
SCREENS = [[60, 458, 130, 505, "chart"], [62, 528, 118, 572, "chart"], [100, 586, 168, 624, "text"],
           [1462, 543, 1528, 588, "heart"]]
# Luces de cultivo del invernadero (se encienden y apagan suave)
GROW_LIGHTS = [[478, 512, 655, 526], [478, 590, 655, 604], [640, 445, 730, 470]]
# Flecha de salida (suelo libre, abajo al centro)
EXIT = [1000, 1010]


def cover():
    im = Image.open(SRC).convert("RGB")
    s = max(W / im.width, H / im.height)
    nw, nh = round(im.width * s), round(im.height * s)
    ox, oy = (nw - W) / 2, (nh - H) / 2
    return im.resize((nw, nh), Image.LANCZOS).crop((round(ox), round(oy), round(ox) + W, round(oy) + H)), s, ox, oy


def main():
    img, s, ox, oy = cover()
    pt = lambda p: [round(p[0] * s - ox), round(p[1] * s - oy)]
    rect = lambda r: pt(r[:2]) + pt(r[2:4])
    data = {
        "doors": [{"id": i, "name": n, "color": c, "rect": rect(r), "scene": MODULES % (i, i)}
                  for i, n, c, r in DOORS],
        "door_lights": [pt(p) for p in DOOR_LIGHTS],
        "status_lights": [pt(p) for p in STATUS_LIGHTS],
        "windows": [rect(r) for r in WINDOWS],
        "screens": [rect(r) + [r[4]] for r in SCREENS],
        "grow_lights": [rect(r) for r in GROW_LIGHTS],
        "exit": pt(EXIT),
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    img.save(OUT_DIR / "hub.png")
    (OUT_DIR / "hub.json").write_text(json.dumps(data, indent=1), encoding="utf-8")
    print("hub.png", img.size, "·", len(data["doors"]), "puertas")

    if "--preview" in sys.argv:
        pv = img.copy()
        d = ImageDraw.Draw(pv)
        for door in data["doors"]:
            d.rectangle(door["rect"], outline="#" + door["color"], width=3)
        for r in data["windows"] + data["grow_lights"]:
            d.rectangle(r, outline="white")
        for r in data["screens"]:
            d.rectangle(r[:4], outline="cyan")
        for p in data["door_lights"] + data["status_lights"] + [data["exit"]]:
            d.ellipse([p[0] - 5, p[1] - 5, p[0] + 5, p[1] + 5], outline="yellow", width=2)
        out = ROOT.parent / "_previews"
        out.mkdir(exist_ok=True)
        pv.save(out / "hub_zonas.png")
        print("preview:", out / "hub_zonas.png")


if __name__ == "__main__":
    main()
