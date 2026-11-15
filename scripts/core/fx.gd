extends RefCounted
## Texturas y ayudas para partículas, compartidas por la colonia, el astronauta y la intro.
## Las texturas son blancas (el color se pone en Godot); las genera tools/build_fx.py.
## Uso: const Fx := preload("res://scripts/core/fx.gd")

const GLOW := preload("res://assets/fx/glow.png")      # halo suave 64x64 (luces)
const GLINT := preload("res://assets/fx/glint.png")    # destello de 4 puntas
const DUST := preload("res://assets/fx/dust.png")      # grano de polvo 2x2
const STREAK := preload("res://assets/fx/streak.png")  # ráfaga de viento horizontal 12x2
const PUFF := preload("res://assets/fx/puff.png")      # bocanada de humo 8x8


## CPUParticles2D con lo que casi siempre se repite. El resto se ajusta al volver.
static func particles(texture: Texture2D, amount: int, lifetime: float, direction: Vector2,
		spread: float, speed_min: float, speed_max: float, gravity := Vector2.ZERO) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = texture
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime  # que ya haya partículas al aparecer la escena
	p.direction = direction
	p.spread = spread
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.gravity = gravity
	return p


## Degradado de color durante la vida de la partícula.
## Sin `end_color`, termina en el mismo color transparente.
static func ramp(start_color: Color, end_color := Color(0, 0, 0, -1)) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, start_color)
	g.set_color(1, Color(start_color, 0.0) if end_color.a < 0 else end_color)
	return g


## Curva de tamaño de `start` a `end` (las bocanadas crecen al subir).
static func grow(start: float, end: float) -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, start))
	c.add_point(Vector2(1, end))
	return c
