"""Plantas del invernadero: etapas de marchitez de las papas (Mission.crops).

Fuentes:
  tools/data/interiores/invernadero/plantas_etapas_gemini.jpg  3 macetas sobre fondo verde
      (planta con puntas amarillas, marchita y seca)
  assets/interiores/estacion_ares1/invernadero/invernadero_base.png, fondo_vacio.png y fondo_plantas.png
      (fondos del equipo: la sala con las camas y la vista cenital)

Salida (assets/interiores/estacion_ares1/invernadero/plantas/):
  maceta_0.png ... maceta_3.png   icono de la planta en maceta: 0 sana, 1 débil, 2 marchita, 3 muerta
                                  (la sana sale de la débil pasando el amarillo a verde)
  camas_vacias.png                capa 1280x720 que tapa las plantas pintadas en las camas de la sala
  camas_1.png ... camas_3.png     capa 1280x720 con las plantas de la sala cada vez más secas
  planta_0.png ... planta_3.png   planta grande suelta en vista cenital (minijuego de cosechar)

Las etapas siguen al rendimiento (data/mission/rules.json -> crops.potato.dry_penalties):
  0 = 100 %, 1 = -10 %, 2 = -25 % o -50 %, 3 = muerta.

Uso: python tools/build_plantas.py
"""
import json
import pathlib

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "tools/data/interiores/invernadero/plantas_etapas_gemini.jpg"
DIR = ROOT / "assets/interiores/estacion_ares1/invernadero"
OUT = DIR / "plantas"
OUT.mkdir(parents=True, exist_ok=True)

# cuánto se seca cada etapa (0 = como está, 1 = del todo) en las plantas de la sala y la vista cenital
WILT = [0.0, 0.4, 0.8, 1.0]
# paletas (de oscuro a claro) sacadas de las macetas: marchita (amarillo paja) y muerta (marrón y gris)
DRY = np.array([(46, 30, 20), (92, 66, 34), (150, 116, 56), (196, 160, 92), (214, 196, 150)], np.float32)
DEAD = np.array([(34, 24, 18), (64, 46, 32), (98, 78, 56), (132, 116, 92), (160, 150, 128)], np.float32)


# ---------------------------------------------------------------- utilidades

def dilate(mask, r=1):
    out = mask.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            out |= np.roll(np.roll(mask, dy, 0), dx, 1)
    return out


def dry_color(rgb, pal):
    """Color seco según la luminosidad de cada píxel (interpola en la paleta `pal`)."""
    lum = (rgb * np.array([0.3, 0.55, 0.15], np.float32)).sum(-1)
    t = np.clip((lum - 20) / 150, 0, 1) * (len(pal) - 1)
    i = np.minimum(t.astype(int), len(pal) - 2)
    f = (t - i)[..., None]
    return pal[i] * (1 - f) + pal[i + 1] * f


def wilt(rgb, mask, stage):
    """Seca los píxeles de `mask` según la etapa: mezcla su color con el seco (la muerta, con el marrón).
    Las partes claras (puntas) se secan antes."""
    out = rgb.astype(np.float32).copy()
    amount = WILT[stage]
    if amount <= 0:
        return out
    lum = (out * np.array([0.3, 0.55, 0.15], np.float32)).sum(-1)
    k = np.clip(amount * (0.75 + lum / 400.0), 0, 1)[..., None]
    pal = DEAD if stage == 3 else DRY
    out[mask] = (out * (1 - k) + dry_color(out, pal) * k)[mask]
    return out


def save(arr, name):
    Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA").save(OUT / name)
    print("  ", name)


# ---------------------------------------------------------------- macetas (icono)

def grid_period(profile, lo=20.0, hi=30.0):
    """Tamaño y desfase de la cuadrícula de píxeles: los que hacen caer más bordes en las líneas."""
    best = (-1, 0, 0)
    for p in np.arange(lo, hi, 0.05):
        for ph in np.arange(0, p, 0.5):
            idx = np.round(np.arange(ph, len(profile) - 1, p)).astype(int)
            s = profile[idx].mean()
            if s > best[0]:
                best = (s, p, ph)
    return best[1], best[2]


def pot_sprites():
    img = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float32)
    dark = (img.sum(2) < 150).mean(0) > 0.9          # separadores oscuros entre las 3 macetas
    cols = np.nonzero(~dark)[0]
    panels, start = [], cols[0]
    for a, b in zip(cols[:-1], cols[1:]):
        if b != a + 1:
            panels.append((start, a + 1))
            start = b
    panels.append((start, cols[-1] + 1))
    assert len(panels) == 3, panels
    sprites = []
    for x0, x1 in panels:
        p = img[:, x0:x1]
        bg = (p[..., 1] > 170) & (p[..., 0] < 110) & (p[..., 2] < 110)
        gx = np.abs(np.diff(p, axis=1)).sum(2).sum(0)
        gy = np.abs(np.diff(p, axis=0)).sum(2).sum(1)
        px, phx = grid_period(gx)
        py, phy = grid_period(gy)
        xs = np.arange(phx, p.shape[1] - px / 2, px)
        ys = np.arange(phy, p.shape[0] - py / 2, py)
        out = np.zeros((len(ys) - 1, len(xs) - 1, 4), np.float32)
        for j in range(len(ys) - 1):
            for i in range(len(xs) - 1):
                # centro de la celda (sin los bordes, que el JPG mezcla)
                a0, a1 = int(ys[j] + py * 0.3), int(ys[j] + py * 0.7)
                b0, b1 = int(xs[i] + px * 0.3), int(xs[i] + px * 0.7)
                cell = p[a0:a1, b0:b1].reshape(-1, 3)
                cbg = bg[a0:a1, b0:b1].reshape(-1)
                if cbg.mean() > 0.5:
                    continue
                out[j, i, :3] = np.median(cell[~cbg], axis=0)
                out[j, i, 3] = 255
        ys_, xs_ = np.nonzero(out[..., 3])
        sprites.append(out[ys_.min():ys_.max() + 1, xs_.min():xs_.max() + 1])
    return sprites


def healthy(sprite):
    """Planta sana: el amarillo y el ocre de las hojas pasan a verde (la maceta no se toca)."""
    out = sprite.copy()
    rgb = out[..., :3]
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1)
    leaf = (out[..., 3] > 0) & (r >= g) & (g > b * 1.25) & (sat > 0.35) & (g > 70)
    lum = (rgb * np.array([0.3, 0.55, 0.15], np.float32)).sum(-1)
    green = np.stack([lum * 0.55, lum * 1.15, lum * 0.45], -1)
    rgb[leaf] = green[leaf]
    return out


def same_size(sprites):
    """Mismo tamaño para las 4 (pegadas abajo y centradas), para que el icono no salte al cambiar."""
    h = max(s.shape[0] for s in sprites)
    w = max(s.shape[1] for s in sprites)
    out = []
    for s in sprites:
        c = np.zeros((h, w, 4), np.float32)
        y0, x0 = h - s.shape[0], (w - s.shape[1]) // 2
        c[y0:, x0:x0 + s.shape[1]] = s
        out.append(c)
    return out


# ---------------------------------------------------------------- camas de la sala

def bed_layers():
    base = np.asarray(Image.open(DIR / "invernadero_base.png").convert("RGB")).astype(np.float32)
    lay = json.loads((DIR / "invernadero_layout.json").read_text(encoding="utf-8"))
    inside = np.zeros(base.shape[:2], bool)
    for c in lay["camas"]:
        t = c["tierra"]
        inside[t["y"]:t["y"] + t["h"], t["x"]:t["x"] + t["w"]] = True
    r, g, b = base[..., 0], base[..., 1], base[..., 2]
    plant = inside & (g > r + 8) & (g >= b)                # verde (la tubería azul tiene b > g)
    plant = dilate(plant, 1) & inside & ~((b > g + 10) | (b > r + 20))
    # al vaciar la cama se tapa todo lo que no es tierra cerca de cada planta (hojas y sombra),
    # salvo la tubería azul y el borde gris de metal
    soil_like = (r > g + 25) & (r > b + 35)
    metal = (np.abs(r - b) < 25) & (np.abs(r - g) < 25)
    shade = dilate(plant, 5) & inside & ~soil_like & ~metal & ~((b > g + 10) | (b > r + 20))

    # camas vacías: se rellena la planta con la tierra de alrededor (difusión) y unas motas
    soil = base.copy()
    known = inside & soil_like & ~dilate(plant | shade, 1)
    soil[~known] = 0
    w = known.astype(np.float32)
    for _ in range(30):
        acc = sum(np.roll(np.roll(soil * w[..., None], dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1))
        cnt = sum(np.roll(np.roll(w, dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1))
        fill = (~known) & (cnt > 0)
        soil[fill] = acc[fill] / cnt[fill][..., None]
        w = np.where(fill, 1.0, w)
        known = known | fill
    yy, xx = np.indices(base.shape[:2])
    noise = (xx * 73856093 ^ yy * 19349663) % 9               # motas fijas (sin numpy.random)
    hole = dilate(plant | shade, 1) & inside
    soil[hole & (noise == 0)] *= 0.82                       # motas oscuras y claras de la tierra
    soil[hole & (noise == 1)] *= 1.12
    soil[hole & (noise == 2)] *= 0.9
    empty = np.zeros((*base.shape[:2], 4), np.float32)
    empty[..., :3] = soil
    empty[..., 3] = np.where(hole, 255, 0)
    save(empty, "camas_vacias.png")

    for k in (1, 2, 3):
        layer = np.zeros_like(empty)
        layer[..., :3] = wilt(base, plant, k)
        layer[..., 3] = np.where(plant, 255, 0)
        save(layer, "camas_%d.png" % k)


# ---------------------------------------------------------------- planta cenital (cosechar)

def top_plant():
    """Recorta una planta de fondo_plantas restando fondo_vacio (alrededor del primer hueco)."""
    full = np.asarray(Image.open(DIR / "fondo_plantas.png").convert("RGB")).astype(np.float32)
    empty = np.asarray(Image.open(DIR / "fondo_vacio.png").convert("RGB")).astype(np.float32)
    holes = json.loads((DIR / "huecos_layout.json").read_text(encoding="utf-8"))
    h0 = holes["camas"][0]["huecos"][0]
    cx, cy, R = int(h0["x"]), int(h0["y"]), 40
    a = full[cy - R:cy + R, cx - R:cx + R]
    e = empty[cy - R:cy + R, cx - R:cx + R]
    diff = np.abs(a - e).max(-1) > 40
    green = (a[..., 1] > a[..., 0] + 10)
    mask = diff & (green | dilate(green, 2))
    ys, xs = np.nonzero(mask)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    crop, m = a[y0:y1, x0:x1], mask[y0:y1, x0:x1]
    info = {"centro_hueco": [int(cx - (cx - R + x0)), int(cy - (cy - R + y0))], "tamano": [int(x1 - x0), int(y1 - y0)]}
    for k in range(4):
        spr = np.zeros((*crop.shape[:2], 4), np.float32)
        spr[..., :3] = wilt(crop, m, k)
        spr[..., 3] = np.where(m, 255, 0)
        save(spr, "planta_%d.png" % k)
    return info


def main():
    print("macetas")
    weak, wilted, dead = pot_sprites()
    for k, s in enumerate(same_size([healthy(weak), weak, wilted, dead])):
        save(s, "maceta_%d.png" % k)
    print("camas de la sala")
    bed_layers()
    print("planta cenital")
    info = top_plant()
    (OUT / "plantas.json").write_text(json.dumps({
        "_comment": "Lo genera tools/build_plantas.py. Etapas: 0 sana, 1 débil (-10 %), 2 marchita (-25 / -50 %), 3 muerta.",
        "planta": info,
    }, indent=2, ensure_ascii=False), encoding="utf-8")


if __name__ == "__main__":
    main()
