# Energía, tormentas y paneles solares

## Autoload `Mission` (`scripts/core/mission.gd`)

Lleva el tiempo y la energía de la misión en todo el juego (se para en el menú y la intro).
Todos los números están en **`data/mission/rules.json`** (valores del documento de reglas del equipo;
los campos `_proposed` son propuestas nuestras y se pueden cambiar).

| Sistema | Cómo funciona |
|---|---|
| Reloj | 1 min real = 1 h de juego. Empieza en Sol 1, 08:00. 60 sols. |
| Batería | 0–1000 EU, empieza en 800. Cada instante: `+ generación − consumo`. Si llega a 0, termina la misión. |
| Generación | Según la limpieza media de los paneles (70–100: 12 EU/h, 40–69: 6, 1–39: 2, 0: 0) × paneles que funcionan / 16 × (1 − reducción por tormenta). |
| Consumo | Soporte vital 4 + cápsulas 1 + invernadero 2 + luces/auxiliares 1 = 8 EU/h, más consumos extra (laboratorio). |
| Paneles | 16 paneles (4×4) con suciedad 0–100 y roto/sano. Cada fila va en serie hasta su caja: un panel da energía si no está roto y el cable hasta la caja está entero. Cada sol +10 de suciedad. |
| Tormentas | Tras 3 sols de protección, 15 % por sol. Aviso ≥ 6 h antes. Leve 12 h −20 %, moderada 24 h −45 %, intensa 48 h −70 %. Al terminar: +20 de suciedad, paneles rotos y cables cortados (leve 1/0, moderada 2/1, intensa 4/3). |
| Encierro | Con tormenta moderada o intensa, el jugador va solo al centro de la estación y no puede salir hasta que pase. |
| Auxiliares | Se pueden apagar antes de una expedición. Apagados, no se puede entrar a la estación (A.R.I.A. lo explica). |
| Invernadero | Se puede apagar. Las consecuencias para las plantas las aplica el módulo del invernadero (ver abajo). |

### Cómo lo usan otros módulos

```gdscript
Mission.advance_hours(2.0)           # actividad que dura 2 h de juego (gimnasio, dormir, analizar...)
Mission.spend(20)                    # gasto puntual (escáner médico: 20 EU). false si no alcanza
Mission.set_extra_load("lab", 4)     # consumo extra mientras dure; set_extra_load("lab", 0) para quitarlo
Mission.is_on("greenhouse")          # ¿invernadero encendido?
Mission.notify("Text")               # mensaje de A.R.I.A. en pantalla
Mission.sol(); Mission.hour_of_day() # tiempo actual
Mission.sol_started.connect(f)       # señales: hour_passed, sol_started, storm_warning, storm_started,
                                     # storm_ended, systems_changed, panels_changed, mission_over
```

Pendiente para otros módulos:
- **Invernadero** (`scripts/interiores/estacion_ares1/invernadero.gd`): si `Mission.is_on("greenhouse")` es false
  con un cultivo plantado, cada sol cuenta como "sol sin regar" (tabla del documento: −10 %, −25 %, −50 %,
  muere al 4.º). También se puede usar `Mission.sol_started` para el riego diario.
- **Gimnasio**: la caminadora dura 15 s reales; debería llamar `Mission.advance_hours(2.0 - 0.25)` al completarse.

### Atajos de prueba (solo al ejecutar desde el editor)

| Tecla | Qué hace |
|---|---|
| Ctrl+1 | Tormenta ya (leve → moderada → intensa, en orden) |
| Ctrl+2 | +1 hora |
| Ctrl+3 | +1 sol (los paneles se ensucian) |
| Ctrl+4 | Daños de tormenta intensa en los paneles |

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
