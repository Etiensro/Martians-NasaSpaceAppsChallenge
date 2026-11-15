extends Node2D
## Centro de la Estación Ares 1 en primera persona (scenes/interiores/estacion_ares1/estacion_ares1.tscn).
## El jugador elige con el cursor a qué módulo ir: Work Room, Greenhouse, Gym, Infirmary o Crew Quarters.
## La flecha animada de abajo (o Esc) sale a AP-1, delante de la puerta de la estación.
## Fondo y zonas: assets/interiores/estacion_ares1/hub.png / hub.json (los genera tools/build_station_hub.py).
## Si el módulo todavía no tiene escena, avisa "Coming soon".

const Style := preload("res://scripts/core/style.gd")
const Fx := preload("res://scripts/core/fx.gd")
const ExitArrow := preload("res://scripts/core/exit_arrow.gd")

const BG := preload("res://assets/interiores/estacion_ares1/hub.png")
const DATA := "res://assets/interiores/estacion_ares1/hub.json"

var data: Dictionary
var _add := CanvasItemMaterial.new()
var _fx := Node2D.new()          # pantallas, luces de cultivo y luces de estado (dibujadas)
var _hover_box := Node2D.new()   # resalte de la puerta bajo el cursor
var _exit := ExitArrow.new()
var _banner: Label
var _sub: Label
var _toast: Label
var _hovered := ""               # id de la puerta, "exit" o ""
var _t := 0.0
var _leaving := false


func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var bg := Sprite2D.new()
	bg.texture = BG
	bg.centered = false
	add_child(bg)

	_build_windows()
	_build_lights()
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_build_motes()
	_hover_box.draw.connect(_draw_hover)
	add_child(_hover_box)
	_build_exit_arrow()
	_build_ui()


# ---------------------------------------------------------------- efectos

## La tormenta pasa por las ventanas del techo: rachas de polvo recortadas a cada ventana.
func _build_windows() -> void:
	for w in data.windows:
		var r := Rect2(w[0], w[1], w[2] - w[0], w[3] - w[1])
		var mask := ColorRect.new()
		mask.position = r.position
		mask.size = r.size
		mask.color = Color.WHITE  # solo sirve de máscara (no se dibuja)
		mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mask)
		var p := Fx.particles(Fx.STREAK, 14, r.size.x / 120.0, Vector2(1, 0.15), 4, 100, 160)
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(4, r.size.y / 2)
		p.position = Vector2(-10, r.size.y / 2)
		p.scale_amount_min = 2.0
		p.scale_amount_max = 4.0
		p.color = Color(1, 0.8, 0.6, 0.45)
		mask.add_child(p)
		var haze := Fx.particles(Fx.PUFF, 4, r.size.x / 50.0, Vector2(1, 0), 10, 30, 55)
		haze.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		haze.emission_rect_extents = Vector2(4, r.size.y / 2)
		haze.position = Vector2(-20, r.size.y / 2)
		haze.scale_amount_min = 6.0
		haze.scale_amount_max = 10.0
		haze.color = Color(0.85, 0.5, 0.3, 0.25)
		mask.add_child(haze)


## Halo de color de la luz de cada puerta (late suave) y halos de las luces de estado.
func _build_lights() -> void:
	for i in data.door_lights.size():
		var p: Array = data.door_lights[i]
		var color := Color(data.doors[i].color)
		var g := _glow(Vector2(p[0], p[1]), color, 1.4)
		var tw := create_tween().set_loops()
		tw.tween_property(g, "modulate:a", 0.45, 1.1 + i * 0.13).set_trans(Tween.TRANS_SINE)
		tw.tween_property(g, "modulate:a", 0.9, 1.1 + i * 0.13).set_trans(Tween.TRANS_SINE)


func _glow(at: Vector2, color: Color, size: float) -> Sprite2D:
	var g := Sprite2D.new()
	g.texture = Fx.GLOW
	g.material = _add
	g.position = at
	g.scale = Vector2.ONE * size
	g.modulate = color
	add_child(g)
	return g


## Motas de polvo flotando en el aire de la estación.
func _build_motes() -> void:
	var m := Fx.particles(Fx.DUST, 36, 10.0, Vector2(1, -0.3), 50, 4, 12)
	m.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	m.position = Vector2(640, 420)
	m.emission_rect_extents = Vector2(640, 280)
	m.scale_amount_min = 1.0
	m.scale_amount_max = 2.0
	m.color = Color(1, 0.95, 0.85, 0.3)
	add_child(m)


func _draw_fx() -> void:
	# Luces de cultivo del invernadero (respiran)
	var grow := 0.18 + 0.1 * sin(_t * 1.6)
	for r in data.grow_lights:
		_fx.draw_rect(Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1]), Color(0.85, 0.4, 1.0, grow))
	# Pantallas: gráficas que avanzan, texto que parpadea y el latido de la enfermería
	for s in data.screens:
		var r := Rect2(s[0], s[1], s[2] - s[0], s[3] - s[1])
		match s[4]:
			"chart":
				var x := r.position.x + fmod(_t * 18.0 + r.position.y, r.size.x)
				_fx.draw_line(Vector2(x, r.position.y + 2), Vector2(x, r.end.y - 2), Color(0.5, 1, 0.9, 0.55), 2)
			"text":
				if fmod(_t, 1.0) < 0.5:
					_fx.draw_rect(Rect2(r.position + Vector2(4, r.size.y - 8), Vector2(6, 3)), Color(0.6, 1, 0.9, 0.9))
			"heart":
				var pts := PackedVector2Array()
				for k in 16:
					var x2 := r.position.x + 3 + k * (r.size.x - 6) / 15.0
					var beat := 9.0 if (k + int(_t * 8.0)) % 16 == 7 else (-4.0 if (k + int(_t * 8.0)) % 16 == 8 else 0.0)
					pts.append(Vector2(x2, r.get_center().y - beat))
				_fx.draw_polyline(pts, Color(0.4, 1, 0.5, 0.95), 2)
	# Luces de estado de los marcos de las puertas
	for i in data.status_lights.size():
		var p: Array = data.status_lights[i]
		if fmod(_t * 0.8 + i * 0.37, 2.0) < 0.6:
			_fx.draw_circle(Vector2(p[0], p[1]), 3, Color(0.6, 1, 0.8, 0.9))


func _draw_hover() -> void:
	if _hovered == "" or _hovered == "exit":
		return
	var door := _door(_hovered)
	var r := _rect(door)
	var c := Color(door.color)
	var a := 0.75 + 0.25 * sin(_t * 6.0)
	_hover_box.draw_rect(r, Color(c, 0.2 * a))
	_hover_box.draw_rect(r.grow(2), Color(c, a), false, 4)
	# esquinas tipo "visor" para que se note que se puede elegir
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var dx := 18.0 if corner.x == r.position.x else -18.0
		var dy := 18.0 if corner.y == r.position.y else -18.0
		_hover_box.draw_line(corner, corner + Vector2(dx, 0), Style.WHITE, 4)
		_hover_box.draw_line(corner, corner + Vector2(0, dy), Style.WHITE, 4)


# ---------------------------------------------------------------- flecha de salida (animada)

func _build_exit_arrow() -> void:
	_exit.position = Vector2(data.exit[0], data.exit[1])
	add_child(_exit)


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var hint := Style.label("Ares 1 Station  ·  Click a room to enter  ·  Esc: exit", 16, Style.WHITE, 5)
	hint.position = Vector2(16, 10)
	layer.add_child(hint)

	_banner = Style.brand_title("", 40, Style.WHITE, 10)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -500
	_banner.offset_right = 500
	_banner.offset_top = 40
	_banner.offset_bottom = 90
	_banner.modulate.a = 0.0
	layer.add_child(_banner)
	_sub = Style.label("Click to enter", 18, Style.NEON_YELLOW, 5)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_sub.offset_left = -500
	_sub.offset_right = 500
	_sub.offset_top = 90
	_sub.offset_bottom = 116
	_sub.modulate.a = 0.0
	layer.add_child(_sub)

	_toast = Style.label("", 22, Style.WHITE, 6)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -400
	_toast.offset_right = 400
	_toast.offset_top = 130
	_toast.modulate.a = 0.0
	layer.add_child(_toast)


# ---------------------------------------------------------------- interacción

func _process(delta: float) -> void:
	_t += delta
	_fx.queue_redraw()
	_hover_box.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event is InputEventMouseMotion:
		_set_hover(_hit(get_global_mouse_position()))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := _hit(get_global_mouse_position())
		if id == "exit":
			_leave()
		elif id != "":
			_enter(_door(id))
	elif event.is_action_pressed("ui_cancel"):
		_leave()


func _hit(p: Vector2) -> String:
	if _exit.hit(p):
		return "exit"
	for door in data.doors:
		if _rect(door).has_point(p):
			return door.id
	return ""


func _set_hover(id: String) -> void:
	if id == _hovered:
		return
	_hovered = id
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if id != "" else Input.CURSOR_ARROW)
	var is_exit := id == "exit"
	_exit.hovered = is_exit
	var tw := create_tween().set_parallel()
	var show_door := id != "" and not is_exit
	if show_door:
		_banner.text = _door(id).name
	tw.tween_property(_banner, "modulate:a", 1.0 if show_door else 0.0, 0.15)
	tw.tween_property(_sub, "modulate:a", 1.0 if show_door else 0.0, 0.15)


func _enter(door: Dictionary) -> void:
	if ResourceLoader.exists(door.scene):
		_leaving = true
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		SceneChanger.go_to(door.scene)
		return
	_toast.text = "%s  ·  Coming soon" % door.name
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _leave() -> void:
	_leaving = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	GameState.leave_building()


func _door(id: String) -> Dictionary:
	for door in data.doors:
		if door.id == id:
			return door
	return {}


func _rect(door: Dictionary) -> Rect2:
	var r: Array = door.rect
	return Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1])
