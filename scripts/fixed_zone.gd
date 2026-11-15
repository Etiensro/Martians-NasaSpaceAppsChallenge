extends Node2D
## Zona de pantalla única (raíz de zone_base.tscn; la heredan ap1/ap8/ap9_zone.tscn).
## La cámara fija a zoom 0.33 enseña todo el suelo; el astronauta solo se mueve dentro de lo
## que se ve. Esc vuelve al mapa general.

const CAMERA_ZOOM := 0.33
const HEAD_ROOM := 60.0  # la posición del personaje son sus pies y mide ~80 px: margen arriba

@onready var zone: Node2D = $Zona
@onready var player: Node2D = $Astronauta
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	# El jugador es el tripulante que eligió en la intro
	player.get_node("Sprite").sprite_frames = GameState.frames_for()
	camera.position = zone.center()
	camera.zoom = Vector2.ONE * CAMERA_ZOOM
	await get_tree().process_frame  # esperar a que la cámara se aplique
	zone.fit_to_camera(camera)
	zone.walk_rect = zone.walk_rect.grow_individual(0, -HEAD_ROOM, 0, 0)

	# Dónde aparece: delante de la puerta si venimos de un edificio; si no, en la entrada
	var back := GameState.take_return_position(scene_file_path)
	if back != Vector2.INF:
		player.position = back
	elif has_node("Colonia"):  # AP-1: frente a la estación principal
		player.position = $Colonia.spawn_point()
	else:
		player.position = zone.center()
	if has_node("Robot"):  # el robot acompañante aparece junto al jugador
		$Robot.snap_to_target()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		SceneChanger.go_to(GameState.WORLD_MAP)
