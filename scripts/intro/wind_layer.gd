extends CanvasLayer
## Viento con polvo en espacio de pantalla (va encima del mundo, debajo de la UI).
## "intensity" 0..1 controla velocidad, opacidad de las rachas y la neblina de polvo.

const Style := preload("res://scripts/intro/intro_style.gd")

@export var intensity := 0.3:
	set(v):
		intensity = clampf(v, 0.0, 1.0)
		_apply()

var _root := Node2D.new()
var _streaks := CPUParticles2D.new()
var _grains := CPUParticles2D.new()
var _haze := TextureRect.new()      # neblina de polvo en el borde derecho (de donde viene la tormenta)
var _overlay := ColorRect.new()     # tinte de polvo en toda la pantalla


func _init() -> void:
	layer = 5


func _ready() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(Style.DUST, 0.0))
	grad.set_color(1, Color(Style.DUST, 0.75))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	_haze.texture = gt
	_haze.stretch_mode = TextureRect.STRETCH_SCALE
	_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_haze)

	_overlay.color = Style.DUST.darkened(0.1)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	add_child(_root)  # partículas encima de la neblina

	# Rachas largas (alineadas con la velocidad)
	_streaks.texture = Style.solid_texture(2, 14, Color.WHITE)
	_streaks.particle_flag_align_y = true
	_streaks.amount = 140
	_streaks.lifetime = 2.0
	_streaks.preprocess = 2.0
	_streaks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_streaks.direction = Vector2(-1, 0.18)
	_streaks.spread = 4.0
	_streaks.gravity = Vector2.ZERO
	_streaks.initial_velocity_min = 700.0
	_streaks.initial_velocity_max = 1200.0
	_streaks.scale_amount_min = 1.0
	_streaks.scale_amount_max = 2.5
	_streaks.color = Color(Style.DUST.lightened(0.3), 0.55)
	_root.add_child(_streaks)

	# Granos de arena sueltos, más lentos
	_grains.texture = Style.solid_texture(3, 3, Color.WHITE)
	_grains.amount = 220
	_grains.lifetime = 4.0
	_grains.preprocess = 4.0
	_grains.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_grains.direction = Vector2(-1, 0.25)
	_grains.spread = 15.0
	_grains.gravity = Vector2.ZERO
	_grains.initial_velocity_min = 250.0
	_grains.initial_velocity_max = 520.0
	_grains.scale_amount_min = 1.0
	_grains.scale_amount_max = 2.0
	_grains.color = Color(Style.DUST.lightened(0.15), 0.7)
	_root.add_child(_grains)

	get_viewport().size_changed.connect(_layout)
	_layout()
	_apply()


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	for p in [_streaks, _grains]:
		p.position = Vector2(vp.x + 40, vp.y / 2.0)
		p.emission_rect_extents = Vector2(20, vp.y * 0.65)
	_haze.position = Vector2(vp.x * 0.55, 0)
	_haze.size = Vector2(vp.x * 0.45, vp.y)
	_overlay.position = Vector2.ZERO
	_overlay.size = vp


func _apply() -> void:
	if not is_inside_tree():
		return
	_streaks.speed_scale = 0.6 + intensity * 1.2
	_grains.speed_scale = 0.6 + intensity * 1.2
	_root.modulate.a = 0.35 + intensity * 0.65
	_haze.modulate.a = 0.25 + intensity * 0.75
	_overlay.color.a = maxf(0.0, intensity - 0.45) * 1.1  # solo se nota cuando la tormenta está encima
