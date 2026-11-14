"""Convierte la hoja de sprites del astronauta (generada con Gemini) en:
  - assets/characters/astronaut.png        (sprite sheet 96x96: fila = animación, columna = frame)
  - assets/characters/astronaut_frames.tres (SpriteFrames para AnimatedSprite2D)

Los sprites de lado miran a la DERECHA; para la izquierda se usa flip_h en Godot.

Uso:  python tools/build_character.py
"""
import pathlib
from collections import deque
import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "tools" / "data" / "characters" / "astronaut_sheet_gemini_v2.jpg"
OUT = ROOT / "assets" / "characters"
OUT.mkdir(parents=True, exist_ok=True)

CELL = 96          # tamaño de cada frame
DOWNSCALE = 4.0    # el sprite de Gemini (~310 px de alto) queda en ~78 px
BG_TOLERANCE = 90  # diferencia con el naranja del fondo para considerar "personaje"
COLORS = 48        # paleta final (limpia el ruido del JPG)

# Animaciones: (nombre, fps, loop, [(fila, x aproximado del sprite en la imagen original)])
# Filas detectadas en la imagen: 0..4 de arriba a abajo.
ANIMS = [
    ("idle_down", 1, True,  [(0, 74)]),
    ("idle_side", 1, True,  [(0, 357)]),
    ("idle_up",   1, True,  [(0, 591)]),
    ("walk_down", 8, True,  [(1, 66), (1, 307), (1, 532), (1, 765)]),
    ("walk_side", 8, True,  [(1, 1016), (1, 1249), (1, 1482), (1, 1724)]),
    ("walk_up",   8, True,  [(2, 74), (2, 299), (2, 532), (2, 766)]),
    ("celebrate", 1, False, [(2, 1474)]),
]


def find_sprites(rgb):
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
    # agrupar en filas por la posición vertical
    boxes.sort(key=lambda b: b[1])
    rows, current = [], [boxes[0]]
    for b in boxes[1:]:
        if b[1] - current[0][1] > 100:
            rows.append(current); current = []
        current.append(b)
    rows.append(current)
    return mask, [sorted(r) for r in rows]


def shrink(rgba, box):
    """Reduce el sprite a 1/DOWNSCALE con promedio (BOX) y alfa binaria.
    El arte de Gemini no sigue una rejilla de píxeles exacta, así que reducirlo
    a su "resolución real" pierde detalle; a 1/4 conserva el dibujo casi intacto."""
    x0, y0, x1, y1 = box
    crop = Image.fromarray(rgba[y0:y1, x0:x1])
    small = np.asarray(crop.resize((round(crop.width / DOWNSCALE), round(crop.height / DOWNSCALE)), Image.BOX)).copy()
    small[..., 3] = np.where(small[..., 3] > 140, 255, 0)
    ys, xs = np.nonzero(small[..., 3])
    return small[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def main():
    rgb = np.asarray(Image.open(SRC).convert("RGB")).astype(np.int32)
    mask, rows = find_sprites(rgb)
    rgba = np.dstack([rgb, mask * 255]).astype(np.uint8)
    sheet = Image.new("RGBA", (CELL * 4, CELL * len(ANIMS)), (0, 0, 0, 0))
    for ai, (name, _, _, frames) in enumerate(ANIMS):
        natives = []
        for row, x_hint in frames:
            box = min(rows[row], key=lambda b: abs(b[0] - x_hint))
            natives.append(shrink(rgba, box))
        # Todos los frames de una animación comparten la misma línea superior (casco)
        # y se centran por el casco, no por la caja: así el cuerpo no "salta" al abrir las piernas.
        anim_h = max(n.shape[0] for n in natives)
        top = CELL - 1 - anim_h
        for fi, n in enumerate(natives):
            helmet = n[: max(1, n.shape[0] * 2 // 5), :, 3] > 0
            cx = np.nonzero(helmet)[1].mean()
            left = int(round(CELL / 2 - cx - 0.5))
            sheet.alpha_composite(Image.fromarray(n), (fi * CELL + left, ai * CELL + top))

    # paleta reducida para quitar el ruido del JPG
    alpha = sheet.getchannel("A")
    q = sheet.convert("RGB").quantize(COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
    q.putalpha(alpha)
    q.save(OUT / "astronaut.png")

    # SpriteFrames
    lines = ['[gd_resource type="SpriteFrames" format=3]', "",
             '[ext_resource type="Texture2D" path="res://assets/characters/astronaut.png" id="1_sheet"]', ""]
    anim_txt = []
    for ai, (name, fps, loop, frames) in enumerate(ANIMS):
        refs = []
        for fi in range(len(frames)):
            sid = f"AtlasTexture_{name}_{fi}"
            lines += [f'[sub_resource type="AtlasTexture" id="{sid}"]', 'atlas = ExtResource("1_sheet")',
                      f"region = Rect2({fi * CELL}, {ai * CELL}, {CELL}, {CELL})", ""]
            refs.append(f'{{\n"duration": 1.0,\n"texture": SubResource("{sid}")\n}}')
        anim_txt.append(f'{{\n"frames": [{", ".join(refs)}],\n"loop": {str(loop).lower()},\n'
                        f'"name": &"{name}",\n"speed": {float(fps)}\n}}')
    lines += ["[resource]", f"animations = [{', '.join(anim_txt)}]", ""]
    (OUT / "astronaut_frames.tres").write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print("filas detectadas:", [len(r) for r in rows], "->", OUT)


if __name__ == "__main__":
    main()
