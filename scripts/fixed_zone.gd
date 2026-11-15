extends Node2D
## Zona de pantalla única (AP-1, AP-8, AP-9): mismo comportamiento, cambia el suelo y el título.
## Mismos tiles y tamaño de personaje que AP-8; la cámara fija a zoom 0.33 aleja la vista
## para que todo el mapa quepa en la pantalla. El astronauta solo puede moverse dentro
## de lo que se ve.
## (El rover está en scenes/rover.tscn con su mecánica de subir/bajar, listo para añadirlo.)

const WORLD_MAP := "res://scenes/world_map.tscn"

@onready var zone: Node2D = $Zona
@onready var player: Node2D = $Astronauta
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	# El jugador es el tripulante que eligió en la intro
	var gs0 := get_node_or_null("/root/GameState")
	if gs0 and gs0.selected_role != "":
		player.get_node("Sprite").sprite_frames = gs0.frames_for()
	camera.position = zone.center()
	camera.zoom = Vector2(0.33, 0.33)
	await get_tree().process_frame  # esperar a que la cámara se aplique
	zone.fit_to_camera(camera)
	# Margen extra arriba: la posición del personaje son sus pies y mide ~80 px de alto
	zone.walk_rect = zone.walk_rect.grow_individual(0, -60, 0, 0)
	player.position = zone.center()
	if has_node("Colonia"):  # AP-1: aparecer frente a la estación principal
		player.position = $Colonia.spawn_point()
	# Si venimos de un edificio, aparecer delante de su puerta
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.return_scene == scene_file_path and gs.return_position != Vector2.INF:
		player.position = gs.return_position
		gs.return_scene = ""
		gs.return_position = Vector2.INF


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file(WORLD_MAP)
