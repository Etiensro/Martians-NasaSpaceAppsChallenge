extends Node2D
## Zona de pantalla única (p. ej. AP-1): un fondo pixelado y un rectángulo donde se puede caminar.
## Ofrece la misma interfaz que site_map.gd (local_to_map, map_to_local, is_walkable…)
## para que el astronauta y el rover funcionen igual que en las zonas con TileMap.

@export var texture: Texture2D
@export var cell := 12.0           # cada píxel del fondo mide "cell" px de mundo (AP-1 usa 9)
@export var margin := 60.0         # distancia mínima al borde visible
## Rectángulo transitable (en coordenadas de la zona). Si está vacío se calcula
## a partir de lo que ve la cámara, para que el jugador nunca salga de la pantalla.
@export var walk_rect := Rect2()

var map_size := Vector2i.ZERO

@onready var ground: Sprite2D = $Suelo


func _ready() -> void:
	ground.texture = texture
	ground.centered = false
	ground.scale = Vector2.ONE * cell
	map_size = texture.get_size()


func size() -> Vector2:
	return texture.get_size() * cell


func center() -> Vector2:
	return size() / 2.0


## Limita el área transitable a lo que muestra la cámara (menos un margen).
func fit_to_camera(cam: Camera2D) -> void:
	var view := get_viewport_rect().size / cam.zoom
	var r := Rect2(cam.global_position - view / 2.0, view).intersection(Rect2(Vector2.ZERO, size()))
	walk_rect = r.grow(-margin)


func local_to_map(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / cell), floori(p.y / cell))


func map_to_local(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * cell


func is_walkable(c: Vector2i) -> bool:
	return walk_rect.has_point(map_to_local(c))


func terrain_at(c: Vector2i) -> String:
	return "suelo" if is_walkable(c) else ""
