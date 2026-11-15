extends Node2D
## Astronauta jugable en vista cenital.
## WASD / flechas para moverse, Shift para correr.
## No puede pisar celdas no transitables del mapa (pingos, montículos, paredes de cráter, fuera de zona).

@export var map: Node2D  # TileMapLayer (site_map.gd) o zona fija (zone_area.gd)
@export var walk_speed := 130.0  # píxeles por segundo; ajustado al paso de la animación para que los pies no patinen
@export var run_speed := 240.0

@onready var sprite: AnimatedSprite2D = $Sprite

## Polvo que levanta al caminar (más al correr)
@export var dust_color := Color(0.93, 0.72, 0.58, 0.8)
var _dust: CPUParticles2D

var facing := "down"   # down, up, side
var _face_left := false


func _ready() -> void:
	_dust = CPUParticles2D.new()
	_dust.texture = preload("res://assets/fx/puff.png")
	_dust.emitting = false
	_dust.local_coords = false          # el polvo se queda donde pisó
	_dust.amount = 16
	_dust.lifetime = 0.6
	_dust.position = Vector2(0, -2)
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(10, 2)
	_dust.direction = Vector2(0, -1)
	_dust.spread = 70
	_dust.initial_velocity_min = 10
	_dust.initial_velocity_max = 30
	_dust.gravity = Vector2(0, 20)
	_dust.scale_amount_min = 1.4
	_dust.scale_amount_max = 2.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6)); curve.add_point(Vector2(1, 1.8))
	_dust.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, dust_color); grad.set_color(1, Color(dust_color, 0.0))
	_dust.color_ramp = grad
	add_child(_dust)


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
	_dust.emitting = dir != Vector2.ZERO
	_dust.scale_amount_max = 3.2 if running else 2.2  # al correr levanta más polvo


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
