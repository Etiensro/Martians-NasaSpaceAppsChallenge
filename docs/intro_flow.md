# Intro de Misión Ares 1 (menú → cinemática → diálogo → selección → criosueño)

Escena inicial del proyecto: `res://scenes/intro/main_menu.tscn` (ya configurada como *main scene*).

| Paso | Escena / script | Qué pasa |
|---|---|---|
| 1. Menú | `scenes/intro/main_menu.tscn` → `scripts/intro/main_menu.gd` | Base vista desde arriba, viento y polvo, logos, título, START MISSION y VIEW REPOSITORY |
| 2. Cinemática | mismo script (`_on_start`) | UI se desvanece, franjas de cine, la cámara se aleja hacia la tormenta, fundido a negro. Esc/Espacio/clic la saltan |
| 3. Diálogo | `scenes/intro/base_interior.tscn` → `base_interior.gd` + `dialogue_box.gd` | A.R.I.A. da la alerta, la tripulación decide que 3 duermen. Textos en `data/intro/intro_dialogue.json` |
| 4. Selección | `role_select.gd` | 4 tarjetas con las ventajas de cada rol (`data/intro/roles.json`) |
| 5. Cierre | `base_interior.gd` (`_sleep_sequence`, `_final_shot`) | Los otros 3 entran en las cápsulas; se cambia a `GameState.GAMEPLAY_SCENE` |

## Para el equipo de jugabilidad

Al terminar la intro, el autoload `GameState` contiene:

```gdscript
GameState.selected_role          # "engineer" | "biologist" | "medic" | "astrophysicist"
GameState.role_data              # el bloque de roles.json de ese rol (title, crew_name, perks, modifiers...)
GameState.crew                   # [{role, name, state: "awake" | "cryo"}, ...]
GameState.modifier("repair_speed")  # multiplicador de la ventaja (1.0 si el rol no la tiene)
```

Modificadores disponibles (en `roles.json`): `repair_speed`, `energy_drain`, `oxygen_drain`,
`health_recovery`, `research_gain`, `storm_warning`. Se pueden cambiar sin tocar código.

La escena de destino se cambia en una sola línea: `GAMEPLAY_SCENE` en `scripts/game_state.gd`
(ahora apunta a `world_map.tscn`).

## Cambiar textos

- Diálogos: `data/intro/intro_dialogue.json`. Eventos por línea: `alarm_on`, `alarm_off`, `shake`, `lights_dim`.
  `{player}` y `{player_role}` se sustituyen por el nombre y rol elegidos.
- Roles: `data/intro/roles.json` (nombre, color del traje, ventajas, dato curioso, modificadores).

## Enchufar arte final (todo lo actual es provisional, dibujado por código)

| Qué | Dónde |
|---|---|
| Logos NASA / Space Apps | Guardar como `assets/ui/logo_nasa.png` y `assets/ui/logo_space_apps.png` (aparecen solos) |
| Logo del juego | `title_texture` en el nodo raíz de `main_menu.tscn` |
| Fuente pixel | `title_font` en `main_menu.tscn` |
| Base vista desde arriba | `base_texture` en `scripts/intro/base_exterior.gd` |
| Suelo del menú | `ground_texture` en `main_menu.tscn` (ahora usa `assets/zones/ap1_ground.png`) |
| Interior de la base (1280x720) | `room_texture` en `scripts/intro/interior_room.gd` |
| Astronautas por rol | Hoy se reutiliza `astronaut_frames.tres` y `suit_tint.gdshader` cambia el color del traje. Con sprites propios, quitar el material |

Las imágenes de Gemini (2400x1792) conviene reducirlas antes de importarlas (p. ej. con los scripts de `tools/`)
para que todos los píxeles tengan el mismo tamaño en pantalla.

## Exportar

Los `.json` de `data/` se leen con `FileAccess`: en el preset de exportación añade `*.json` en
"Filters to export non-resource files" (igual que `assets/world/world_sites.json`).
