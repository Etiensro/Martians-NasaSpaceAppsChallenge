"""Vestíbulos en primera persona (se elige con el cursor a dónde ir). Los usa scripts/interiores/lobby.gd.

Por cada vestíbulo de LOBBIES:
  fuente:  tools/data/interiores/<src>           (imagen de Gemini)
  genera:  assets/interiores/<id>/hub.png        fondo a 1280x720 (recorte tipo "cover")
           assets/interiores/<id>/hub.json       puertas (zonas para hacer clic) y efectos, en px de 1280x720

Las coordenadas de LOBBIES están en px de la imagen fuente; si cambia la imagen, se ajustan aquí.
Efectos que entiende lobby.gd (todos opcionales):
  windows        [x0, y0, x1, y1]          rachas de polvo de la tormenta recortadas al rectángulo
  window_polys   [[x, y], ...]             lo mismo pero con forma libre
  door_lights    [x, y]  (una por puerta)  halo del color de la puerta que late
  lamps          [x, y, "rrggbb", tamaño]  halo de una lámpara que late
  status_lights  [x, y]                    lucecitas verdes que parpadean
  screens        [x0, y0, x1, y1, tipo]    "chart" | "text" | "heart" | "bar"
  grow_lights    [x0, y0, x1, y1]          luz morada de cultivo que respira
  glints         [x, y]                    destellos (p. ej. sol en paneles solares)
  sparks         [x, y]                    chispas eléctricas de vez en cuando
  exit           [x, y]                    flecha de salida (suelo libre)

Uso:  python tools/build_lobbies.py [--preview]   (--preview dibuja las zonas en ../_previews)
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
W, H = 1280, 720

LOBBIES = {
    # Centro de la Estación Ares 1: 5 módulos
    "estacion_ares1": {
        "src": "estacion_hub_gemini.jpg",
        "scenes": "res://scenes/interiores/estacion_ares1/modulos/%s/%s.tscn",
        "doors": [
            ("sala_trabajo", "WORK ROOM", "5aa8ff", [45, 340, 345, 850]),
            ("invernadero", "GREENHOUSE", "5cf27a", [462, 395, 778, 800]),
            ("gimnasio", "GYM", "ffa640", [858, 410, 1165, 790]),
            ("enfermeria", "INFIRMARY", "ff4a4a", [1245, 395, 1560, 800]),
            ("dormitorios", "CREW QUARTERS", "ffc861", [1645, 340, 1955, 850]),
        ],
        "door_lights": [[235, 245], [630, 310], [1010, 325], [1390, 312], [1782, 245]],
        "status_lights": [[18, 600], [18, 630], [390, 590], [790, 600], [1180, 600], [1575, 590],
                          [1980, 600], [1980, 630]],
        "windows": [[150, 30, 405, 135], [500, 95, 765, 200], [870, 135, 1145, 215],
                    [1255, 95, 1515, 200], [1615, 30, 1860, 135]],
        "screens": [[60, 458, 130, 505, "chart"], [62, 528, 118, 572, "chart"], [100, 586, 168, 624, "text"],
                    [1462, 543, 1528, 588, "heart"]],
        "grow_lights": [[478, 512, 655, 526], [478, 590, 655, 604], [640, 445, 730, 470]],
        "exit": [1000, 1010],
    },
    # Paneles solares: campo de paneles (afuera) y sala eléctrica. Cada una abre un minijuego.
    "paneles_solares": {
        "src": "paneles_hub_gemini.jpg",
        "scenes": "res://scenes/interiores/paneles_solares/minijuegos/%s/%s.tscn",
        "doors": [
            ("campo_solar", "SOLAR FIELD", "ffa860", [292, 350, 780, 815]),
            ("sala_electrica", "POWER ROOM", "ffd23a", [1245, 345, 1745, 800]),
        ],
        "lamps": [[540, 348, "ff3b30", 1.3], [1560, 405, "ffd27a", 1.9], [1695, 382, "ffd27a", 1.2]],
        "status_lights": [[868, 392], [890, 392], [912, 392], [868, 406], [890, 406], [912, 406],
                          [258, 118], [1742, 116], [1650, 275], [372, 268], [1130, 325],
                          # luces de las baterías (bastidores de la sala eléctrica)
                          [1505, 511], [1555, 561], [1505, 611], [1555, 657], [1505, 705],
                          [1642, 511], [1704, 561], [1642, 611], [1704, 657], [1642, 705]],
        "window_polys": [[[300, 372], [668, 372], [668, 790], [340, 805], [300, 760]]],
        # cristal de cada pantalla (sin el marco; la de la izquierda la corta la columna en x=970)
        "screens": [[920, 543, 969, 603, "chart"], [1031, 543, 1096, 603, "chart"],
                    [1031, 632, 1059, 655, "bar"], [918, 627, 956, 645, "text"], [1310, 480, 1360, 522, "text"]],
        "glints": [[352, 575], [410, 590], [470, 600], [520, 585], [590, 575], [640, 600], [330, 610]],
        "sparks": [[1345, 600], [1440, 560], [1300, 540]],
        "exit": [1000, 1010],
    },
    # Módulos de la estación con un lugar donde hacer clic (vuelven al centro de la estación: exit_scene
    # en su .tscn). Fuentes en tools/data/interiores/<módulo>/.
    "estacion_ares1/sala_trabajo": {
        "src": "sala_trabajo/laboratorio_gemini.webp",
        "scenes": "res://scenes/interiores/estacion_ares1/modulos/sala_trabajo/%s.tscn",
        "doors": [
            ("analisis", "BIOSAFETY CABINET", "5aa8ff", [1010, 185, 1376, 640]),
            ("microscopio", "MICROSCOPE", "9ad7ff", [175, 300, 335, 590]),
        ],
        "status_lights": [[505, 216], [580, 216], [760, 216], [1068, 268], [1092, 268]],
        "screens": [[320, 268, 420, 360, "chart"], [712, 340, 852, 432, "chart"]],
        "lamps": [[688, 172, "dff3ff", 1.6], [1145, 150, "dff3ff", 1.4]],
        "exit": [688, 735],
    },
    "estacion_ares1/enfermeria": {
        "src": "enfermeria/enfermeria_gemini.webp",
        "scenes": "res://scenes/interiores/estacion_ares1/modulos/enfermeria/%s.tscn",
        "doors": [
            ("escaneo", "BODY SCANNER", "3dff7a", [430, 280, 720, 600]),
        ],
        "status_lights": [[580, 216], [760, 216], [1052, 432], [1052, 448]],
        "screens": [[1022, 302, 1092, 352, "heart"], [1122, 250, 1196, 300, "heart"]],
        "lamps": [[575, 380, "7ff7ff", 2.2], [688, 172, "dff3ff", 1.6]],
        "exit": [688, 735],
    },
    # Excavadora de hielo: la consola de control abre el minijuego (el rover se maneja a distancia)
    "excavadora": {
        "src": "excavadora_hub_gemini.jpg",
        "scenes": "res://scenes/interiores/excavadora/minijuegos/%s/%s.tscn",
        "doors": [
            ("extraccion_hielo", "ICE DRILL CONTROL", "eafe07", [2060, 520, 2480, 1150]),
        ],
        "lamps": [[310, 536, "ff3b30", 1.2], [526, 580, "ff3b30", 1.2], [1090, 280, "ffe9b0", 1.6],
                  [1666, 280, "ffe9b0", 1.6], [2300, 660, "7fe8ff", 2.4]],
        "status_lights": [[2282, 306], [2330, 380], [2440, 700], [2440, 760], [2314, 1200], [2314, 1230],
                          [578, 880], [1232, 720], [1232, 740]],
        "screens": [[1044, 680, 1192, 766, "chart"], [2214, 822, 2386, 928, "chart"],
                    [2084, 812, 2176, 896, "text"], [1916, 616, 2096, 716, "text"]],
        "glints": [[2300, 640], [2270, 700], [2330, 610], [2250, 660]],
        "exit": [1376, 1400],
    },
}


def cover(src):
    im = Image.open(src).convert("RGB")
    s = max(W / im.width, H / im.height)
    nw, nh = round(im.width * s), round(im.height * s)
    ox, oy = (nw - W) / 2, (nh - H) / 2
    img = im.resize((nw, nh), Image.LANCZOS).crop((round(ox), round(oy), round(ox) + W, round(oy) + H))
    return img, s, ox, oy


def build(lid, cfg, preview):
    img, s, ox, oy = cover(ROOT / "tools/data/interiores" / cfg["src"])
    pt = lambda p: [round(p[0] * s - ox), round(p[1] * s - oy)]
    rect = lambda r: pt(r[:2]) + pt(r[2:4]) + list(r[4:])
    data = {"doors": [{"id": i, "name": n, "color": c, "rect": rect(r), "scene": cfg["scenes"].replace("%s", i)}
                      for i, n, c, r in cfg["doors"]]}
    for key in ("door_lights", "status_lights", "glints", "sparks"):
        data[key] = [pt(p) for p in cfg.get(key, [])]
    data["lamps"] = [pt(l[:2]) + list(l[2:]) for l in cfg.get("lamps", [])]
    for key in ("windows", "screens", "grow_lights"):
        data[key] = [rect(r) for r in cfg.get(key, [])]
    data["window_polys"] = [[pt(p) for p in poly] for poly in cfg.get("window_polys", [])]
    data["exit"] = pt(cfg["exit"])

    out = ROOT / "assets/interiores" / lid
    out.mkdir(parents=True, exist_ok=True)
    img.save(out / "hub.png")
    (out / "hub.json").write_text(json.dumps(data, indent=1), encoding="utf-8")
    print(f"{lid}: {len(data['doors'])} puertas -> {out}")

    if preview:
        pv = img.copy()
        d = ImageDraw.Draw(pv)
        for door in data["doors"]:
            d.rectangle(door["rect"], outline="#" + door["color"], width=3)
        for r in data["windows"] + data["grow_lights"]:
            d.rectangle(r[:4], outline="white")
        for poly in data["window_polys"]:
            d.polygon([tuple(p) for p in poly], outline="white")
        for r in data["screens"]:
            d.rectangle(r[:4], outline="cyan")
        for p in data["door_lights"] + data["status_lights"] + [l[:2] for l in data["lamps"]] + [data["exit"]]:
            d.ellipse([p[0] - 4, p[1] - 4, p[0] + 4, p[1] + 4], outline="yellow", width=2)
        for p in data["glints"] + data["sparks"]:
            d.ellipse([p[0] - 4, p[1] - 4, p[0] + 4, p[1] + 4], outline="magenta", width=2)
        prev = ROOT.parent / "_previews"
        prev.mkdir(exist_ok=True)
        pv.save(prev / f"lobby_{lid.replace('/', '_')}.png")


def main():
    for lid, cfg in LOBBIES.items():
        if len(sys.argv) < 2 or lid in sys.argv[1:] or sys.argv[1:] == ["--preview"]:
            build(lid, cfg, "--preview" in sys.argv)


if __name__ == "__main__":
    main()
