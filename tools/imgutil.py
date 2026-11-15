"""Funciones compartidas por todos los scripts build_*.py.

Las imágenes de Gemini tienen un fondo de color liso; casi todo el trabajo consiste en:
  1. separar el objeto del fondo            -> object_mask()
  2. encontrar cada sprite de una hoja      -> find_sprites()
  3. reducirlo a pixel art                  -> shrink_to() / downscale_masked()
  4. limpiar la paleta                      -> quantize_rgba()
  5. escribir el SpriteFrames de Godot      -> write_sprite_frames()
"""
from collections import deque

import numpy as np
from PIL import Image

BG_TOLERANCE = 90  # diferencia mínima con el color de fondo para considerar "objeto"


# ---------------------------------------------------------------- fondo y máscaras

def background_color(rgb, corner=20):
    """Color del fondo: la mediana de la esquina superior izquierda."""
    return np.median(rgb[:corner, :corner].reshape(-1, 3), axis=0)


def object_mask(rgb, bg=None, tolerance=BG_TOLERANCE):
    """True donde hay objeto (todo lo que se aleja lo suficiente del color de fondo)."""
    if bg is None:
        bg = background_color(rgb)
    return np.abs(rgb - bg).sum(2) > tolerance


def components(mask):
    """Zonas conectadas (4 vecinos) de la máscara, en orden de lectura (arriba-abajo, izq-der).
    Devuelve una lista de (ys, xs) por zona."""
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    out = []
    for y, x in zip(*np.nonzero(mask)):
        if seen[y, x]:
            continue
        seen[y, x] = True
        q = deque([(y, x)])
        ys, xs = [], []
        while q:
            cy, cx = q.popleft()
            ys.append(cy)
            xs.append(cx)
            for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    q.append((ny, nx))
        out.append((ys, xs))
    return out


def find_sprites(rgb, min_pixels=500, row_gap=100):
    """Máscara del objeto y cajas (x0, y0, x1, y1) de cada sprite de una hoja, agrupadas por filas
    (de arriba abajo) y ordenadas de izquierda a derecha dentro de cada fila."""
    mask = object_mask(rgb)
    boxes = [(min(xs), min(ys), max(xs) + 1, max(ys) + 1)
             for ys, xs in components(mask) if len(ys) > min_pixels]
    boxes.sort(key=lambda b: b[1])
    rows, current = [], [boxes[0]]
    for b in boxes[1:]:
        if b[1] - current[0][1] > row_gap:
            rows.append(current)
            current = []
        current.append(b)
    rows.append(current)
    return mask, [sorted(r) for r in rows]


def fill_holes(rgb, mask, color, min_area=800):
    """Rellena con `color` los huecos grandes dentro del objeto (p. ej. un visor que deja ver
    el fondo). Un hueco es fondo que no toca el borde de la imagen."""
    h, w = mask.shape
    rgb = rgb.copy()
    mask = mask.copy()
    for ys, xs in components(~mask):
        touches_border = min(ys) == 0 or min(xs) == 0 or max(ys) == h - 1 or max(xs) == w - 1
        if not touches_border and len(ys) >= min_area:
            rgb[ys, xs] = color
            mask[ys, xs] = True
    return rgb, mask


def crop_to_mask(rgb, mask):
    """Recorta imagen y máscara a la caja del objeto. Devuelve (rgb, mask, caja)."""
    ys, xs = np.nonzero(mask)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    return rgb[box[1]:box[3], box[0]:box[2]], mask[box[1]:box[3], box[0]:box[2]], box


# ---------------------------------------------------------------- reducir a pixel art

def binarize_alpha(rgba, threshold=140):
    """Alfa todo o nada (pixel art sin bordes semitransparentes)."""
    rgba[..., 3] = np.where(rgba[..., 3] > threshold, 255, 0)
    return rgba


def shrink_to(rgba, box, size, trim=True):
    """Recorta `box` de una imagen RGBA y la reduce a `size` (ancho, alto) promediando (BOX).
    Con trim=True se quitan los bordes que quedan transparentes."""
    x0, y0, x1, y1 = box
    small = np.asarray(Image.fromarray(rgba[y0:y1, x0:x1]).resize(size, Image.BOX)).copy()
    binarize_alpha(small)
    if not trim:
        return small
    ys, xs = np.nonzero(small[..., 3])
    return small[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def downscale_masked(rgb, mask, size):
    """Reduce a `size` promediando SOLO los píxeles del objeto, para que el color del fondo
    no se cuele en los bordes. Devuelve un array RGBA uint8."""
    m = mask.astype(np.float32)

    def down(a):
        return np.asarray(Image.fromarray(a.astype(np.float32), mode="F").resize(size, Image.BOX))

    a = down(m)
    col = np.stack([down(rgb[..., i] * m) for i in range(3)], -1) / np.maximum(a, 1e-6)[..., None]
    out = np.zeros((size[1], size[0], 4), np.uint8)
    out[..., :3] = col.clip(0, 255)
    out[..., 3] = np.where(a > 0.5, 255, 0)
    return out


def quantize_rgba(img, colors):
    """Reduce la paleta (quita el ruido del JPG) conservando la transparencia."""
    alpha = img.getchannel("A")
    q = img.convert("RGB").quantize(colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
    q.putalpha(alpha)
    return q


# ---------------------------------------------------------------- recursos de Godot

def write_sprite_frames(path, texture_res, anims, cell_w, cell_h):
    """Escribe un SpriteFrames (.tres) para una hoja con una animación por fila.
    anims: lista de (nombre, fps, loop, número de frames), en el orden de las filas."""
    lines = ['[gd_resource type="SpriteFrames" format=3]', "",
             f'[ext_resource type="Texture2D" path="{texture_res}" id="1_sheet"]', ""]
    anim_txt = []
    for ai, (name, fps, loop, n_frames) in enumerate(anims):
        refs = []
        for fi in range(n_frames):
            sid = f"AtlasTexture_{name}_{fi}"
            lines += [f'[sub_resource type="AtlasTexture" id="{sid}"]', 'atlas = ExtResource("1_sheet")',
                      f"region = Rect2({fi * cell_w}, {ai * cell_h}, {cell_w}, {cell_h})", ""]
            refs.append(f'{{\n"duration": 1.0,\n"texture": SubResource("{sid}")\n}}')
        anim_txt.append(f'{{\n"frames": [{", ".join(refs)}],\n"loop": {str(loop).lower()},\n'
                        f'"name": &"{name}",\n"speed": {float(fps)}\n}}')
    lines += ["[resource]", f"animations = [{', '.join(anim_txt)}]", ""]
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")
