# Martians · Misión Ares 1 — Guía del proyecto

Reglas de trabajo en equipo (ramas, commits, qué reutilizar): `CONTRIBUTING.md`.

Godot 4.7 (GL Compatibility), 1280×720, pixel art con filtro "nearest".
Todo el texto que ve el jugador está en **inglés**; comentarios y documentación, en español.

## Flujo del juego

```
scenes/intro/main_menu.tscn ──START──▶ scenes/intro/base_interior.tscn ──elige rol──▶ scenes/world_map.tscn
                                                                                       │ clic en un sitio
                                                                                       ▼
                           scenes/interiores/*  ◀──E (puerta)── scenes/ap1_zone.tscn / ap8 / ap9  ──Esc──▶ mapa
```

## Autoloads (existen en todas las escenas)

| Nombre | Archivo | Para qué |
|---|---|---|
| `GameState` | `scripts/game_state.gd` | Roles y tripulación (`roles`, `selected_role`, `frames_for()`, `portrait_for()`, `role_color()`, `first_name()`, `modifier()`), sitio elegido, rutas de escenas (`WORLD_MAP`, `BASE_ZONE`, `GAMEPLAY_SCENE`, `site_scene()`), entrar/salir de edificios (`enter_building()`, `leave_building()`) |
| `SceneChanger` | `scripts/core/scene_changer.gd` | **Único** sitio donde se cambia de escena: `SceneChanger.go_to(ruta)` (con fundido a negro) |

## Módulos compartidos (`scripts/core/`)

Se usan con `const X := preload("res://scripts/core/x.gd")`.

| Módulo | Qué tiene |
|---|---|
| `movement.gd` | `input_vector()` (WASD/flechas), `is_running()`, `facing_of(dir)`, `slide()` (moverse esquivando obstáculos), `animate(sprite, "walk", facing, face_left)`, `walk_to()` (caminar solo hasta un punto) |
| `style.gd` | Colores (`NAVY`, `AMBER`, `CYAN`, `DUST`…), `box()`, `style_button()`, `label()`, `world_hint()` |
| `fx.gd` | Texturas de efectos (`GLOW`, `GLINT`, `DUST`, `STREAK`, `PUFF`) y `particles()`, `ramp()`, `grow()` |

## Carpetas

| Carpeta | Contenido |
|---|---|
| `scenes/` | `zone_base.tscn` (zona genérica) y `ap1/ap8/ap9_zone.tscn` que la **heredan**; `world_map.tscn`; `astronaut.tscn`, `rover.tscn`, `robot.tscn` |
| `scenes/intro/` | Menú + cinemática y el interior con diálogo, selección de rol y criosueño |
| `scenes/interiores/` | `interior_base.tscn` y los interiores que la heredan (ver su README) |
| `scripts/` | Un script por escena o personaje (mismo nombre que su escena cuando se puede) |
| `scripts/core/` | Lo compartido (ver arriba) |
| `scripts/intro/` | Solo lo de la intro |
| `data/intro/` | `intro_dialogue.json` (diálogos) y `roles.json` (profesiones) |
| `assets/` | Imágenes y recursos que usa el juego. **Casi todo lo genera `tools/`**: no se editan a mano |
| `tools/` | Scripts de Python que convierten las imágenes de Gemini/NASA en assets (Godot ignora esta carpeta) |

## Zonas

`fixed_zone.gd` (raíz) coloca la cámara, limita por dónde se camina y pone al jugador en su sitio.
`zone_area.gd` (nodo "Zona") es el suelo: dice qué celdas se pueden pisar (`is_walkable`).
En AP-1, `colony.gd` coloca los edificios y el vehículo (`building.gd`) y los efectos, leyendo
`assets/buildings/colony.json`.

Zona nueva: *Escena → Nueva escena heredada* de `zone_base.tscn`, cambiar la textura de "Zona" y el
texto de "HUD/Titulo", y guardarla como `scenes/apN_zone.tscn` (así `GameState.site_scene("AP-N")` la encuentra).

## Herramientas (`tools/`)

Requieren `pip install numpy pillow`. Se ejecutan desde la raíz del proyecto: `python tools/build_X.py`.

| Script | Genera |
|---|---|
| `imgutil.py` | (no se ejecuta) funciones compartidas: quitar fondo, encontrar sprites, reducir, paleta, escribir SpriteFrames |
| `build_character.py` | Personajes: `assets/characters/<id>.png` + `<id>_frames.tres` |
| `build_rover.py` | Rover: `assets/vehicles/` |
| `build_portraits.py` | Retratos con y sin casco: `assets/characters/portraits/` |
| `build_world_map.py` | Mapa general, iconos, títulos y `world_sites.json` (los textos de los sitios se cambian aquí) |
| `build_zones.py` | Suelos de AP-1, AP-8 y AP-9 |
| `build_colony.py` | Edificios de AP-1, suelo de la colonia, colisiones y `colony.json` (ejecutar después de `build_zones.py`) |
| `build_fx.py` | Texturas de efectos de `assets/fx/` |

## Editar textos

- Diálogos: `data/intro/intro_dialogue.json`. Eventos por línea: `alarm_on`, `alarm_off`, `shake`, `lights_dim`.
  `{player}` y `{player_role}` se cambian solos. Si el JSON tiene un error, la intro se salta a la selección.
- Profesiones: `data/intro/roles.json` (nombre, color, ventajas, dato curioso, multiplicadores).
- Sitios del mapa: diccionario `SITES` de `tools/build_world_map.py` y volver a ejecutarlo.
- Nombres de edificios: `BUILDINGS` de `tools/build_colony.py` y volver a ejecutarlo.

## Marca NASA Space Apps (menú principal)

Sigue la guía oficial: https://www.spaceappschallenge.org/brand/

| Qué | Dónde |
|---|---|
| Logo (solo el de NASA Space Apps; **no** se usan logos oficiales de NASA) | `assets/ui/logo_space_apps.png` (versión horizontal blanca, del ZIP oficial) |
| Fuentes: Fira Sans Black (títulos) y Overpass (texto y botones), licencia OFL | `assets/fonts/` |
| Colores, `brand_title()`, `brand_label()`, `brand_button()`, `brand_gradient()` | `scripts/core/style.gd` (sección "marca NASA Space Apps") |
| Fondo del menú | La colonia de AP-1 (`colony.gd`), sin jugador ni puertas |
| Interior de la base (1280×720) | Inspector del nodo raíz de `base_interior.tscn` (`Room Texture`) |

## Exportar

Los `.json` se leen con `FileAccess`: en el preset de exportación añade `*.json` en
"Filters to export non-resource files".
