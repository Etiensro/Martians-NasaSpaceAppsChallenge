# Laboratorio (Work Room) y enfermería

Los dos módulos de la estación que usan las reglas de investigación y de radiación del autoload
`Mission` (ver `docs/SISTEMAS_DE_MISION.md`).

## Cómo se llega

```
estacion_ares1.tscn ──WORK ROOM──▶ modulos/sala_trabajo/sala_trabajo.tscn ──BIOSAFETY CABINET──▶ analisis.tscn
                    │                                                   └──MICROSCOPE──▶ "Coming soon" (falta)
                    └──INFIRMARY──▶ modulos/enfermeria/enfermeria.tscn  ──BODY SCANNER──▶ escaneo.tscn
```

Los dos cuartos son vestíbulos con `scripts/interiores/lobby.gd` (zonas para hacer clic). Su imagen y su
`hub.json` los genera `tools/build_lobbies.py`. La flecha de salida vuelve al centro de la estación
(`exit_scene` en el `.tscn`). Los minijuegos vuelven a su cuarto.

## Laboratorio: preparar una muestra de hielo (`scripts/interiores/estacion_ares1/analisis.gd`)

Solo se puede jugar con una muestra guardada en la base (`Mission.research.stored`) y sin otro análisis
en marcha. Si no, sale "WAITING FOR SAMPLE..." con el motivo. Para probarlo desde el editor: **Ctrl+9**
guarda una muestra de AP-1.

| Paso | Qué hace el jugador | Por qué (ciencia real) |
|---|---|---|
| 1. TRANSFER | Arrastra cada trozo de hielo con las **pinzas** de la caja al matraz. Si lo suelta fuera: "DO NOT DROP THE ICE!", baja la calidad y el trozo vuelve a la caja. | Todo se hace dentro de la **cabina de bioseguridad** y con pinzas estériles: la muestra no se toca con las manos para no contaminarla con microbios de la Tierra (protección planetaria). |
| 2. HEAT | Mantiene pulsado para calentar y suelta para enfriar. Termómetro: azul (no se derrite), **verde** (se derrite), amarillo (más rápido, con riesgo), rojo (hierve: "WARNING!", y si sigue: "FAILED"). | El hielo se derrite con **calor suave**. Si hierve, se destruyen las moléculas orgánicas o los posibles microbios que se buscan. |
| 3. POUR | Lleva el matraz a la caja de Petri estéril y mantiene pulsado para verter. Si vierte fuera, se derrama y baja la calidad. | El agua de deshielo pasa a un recipiente estéril para analizarla. |
| Final | "WELL DONE!" y empieza el análisis de 72 h (`Mission.research.start_analysis()`, +4 EU/h). | El analizador del laboratorio estudia el agua; la zona cuenta para la investigación cuando termina. |

- **Calidad de la muestra** (barra arriba a la izquierda): baja al soltar hielo, hervir o derramar.
  Si llega a 0, hay que empezar de nuevo.
- Si hierve, se repite solo el calentamiento.
- Los números del minijuego están en las constantes del principio de `analisis.gd`. No son reglas de la
  misión: son de dificultad del minijuego.

### Propuesta para hacerlo más real (falta el arte)

Un **paso 4 de microscopio**: poner una gota en un portaobjetos y mirar por el microscopio del
laboratorio (el cuarto ya tiene la zona "MICROSCOPE"). El jugador enfoca girando una rueda hasta que
la imagen se ve nítida y marca lo que encuentra: granos de mineral, burbujas, ¿algo vivo? Es lo que
hacen los astrobiólogos con el hielo de Marte, y enseña que "buscar vida" es mirar con mucho cuidado.

## Enfermería: escáner corporal (`scripts/interiores/estacion_ares1/escaneo.gd`)

El astronauta (el sprite del rol elegido, sin casco) está sobre la plataforma SCAN-MO-TRON 2000. Al
hacer clic:

1. Si no hay energía para el chequeo (`Mission.crew.checkup_blocked_reason()`), la plataforma se pone
   roja, aparece el aviso y A.R.I.A. explica el motivo.
2. Si la hay, el rayo verde recorre el cuerpo durante 6 s (lo que dice la pantalla), la barra se llena
   y sale "SCAN COMPLETED!".
3. Se aplica el chequeo de la misión: `Mission.crew.medical_checkup(horas_ya_jugadas)`. Cuesta 20 EU
   (el médico: 0), dura 4 h con penalizaciones (el médico: más rápido) y baja la radiación 30. El reloj
   adelanta lo que falta de las 4 h.
4. La pantalla dice "HEALTHY" o "HIGH RADIATION", y arriba a la izquierda sale "Radiation 66 → 41" con
   la energía usada. La radiación final incluye la que sube mientras dura el chequeo (+1/h dentro).

## Assets

Fuentes en `tools/data/interiores/sala_trabajo/` y `tools/data/interiores/enfermeria/` (hojas de Gemini
con fondo magenta). `python tools/build_lab_medico.py [--preview]` recorta cada sprite (en
`assets/interiores/estacion_ares1/sala_trabajo/lab/` y `.../enfermeria/scan/`). Las coordenadas de
cada sprite (puntos que caen sobre él) están en `LAB_SHEETS` y `MED_SHEETS`. El fondo magenta se quita
con `magenta_to_alpha()` de `tools/imgutil.py`, que deja el vidrio y el vapor semitransparentes.

`plate_beaker_off.png` (matraz vacío sobre la parrilla apagada) no viene en la hoja: se arma en el
script oscureciendo la resistencia del matraz con la parrilla encendida.

### Pendientes (ahora son provisionales)

Pedir con **fondo magenta liso (#FF00FF)** como el resto, en el mismo estilo pixel art:

| Para | Qué falta | Ahora |
|---|---|---|
| Laboratorio | Fondo del minijuego: **interior de la cabina de bioseguridad visto de frente** (mesa de trabajo, cristal arriba, guantes a los lados), 16:9, sin objetos sueltos. | La sala completa oscurecida. |
| Laboratorio | **Termómetro** vertical de laboratorio con escala (azul, verde, amarillo, rojo) y su aguja por separado. | Dibujado por código. |
| Laboratorio | **Matraz con agua derretida sobre la parrilla, sin vapor ni burbujas** (el calentamiento correcto). | Se pasa directo a servir. |
| Laboratorio | **Contenedor de muestra sellado** (cerrado y abierto) para un paso 0 de "abrir la muestra dentro de la cabina". | No hay paso 0. |
| Laboratorio | Paso del **microscopio**: portaobjetos, gota, vista por el ocular (borrosa y nítida) y 3 o 4 "hallazgos" (grano de mineral, burbuja, microfósil). | Zona "Coming soon". |
| Laboratorio | Letrero "TEMPERATURE" (como los de la hoja de textos). | No se usa. |
| Enfermería | La pantalla SCAN-MO-TRON trae **HEIGHT** impreso. O se añade la estatura de cada rol (`"height": "5' 9\""` en `data/intro/roles.json`), o se pide la pantalla con **RADIATION** en lugar de HEIGHT. | Muestra "--". |
| Enfermería | La pantalla del progreso trae **"6s"** impreso: si se quiere una cuenta atrás, pedir el marco sin texto. | Fijo. |

Prompt base (Gemini): *"16-bit pixel art, <objeto>, same style as a cozy sci-fi Mars base game,
crisp pixels, limited palette, no text, centered on a solid flat magenta background (#FF00FF)."*
