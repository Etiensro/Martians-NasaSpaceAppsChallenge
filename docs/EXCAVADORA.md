# Excavadora de hielo: extracción de la muestra de AP-1

## Escenas

| Escena | Script | Qué es |
|---|---|---|
| `scenes/interiores/excavadora/excavadora.tscn` | `scripts/interiores/lobby.gd` | Vestíbulo (cabina). Su única puerta es la consola **ICE DRILL CONTROL**. Imagen y zonas: `excavadora` en `tools/build_lobbies.py` (fuente `tools/data/interiores/excavadora_hub_gemini.jpg`) |
| `scenes/interiores/excavadora/minijuegos/extraccion_hielo/extraccion_hielo.tscn` | `scripts/interiores/excavadora/extraccion_hielo.gd` | Minijuego: cámara del rover en el campo de hielo, de perfil |

El rover se maneja **a distancia** desde la consola, así que el jugador sigue dentro (radiación de interior).

## Cómo se juega

- **A/D o flechas**: mover el rover. Si la broca está abajo, primero se sube.
- **Mantener Espacio o el clic**: taladrar. La broca baja por la tierra y deja un agujero.
- Al tocar un **depósito de hielo** la broca se para y lo va agrietando: entero → grieta 1 → grieta 2 → partido → esquirlas.
  Al romperse suma hielo: pequeño 20, mediano 30 y grande 45. Hay 4 depósitos (125 de hielo) colocados al azar.
- **Calor**: sube al taladrar (20/s en tierra, 28/s en hielo) y baja al soltar (32/s). Si llega a 100 la broca se
  **sobrecalienta** y no taladra hasta bajar a 35. Así que hay que soltar a tiempo.
- Con el medidor de hielo al 100 % se asegura el núcleo y se llama a
  `Mission.expedition.start_extraction(horas_jugadas)`: el taladro trabaja solo 24 h (tarea `excavation`)
  **menos lo que ya duró el minijuego** (1 min real = 1 h). Al terminar, la muestra de AP-1 va directa al laboratorio.
- Salir antes (Esc o la flecha) no guarda nada.
- Si ya se tiene la muestra de AP-1 o el taladro está trabajando, la consola no deja entrar y enseña el motivo
  (`Mission.entry_blocked_reason`, que usa `Mission.expedition.extract_blocked_reason()`).

Los números del minijuego (velocidades, calor, hielo de cada depósito) son constantes al principio de
`extraccion_hielo.gd`. Las 24 h de la extracción están en `data/mission/rules.json` (`research.extraction_hours`).

## Assets (`assets/interiores/excavadora/extraccion_hielo/`)

Los hizo el equipo: pixel art a resolución nativa con fondo transparente. El recorte de cada sprite está en `sprites.json`.
La escena dibuja todo a 384×216 y lo escala ×3 dentro del marco de la cámara (1152×648).

| Archivo | Uso |
|---|---|
| `fondo_hielo_nativo.png` | Fondo (384×216). El suelo está en y = 100 |
| `rover.png` | Rover 80×64, 6×4 cuadros: avanzar, retroceder, taladrar a la derecha y a la izquierda |
| `broca_vertical.png` | Broca bajo tierra (4 cuadros). Encima se dibuja el tubo cuando baja más de 48 px |
| `hielo_depositos.png` | Depósitos (3 tamaños × 5 estados) |
| `hielo_esquirlas.png` | Partículas al taladrar y romper hielo |
| `efectos.png` | Polvo (moverse o taladrar tierra), chispas (sobrecalentamiento o roca madre) y destello (hielo roto) |
| `ui.png` | Medidores de hielo y calor con sus iconos. **El interior del marco es opaco**, así que el relleno se dibuja encima (no detrás, como decía el LEEME original) |

Del ZIP original no se usan `taladro.png` (broca horizontal) ni `fondo_hielo.png` (es el mismo fondo ×5).
