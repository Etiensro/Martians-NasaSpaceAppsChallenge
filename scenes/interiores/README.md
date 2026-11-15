# Interiores de AP-1 (Base Ares 1)

Cada edificio de la colonia en el que se puede entrar con **E** tiene su carpeta.
Aquí cada quien arma el escenario de su edificio.

| Edificio en el mapa | Escena que se abre al entrar | Imágenes / sonidos | Scripts |
|---|---|---|---|
| Estación Ares 1 (rampa con poste de luz) | `scenes/interiores/estacion_ares1/estacion_ares1.tscn` | `assets/interiores/estacion_ares1/` | `scripts/interiores/estacion_ares1/` |
| Paneles solares (módulo de control) | `scenes/interiores/paneles_solares/paneles_solares.tscn` | `assets/interiores/paneles_solares/` | `scripts/interiores/paneles_solares/` |
| Excavadora de hielo (cabina) | `scenes/interiores/excavadora/excavadora.tscn` | `assets/interiores/excavadora/` | `scripts/interiores/excavadora/` |

La nave espacial es decoración: no tiene interior.

## Estación Ares 1: módulos

La estación tiene varios módulos. Cada uno tiene su carpeta para su escena en
`scenes/interiores/estacion_ares1/modulos/` y para sus imágenes en
`assets/interiores/estacion_ares1/`:

`sala_trabajo` (Work Room), `invernadero`, `gimnasio`, `enfermeria`, `dormitorios`.

`estacion_ares1.tscn` es la entrada: un menú en primera persona donde se elige con el cursor a qué módulo ir o la flecha EXIT para salir a AP-1.

## Reglas para que todo siga funcionando

1. **No cambies el nombre ni la ruta** de las tres escenas de entrada (`estacion_ares1.tscn`,
   `paneles_solares.tscn`, `excavadora.tscn`): son las que abren las puertas del mapa.
   Si hace falta cambiarlas, se cambian también en `tools/build_colony.py` (campo `"interior"`)
   y se vuelve a ejecutar `python tools/build_colony.py`.
2. **Cada interior hereda de `scenes/interiores/interior_base.tscn`** (fondo, título y salida
   con E o Esc ya hechos). Para uno nuevo: *Escena → Nueva escena heredada* y cambiar `title`.
3. **Para salir a la zona** usa `GameState.leave_building()`: el personaje aparece delante de la
   puerta por la que entró.
4. **El personaje elegido** está en `GameState.selected_role`; su sprite con `GameState.frames_for()`
   y su retrato con `GameState.portrait_for(GameState.selected_role)`.
5. **Para cambiar de escena** usa siempre `SceneChanger.go_to("res://...tscn")` (hace el fundido).
   Por ejemplo, para ir a un módulo de la estación:
   `SceneChanger.go_to("res://scenes/interiores/estacion_ares1/modulos/sala_trabajo/sala_trabajo.tscn")`.

Ahora mismo las tres escenas son provisionales (pantalla con el nombre y "E or Esc: exit").

## Paneles solares: vestíbulo y minijuegos

`paneles_solares.tscn` es un vestíbulo en primera persona (como el de la estación) con dos lugares:
**SOLAR FIELD** (campo de paneles, afuera) y **POWER ROOM** (sala eléctrica). Cada uno abre su minijuego:

- `scenes/interiores/paneles_solares/minijuegos/campo_solar/campo_solar.tscn`
- `scenes/interiores/paneles_solares/minijuegos/sala_electrica/sala_electrica.tscn`

Mientras no existan, la puerta dice "Coming soon". Al terminar un minijuego, vuelve al vestíbulo con
`SceneChanger.go_to("res://scenes/interiores/paneles_solares/paneles_solares.tscn")`.

Los vestíbulos usan `scripts/interiores/lobby.gd`; sus imágenes, puertas y efectos se generan con
`python tools/build_lobbies.py`.
