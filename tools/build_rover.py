"""Convierte la hoja de sprites del rover (generada con Gemini) en:
  - assets/vehicles/rover.png         (sprite sheet: fila = animación, columna = frame)
  - assets/vehicles/rover_frames.tres (SpriteFrames para AnimatedSprite2D)

Se reduce para que sus "píxeles" midan lo mismo que los del astronauta en el juego
(~3 px), así ambos se ven del mismo estilo. Los sprites de lado miran a la DERECHA;
para la izquierda se usa flip_h en Godot.

Uso:  python tools/build_rover.py
"""
import pathlib

import numpy as np
from PIL import Image

from imgutil import find_sprites, quantize_rgba, shrink_to, write_sprite_frames

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "tools" / "data" / "vehicles" / "rover_sheet_gemini.png"
OUT = ROOT / "assets" / "vehicles"

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


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rgb = np.asarray(Image.open(SRC).convert("RGB")).astype(np.int32)
    mask, rows = find_sprites(rgb)
    rgba = np.dstack([rgb, mask * 255]).astype(np.uint8)

    max_frames = max(len(f) for _, _, f in ANIMS)
    sheet = Image.new("RGBA", (CELL_W * max_frames, CELL_H * len(ANIMS)), (0, 0, 0, 0))
    for ai, (_, _, frames) in enumerate(ANIMS):
        for fi, (row, col) in enumerate(frames):
            x0, y0, x1, y1 = box = rows[row][col]
            s = shrink_to(rgba, box, (round((x1 - x0) * SCALE), round((y1 - y0) * SCALE)))
            # centrar por la carrocería (franja media), apoyado abajo: el rover no "tiembla"
            band = s[s.shape[0] * 2 // 5: s.shape[0] * 4 // 5, :, 3] > 0
            cx = np.nonzero(band)[1].mean()
            left = int(round(CELL_W / 2 - cx - 0.5))
            sheet.alpha_composite(Image.fromarray(s), (fi * CELL_W + left, ai * CELL_H + CELL_H - 1 - s.shape[0]))

    quantize_rgba(sheet, COLORS).save(OUT / "rover.png")
    write_sprite_frames(OUT / "rover_frames.tres", "res://assets/vehicles/rover.png",
                        [(name, fps, True, len(frames)) for name, fps, frames in ANIMS], CELL_W, CELL_H)
    print("filas detectadas:", [len(r) for r in rows], f"escala {SCALE:.3f} ->", OUT)


if __name__ == "__main__":
    main()
