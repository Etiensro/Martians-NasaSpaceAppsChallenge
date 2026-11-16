# Sistemas de la misión (autoload `Mission`)

El sistema base del juego: tiempo, energía, hambre, cansancio, radiación, condición física, cultivos,
investigación, expediciones, tormentas y puntuación. **Léelo antes de tocar cualquier escena que gaste
tiempo o energía.** Fuente de las reglas: documento del equipo *"Sistema de Radiación y Salud Celular
(Base Ares 1)"*. Todos los números están en **`data/mission/rules.json`**: para balancear el juego se
cambia el JSON, no el código.

## Archivos

| Archivo | Qué tiene |
|---|---|
| `scripts/core/mission.gd` | Autoload `Mission` (registrado en `project.godot`). Reloj, actividades, tareas, energía, sistemas, paneles, tormentas, despensa, puntuación y fin de misión. Atajos de prueba. |
| `scripts/core/mission/crew.gd` | `Mission.crew`: hambre, cansancio, radiación, condición física. Comer, dormir, ejercicio, chequeo médico. Avisos de A.R.I.A. |
| `scripts/core/mission/crops.gd` | `Mission.crops`: cultivo de papas (plantar, regar, crecer, cosechar, limpiar la planta muerta). |
| `scripts/core/mission/research.gd` | `Mission.research`: muestras y análisis en el laboratorio. |
| `scripts/core/mission/expedition.gd` | `Mission.expedition`: carro explorador, viajes a AP-8/AP-9 y extracción de muestras. |
| `scripts/core/mission_hud.gd` | HUD: reloj, batería, barras, investigación, tormenta, mensajes de A.R.I.A., cartel de actividad y pantalla final con la puntuación. |
| `data/mission/rules.json` | Todas las reglas. Los campos `_proposed` son decisiones nuestras que el documento no fija. |
| `data/intro/roles.json` | Ventajas de cada rol (`modifiers`), que se leen con `GameState.modifier(clave)`. |

Los módulos son `RefCounted` (no nodos): `Mission` los crea, les pasa el tiempo y llama a su `reset()`.
Se usan siempre a través del autoload: `Mission.crew.eat()`, nunca `Crew.new()`.

## Cómo corre el tiempo

- **1 minuto real = 1 hora de juego.** Empieza en el Sol 1 a las 08:00 y dura 60 sols (1440 h).
- El reloj se para en el menú y la intro (`scenes/intro/`) y cuando termina la misión.
- `Mission.advance_hours(h)` avanza en pasos de 15 min. En cada paso: batería, barras de la tripulación,
  laboratorio y taladro. Cada hora: tormentas y encierro. A medianoche (sol nuevo): suciedad de los
  paneles, condición física, riego del cultivo y probabilidad de tormenta.
- **Actividades** (`Mission.run_activity`): dormir, chequeo, viajes, reparaciones... El documento pide
  que el tiempo avance durante ellas. Para que no haya que esperar 8 minutos reales a que el
  personaje duerma, se **adelanta el reloj en unos segundos** (0.35 s por hora, entre 1.5 y 6 s): la
  escena se pausa, aparece un cartel ("Sleeping 22:00 → 06:00") y todas las barras y los eventos se
  actualizan hora a hora como si pasara el tiempo de verdad.

```gdscript
await Mission.run_activity("Sleeping", 8.0, {"asleep": true})     # adelanta 8 h
await Mission.run_task("Repairing", 2.0, "repair")                # 2 h con penalizaciones (ver Tareas)
await Mission.run_task("Repairing", 2.0, "repair", 0.25)          # si el minijuego ya duró 0.25 h reales
```

Son corrutinas: llámalas con `await` si después tienes que hacer algo (cambiar de escena, etc.).
Si ya hay una actividad, la siguiente espera su turno. `Mission.is_busy()` dice si hay una en curso.

### Minijuegos y tiempo real

Mientras se juega un minijuego, el reloj sigue a 1 min = 1 h. Al terminar, la escena le dice a
`Mission` cuánto dura la tarea, y `Mission` adelanta **solo lo que falta**, restando lo ya jugado
(`already_played_hours`). Ejemplo, la caminadora: 15 s reales = 0.25 h ya jugadas; el ejercicio dura
2 h, así que se adelantan 1.75 h.

## Tareas y penalizaciones

Fórmula del documento (sección 12):

```
T_final = T_base × M_hambre × M_cansancio × M_radiación × [M_condición_física si es física] / velocidad_del_rol
```

```gdscript
Mission.task_hours(4.0, "general")    # 4 h con hambre 10-30, cansancio 80+ y radiación 50-74 -> 8.38 h
Mission.task_multiplier("physical")   # solo el multiplicador
```

| Tipo (`kind`) | Penalizaciones | Velocidad del rol |
|---|---|---|
| `general`, `medical` | hambre, cansancio, radiación | — |
| `physical` | + condición física | — |
| `repair`, `maintenance` | + condición física | `repair_speed` (ingeniero ×1.25) |
| `excavation` | + condición física | `extraction_speed` (astrofísico ×1.25) |
| `research` | hambre, cansancio, radiación | `research_speed` (astrofísico ×1.25) |
| `fixed` | ninguna | — |

Las tablas de penalización están en `rules.json -> crew.<barra>.penalties` como `[umbral, multiplicador]`
de mayor a menor umbral (se usa la primera fila con umbral ≤ valor). `Mission.tier(tabla, valor)` las lee.

## Barras de la tripulación (`Mission.crew`)

| Barra | Empieza | Cambia | Penalización | Fin de misión |
|---|---|---|---|---|
| `hunger` (hambre, 100 = lleno) | 100 | −6 por sol (poco a poco), +2 por comida, mín. 5 h entre comidas | 70+: ×1 · 40-69: ×1.15 · 0-39: ×1.35 | 0 |
| `fatigue` (cansancio, 0 = descansado) | 20 | +4/h despierto, −9/h dormido | 0-49: ×1 · 50-79: ×1.10 · 80+: ×1.35 | 100 |
| `radiation` (radiación) | 0 | +1/h dentro, +4/h fuera (zonas, mapa, campo solar, viajes). Solo baja con el chequeo (−30) | 25+: aviso · 50-74: ×1.15 · 75+: ×1.35 | 100 |
| `fitness` (condición física) | 100 | −15 cada sol sin ejercicio, +20 por sesión (1 por sol) | Solo tareas físicas: 75+: ×1 · 50-74: ×1.10 · 25-49: ×1.20 · 1-24: ×1.35 · 0: ×1.5 | — |

```gdscript
Mission.crew.eat()                       # "" o el motivo ("You ate not long ago...")
Mission.crew.eat_blocked_reason()        # para desactivar un botón
await Mission.crew.sleep(8)              # 1-24 h. Bajo techo: cuenta como interior
await Mission.crew.exercise(0.25)        # al terminar la caminadora. "" o "You already trained today..."
Mission.crew.can_exercise()
await Mission.crew.medical_checkup(0.1)  # 20 EU (médico: 0), 4 h (médico: más rápido), radiación −30
                                         # (0.1 h ya jugadas en el minijuego del escáner)
Mission.crew.checkup_blocked_reason()    # "" o el motivo (sin energía)
Mission.crew.value_of("fatigue")         # valor de una barra por nombre
```

**Comida:** en la base sale de la despensa (`Mission.pantry_meals`, empieza con 30); durante una
expedición, de las comidas cargadas en el carro. Cada papa cosechada es una comida más.

**Avisos:** A.R.I.A. avisa al cruzar umbrales (`rules.json -> crew.warnings.list`, textos en inglés).

**Ubicación** (`Mission.location()`): `"outside"` si la escena empieza por alguna ruta de
`rules.json -> locations.outside`, si no `"inside"`. Una actividad puede forzarla (los viajes son
`"outside"` y dormir es `"inside"`). **Si haces una escena exterior nueva, añádela a esa lista.**

## Energía (`Mission`)

| | |
|---|---|
| Batería | 0-1000 EU, empieza en 800. Nunca pasa de 1000. Si llega a 0, termina la misión. |
| Generación | 12 EU/h (`max_generation`) × paneles que funcionan / 16 × limpieza media / 100 × (1 − pérdida por tormenta). |
| Consumo | Soporte vital 4 + cápsulas 1 + invernadero 2 + luces/auxiliares 1 = 8 EU/h, + laboratorio 4 EU/h mientras analiza. × `energy_drain` del rol (ingeniero 0.9). |
| Gastos puntuales | Chequeo médico 20 EU, cambiar un panel 10 EU, reparar invernadero o carro 10 EU. |

Sistemas (`rules.json -> energy.systems`):
- `basic` y `cryo`: nunca se apagan.
- `greenhouse`: solo se apaga si no hay papas creciendo.
- `auxiliary`: se puede apagar (antes de una expedición), pidiendo confirmación. Apagado, **no se puede entrar a la
  estación**; se vuelve a encender en la Power Room (edificio de paneles).

```gdscript
Mission.switch_blocked_reason("greenhouse")   # "" o el motivo
Mission.set_system("auxiliary", false)        # false si no se puede
Mission.spend(20)                             # false (y no gasta) si no alcanza
Mission.set_extra_load("lab", 4)              # consumo extra mientras dure (0 para quitarlo)
Mission.generation(); Mission.consumption(); Mission.net(); Mission.hours_to_empty()
```

Paneles, cables, tormentas y los minijuegos del edificio de paneles: **`docs/PANELES_SOLARES.md`**.

## Tormentas (resumen)

Tras 3 sols de protección, 15 % por sol. Aviso ≥ 6 h antes. Leve 12 h −20 % solar, moderada 24 h −45 %,
intensa 48 h −70 %. Con moderada o intensa hay **encierro**: el jugador va a la estación y no puede
salir (salvo que esté de expedición: se queda en la zona y no puede volver hasta que pase).
Mientras dura, la arena ensucia los paneles hora a hora (leve +15, moderada +35, intensa +50 en total); al terminar,
la intensa rompe 4 paneles y corta 2 cables (`docs/PANELES_SOLARES.md`).
**Al terminar se revisan los sistemas dañados** (documento de mecánicas, sección 7): leve → **paneles**;
moderada → paneles e **invernadero** (las papas no crecen hasta repararlo); intensa → paneles, invernadero
y **carro**. Cada reparación **2 h y 10 EU**: `await Mission.repair_system("panels" | "greenhouse" | "rover")`.
Mientras los paneles no se revisan generan un 25 % menos (`storms.unchecked_panels_loss`, propuesta).
Se reparan desde la sección **STORM REPAIRS** de la lista de A.R.I.A. (en la base); el carro también desde
su panel. `Mission.damaged_systems()` dice qué está dañado (`Mission.panels_need_check` para los paneles).

## Cultivo de papas (`Mission.crops`)

Plantar 1 h → regar cada sol (30 min) → 8 sols creciendo (biólogo: más rápido) → cosechar 1 h: 24 papas
(biólogo ×1.25). Sols seguidos sin regar: 1 → −10 %, 2 → −25 %, 3 → −50 %, 4 → muere. El rendimiento
se calcula al cosechar con la peor racha (regar otra vez no lo recupera).

**Planta muerta** (propuesta): se queda seca en las camas y **no se puede quitar ni volver a plantar
hasta que termina su ciclo** (los 8 sols de crecer contados desde la siembra; con el biólogo, 7).
Entonces el paso 3 del invernadero es **limpiar las camas** (1 h, `clear_hours`) y se puede sembrar otra
vez. Mientras la planta muerta ocupa las camas el invernadero **sí se puede apagar** (no es una
plantación activa, y así se ahorran 2 EU/h).

```gdscript
Mission.crops.next_task()        # "plant", "water", "harvest", "clear" o "" (no hay nada que hacer)
await Mission.crops.plant()      # lo llama sembrar.gd al terminar
await Mission.crops.water()      # lo llama regar.gd al terminar
await Mission.crops.harvest()    # lo llama cosechar.gd al terminar (cuando is_ready())
await Mission.crops.clear()      # lo llama cosechar.gd al limpiar la planta muerta (cuando can_clear())
Mission.crops.plant_blocked_reason(); Mission.crops.water_blocked_reason()   # "" o el motivo
Mission.crops.stage()            # 0 sana, 1 débil (−10 %), 2 marchita (−25/−50 %), 3 muerta
Mission.crops.expected_harvest() # papas que daría la cosecha ahora (24 × rendimiento × rol)
Mission.crops.sols_to_harvest(); Mission.crops.sols_to_clear(); Mission.crops.progress()
```

Estado: `planted` (hay plantas, vivas o muertas), `dead`, `age` (sols desde la siembra, cuenta siempre),
`growth` (sols de crecimiento, solo con el invernadero encendido y sin daños), `watered_today`,
`dry_streak`, `worst_dry_streak`, `last_harvest`.

Cómo se ve (`scripts/interiores/estacion_ares1/invernadero.gd`, assets en `invernadero/plantas/`, generados
con `tools/build_plantas.py` a partir de las macetas de `tools/data/interiores/invernadero/`):

| Etapa | Cuándo | Camas de la sala | Tarjeta |
|---|---|---|---|
| — | Nada plantado | Vacías (`camas_vacias.png`) | "BEDS EMPTY" y la última cosecha |
| 0 sana | Siempre regada | Las del fondo | Sol de crecimiento y papas esperadas |
| 1 débil | 1 sol sin regar (−10 %) | `camas_1.png` | ídem con "(−10 %)" |
| 2 marchita | 2 o 3 sols sin regar (−25 / −50 %) | `camas_2.png` | ídem con "(−25 %)" o "(−50 %)" |
| 3 muerta | 4 sols sin regar | `camas_3.png` | Sols que faltan para limpiar |

La tarjeta (abajo a la derecha) usa `maceta_0..3.png` y avisa "Needs water today!". El minijuego de
cosechar (`cosechar.gd`) dibuja las plantas con `planta_<etapa>.png`: se arrastra cada planta hacia arriba
y salen las papas de `expected_harvest()` repartidas entre las 24 (con menos rendimiento algunas no
tienen). Con la planta muerta es el mismo minijuego para limpiar, sin papas.

`Mission.crops` también actualiza **`GameState.greenhouse_step`** (lo usa la guía del día 1):
0 = sembrar, 1 = toca regar hoy, 2 = ya regado, listo para cosechar o planta muerta. Al empezar cada sol
vuelve a 1 si hay que regar. El invernadero decide el paso actual con `next_task()`.

## Investigación y expediciones

Investigación total = AP-1 33.33 % + AP-8 33.33 % + AP-9 33.34 %. Por zona: extraer la muestra (24 h),
llevarla a la base y analizarla en el laboratorio (72 h, +4 EU/h). Solo cuenta cuando el análisis
termina. **El análisis y el taladro trabajan solos**: el jugador puede dormir, comer o hacer otras
cosas mientras tanto.

```gdscript
# Laboratorio (Work Room)
Mission.research.start_analysis()       # "" o el motivo. Analiza la siguiente muestra guardada
Mission.research.percent(); Mission.research.is_analysing(); Mission.research.analysis_progress()

# Antes de salir (en AP-1)
await Mission.expedition.inspect()      # 2 h
await Mission.expedition.maintain()     # 2 h (después de inspeccionar)
await Mission.expedition.repair()       # 2 h y 10 EU, solo si una tormenta intensa lo dañó
await Mission.expedition.load_meals(5)  # 1 h. Máximo 6 comidas
Mission.expedition.departure_problems("AP-8")   # lista de lo que falta (vacía = se puede salir)

# Viajar (ya conectado en world_map.gd)
Mission.expedition.travel_blocked_reason("AP-8")
await Mission.expedition.travel("AP-8")  # 6.5 h fuera; después la escena cambia a la zona

# En la zona
Mission.expedition.mark_zone_panels_clean()   # falta el minijuego de limpiar los paneles de la mini base
Mission.expedition.start_extraction()          # "" o el motivo. 24 h; mientras, dormir en la mini base
Mission.expedition.start_extraction(0.5)       # si el minijuego ya duró 0.5 h reales, se restan
```

Requisitos para salir: carro inspeccionado y con mantenimiento (y reparado), energía suficiente para la
ausencia, hueco para la muestra y ninguna tormenta activa. La comida la decide el jugador (1 a 6 en el
carro): `meals_needed(dest)` es solo la cantidad **recomendada** (3 por sol de viaje); con menos, se pasa
hambre durante la expedición. Ir al mapa y volver a AP-1 sin viajar no cambia nada del carro.
No se puede volver a la base sin la muestra. Al volver, la muestra pasa al laboratorio y la comida
sobrante a la despensa. La muestra de AP-1 se extrae en la base (va directa al laboratorio).

## Puntuación y fin de misión

`P = 10·I + H + (100 − C) + E/10 + F + D` (investigación %, hambre, cansancio, energía, condición física,
sols restantes). `Mission.score()` devuelve cada parte y `total`.

La misión termina (`Mission.mission_over(reason)`, `Mission.end_reason`) con `"complete"` (pasan los 60
sols), `"energy"`, `"hunger"`, `"fatigue"` o `"radiation"`. La pantalla final enseña el motivo y la
puntuación; "BACK TO MENU" llama a `Mission.reset()`.

## Señales

`hour_passed`, `sol_started(sol)`, `storm_warning(type, hours_left)`, `storm_started(type)`,
`storm_ended(type)`, `systems_changed`, `panels_changed`, `crew_changed`, `crops_changed`,
`research_changed`, `expedition_changed`, `activity_started(label, hours)`, `activity_finished(label)`,
`mission_over(reason)`.

## Ventajas de los roles (`data/intro/roles.json -> modifiers`)

Todas son multiplicadores (1.0 = normal) y se leen con `GameState.modifier(clave)`:

| Clave | Significado | Quién |
|---|---|---|
| `repair_speed` | velocidad de reparación y mantenimiento (divide la duración) | Ingeniero 1.25 |
| `energy_drain` | consumo de energía de la base | Ingeniero 0.90 |
| `research_speed` | velocidad del análisis | Astrofísico 1.25 |
| `extraction_speed` | velocidad de extracción | Astrofísico 1.25 |
| `crop_speed` | velocidad de crecimiento de las papas | Biólogo 1.15 |
| `harvest_yield` | papas por cosecha | Biólogo 1.25 |
| `health_recovery` | velocidad del chequeo médico (divide la duración) | Médico 1.5 |
| `medical_energy` | energía del chequeo | Médico 0 |

## Qué falta por conectar (escenas)

| Escena | Qué tiene que llamar |
|---|---|
| ~~Dormitorios (`modulos/dormitorios/`)~~ | **Hecho**: litera → reloj para elegir las horas (1-24) → `await Mission.crew.sleep(h)` (`scripts/interiores/estacion_ares1/dormitorios.gd`). |
| Comer (¿cocina/comedor en la estación?) | `Mission.crew.eat()` (y `eat_blocked_reason()` para el botón). |
| ~~Enfermería (`modulos/enfermeria/`)~~ | **Hecho**: escáner corporal → `await Mission.crew.medical_checkup(horas_jugadas)` (`escaneo.gd`, ver `docs/LABORATORIO_Y_ENFERMERIA.md`). |
| ~~Work Room / laboratorio (`modulos/sala_trabajo/`)~~ | **Hecho**: preparar la muestra de hielo → `Mission.research.start_analysis()` (`analisis.gd`). Falta el paso del microscopio. |
| ~~Invernadero: cosechar~~ | **Hecho**: camas → minijuego de cosechar (`cosechar.gd`) → `await Mission.crops.harvest()`; con la planta muerta, el mismo minijuego → `await Mission.crops.clear()`. |
| ~~Reparaciones tras una tormenta~~ | **Hecho**: sección STORM REPAIRS de la lista de A.R.I.A. (`guide.gd`) → `Mission.repair_system()`. |
| ~~Carro (AP-1)~~ | **Hecho**: al acercarse al carro sale un panel con botones (inspeccionar, mantenimiento, reparar, cargar comida, ir al mapa) que llaman a `Mission.expedition`; cada tarea solo enseña el cartel del tiempo pasando (`scripts/rover_panel.gd`). |
| AP-8 / AP-9 | `scripts/expedition_site.gd`: paneles pequeños (limpiar con el ratón, `zone_panels_clean.gd`) → `mark_zone_panels_clean()`; excavadora → minijuego del taladro (cada zona distinta) → `start_extraction()`; carro (`zone_rover_panel.gd`): comer, dormir y volver con la muestra. Suelo y posiciones: `tools/build_sites.py`. |
| ~~Excavadora (AP-1)~~ | **Hecho**: el minijuego de extracción de hielo llama a `start_extraction(horas_jugadas)` (ver `docs/EXCAVADORA.md`). |

## Atajos de prueba (solo ejecutando desde el editor, con la misión en marcha)

| Tecla | Qué hace | Tecla | Qué hace |
|---|---|---|---|
| Ctrl+1 | Tormenta ya (leve → moderada → intensa) | Ctrl+6 | Comer |
| Ctrl+2 | +1 hora | Ctrl+7 | Chequeo médico |
| Ctrl+3 | +1 sol | Ctrl+8 | Ejercicio |
| Ctrl+4 | Suciedad y daños de tormenta intensa | Ctrl+9 | Guarda una muestra de AP-1 en la base (para probar el laboratorio) |
| Ctrl+5 | Dormir 8 h | Ctrl+0 | Imprime todo el estado en la consola (`Mission.debug_text()`) |

## Decisiones sobre el documento

**Se usan los valores explícitos de cada sección.** La tabla "Resumen de valores para programación" del
final del documento **no cuenta** (tiene cifras que contradicen las secciones).

Confirmadas por el equipo (`_decision` en `rules.json`):

1. **Radiación:** +1/h dentro y +4/h fuera (sección 4); solo el chequeo médico la baja (−30).
2. **Ejercicio:** +20 de condición física por sesión (sección 6).
3. **Extracción:** el taladro trabaja solo y mientras tanto se puede dormir en la mini base (si no, las
   24 h despierto subirían el cansancio +96 y la misión terminaría).
4. **Radiación de las expediciones:** se queda como está (ir y volver de AP-8 suma ~52 solo en el viaje:
   conviene hacerse un chequeo antes de salir).
5. **Comida:** la despensa empieza con 30 comidas.
6. **Auxiliares apagados:** no se puede entrar a la estación principal (Ares 1). El edificio de paneles
   (con la Power Room, donde se vuelven a encender) sigue accesible.

Propuestas nuestras donde el documento no dice nada (`_proposed`, se pueden cambiar):

- Huecos de la tabla del hambre (61-69, 31-39, 1-9): se usa la fila de abajo.
- Cada papa cosechada es 1 comida.
- Invernadero dañado por una tormenta: las papas no crecen hasta repararlo (2 h, 10 EU).
- Papas muertas: se quedan en las camas hasta que termina su ciclo (8 sols desde la siembra); luego se
  limpian (1 h) para volver a plantar. Con la planta muerta el invernadero se puede apagar.
- Viaje entre AP-8 y AP-9: se suman las dos idas, como si se pasara por la base.
- Las actividades adelantan el reloj en unos segundos (no 1 min real por hora).
- El análisis y la extracción fijan su duración al empezar, con las penalizaciones de ese momento.
- Los paneles empiezan cubiertos de polvo (suciedad 100) y 3 rotos por la tormenta del aterrizaje.
- Generación proporcional: máximo × paneles que funcionan / total × limpieza / 100.
- Efecto de cada tormenta en los paneles (leve y moderada ensucian, intensa ensucia y rompe), y ráfagas del minijuego de paneles (`docs/PANELES_SOLARES.md`).
