# Finales de la misión

**Siempre se regresa a la Tierra.** La nave de regreso espera en órbita y el **sol 60 es la última
ventana de lanzamiento**, no la única: si la ciencia termina antes, Control de Misión manda a la
tripulación a casa en ese momento. Así lo que manda es el tiempo (como en una misión real, la fecha la
ponen las órbitas) y el juego no obliga a seguir jugando cuando ya no queda nada que hacer. La fórmula
del documento lo premia: `D = sols restantes` solo suma si se termina antes del sol 60. **D solo cuenta
en la victoria**: en una evacuación vale 0 (si no, rendirse pronto daría más puntos que aguantar).

## Cuándo termina y qué final sale

| `Mission.end_reason` | Cuándo | Final | Tono (`mood`) |
|---|---|---|---|
| `research` | Termina el análisis de la última zona (100 %) | **Victoria**: "SCIENCE COMPLETE!" | `victory` |
| `complete` | Empieza el sol 61 sin el 100 % | **Regreso**: "TIME TO GO HOME" | `calm` |
| `energy`, `hunger`, `fatigue`, `radiation` | Batería a 0 o una barra al límite | **Evacuación**: "EMERGENCY RETURN" | `emergency` (alarma) |

Nadie "muere" ni "pierde": en una evacuación Control de Misión lleva a la tripulación a casa para
cuidarla, y la pantalla final da un consejo para la próxima vez.

La **medalla** depende de las zonas analizadas (cada una vale 33.33 %), en cualquier final:
oro 3, plata 2, bronce 1 e insignia "SAFE RETURN" sin ninguna.

## La secuencia

1. **Mensaje de Control de Misión** (`mission_hud.gd`, `show_end()`): la escena se congela y sale el mensaje
   con el título y el texto del final. Botón "WAKE UP THE CREW".
2. **Despertar a la tripulación** (`scenes/finales/despertar.tscn`): la sala de criosueño de la intro
   (`scripts/intro/interior_room.gd`) con los 3 compañeros congelados. Se hace clic en cada cápsula: se
   derrite el hielo, sale el tripulante y dice una frase (`wake_lines`). En la victoria celebran; en la
   evacuación suena la alarma.
3. **Despegue** (`scenes/finales/despegue.tscn`): la colonia de AP-1 con su nave. Cuenta atrás, fuego,
   humo y la nave sube con sus luces.
4. **Viaje y llegada** (`scenes/finales/tierra.tscn`): la nave va de Marte a la Tierra y sale la tarjeta
   final: medalla, las 3 zonas (en color las investigadas), texto de llegada, puntuación
   (`Mission.final_score`, calculada al terminar) y consejo. "BACK TO MENU" llama a `Mission.reset()`.

## Dónde se cambia cada cosa

| Qué | Dónde |
|---|---|
| Textos (título, mensaje, llegada, consejo), medallas y frases al despertar | `data/mission/endings.json` |
| Cuándo termina | `Mission.end_mission(reason)`; la victoria la llama `research.gd` al completar la última zona |
| Datos del final para las escenas | `scripts/finales/final.gd` (`reason()`, `mood()`, `medal()`, `fill()`) |
| Nave en vuelo (sin la sombra de la plataforma) | `tools/build_nave_vuelo.py` → `assets/buildings/nave_vuelo.png` |
| Probar un final | Ctrl+E desde el editor con la misión en marcha (cada vez sale otro motivo) |

## Arte que falta (ahora dibujado con código, provisional)

- **Marte y la Tierra** del viaje (`tierra.gd`, `_planet()`): dos planetas en pixel art, con fondo transparente.
- **Medallas** de oro, plata, bronce y la insignia "safe return" (`tierra.gd`, `_draw_medal()`).
- **Fondo de estrellas** (`tierra.gd`, `_draw()`), opcional.
- La sala de criosueño de la intro también es provisional (`interior_room.gd`); si se cambia, el
  despertar la usa igual.
