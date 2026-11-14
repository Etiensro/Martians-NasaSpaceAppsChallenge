extends Node2D
## Astronauta jugable en vista cenital.
## WASD / flechas para moverse, Shift para correr.
## No puede pisar celdas no transitables del mapa (pingos, montículos, paredes de cráter, fuera de zona).

@export var map: Node2D  # TileMapLayer (site_map.gd) o zona fija (zone_area.gd)
@export var walk_speed := 130.0  # píxeles por segundo; ajustado al paso de la animación para que los pies no patinen
@export var run_speed := 240.0

@onready var sprite: AnimatedSprite2D = $Sprite

var facing := "down"   # down, up, side
var _face_left := false


func _process(delta: float) -> void:
	var dir := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	var running := Input.is_key_pressed(KEY_SHIFT)

	if dir != Vector2.ZERO:
		dir = dir.normalized()
		var step := dir * (run_speed if running else walk_speed) * delta
		# Mover por ejes por separado para "deslizar" contra los obstáculos
		if _can_stand(position + Vector2(step.x, 0)):
			position.x += step.x
		if _can_stand(position + Vector2(0, step.y)):
			position.y += step.y
		if absf(dir.x) > absf(dir.y):
			facing = "side"
			_face_left = dir.x < 0
		else:
			facing = "down" if dir.y > 0 else "up"

	_animate(dir != Vector2.ZERO, running)


func _animate(moving: bool, running: bool) -> void:
	var anim := ("walk_" if moving else "idle_") + facing
	# Al correr se usa la misma animación de caminar, más rápida.
	# La velocidad de la animación sigue a la del movimiento para que los pies no "patinen".
	sprite.speed_scale = (run_speed / walk_speed) if (moving and running) else 1.0
	sprite.flip_h = facing == "side" and _face_left
	if sprite.animation != anim:
		sprite.play(anim)


func _can_stand(at: Vector2) -> bool:
	if not map:
		return true
	# "at" está en coordenadas del padre; convertir a coordenadas del mapa
	var cell: Vector2i = map.local_to_map(map.to_local(get_parent().to_global(at)))
	return map.is_walkable(cell) if map.has_method("is_walkable") else map.terrain_at(cell) != ""


## Coloca al astronauta en la celda transitable más cercana a (lat, lon).
func spawn_at(lat: float, lon: float) -> void:
	var start: Vector2i = map.latlon_to_cell(lat, lon)
	for r in 60:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := start + Vector2i(dx, dy)
				if map.is_walkable(c):
					position = _cell_to_parent(c)
					return
	position = _cell_to_parent(start)


func _cell_to_parent(c: Vector2i) -> Vector2:
	# el mapa puede estar escalado: convertir de coordenadas del mapa a las del padre
	return get_parent().to_local(map.to_global(map.map_to_local(c)))
