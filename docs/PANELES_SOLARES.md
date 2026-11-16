# Energía, tormentas y paneles solares

El tiempo, la energía, las tormentas y el resto de sistemas de la misión (autoload `Mission`) están
explicados en **`docs/SISTEMAS_DE_MISION.md`**. Aquí solo va lo propio de los paneles.

## Paneles y cables

| | |
|---|---|
| Paneles | 16 paneles (4×4) con suciedad 0–100 y roto/sano. **Empiezan cubiertos de polvo y con 3 rotos** (suciedad 100 cada uno; `panels.start_dirt_min/max`, `start_broken`, `start_cut_cables`; `_proposed`: la tormenta del aterrizaje), así que al empezar la generación es 0 EU/h (balance −8 EU/h) y hay que limpiarlos y cambiar los rotos. Cada sol +10 de suciedad. Un panel nuevo llega limpio. |
| Cables | Cada fila va en serie hasta su caja: un panel da energía si no está roto y el cable hasta la caja está entero. |
| Generación | 12 EU/h (`energy.max_generation`) × paneles que funcionan / 16 × limpieza media / 100 × (1 − pérdida por tormenta). Ej.: 13 sanos y 50 % limpios → 12 × 13/16 × 0.5 ≈ 4.9 EU/h. |
| Imagen en el mapa (AP-1) | `colony.gd` cambia la imagen del campo solar según la limpieza media: ≥95 limpio (`paneles_grande.png`, o `paneles_averiados.png` si hay rotos o cables cortados), 66–94 `paneles sucios 1.png`, 33–65 `paneles sucios 2.png`, 0–32 `paneles sucios 3.png`. Se actualiza en vivo (tormentas, polvo de cada sol). |
| Tormentas | Tres niveles (`storms.types.<tipo>`, `_proposed_panels`): **leve** ensucia poco (+15), **moderada** ensucia más (+35), **intensa** ensucia (+50) y además rompe 4 paneles y corta 2 cables. La suciedad (`dirt`) se suma hora a hora mientras dura la tormenta (se ve caer la arena si estás en el campo durante una leve); las roturas (`broken_panels`, `cut_cables`) llegan al terminar. |
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

### Campo solar (hechos por el equipo)
Fuentes de Gemini (fondo naranja liso) en `tools/data/interiores/paneles_solares/field_*_gemini.jpg`;
`python tools/build_field.py` (con `--preview` deja una vista previa en `../_previews/`) recorta el fondo,
reduce cada imagen a su tamaño y las guarda en `assets/interiores/paneles_solares/campo_solar/`.
`campo_solar.gd` las usa solas; si falta alguna, esa parte se dibuja por código.
La **arena no necesita imágenes**: es una capa que el juego genera y que la brocha borra; así sirve para
cualquier nivel de suciedad. Se pinta opaca y con los colores del polvo de `assets/buildings/paneles sucios 1-3.png`
(`_show_dirt()` en `campo_solar.gd`): con ~60 % de suciedad el panel ya se ve tapado. Solo cambia el dibujo; la
suciedad que cuenta para `Mission` es la cantidad real de arena.

| Archivo | Qué es | Tamaño final |
|---|---|---|
| `field_panel.png` | Panel solar limpio, visto desde arriba (solo el marco; el conector del cable lo dibuja el juego) | 180×100 |
| `field_panel_broken.png` | El mismo panel roto | 180×100 |
| `field_crate.png` | Caja con paneles de repuesto (centrada, sin deformar) | 210×92 |
| `field_ground.png` | Suelo del campo | 1280×720 |
| `field_combiner.png` | Caja de conexiones de cada fila (sin el poste: el cable principal lo dibuja el juego). Su luz la pinta el juego: verde si algún panel de la fila da energía, roja si ninguno | 50 de alto |
| `field_brush.png` | Brocha que sigue al ratón sobre los paneles | 60 de ancho |
| `field.json` | `brush_anchor`: punto de la brocha (centro de las cerdas) que va bajo el ratón | — |

Para cambiar un asset: generar la imagen nueva con el mismo nombre en `tools/data/...` y volver a ejecutar
`python tools/build_field.py`. Prompts: vista **cenital y recta** (sin perspectiva), **fondo naranja liso
#E8742C**, sin naranja en el objeto y sin sombra; el panel limpio y el roto, en la misma conversación.

### Brocha y estado de la tripulación
Limpiar es una tarea de mantenimiento: la brocha quita arena a `1 / Mission.task_multiplier("maintenance")`
de su velocidad normal. Con hambre, cansancio, radiación o mala condición física limpia más lento, y con el
ingeniero (`repair_speed` 1.25) más rápido. La línea de estado de abajo lo avisa.
