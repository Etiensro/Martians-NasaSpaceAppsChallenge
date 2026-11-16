extends SceneTree
## Saca capturas del juego para las lecciones del robot (A.R.I.A.).
## Se guardan sin editar en tools/data/guide/raw/; luego `python tools/build_guide_shots.py` las recorta,
## les pone etiquetas y las deja en assets/ui/guide/.
##
## Uso (desde la raíz del proyecto, con ventana: hace falta dibujar):
##   Godot_v4.7.2-stable_win64_console.exe --path . -s tools/capture_guide_shots.gd

const OUT := "res://tools/data/guide/raw/"
const SHOTS := [
	["station", "res://scenes/interiores/estacion_ares1/estacion_ares1.tscn"],
	["ap1", "res://scenes/ap1_zone.tscn"],
	["panels", "res://scenes/interiores/paneles_solares/paneles_solares.tscn"],
	["solar_field", "res://scenes/interiores/paneles_solares/minijuegos/campo_solar/campo_solar.tscn"],
	["greenhouse", "res://scenes/interiores/estacion_ares1/modulos/invernadero/invernadero.tscn"],
	["gym", "res://scenes/interiores/estacion_ares1/modulos/gimnasio/gimnasio.tscn"],
	["world_map", "res://scenes/world_map.tscn"],
]


func _initialize() -> void:
	root.get_node("GameState").choose_role("biologist")
	var guide := root.get_node("Guide")
	guide.process_mode = Node.PROCESS_MODE_DISABLED  # que el robot no salga en las capturas
	guide.visible = false
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for s in SHOTS:
		change_scene_to_file(s[1])
		for i in 50:
			await process_frame
		await create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + s[0] + ".png"))
		print("captura: ", s[0])
	quit()
