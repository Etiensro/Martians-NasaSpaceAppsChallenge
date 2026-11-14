"""Convierte la hoja de sprites del rover (generada con Gemini) en:
  - assets/vehicles/rover.png         (sprite sheet: fila = animación, columna = frame)
  - assets/vehicles/rover_frames.tres (SpriteFrames para AnimatedSprite2D)

Se reduce para que sus "píxeles" midan lo mismo que los del astronauta en el juego
(~3 px), así ambos se ven del mismo estilo. Los sprites de lado miran a la DERECHA;
para la izquierda se usa flip_h en Godot.

Uso:  python tools/build_rover.py
"""
import pathlib
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from build_character import find_sprites  # noqa: E402  (misma detección que el astronauta)

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "tools" / "data" / "vehicles" / "rover_sheet_gemini.png"
OUT = ROOT / "assets" / "vehicles"
OUT.mkdir(parents=True, exist_ok=True)

ROVER_ART_PIXEL = 6.0     # tamaño aprox. de cada "píxel" del dibujo en la imagen de Gemini
TARGET_ART_PIXEL = 3.125  # tamaño de píxel del astronauta en el juego (12.5 / 4)
SCALE = TARGET_ART_PIXEL / ROVER_ART_PIXEL
CELL_W, CELL_H = 128, 128
COLORS = 48

# (nombre, fps, [(fila, índice de columna)])  — filas: 0 abajo, 1 derecha, 2 arriba
# En la fila de "arriba" el 2.º frame salió distinto (sin panel solar), por eso se omite.
ANIMS = [
    ("idle_down", 1, [(0, 0)]),
    ("idle_side", 1, [(1, 0)]),
    ("idle_up", 1, [(2, 0)]),
    ("drive_down", 8, [(0, 0), (0, 1), (0, 2), (0, 3)]),
    ("drive_side", 8, [(1, 0), (1, 1), (1, 2), (1, 3)]),
    ("drive_up", 8, [(2, 0), (2, 2), (2, 3)]),
]


def shrink(rgba, box):
    x0, y0, x1, y1 = box
    crop = Image.fromarray(rgba[y0:y1, x0:x1])
    small = np.asarray(crop.resize((round(crop.width * SCALE), round(crop.height * SCALE)), Image.BOX)).copy()
    small[..., 3] = np.where(small[..., 3] > 140, 255, 0)
    ys, xs = np.nonzero(small[..., 3])
    return small[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def main():
    rgb = np.asarray(Image.open(SRC).convert("RGB")).astype(np.int32)
    mask, rows = find_sprites(rgb)
    rgba = np.dstack([rgb, mask * 255]).astype(np.uint8)

    max_frames = max(len(f) for _, _, f in ANIMS)
    sheet = Image.new("RGBA", (CELL_W * max_frames, CELL_H * len(ANIMS)), (0, 0, 0, 0))
    for ai, (_, _, frames) in enumerate(ANIMS):
        for fi, (row, col) in enumerate(frames):
            s = shrink(rgba, rows[row][col])
            # centrar por la carrocería (franja media), apoyado abajo: el rover no "tiembla"
            band = s[s.shape[0] * 2 // 5: s.shape[0] * 4 // 5, :, 3] > 0
            cx = np.nonzero(band)[1].mean()
            left = int(round(CELL_W / 2 - cx - 0.5))
            sheet.alpha_composite(Image.fromarray(s), (fi * CELL_W + left, ai * CELL_H + CELL_H - 1 - s.shape[0]))

    alpha = sheet.getchannel("A")
    q = sheet.convert("RGB").quantize(COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
    q.putalpha(alpha)
    q.save(OUT / "rover.png")

    lines = ['[gd_resource type="SpriteFrames" format=3]', "",
             '[ext_resource type="Texture2D" path="res://assets/vehicles/rover.png" id="1_sheet"]', ""]
    anim_txt = []
    for ai, (name, fps, frames) in enumerate(ANIMS):
        refs = []
        for fi in range(len(frames)):
            sid = f"AtlasTexture_{name}_{fi}"
            lines += [f'[sub_resource type="AtlasTexture" id="{sid}"]', 'atlas = ExtResource("1_sheet")',
                      f"region = Rect2({fi * CELL_W}, {ai * CELL_H}, {CELL_W}, {CELL_H})", ""]
            refs.append(f'{{\n"duration": 1.0,\n"texture": SubResource("{sid}")\n}}')
        anim_txt.append(f'{{\n"frames": [{", ".join(refs)}],\n"loop": true,\n"name": &"{name}",\n"speed": {float(fps)}\n}}')
    lines += ["[resource]", f"animations = [{', '.join(anim_txt)}]", ""]
    (OUT / "rover_frames.tres").write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print("filas detectadas:", [len(r) for r in rows], f"escala {SCALE:.3f} ->", OUT)


if __name__ == "__main__":
    main()
