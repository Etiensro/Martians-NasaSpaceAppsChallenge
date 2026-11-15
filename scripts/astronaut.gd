extends Node2D
## Astronauta jugable en vista cenital.
## WASD / flechas para moverse, Shift para correr.
## No puede pisar celdas no transitables de la zona (edificios, fuera de pantalla...).

const Movement := preload("res://scripts/core/movement.gd")
const Fx := preload("res://scripts/core/fx.gd")

@export var map: Node2D  # la zona (zone_area.gd): dice qué celdas se pueden pisar
@export var walk_speed := 130.0  # px/s; ajustado al paso de la animación para que los pies no patinen
@export var run_speed := 240.0
@export var dust_color := Color(0.93, 0.72, 0.58, 0.8)  # polvo que levanta al caminar

@onready var sprite: AnimatedSprite2D = $Sprite

## Hacia dónde mira: "down", "up" o "side" (lo lee también el robot acompañante).
var facing := "down"
var face_left := false
var _dust: CPUParticles2D


func _ready() -> void:
	_dust = Fx.particles(Fx.PUFF, 16, 0.6, Vector2(0, -1), 70, 10, 30, Vector2(0, 20))
	_dust.preprocess = 0.0
	_dust.emitting = false
	_dust.local_coords = false  # el polvo se queda donde pisó
	_dust.position = Vector2(0, -2)
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(10, 2)
	_dust.scale_amount_min = 1.4
	_dust.scale_amount_curve = Fx.grow(0.6, 1.8)
	_dust.color_ramp = Fx.ramp(dust_color)
	add_child(_dust)


func _process(delta: float) -> void:
	var dir := Movement.input_vector()
	var moving := dir != Vector2.ZERO
	var running := Movement.is_running()
	if moving:
		position = Movement.slide(position, dir * (run_speed if running else walk_speed) * delta, can_stand)
		facing = Movement.facing_of(dir)
		if facing == "side":
			face_left = dir.x < 0

	# Al correr se usa la animación de caminar, más rápida (para que los pies no "patinen").
	sprite.speed_scale = run_speed / walk_speed if moving and running else 1.0
	Movement.animate(sprite, "walk" if moving else "idle", facing, face_left)
	_dust.emitting = moving
	_dust.scale_amount_max = 3.2 if running else 2.2  # al correr levanta más polvo


## ¿Se puede estar en `at` (coordenadas del padre)?
func can_stand(at: Vector2) -> bool:
	if not map:
		return true
	return map.is_walkable(map.local_to_map(map.to_local(get_parent().to_global(at))))
