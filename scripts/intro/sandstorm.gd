extends Node2D
## Muro de la tormenta de arena visto desde arriba (placeholder por código + partículas).
## El frente de la tormenta está en x = 0 (local) y el polvo se extiende hacia +x.
## Mueve el nodo hacia la izquierda para que la tormenta "avance".

const Style := preload("res://scripts/intro/intro_style.gd")

@export var height := 7000.0
@export var depth := 7000.0
## 0..1: qué tan agitado se ve el frente (sube durante la cinemática).
@export var intensity := 0.4:
	set(v):
		intensity = v
		if _billow:
			_billow.speed_scale = 0.6 + v * 1.4

var _t := 0.0
var _billow: CPUParticles2D
var _puffs: Array = []  # [y, radio, fase]


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var y := -height / 2.0
	while y < height / 2.0:
		_puffs.append([y, rng.randf_range(90, 220), rng.randf() * TAU])
		y += rng.randf_range(70, 140)
	_build_particles()
	intensity = intensity


func _build_particles() -> void:
	# Nubes de polvo que salen del frente de la tormenta
	_billow = CPUParticles2D.new()
	_billow.texture = Style.puff_texture(8)
	_billow.amount = 260
	_billow.lifetime = 5.0
	_billow.preprocess = 5.0
	_billow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_billow.emission_rect_extents = Vector2(80, height / 2.0)
	_billow.direction = Vector2(-1, 0.1)
	_billow.spread = 25.0
	_billow.gravity = Vector2.ZERO
	_billow.initial_velocity_min = 120.0
	_billow.initial_velocity_max = 380.0
	_billow.scale_amount_min = 6.0
	_billow.scale_amount_max = 18.0
	_billow.angular_velocity_min = -40.0
	_billow.angular_velocity_max = 40.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(Style.DUST, 0.0))
	ramp.add_point(0.2, Color(Style.DUST, 0.55))
	ramp.set_color(ramp.get_point_count() - 1, Color(Style.DUST.darkened(0.2), 0.0))
	_billow.color_ramp = ramp
	_billow.position = Vector2(120, 0)
	add_child(_billow)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# Cuerpo de la tormenta: capas cada vez más densas hacia dentro
	draw_rect(Rect2(Vector2(400, -height / 2), Vector2(depth, height)), Style.DUST_DARK)
	draw_rect(Rect2(Vector2(160, -height / 2), Vector2(260, height)), Color(Style.DUST.darkened(0.3), 0.92))
	draw_rect(Rect2(Vector2(40, -height / 2), Vector2(140, height)), Color(Style.DUST, 0.75))
	# Frente irregular: "coliflores" de polvo que se agitan
	var wobble := 10.0 + intensity * 30.0
	for p in _puffs:
		var ph: float = p[2]
		var c := Vector2(40 + sin(_t * 1.3 + ph) * wobble, p[0] + cos(_t * 0.9 + ph) * wobble * 0.5)
		var r: float = p[1] * (1.0 + 0.06 * sin(_t * 2.0 + ph))
		draw_circle(c + Vector2(60, 0), r, Color(Style.DUST.darkened(0.15), 0.85))
		draw_circle(c, r * 0.75, Color(Style.DUST, 0.6))
		draw_circle(c - Vector2(r * 0.35, 0), r * 0.4, Color(Style.DUST.lightened(0.15), 0.35))
	# Rayos/sombras dentro de la tormenta para dar sensación de movimiento
	for i in 14:
		var yy := -height / 2 + fmod(i * 523.0 + _t * 260.0, height)
		draw_line(Vector2(300, yy), Vector2(1400, yy + 160), Color(0.3, 0.13, 0.06, 0.35), 26)
