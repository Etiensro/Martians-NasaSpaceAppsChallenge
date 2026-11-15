extends Node2D
## Robot acompañante: sigue al personaje (target) quedándose un poco detrás y a un lado.
## No se controla; solo acompaña. Si el personaje se oculta (p. ej. sube al rover), el robot también.

@export var target: Node2D
@export var offset := Vector2(-60, 12)   # dónde se coloca respecto al personaje
@export var speed := 240.0               # px/s; acelera si se queda muy lejos
@export var stop_distance := 10.0
@export var teleport_distance := 700.0   # si se aleja demasiado, aparece junto al personaje

@onready var sprite: AnimatedSprite2D = $Sprite

var facing := "down"
var _face_left := false
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
	if "facing" in target and target.facing == "side" and not target.get("_face_left"):
		side.x = -absf(offset.x)
	elif "facing" in target and target.facing == "side":
		side.x = absf(offset.x)
	var goal: Vector2 = target.position + side
	var to_goal := goal - position
	var dist := to_goal.length()

	if dist > teleport_distance:
		position = goal
		dist = 0.0
	var moving := dist > stop_distance
	if moving:
		var v := speed * clampf(dist / 120.0, 1.0, 3.0)  # más rápido cuanto más lejos
		position += to_goal.normalized() * minf(v * delta, dist)
		if absf(to_goal.x) > absf(to_goal.y):
			facing = "side"
			_face_left = to_goal.x < 0
		else:
			facing = "down" if to_goal.y > 0 else "up"

	# Flota suavemente
	sprite.offset.y = _base_offset_y + sin(_t * 4.0) * 1.5
	sprite.flip_h = facing == "side" and _face_left
	var anim := ("walk_" if moving else "idle_") + facing
	if sprite.animation != anim:
		sprite.play(anim)


## Animación de "reparando" (brazo con llave), por ejemplo al arreglar un panel.
func play_repair() -> void:
	sprite.play("celebrate")
