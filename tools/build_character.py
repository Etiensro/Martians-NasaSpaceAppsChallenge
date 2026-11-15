"""Convierte las hojas de sprites de los personajes (generadas con Gemini) en recursos de Godot.

Por cada personaje de CHARACTERS genera:
  - assets/characters/<id>.png         (sprite sheet: fila = animación, columna = frame, celdas de 96x96)
  - assets/characters/<id>_frames.tres (SpriteFrames para AnimatedSprite2D)

Todos los personajes comparten los mismos nombres de animación (idle_down, walk_side, celebrate…),
así que cualquiera funciona con scripts/astronaut.gd.
Los sprites de lado miran a la DERECHA; para la izquierda se usa flip_h en Godot.

Para añadir un personaje nuevo:
  1. Guarda la hoja de Gemini (fondo naranja liso) en tools/data/characters/
  2. Añade una entrada en CHARACTERS indicando qué sprite (fila, columna) va en cada animación
  3. python tools/build_character.py

Uso:  python tools/build_character.py            (todos)
      python tools/build_character.py biologo    (solo uno)
"""
import pathlib
import sys
from collections import deque

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = ROOT / "tools" / "data" / "characters"
OUT = ROOT / "assets" / "characters"

CELL = 96          # tamaño de cada frame
TARGET_H = 78      # alto del personaje en el juego (px), igual para todos
BG_TOLERANCE = 90  # diferencia con el naranja del fondo para considerar "personaje"
COLORS = 48        # paleta final (limpia el ruido del JPG)
GLASS = (128, 190, 240)  # color con el que se rellena un visor "transparente" (que deja ver el fondo)

# Animaciones: nombre -> (fps, loop, [(fila, columna), ...]) contando filas/columnas desde 0
# en el orden en que aparecen los sprites en la hoja.
CHARACTERS = {
    # Robot acompañante (más pequeño; sigue al personaje). Usa las mismas animaciones base.
    "robot": {
        "sheet": "robot_sheet_gemini.jpg",
        "fill_visor": False,
        "downscale": 5.2,      # ~50 px de alto: más pequeño que la tripulación
        "align": "bottom",     # sus sprites tienen alturas distintas: se apoyan por abajo (las ruedas)
        "anims": {
            "idle_down": (1, True, [(0, 3)]),
            "idle_side": (1, True, [(1, 2)]),
            "idle_up":   (1, True, [(0, 6)]),
            "walk_down": (6, True, [(0, 3), (1, 4)]),
            "walk_side": (6, True, [(0, 2), (1, 2), (1, 3)]),
            "walk_up":   (6, True, [(0, 6), (1, 7)]),
            "celebrate": (4, True, [(2, 2), (2, 3)]),   # brazo con llave: "reparando"
        },
    },
    "astronaut": {
        "sheet": "astronaut_sheet_gemini_v2.jpg",
        "fill_visor": False,
        "downscale": 4.0,  # fijo: así quedó el astronauta que ya está en el juego
        "anims": {
            "idle_down": (1, True, [(0, 0)]),
            "idle_side": (1, True, [(0, 1)]),
            "idle_up":   (1, True, [(0, 2)]),
            "walk_down": (8, True, [(1, 0), (1, 1), (1, 2), (1, 3)]),
            "walk_side": (8, True, [(1, 4), (1, 5), (1, 6), (1, 7)]),
            "walk_up":   (8, True, [(2, 0), (2, 1), (2, 2), (2, 3)]),
            "celebrate": (1, False, [(2, 5)]),
        },
    },
    "biologo": {
        "sheet": "biologo_sheet_gemini.jpg",
        "fill_visor": True,   # en la vista de lado el visor deja ver el fondo naranja
        "anims": {
            "idle_down": (1, True, [(3, 2)]),
            "idle_side": (1, True, [(3, 3)]),
            "idle_up":   (1, True, [(1, 0)]),
            "walk_down": (10, True, [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4), (0, 5)]),
            "walk_side": (10, True, [(2, 0), (2, 1), (2, 2), (2, 3), (2, 4), (2, 5)]),
            "walk_up":   (10, True, [(1, 0), (1, 1), (1, 2), (1, 3), (1, 4), (1, 5)]),
            "celebrate": (4, True, [(3, 0), (3, 1)]),
        },
    },
    "astrofisico": {
        "sheet": "astrofisico_sheet_gemini.jpg",
        "fill_visor": True,   # en la vista de lado el visor deja ver el fondo naranja
        "anims": {
            "idle_down": (1, True, [(3, 2)]),
            "idle_side": (1, True, [(3, 3)]),
            "idle_up":   (1, True, [(1, 0)]),
            "walk_down": (10, True, [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4), (0, 5)]),
            "walk_side": (10, True, [(2, 0), (2, 1), (2, 2), (2, 3), (2, 4), (2, 5)]),
            "walk_up":   (10, True, [(1, 0), (1, 1), (1, 2), (1, 3), (1, 4), (1, 5)]),
            # Esta hoja no trae pose de celebrar: se usan dos poses de frente como provisional
            "celebrate": (4, True, [(3, 0), (3, 1)]),
        },
    },
    "ingeniero": {
        "sheet": "ingeniero_sheet_gemini.jpg",
        "fill_visor": True,   # en la vista de lado el visor deja ver el fondo naranja
        "size_ref": (3, 2),   # pose de pie para medir el tamaño (su cara salió gris, por eso no es el idle)
        "anims": {
            "idle_down": (1, True, [(0, 0)]),
            "idle_side": (1, True, [(3, 3)]),
            "idle_up":   (1, True, [(1, 0)]),
            "walk_down": (10, True, [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4), (0, 5)]),
            "walk_side": (10, True, [(2, 0), (2, 1), (2, 2), (2, 3), (2, 4), (2, 5)]),
            "walk_up":   (10, True, [(1, 0), (1, 1), (1, 2), (1, 3), (1, 4), (1, 5)]),
            "celebrate": (4, True, [(3, 0), (3, 1)]),  # el 2.º sprite de la última fila abre los brazos
        },
    },
    "medico": {
        "sheet": "medico_sheet_gemini.jpg",
        "fill_visor": True,   # en la vista de lado el visor deja ver el fondo naranja
        "anims": {
            "idle_down": (1, True, [(3, 2)]),
            "idle_side": (1, True, [(3, 3)]),
            "idle_up":   (1, True, [(1, 0)]),
            "walk_down": (10, True, [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4), (0, 5)]),
            "walk_side": (10, True, [(2, 0), (2, 1), (2, 2), (2, 3), (2, 4), (2, 5)]),
            "walk_up":   (10, True, [(1, 0), (1, 1), (1, 2), (1, 3), (1, 4), (1, 5)]),
            # Esta hoja no trae pose de celebrar: se usan dos poses de frente como provisional
            "celebrate": (4, True, [(3, 0), (3, 1)]),
        },
    },
}


def find_sprites(rgb):
    """Máscara del personaje (todo lo que no es el fondo) y cajas de cada sprite agrupadas por filas."""
    bg = np.median(rgb[:20, :20].reshape(-1, 3), axis=0)
    mask = np.abs(rgb - bg).sum(2) > BG_TOLERANCE
    h, w = mask.shape
    seen = np.zeros_like(mask)
    boxes = []
    for y in range(h):
        for x in range(w):
            if mask[y, x] and not seen[y, x]:
                q = deque([(y, x)]); seen[y, x] = True; ys, xs = [], []
                while q:
                    cy, cx = q.popleft(); ys.append(cy); xs.append(cx)
                    for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True; q.append((ny, nx))
                if len(ys) > 500:
                    boxes.append((min(xs), min(ys), max(xs) + 1, max(ys) + 1))
    boxes.sort(key=lambda b: b[1])
    rows, current = [], [boxes[0]]
    for b in boxes[1:]:
        if b[1] - current[0][1] > 100:
            rows.append(current); current = []
        current.append(b)
    rows.append(current)
    return mask, [sorted(r) for r in rows]


def fill_holes(rgb, mask, min_area=800):
    """Rellena los huecos grandes dentro de un sprite (p. ej. un visor que deja ver el fondo)
    con color de cristal. Devuelve la máscara y la imagen corregidas."""
    h, w = mask.shape
    outside = np.zeros_like(mask)
    q = deque((y, x) for y in range(h) for x in (0, w - 1) if not mask[y, x])
    q.extend((y, x) for x in range(w) for y in (0, h - 1) if not mask[y, x])
    for y, x in q:
        outside[y, x] = True
    while q:
        cy, cx = q.popleft()
        for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
            if 0 <= ny < h and 0 <= nx < w and not mask[ny, nx] and not outside[ny, nx]:
                outside[ny, nx] = True; q.append((ny, nx))
    holes = ~mask & ~outside
    seen = np.zeros_like(holes)
    rgb = rgb.copy()
    for y, x in zip(*np.nonzero(holes)):
        if seen[y, x]:
            continue
        comp = [(y, x)]; seen[y, x] = True; i = 0
        while i < len(comp):
            cy, cx = comp[i]; i += 1
            for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                if holes[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True; comp.append((ny, nx))
        if len(comp) >= min_area:
            ys, xs = zip(*comp)
            rgb[ys, xs] = GLASS
            mask[ys, xs] = True
    return rgb, mask


def shrink(rgba, box, downscale):
    """Reduce el sprite con promedio (BOX) y alfa binaria."""
    x0, y0, x1, y1 = box
    crop = Image.fromarray(rgba[y0:y1, x0:x1])
    small = np.asarray(crop.resize((round(crop.width / downscale), round(crop.height / downscale)), Image.BOX)).copy()
    small[..., 3] = np.where(small[..., 3] > 140, 255, 0)
    ys, xs = np.nonzero(small[..., 3])
    return small[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def build(cid, cfg):
    rgb = np.asarray(Image.open(DATA / cfg["sheet"]).convert("RGB")).astype(np.int32)
    mask, rows = find_sprites(rgb)
    if cfg.get("fill_visor"):
        rgb, mask = fill_holes(rgb, mask)
    rgba = np.dstack([rgb, mask * 255]).astype(np.uint8)
    # misma altura en el juego para todos los personajes (según el sprite de frente quieto)
    r0, c0 = cfg.get("size_ref") or cfg["anims"]["idle_down"][2][0]
    downscale = cfg.get("downscale") or (rows[r0][c0][3] - rows[r0][c0][1]) / TARGET_H

    anims = list(cfg["anims"].items())
    max_frames = max(len(f) for _, (_, _, f) in anims)
    sheet = Image.new("RGBA", (CELL * max_frames, CELL * len(anims)), (0, 0, 0, 0))
    for ai, (name, (_, _, frames)) in enumerate(anims):
        natives = [shrink(rgba, rows[r][c], downscale) for r, c in frames]
        # Todos los frames de una animación comparten la misma línea superior (casco)
        # y se centran por el casco: así el cuerpo no "salta" al mover las piernas.
        anim_h = max(n.shape[0] for n in natives)
        for fi, n in enumerate(natives):
            # "bottom": cada frame apoyado en el suelo (para sprites de alturas distintas)
            top = CELL - 1 - (n.shape[0] if cfg.get("align") == "bottom" else anim_h)
            helmet = n[: max(1, n.shape[0] * 2 // 5), :, 3] > 0
            cx = np.nonzero(helmet)[1].mean()
            left = int(round(CELL / 2 - cx - 0.5))
            sheet.alpha_composite(Image.fromarray(n), (fi * CELL + left, ai * CELL + top))

    alpha = sheet.getchannel("A")
    q = sheet.convert("RGB").quantize(COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
    q.putalpha(alpha)
    q.save(OUT / f"{cid}.png")

    lines = ['[gd_resource type="SpriteFrames" format=3]', "",
             f'[ext_resource type="Texture2D" path="res://assets/characters/{cid}.png" id="1_sheet"]', ""]
    anim_txt = []
    for ai, (name, (fps, loop, frames)) in enumerate(anims):
        refs = []
        for fi in range(len(frames)):
            sid = f"AtlasTexture_{name}_{fi}"
            lines += [f'[sub_resource type="AtlasTexture" id="{sid}"]', 'atlas = ExtResource("1_sheet")',
                      f"region = Rect2({fi * CELL}, {ai * CELL}, {CELL}, {CELL})", ""]
            refs.append(f'{{\n"duration": 1.0,\n"texture": SubResource("{sid}")\n}}')
        anim_txt.append(f'{{\n"frames": [{", ".join(refs)}],\n"loop": {str(loop).lower()},\n'
                        f'"name": &"{name}",\n"speed": {float(fps)}\n}}')
    lines += ["[resource]", f"animations = [{', '.join(anim_txt)}]", ""]
    (OUT / f"{cid}_frames.tres").write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"{cid}: filas {[len(r) for r in rows]}, escala 1/{downscale:.2f} -> {OUT / (cid + '.png')}")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    only = sys.argv[1:]
    for cid, cfg in CHARACTERS.items():
        if not only or cid in only:
            build(cid, cfg)


if __name__ == "__main__":
    main()
