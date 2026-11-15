extends Node2D
## Rover (scenes/rover.tscn). Todavía no está colocado en ninguna zona: para usarlo,
## instancia rover.tscn en la zona y asígnale `map` (la Zona) y `player` (el Astronauta).
## - Clic sobre el rover estando cerca: el astronauta sube (desaparece) y se maneja con WASD.
## - E (o clic sobre el rover) para bajar: el astronauta reaparece junto al rover.

signal entered
signal exited

const Movement := preload("res://scripts/core/movement.gd")
const CLICK_SIZE := Vector2(110, 120)  # zona de clic (el dibujo del rover dentro del frame de 128x128)

@export var map: Node2D  # la zona (zone_area.gd)
@export var player: Node2D
@export var speed := 280.0
@export var enter_range := 180.0  # distancia máxima (px) para poder subir

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hint: Label = $Hint

var occupied := false
var facing := "down"
var face_left := false


func _process(delta: float) -> void:
	var dir := Movement.input_vector() if occupied else Vector2.ZERO
	if dir != Vector2.ZERO:
		position = Movement.slide(position, dir * speed * delta, can_stand)
		facing = Movement.facing_of(dir)
		if facing == "side":
			face_left = dir.x < 0
	Movement.animate(sprite, "drive" if dir != Vector2.ZERO else "idle", facing, face_left)
	hint.text = "E: get out" if occupied else "Click: get in the rover"
	hint.visible = occupied or _player_near()


func _unhandled_input(event: InputEvent) -> void:
	var clicked: bool = event is InputEventMouseButton and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT and _is_clicked(get_global_mouse_position())
	var pressed_e: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E
	if occupied and (clicked or pressed_e):
		exit_rover()
		get_viewport().set_input_as_handled()
	elif not occupied and clicked and _player_near():
		enter_rover()
		get_viewport().set_input_as_handled()


func enter_rover() -> void:
	occupied = true
	player.hide()
	player.set_process(false)
	entered.emit()


func exit_rover() -> void:
	# Dejar al astronauta en el primer hueco transitable alrededor del rover
	var spot := position
	for offset in [Vector2(0, 70), Vector2(-90, 0), Vector2(90, 0), Vector2(0, -70)]:
		var p: Vector2 = position + offset * scale.x  # las distancias crecen si el rover está escalado
		if can_stand(p):
			spot = p
			break
	player.position = spot
	player.show()
	player.set_process(true)
	occupied = false
	exited.emit()


## El rover ocupa más que el astronauta: se comprueban el centro y los dos costados.
func can_stand(at: Vector2) -> bool:
	if not map:
		return true
	for dx in [-45.0, 0.0, 45.0]:
		var global: Vector2 = get_parent().to_global(at + Vector2(dx, -10) * scale.x)
		if not map.is_walkable(map.local_to_map(map.to_local(global))):
			return false
	return true


func _is_clicked(global_point: Vector2) -> bool:
	return Rect2(Vector2(-CLICK_SIZE.x / 2, -CLICK_SIZE.y), CLICK_SIZE).has_point(to_local(global_point))


func _player_near() -> bool:
	return player != null and player.visible and player.position.distance_to(position) <= enter_range
