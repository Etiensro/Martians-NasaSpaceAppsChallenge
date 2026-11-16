"""Nave en vuelo para el despegue del final (scripts/finales/despegue.gd).

assets/buildings/nave.png (la nave de la colonia de AP-1, de tools/build_colony.py) trae pintada debajo la
sombra gris de la plataforma. Para que no suba con la nave, se quita: se rellena desde el fondo
transparente todo lo gris de la parte de abajo que esté conectado con él (el contorno oscuro de la nave
y sus colores frenan el relleno).

Salida: assets/buildings/nave_vuelo.png (mismo tamaño que nave.png, para colocarla en el mismo sitio).
Uso: python tools/build_nave_vuelo.py
"""
import pathlib
from collections import deque

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/buildings/nave.png"
OUT = ROOT / "assets/buildings/nave_vuelo.png"
FROM_ROW = 0.55          # solo se busca sombra por debajo de esta altura (parte de la imagen)


def main():
    img = np.asarray(Image.open(SRC).convert("RGBA")).copy()
    h, w, _ = img.shape
    rgb = img[..., :3].astype(int)
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1)
    shadow = (img[..., 3] > 0) & (sat < 0.2) & (mx >= 64) & (mx <= 160)
    shadow[: int(h * FROM_ROW)] = False
    clear = img[..., 3] == 0
    seen = np.zeros_like(shadow)
    q = deque()
    for y in range(int(h * FROM_ROW), h):
        for x in range(w):
            if shadow[y, x] and any(0 <= y + dy < h and 0 <= x + dx < w and clear[y + dy, x + dx]
                                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                seen[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and shadow[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    img[seen, 3] = 0
    Image.fromarray(img).save(OUT)
    print("quitados", int(seen.sum()), "px ->", OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
