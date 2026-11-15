extends Node2D
## Robot acompañante (scenes/robot.tscn): sigue al personaje (`target`) un poco detrás y a un lado.
## No se controla. Si el personaje se oculta (p. ej. sube al rover), el robot también.
## Todavía no está colocado en ninguna zona: instancia robot.tscn y asígnale `target`.

const Movement := preload("res://scripts/core/movement.gd")

@export var target: Node2D
@export var offset := Vector2(-60, 12)   # dónde se coloca respecto al personaje
@export var speed := 240.0               # px/s; acelera si se queda muy lejos
@export var stop_distance := 10.0
@export var teleport_distance := 700.0   # si se aleja demasiado, aparece junto al personaje

@onready var sprite: AnimatedSprite2D = $Sprite

var facing := "down"
var face_left := false
var _t := 0.0
var _base_offset_y := 0.0


func _ready() -> void:
	_base_offset_y = sprite.offset.y
	if target:
		position = target.position + offset


func _process(delta: float) -> void:
	if not target:
		return
	visible = target.visible
	_t += delta

	# Se pone del lado contrario hacia donde mira el personaje, para no taparle el paso
	var side := offset
	if target.get("facing") == "side":
		side.x = absf(offset.x) * (1.0 if target.get("face_left") else -1.0)
	var to_goal: Vector2 = target.position + side - position
	var dist := to_goal.length()
	if dist > teleport_distance:
		position += to_goal
		dist = 0.0

	var moving := dist > stop_distance
	if moving:
		var v := speed * clampf(dist / 120.0, 1.0, 3.0)  # más rápido cuanto más lejos
		position += to_goal.normalized() * minf(v * delta, dist)
		facing = Movement.facing_of(to_goal)
		if facing == "side":
			face_left = to_goal.x < 0

	sprite.offset.y = _base_offset_y + sin(_t * 4.0) * 1.5  # flota suavemente
	Movement.animate(sprite, "walk" if moving else "idle", facing, face_left)


## Animación de "reparando" (brazo con llave), por ejemplo al arreglar un panel.
func play_repair() -> void:
	sprite.play("celebrate")
