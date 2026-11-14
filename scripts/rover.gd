extends Node2D
## Rover de la colonia.
## - Clic sobre el rover estando cerca: el astronauta sube (desaparece) y se maneja el rover con WASD.
## - E (o clic sobre el rover) para bajar: el astronauta reaparece junto al rover.
## Como el astronauta, no puede entrar en celdas no transitables.

signal entered
signal exited

@export var map: Node2D  # TileMapLayer (site_map.gd) o zona fija (zone_area.gd)
@export var player: Node2D
@export var camera: Camera2D
@export var speed := 280.0
@export var enter_range := 180.0  # distancia máxima (px) para poder subir

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hint: Label = $Hint

var occupied := false
var facing := "down"
var _face_left := false

const SIZE := Vector2(110, 120)  # zona de clic (aprox. el dibujo del rover dentro del frame de 128x128)


func _process(delta: float) -> void:
	if occupied:
		_drive(delta)
	else:
		sprite.play("idle_" + facing)
	_update_hint()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_clicked(get_global_mouse_position()):
			if occupied:
				exit_rover()
			elif _player_near():
				enter_rover()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and occupied:
		exit_rover()
		get_viewport().set_input_as_handled()


func enter_rover() -> void:
	occupied = true
	player.hide()
	player.set_process(false)
	if camera:
		if "target" in camera:
			camera.target = self
	entered.emit()


func exit_rover() -> void:
	# Buscar un sitio transitable al lado del rover para dejar al astronauta
	var offsets := [Vector2(0, 70), Vector2(-90, 0), Vector2(90, 0), Vector2(0, -70)]
	var spot := position
	for o in offsets:
		if _can_stand(position + o * scale.x):  # las distancias crecen si el rover está escalado
			spot = position + o * scale.x
			break
	player.position = spot
	player.show()
	player.set_process(true)
	occupied = false
	if camera:
		if "target" in camera:
			camera.target = player
	exited.emit()


func _drive(delta: float) -> void:
	var dir := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	if dir != Vector2.ZERO:
		dir = dir.normalized()
		var step := dir * speed * delta
		if _can_stand(position + Vector2(step.x, 0)):
			position.x += step.x
		if _can_stand(position + Vector2(0, step.y)):
			position.y += step.y
		if absf(dir.x) > absf(dir.y):
			facing = "side"
			_face_left = dir.x < 0
		else:
			facing = "down" if dir.y > 0 else "up"
	sprite.flip_h = facing == "side" and _face_left
	var anim := ("drive_" if dir != Vector2.ZERO else "idle_") + facing
	if sprite.animation != anim:
		sprite.play(anim)


## El rover ocupa más que el astronauta: se comprueban el centro y los dos costados.
func _can_stand(at: Vector2) -> bool:
	if not map:
		return true
	for dx in [-45.0, 0.0, 45.0]:
		var cell: Vector2i = map.local_to_map(map.to_local(get_parent().to_global(at + Vector2(dx, -10) * scale.x)))
		if not map.is_walkable(cell):
			return false
	return true


func _is_clicked(global_point: Vector2) -> bool:
	var local := to_local(global_point)
	return Rect2(Vector2(-SIZE.x / 2, -SIZE.y), SIZE).has_point(local)


func _player_near() -> bool:
	return player and player.visible and player.position.distance_to(position) <= enter_range


func _update_hint() -> void:
	if occupied:
		hint.text = "E: bajar"
		hint.visible = true
	else:
		hint.text = "Clic: subir al rover"
		hint.visible = _player_near()


## Coloca el rover en la celda transitable más cercana a una posición (en coordenadas del padre).
func place_near(at: Vector2) -> void:
	for r in range(0, 40):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var p := at + Vector2(dx, dy) * 48.0
				if _can_stand(p):
					position = p
					return
	position = at
