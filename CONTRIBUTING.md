# Cómo contribuir

Antes de cambiar código, lee `docs/GUIA_DEL_PROYECTO.md` (estructura, módulos y herramientas).

## Ramas (git flow)

| Rama | Para qué | Sale de | Se une a |
|---|---|---|---|
| `main` | Versión estable, la que se presenta. Nadie trabaja directo aquí | — | — |
| `develop` | Integración: aquí se juntan las funciones terminadas | `main` | `main` (en cada release) |
| `feature/<nombre>` | Una función o cambio nuevo (`feature/menu-inicial`, `feature/interior-cocina`) | `develop` | `develop` |
| `release/<versión>` | Preparar una entrega (solo arreglos y textos) | `develop` | `main` y `develop` |
| `hotfix/<nombre>` | Arreglo urgente de algo que ya está en `main` | `main` | `main` y `develop` |

Flujo de trabajo de cada cambio:

```bash
git checkout develop
git pull
git checkout -b feature/mi-cambio
# ... trabajar y hacer commits pequeños ...
git push -u origin feature/mi-cambio
# abrir un Pull Request hacia develop; otra persona lo revisa antes de unirlo
```

- Una rama por tarea; ramas cortas (unir pronto evita conflictos).
- Antes de abrir el PR: `git pull origin develop` en tu rama y prueba el juego completo en Godot.
- Nombres de rama en minúsculas y con guiones.

## Mensajes de commit

`tipo: descripción corta en presente`, con tipo uno de:
`feat` (función nueva), `fix` (arreglo), `refactor` (reorganizar sin cambiar lo que hace),
`art` (assets), `docs` (documentación), `chore` (configuración, limpieza).

Ejemplo: `feat: selección de personaje con retratos`.

## Reutiliza antes de escribir

- **Cambiar de escena**: siempre `SceneChanger.go_to("res://...tscn")`. Nunca `change_scene_to_file` directo.
- **Rutas de escenas y estado global**: `GameState` (`WORLD_MAP`, `BASE_ZONE`, `GAMEPLAY_SCENE`, `site_scene()`).
  Es un autoload: úsalo directamente, sin `get_node_or_null("/root/GameState")`.
- **Rol del jugador**: `GameState.selected_role`, `role_data`, `frames_for()`, `portrait_for()`, `role_color()`,
  `first_name()`, `modifier()`. Los roles ya están cargados en `GameState.roles`: no vuelvas a leer `roles.json`.
- **Entrar/salir de edificios**: `GameState.enter_building()` / `GameState.leave_building()`.
- **Tiempo, energía, hambre, cansancio, radiación, ejercicio, cultivos, investigación, expediciones y
  tormentas**: autoload `Mission` y sus módulos (`Mission.crew`, `Mission.crops`, `Mission.research`,
  `Mission.expedition`). Una tarea que dura horas se hace con `await Mission.run_task(...)`, nunca
  sumando tiempo a mano. Los números están en `data/mission/rules.json`. Ver `docs/SISTEMAS_DE_MISION.md`.
- **Vestíbulo en primera persona con puertas**: `scripts/interiores/lobby.gd` (+ `tools/build_lobbies.py`).
- **Moverse y animar personajes**: `scripts/core/movement.gd`.
- **Colores, botones, etiquetas, avisos "E: ..."**: `scripts/core/style.gd`.
- **Partículas y texturas de efectos**: `scripts/core/fx.gd`.
- **Herramientas de Python**: funciones de imagen comunes en `tools/imgutil.py`.
- **Escenas parecidas**: hereda (*Nueva escena heredada*) de `scenes/zone_base.tscn` o
  `scenes/interiores/interior_base.tscn` en lugar de copiar una escena.

## Convenciones

- Texto que ve el jugador: inglés. Comentarios y documentación: español.
- Los assets que genera `tools/` no se editan a mano: se cambia la fuente o el script y se regenera.
- Datos editables (diálogos, roles, edificios, sitios) en JSON, no dentro del código.
- Si una función sirve para más de un script, va en `scripts/core/`.
- Al terminar, busca si quedaron funciones, archivos o escenas que ya nadie usa y bórralos.
