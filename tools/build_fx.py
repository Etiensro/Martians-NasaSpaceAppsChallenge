"""Genera las texturas pequeñas de los efectos (blancas: el color se pone en Godot).

  assets/fx/glow.png    halo suave para luces (64x64)
  assets/fx/glint.png   destello de 4 puntas en pixel art (11x11)
  assets/fx/dust.png    grano de polvo (2x2)
  assets/fx/streak.png  ráfaga de viento alargada (12x2)
  assets/fx/puff.png    bocanada de humo/vapor pixelada (8x8)

Uso:  python tools/build_fx.py
"""
import pathlib

import numpy as np
from PIL import Image

OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "fx"


def save(a, name):
    Image.fromarray(a.astype(np.uint8), "RGBA").save(OUT / name)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # halo suave
    n = 64
    yy, xx = np.mgrid[0:n, 0:n]
    d = np.hypot(xx - n / 2 + 0.5, yy - n / 2 + 0.5) / (n / 2)
    a = np.zeros((n, n, 4)); a[..., :3] = 255; a[..., 3] = (np.clip(1 - d, 0, 1) ** 2.2) * 255
    save(a, "glow.png")
    # destello de 4 puntas (pixel art)
    g = np.zeros((11, 11, 4)); g[..., :3] = 255
    for i in range(11):
        v = max(0, 255 - abs(i - 5) * 50)
        g[5, i, 3] = max(g[5, i, 3], v); g[i, 5, 3] = max(g[i, 5, 3], v)
    for dx, dy in ((-1, -1), (1, 1), (-1, 1), (1, -1)):
        g[5 + dy, 5 + dx, 3] = 140
    save(g, "glint.png")
    # polvo
    p = np.zeros((2, 2, 4)); p[..., :3] = 255; p[..., 3] = 255
    save(p, "dust.png")
    # ráfaga
    s = np.zeros((2, 12, 4)); s[..., :3] = 255
    s[..., 3] = np.concatenate([np.linspace(0, 255, 4), np.full(4, 255), np.linspace(255, 0, 4)])[None, :]
    save(s, "streak.png")
    # bocanada pixelada
    pf = np.zeros((8, 8, 4)); pf[..., :3] = 255
    yy, xx = np.mgrid[0:8, 0:8]
    pf[..., 3] = np.where(np.hypot(xx - 3.5, yy - 3.5) < 3.6, 255, 0)
    save(pf, "puff.png")
    print("texturas de efectos listas:", OUT)


if __name__ == "__main__":
    main()
