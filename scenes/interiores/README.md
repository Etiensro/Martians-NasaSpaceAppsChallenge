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

`laboratorio`, `invernadero`, `cocina`, `dormitorios`, `enfermeria`, `criogenia` (las 4 cápsulas), `oxigeno`.

`estacion_ares1.tscn` es la entrada (la esclusa): desde ahí se puede ir a los módulos.

## Reglas para que todo siga funcionando

1. **No cambies el nombre ni la ruta** de las tres escenas de entrada (`estacion_ares1.tscn`,
   `paneles_solares.tscn`, `excavadora.tscn`): son las que abren las puertas del mapa.
   Si hace falta cambiarlas, se cambian también en `tools/build_colony.py` (campo `"interior"`)
   y se vuelve a ejecutar `python tools/build_colony.py`.
2. **Para salir al mapa** usa lo mismo que las escenas actuales (`scripts/interior.gd`):
   ```gdscript
   var gs := get_node_or_null("/root/GameState")
   get_tree().change_scene_to_file(gs.return_scene if gs and gs.return_scene != "" else "res://scenes/ap1_zone.tscn")
   ```
   Así el personaje aparece delante de la puerta por la que entró.
3. **El personaje elegido** está en `GameState.selected_role`; su sprite con `GameState.frames_for()`
   y su retrato con `GameState.portrait_for(GameState.selected_role)`.
4. Para ir a un módulo de la estación: `get_tree().change_scene_to_file("res://scenes/interiores/estacion_ares1/modulos/cocina/cocina.tscn")` (por ejemplo).

Ahora mismo las tres escenas son provisionales (pantalla con el nombre y "E o Esc: salir").
