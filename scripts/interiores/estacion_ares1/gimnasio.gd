extends Node2D
## Gimnasio de la Estación Ares 1 (scenes/interiores/estacion_ares1/modulos/gimnasio/gimnasio.tscn).
## La caminadora brilla para indicar qué hay que hacer; con clic se entra al minijuego (caminadora.tscn).
## La flecha de abajo (o Esc) vuelve al centro de la estación.
## Efectos del cuarto: luces que parpadean, halos de las lámparas y tubos del techo, pantallas que
## parpadean, terminales verdes con texto que corre y un punto en el mapa, y motas de polvo.
## Fondo, zonas y posiciones de los efectos: assets/interiores/estacion_ares1/gimnasio/gym.json
## (lo genera tools/build_gym.py).

const Style := preload("res://scripts/core/style.gd")
const Fx := preload("res://scripts/core/fx.gd")
const ExitArrow := preload("res://scripts/core/exit_arrow.gd")

const DIR := "res://assets/interiores/estacion_ares1/gimnasio/"
const STATION := "res://scenes/interiores/estacion_ares1/estacion_ares1.tscn"
const MINIGAME := "res://scenes/interiores/estacion_ares1/modulos/gimnasio/caminadora.tscn"
const MSG_READY := "Run for 2 hours  ·  Click to start"
const MSG_DONE := "You already trained today  ·  Come back tomorrow"

var data: Dictionary
var _treadmill: Rect2
var _glow := Node2D.new()   # contorno que late alrededor de la caminadora
var _fx := Node2D.new()     # luces que parpadean y pantallas (dibujados)
var _pointer := Node2D.new()
var _exit := ExitArrow.new()
var _add := CanvasItemMaterial.new()
var _hover := ""             # "treadmill", "exit" o ""
var _title: Label
var _sub: Label
var _t := 0.0
var _leaving := false


func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(DIR + "gym.json"))
	var r: Array = data.treadmill
	_treadmill = Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1])
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var bg := Sprite2D.new()
	bg.texture = load(DIR + "gym.png")
	bg.centered = false
	add_child(bg)

	_build_lamps()
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_build_motes()
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	_build_pointer()
	_build_sparkles()
	_exit.position = Vector2(data.exit[0], data.exit[1])
	add_child(_exit)
	_build_ui()
	_refresh()
	Mission.sol_started.connect(_on_sol_started)


# ---------------------------------------------------------------- efectos del cuarto

## Halos de las lámparas del techo y de la luz roja de la puerta (laten suave).
func _build_lamps() -> void:
	for l in data.fx.glow_lights:
		if l[3] <= 0.0:
			continue
		var g := Sprite2D.new()
		g.texture = Fx.GLOW
		g.material = _add
		g.position = Vector2(l[0], l[1])
		g.scale = Vector2.ONE * l[3]
		g.modulate = Color(Color(l[2]), 0.6)
		add_child(g)
		var tw := create_tween().set_loops()
		tw.tween_property(g, "modulate:a", 0.25, randf_range(0.9, 1.4)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(g, "modulate:a", 0.6, randf_range(0.9, 1.4)).set_trans(Tween.TRANS_SINE)


## Motas de polvo flotando en el aire del gimnasio.
func _build_motes() -> void:
	var m := Fx.particles(Fx.DUST, 30, 9.0, Vector2(1, -0.3), 50, 4, 12)
	m.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	m.position = Vector2(560, 400)
	m.emission_rect_extents = Vector2(420, 260)
	m.scale_amount_min = 1.0
	m.scale_amount_max = 2.0
	m.color = Color(1, 0.95, 0.85, 0.3)
	add_child(m)


func _draw_fx() -> void:
	# Luces pequeñas que parpadean (cada una a su ritmo)
	for i in data.fx.blink_lights.size():
		var l: Array = data.fx.blink_lights[i]
		var on := fmod(_t * (0.9 + i * 0.17) + i * 0.4, 2.0) < 1.1
		if on:
			_fx.draw_circle(Vector2(l[0], l[1]), 4, Color(l[2]))
			_fx.draw_circle(Vector2(l[0], l[1]), 9, Color(Color(l[2]), 0.25))
	# Terminales verdes: barrido de refresco que baja, líneas de texto que aparecen y cursor
	for i in data.fx.terminals.size():
		var tr: Array = data.fx.terminals[i]
		var r := Rect2(tr[0], tr[1], tr[2] - tr[0], tr[3] - tr[1])
		var scan := r.position.y + fmod(_t * 40.0 + i * 37.0, r.size.y)
		_fx.draw_rect(Rect2(r.position.x, scan, r.size.x, 3), Color(0.6, 1, 0.7, 0.25))
		if i == 0:
			var lines := int(fmod(_t * 3.0, 9.0))
			for k in lines:
				_fx.draw_rect(Rect2(r.position.x + 8, r.position.y + 10 + k * 10, 20 + (k * 17) % 40, 2), Color(0.5, 1, 0.6, 0.55))
			if fmod(_t, 0.8) < 0.45:
				_fx.draw_rect(Rect2(r.position.x + 8, r.position.y + 10 + lines * 10, 6, 4), Color(0.6, 1, 0.7, 0.9))
	var blip: Array = data.fx.map_blip
	var f := fmod(_t, 1.6) / 1.6
	_fx.draw_circle(Vector2(blip[0], blip[1]), 3, Color(1, 0.9, 0.3))
	_fx.draw_arc(Vector2(blip[0], blip[1]), 4 + f * 14, 0, TAU, 20, Color(0.5, 1, 0.6, 0.8 * (1.0 - f)), 2)
	# Pantallitas que parpadean
	for d in data.fx.displays:
		var dr := Rect2(d[0], d[1], d[2] - d[0], d[3] - d[1])
		if fmod(_t * 1.3 + d[0] * 0.01, 1.6) < 0.25:
			_fx.draw_rect(dr, Color(0.6, 1, 0.9, 0.22))


func _draw_glow() -> void:
	if Mission.exercised_today():
		return
	var on := _hover == "treadmill"
	var a := (0.55 + 0.45 * sin(_t * 4.0)) if not on else 1.0
	var c := Style.NEON_YELLOW
	_glow.draw_rect(_treadmill, Color(c, (0.10 if not on else 0.2) * a))
	_glow.draw_rect(_treadmill.grow(3), Color(c, a), false, 4)
	for corner in [_treadmill.position, Vector2(_treadmill.end.x, _treadmill.position.y), _treadmill.end,
			Vector2(_treadmill.position.x, _treadmill.end.y)]:
		var dx := 20.0 if corner.x == _treadmill.position.x else -20.0
		var dy := 20.0 if corner.y == _treadmill.position.y else -20.0
		_glow.draw_line(corner, corner + Vector2(dx, 0), Style.WHITE, 4)
		_glow.draw_line(corner, corner + Vector2(0, dy), Style.WHITE, 4)


# ---------------------------------------------------------------- caminadora (indicador)

## Flecha que rebota encima de la caminadora: "¡aquí!"
func _build_pointer() -> void:
	_pointer.position = Vector2(_treadmill.get_center().x, _treadmill.position.y - 30)
	var tri := Polygon2D.new()
	tri.polygon = PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(0, 6)])
	tri.color = Style.NEON_YELLOW
	var line := Line2D.new()
	line.points = tri.polygon + PackedVector2Array([tri.polygon[0]])
	line.width = 3
	line.default_color = Style.NAVY
	tri.add_child(line)
	_pointer.add_child(tri)
	add_child(_pointer)
	var tw := create_tween().set_loops()
	tw.tween_property(_pointer, "position:y", _pointer.position.y - 12, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_pointer, "position:y", _pointer.position.y, 0.45).set_trans(Tween.TRANS_SINE)


## Chispitas que suben de la caminadora (llaman la atención).
func _build_sparkles() -> void:
	var p := Fx.particles(Fx.GLINT, 6, 1.4, Vector2(0, -1), 20, 20, 45)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(_treadmill.size.x * 0.4, 6)
	p.position = Vector2(_treadmill.get_center().x, _treadmill.end.y - 30)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.color_ramp = Fx.ramp(Color(Style.NEON_YELLOW, 0.9))
	p.material = _add
	add_child(p)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var hint := Style.label("Gym  ·  Exercise keeps your bones and muscles strong on Mars  ·  Esc: back", 16, Style.WHITE, 5)
	hint.position = Vector2(16, 10)
	layer.add_child(hint)
	_title = Style.brand_title("TREADMILL", 34, Style.WHITE, 10)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size = Vector2(400, 44)
	_title.position = Vector2(_treadmill.get_center().x - 200, _treadmill.position.y - 112)
	layer.add_child(_title)
	_sub = Style.label("Run for 2 hours  ·  Click to start", 18, Style.NEON_YELLOW, 5)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.size = Vector2(400, 26)
	_sub.position = Vector2(_treadmill.get_center().x - 200, _treadmill.position.y - 70)
	layer.add_child(_sub)


func _refresh() -> void:
	var done: bool = Mission.exercised_today()
	_sub.text = MSG_DONE if done else MSG_READY
	_sub.add_theme_color_override("font_color", Style.WHITE if done else Style.NEON_YELLOW)
	_pointer.visible = not done


func _on_sol_started(_sol: int) -> void:
	_refresh()


# ---------------------------------------------------------------- interacción

func _process(delta: float) -> void:
	_t += delta
	_fx.queue_redraw()
	_glow.queue_redraw()


## Avisa que hoy ya hubo sesión: el texto de abajo parpadea en rojo.
func _deny() -> void:
	_sub.add_theme_color_override("font_color", Color(1, 0.35, 0.35))
	var tw := create_tween()
	tw.tween_property(_sub, "modulate:a", 0.3, 0.1)
	tw.tween_property(_sub, "modulate:a", 1.0, 0.1)
	tw.tween_property(_sub, "modulate:a", 0.3, 0.1)
	tw.tween_property(_sub, "modulate:a", 1.0, 0.1)
	tw.tween_callback(func(): _sub.add_theme_color_override("font_color", Style.WHITE))


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event is InputEventMouseMotion:
		var p := get_global_mouse_position()
		_hover = "exit" if _exit.hit(p) else ("treadmill" if _treadmill.has_point(p) else "")
		_exit.hovered = _hover == "exit"
		var clickable: bool = _hover == "exit" or (_hover == "treadmill" and not Mission.exercised_today())		
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if clickable else Input.CURSOR_ARROW)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p := get_global_mouse_position()
		if _exit.hit(p):
			_go(STATION)
		elif _treadmill.has_point(p):
			if Mission.exercised_today():
				_deny()
			else:
				_go(MINIGAME)
	elif event.is_action_pressed("ui_cancel"):
		_go(STATION)


func _go(scene: String) -> void:
	_leaving = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	SceneChanger.go_to(scene)
