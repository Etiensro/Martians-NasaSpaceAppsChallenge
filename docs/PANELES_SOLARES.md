# Energía, tormentas y paneles solares

El tiempo, la energía, las tormentas y el resto de sistemas de la misión (autoload `Mission`) están
explicados en **`docs/SISTEMAS_DE_MISION.md`**. Aquí solo va lo propio de los paneles.

## Paneles y cables

| | |
|---|---|
| Paneles | 16 paneles (4×4) con suciedad 0–100 y roto/sano. Cada sol +10 de suciedad; cada tormenta +20. |
| Cables | Cada fila va en serie hasta su caja: un panel da energía si no está roto y el cable hasta la caja está entero. |
| Generación | Según la limpieza media (70–100: 12 EU/h, 40–69: 6, 1–39: 2, 0: 0) × paneles que funcionan / 16 × (1 − pérdida por tormenta). |
| Daños de tormenta | Paneles rotos / cables cortados: leve 1/0, moderada 2/1, intensa 4/3 (`_proposed` en `rules.json`). |
| Cambiar un panel | 10 EU (`energy.panel_repair_cost`). |

Limpiar los paneles dura 2 h en el documento: en el campo solar se juega en tiempo real (1 min = 1 h),
así que limpiar los 16 a mano tarda más o menos eso y no se adelanta el reloj. Mientras se está en el
campo cuenta como exterior (radiación +4/h).

```gdscript
Mission.cleanliness(); Mission.working_panels(); Mission.is_panel_working(i)
Mission.set_panel_dirt(i, dirt); Mission.replace_panel(i); Mission.repair_cable(k)
Mission.panels_changed.connect(f)
```

## Edificio de paneles solares

El vestíbulo (`scenes/interiores/paneles_solares/paneles_solares.tscn`) usa `scripts/interiores/lobby.gd`
y su imagen de `tools/build_lobbies.py`. Sus dos puertas abren los minijuegos:

| Puerta | Escena | Script | Qué es |
|---|---|---|---|
| SOLAR FIELD | `minijuegos/campo_solar/campo_solar.tscn` | `scripts/interiores/paneles_solares/campo_solar.gd` | Limpiar con la brocha, cambiar paneles rotos, reconectar cables, ráfagas de viento |
| POWER ROOM | `minijuegos/sala_electrica/sala_electrica.tscn` | `scripts/interiores/paneles_solares/sala_electrica.gd` | Interruptores (pastillas) y monitor con el balance de energía |

Con tormenta moderada o intensa, la puerta SOLAR FIELD y la flecha de salida avisan que no se puede salir.

En el mapa de AP-1, el edificio de los paneles cambia de imagen según su estado real: limpio,
`paneles sucios 1/2/3` y `paneles_averiados` (`scripts/colony.gd`). Las imágenes no sirven para el minijuego
(son el edificio entero en perspectiva), pero sí para el mapa.

## Assets

### Sala eléctrica (hechos por el equipo)
Fuentes en `tools/data/interiores/paneles_solares/`; `python tools/build_power_room.py` genera los recortes
en `assets/interiores/paneles_solares/sala_electrica/` (fondo transparente) y la zona de los interruptores.

### Pendientes (ahora se dibujan por código)
Basta con guardarlos con estos nombres en `assets/interiores/paneles_solares/campo_solar/` y la escena los usa sola.
La **arena no necesita imágenes**: es una capa que el juego genera y que la brocha borra; así sirve para
cualquier nivel de suciedad.

| Archivo | Qué es | Tamaño final |
|---|---|---|
| `field_panel.png` | Panel solar limpio, visto desde arriba | 180×100 |
| `field_panel_broken.png` | El mismo panel roto | 180×100 |
| `field_crate.png` | Caja con paneles de repuesto | 210×92 |
| `field_ground.png` | (opcional) suelo del campo; ahora usa el suelo de AP-1 | 1280×720 |

Prompts (Gemini). Pedir **fondo naranja liso** como en el resto de assets para recortarlos con `tools/imgutil.py`:

1. **Panel limpio** — *"16-bit pixel art, single solar panel module seen exactly from above (orthographic top-down, no perspective, no tilt), wide rectangle with 9:5 proportions, dark blue photovoltaic cells in a 6x3 grid with thin light-blue lines, light grey aluminium frame, small junction box on the right edge, crisp pixels, limited palette, no shadow, no text, centered on a solid flat orange background (#E8742C)."*
2. **Panel roto** — *"Same 16-bit pixel art solar panel module seen exactly from above, same size and frame, but broken: shattered glass with white cracks spreading from an impact point, two burnt black cells, a bent frame corner, small yellow sparks, no perspective, no text, solid flat orange background (#E8742C)."* (pedirlo en la misma conversación que el limpio para que coincidan)
3. **Caja de repuestos** — *"16-bit pixel art open metal supply crate seen from above, holding three stacked spare solar panels (dark blue cells, grey frame), NASA-style white and grey crate with yellow hazard stripes, crisp pixels, no text, solid flat orange background (#E8742C)."*
4. **Suelo (opcional)** — *"16-bit pixel art Martian ground seen exactly from above, rusty red-orange regolith with small rocks and subtle wind ripples, seamless, no objects, no buildings, 16:9."*

Si los assets que ya tienen están en horizontal o con perspectiva, no sirven para este minijuego (aquí todo se ve desde arriba y recto); lo mejor es generarlos de nuevo con estos prompts.
