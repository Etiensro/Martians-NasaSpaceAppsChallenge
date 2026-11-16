"""Assets del laboratorio (Work Room) y de la enfermería de la Estación Ares 1 (hojas de Gemini con
fondo magenta, hechas por el equipo).

Fuentes:
  tools/data/interiores/sala_trabajo/
    laboratorio_gemini.webp   sala del laboratorio (también el fondo del vestíbulo: build_lobbies.py)
    hielo_y_matraz.jpg        trozos de hielo, burbujas, parrilla, matraz (hielo / derritiendo / hirviendo),
                              matraz sirviendo y cajas de Petri
    pinzas.jpg                manos con guante y pinzas (abiertas / cerradas)
    textos.jpg                letreros ("DO NOT DROP THE ICE!", "FAILED"...) y números
  tools/data/interiores/enfermeria/
    enfermeria_gemini.webp    bahía médica (fondo del vestíbulo: build_lobbies.py)
    plataformas.jpg           plataforma del escáner (quieta, escaneando, apagada, roja)
    escaner_ui.jpg            pantalla SCAN-MO-TRON 2000, barras, rayo verde y destellos
    monitor_y_letras.webp     iconos (corazón, aviso) y letras

Genera:
  assets/interiores/estacion_ares1/sala_trabajo/lab/*.png + lab.json   (minijuego de análisis)
    plate_beaker_off.png se arma aquí: el matraz vacío con la parrilla apagada (ver coil_off)
  assets/interiores/estacion_ares1/enfermeria/scan/*.png + scan.json   (minijuego del escáner)
  Los .json guardan tamaños y puntos útiles (p. ej. la punta de las pinzas).

Las coordenadas (SEEDS) son puntos en px de cada hoja que caen sobre el sprite: si cambia una hoja,
se ajustan aquí. Con --preview guarda una hoja de contacto en ../_previews.

Uso:  python tools/build_lab_medico.py [--preview]
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

from imgutil import cut_sprite, magenta_to_alpha, sprite_labels

ROOT = Path(__file__).resolve().parent.parent
SRC_LAB = ROOT / "tools/data/interiores/sala_trabajo"
SRC_MED = ROOT / "tools/data/interiores/enfermeria"
OUT_LAB = ROOT / "assets/interiores/estacion_ares1/sala_trabajo/lab"
OUT_MED = ROOT / "assets/interiores/estacion_ares1/enfermeria/scan"

# hoja[#etiqueta] -> (dilatación para unir piezas, {nombre: ([puntos], escala final[, color])})
# color: los píxeles semitransparentes (brillo, halo) se pintan de ese color en lugar del rosa del fondo.
LAB_SHEETS = {
    "hielo_y_matraz.jpg": (0, {
        "ice_1": ([(113, 113)], 0.5),
        "ice_2": ([(453, 112)], 0.5),
        "ice_3": ([(113, 283)], 0.5),
        "ice_4": ([(283, 280)], 0.5),
        "ice_5": ([(460, 275)], 0.5),
        "ice_6": ([(105, 455)], 0.5),
        "bubble": ([(675, 75)], 0.5),
        "plate_off": ([(1217, 250)], 0.62),
        "plate_empty": ([(1733, 283)], 0.62),
        "plate_ice": ([(250, 1000)], 0.62),
        "plate_melting": ([(733, 1000)], 0.62),
        "plate_boiling": ([(1225, 1000)], 0.62),
        "beaker_pour": ([(1717, 833)], 0.62),
        "dish_empty": ([(1000, 1430)], 0.55),
        "dish_sample": ([(1683, 1430)], 0.55),
    }),
    "pinzas.jpg": (0, {
        "hand_open": ([(383, 667)], 0.42),
        "hand_closed": ([(383, 900)], 0.42),
    }),
    "textos.jpg": (2, {
        "txt_objective": ([(717, 1075)], 0.5),
        "txt_do_not_drop": ([(483, 75)], 0.5),
        "txt_ice_melted": ([(683, 478)], 0.5),
        "txt_warning": ([(275, 947)], 0.5),
        "txt_failed": ([(758, 667)], 0.5),
        "txt_try_again": ([(742, 792)], 0.5),
        "txt_stage_complete": ([(1292, 1350), (1292, 1430)], 0.5),
        "txt_well_done": ([(1722, 728)], 0.5),
        "txt_sample_analyzed": ([(1725, 340), (1725, 440)], 0.5),
        "digit_0": ([(1547, 1187)], 0.5), "digit_1": ([(1633, 1187)], 0.5), "digit_2": ([(1728, 1187)], 0.5),
        "digit_3": ([(1833, 1187)], 0.5), "digit_4": ([(1930, 1187)], 0.5), "digit_5": ([(1547, 1300)], 0.5),
        "digit_6": ([(1638, 1300)], 0.5), "digit_7": ([(1733, 1300)], 0.5), "digit_8": ([(1828, 1300)], 0.5),
        "digit_9": ([(1922, 1300)], 0.5), "digit_slash": ([(1638, 1422)], 0.5), "digit_plus": ([(1733, 1422)], 0.5),
        "digit_percent": ([(1833, 1422)], 0.5), "digit_s": ([(1930, 1422)], 0.5),
    }),
    # las líneas de abajo a la izquierda están muy juntas: sin unir letras de más
    "textos.jpg#fino": (1, {
        "txt_waiting": ([(442, 1333)], 0.5),
    }),
}

MED_SHEETS = {
    "plataformas.jpg": (0, {
        "pad_big": ([(650, 392)], 0.42),
        "pad_red": ([(1633, 575)], 0.85),
        "pad_0": ([(367, 967)], 0.85),
        "pad_1": ([(1005, 967)], 0.85),
        "pad_2": ([(1647, 967)], 0.85),
        "pad_3": ([(367, 1308)], 0.85),
        "pad_4": ([(1005, 1308)], 0.85),
        "pad_off": ([(1647, 1308)], 0.85),
    }),
    "escaner_ui.jpg": (1, {
        "monitor": ([(1000, 100)], 0.55),
        "beam": ([(833, 575)], 0.6, "3dff7a"),
        "beam_glow": ([(867, 925)], 0.6, "3dff7a"),
        "bar_empty": ([(275, 108)], 0.6),
        "bar_full": ([(275, 1142)], 0.6),
        "progress_frame": ([(1000, 1083)], 0.6),
        "scan_complete": ([(1700, 1267)], 0.55),
        "sparkle": ([(1517, 767)], 0.6),
    }),
    "monitor_y_letras.webp": (0, {
        "icon_warning": ([(940, 65)], 0.9),
        "icon_heart": ([(940, 300)], 0.9),
    }),
}

def build(src_dir, sheets, out):
    out.mkdir(parents=True, exist_ok=True)
    made = {}
    for name, (dil, items) in sheets.items():
        rgb = np.asarray(Image.open(src_dir / name.split("#")[0]).convert("RGB"))
        rgba = magenta_to_alpha(rgb)
        labels = sprite_labels(rgba[..., 3], dilate=dil)
        for key, (seeds, factor, *tint) in items.items():
            img = cut_sprite(rgba, labels, seeds, factor=factor)
            if tint:
                a = np.asarray(img).copy()
                soft = a[..., 3] < 235
                a[soft, :3] = [int(tint[0][i:i + 2], 16) for i in (0, 2, 4)]
                img = Image.fromarray(a)
            img.save(out / f"{key}.png")
            made[key] = img
    return made


def coil_off(img):
    """Matraz vacío con la parrilla APAGADA (no hay ese dibujo en la hoja): se toma el de la parrilla
    encendida y la resistencia roja/naranja se pasa a gris oscuro, como la de plate_ice."""
    a = np.asarray(img).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    hot = (r > g + 12) & (r > b + 22)
    lum = 0.3 * r + 0.59 * g + 0.11 * b
    dark = np.stack([28 + lum * 0.12, 33 + lum * 0.13, 42 + lum * 0.16], -1)
    a[..., :3] = np.where(hot[..., None], dark, a[..., :3])
    return Image.fromarray(a.clip(0, 255).astype(np.uint8))


def tip_of(img):
    """Punta de las pinzas: el píxel opaco más a la derecha (y la altura media en esa columna)."""
    a = np.asarray(img)[..., 3] > 128
    xs = np.nonzero(a.any(0))[0]
    x = int(xs.max())
    ys = np.nonzero(a[:, x - 3:x + 1].any(1))[0]
    return [x, int(ys.mean())]


def contact_sheet(made, path):
    pad, x, y, row_h = 10, 10, 10, 0
    sheet = Image.new("RGBA", (1600, 1400), (40, 44, 60, 255))
    for img in made.values():
        if x + img.width > sheet.width:
            x, y, row_h = 10, y + row_h + pad, 0
        sheet.alpha_composite(img, (x, y))
        x += img.width + pad
        row_h = max(row_h, img.height)
    sheet.save(path)


def main():
    lab = build(SRC_LAB, LAB_SHEETS, OUT_LAB)
    lab["plate_beaker_off"] = coil_off(lab["plate_empty"])
    lab["plate_beaker_off"].save(OUT_LAB / "plate_beaker_off.png")
    info = {k: list(v.size) for k, v in lab.items()}
    info["tip_open"] = tip_of(lab["hand_open"])
    info["tip_closed"] = tip_of(lab["hand_closed"])
    (OUT_LAB / "lab.json").write_text(json.dumps(info, indent=1), encoding="utf-8")
    print(f"laboratorio: {len(lab)} sprites -> {OUT_LAB}")

    med = build(SRC_MED, MED_SHEETS, OUT_MED)
    (OUT_MED / "scan.json").write_text(json.dumps({k: list(v.size) for k, v in med.items()}, indent=1), encoding="utf-8")
    print(f"enfermeria: {len(med)} sprites -> {OUT_MED}")

    if "--preview" in sys.argv:
        prev = ROOT.parent / "_previews"
        prev.mkdir(exist_ok=True)
        contact_sheet(lab, prev / "lab_sprites.png")
        contact_sheet(med, prev / "scan_sprites.png")


if __name__ == "__main__":
    main()
