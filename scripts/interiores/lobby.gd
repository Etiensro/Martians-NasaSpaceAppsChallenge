extends Node2D
## Vestíbulo en primera persona: el jugador elige con el cursor a qué puerta ir.
## Lo usan la Estación Ares 1 (5 módulos) y los Paneles solares (campo solar y sala eléctrica).
## La flecha animada de abajo (o Esc) sale a AP-1, delante de la puerta del edificio.
## Fondo, puertas y efectos: <data_dir>/hub.png y hub.json (los genera tools/build_lobbies.py).
## Si la puerta todavía no tiene escena, avisa "Coming soon".
## Las reglas de la misión (autoload Mission) pueden impedir salir (tormenta) o entrar a una puerta.

const Style := preload("res://scripts/core/style.gd")
const Fx := preload("res://scripts/core/fx.gd")
const ExitArrow := preload("res://scripts/core/exit_arrow.gd")

## Carpeta con hub.png y hub.json de este vestíbulo.
@export_dir var data_dir := "res://assets/interiores/estacion_ares1"
## Texto de ayuda de arriba a la izquierda (lo ve el jugador: en inglés).
@export var hint := "Ares 1 Station  ·  Click a room to enter  ·  Esc: exit"

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
	data = JSON.parse_string(FileAccess.get_file_as_string(data_dir.path_join("hub.json")))
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var bg := Sprite2D.new()
	bg.texture = load(data_dir.path_join("hub.png"))
	bg.centered = false
	add_child(bg)

	_build_windows()
	_build_lights()
	if not data.get("glints", []).is_empty():
		_glint_loop()
	if not data.get("sparks", []).is_empty():
		_spark_loop()
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_build_motes()
	_hover_box.draw.connect(_draw_hover)
	add_child(_hover_box)
	_build_exit_arrow()
	_build_ui()


# ---------------------------------------------------------------- efectos

## La tormenta pasa por las ventanas: rachas de polvo recortadas a cada ventana (rectángulo o polígono).
func _build_windows() -> void:
	var shapes: Array = []
	for w in data.get("windows", []):
		shapes.append(PackedVector2Array([Vector2(w[0], w[1]), Vector2(w[2], w[1]), Vector2(w[2], w[3]), Vector2(w[0], w[3])]))
	for poly in data.get("window_polys", []):
		var pts := PackedVector2Array()
		for p in poly:
			pts.append(Vector2(p[0], p[1]))
		shapes.append(pts)
	for pts in shapes:
		var r := Rect2(pts[0], Vector2.ZERO)
		for p in pts:
			r = r.expand(p)
		var mask := Polygon2D.new()  # solo sirve de máscara (no se dibuja)
		mask.position = r.position
		var local := PackedVector2Array()
		for p in pts:
			local.append(p - r.position)
		mask.polygon = local
		mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
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


## Halo de color de la luz de cada puerta y de las lámparas (laten suave).
func _build_lights() -> void:
	var lights: Array = []
	var dl: Array = data.get("door_lights", [])
	for i in dl.size():
		lights.append([dl[i][0], dl[i][1], data.doors[i].color, 1.4])
	lights += data.get("lamps", [])
	for i in lights.size():
		var l: Array = lights[i]
		var g := _glow(Vector2(l[0], l[1]), Color(l[2]), l[3])
		var tw := create_tween().set_loops()
		tw.tween_property(g, "modulate:a", 0.45, 1.1 + i * 0.13).set_trans(Tween.TRANS_SINE)
		tw.tween_property(g, "modulate:a", 0.9, 1.1 + i * 0.13).set_trans(Tween.TRANS_SINE)


## Destellos del sol en los paneles solares.
func _glint_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(0.35, 1.0)).timeout
		var p: Array = data.glints.pick_random()
		var s := Sprite2D.new()
		s.texture = Fx.GLINT
		s.material = _add
		s.position = Vector2(p[0], p[1])
		s.modulate = Color(0.9, 0.97, 1.0)
		s.scale = Vector2.ZERO
		add_child(s)
		var tw := create_tween()
		tw.tween_property(s, "scale", Vector2.ONE * randf_range(1.8, 3.0), 0.18)
		tw.parallel().tween_property(s, "rotation", 0.5, 0.45)
		tw.tween_property(s, "scale", Vector2.ZERO, 0.3)
		tw.tween_callback(s.queue_free)


## Chispas eléctricas: de vez en cuando salta un chorro corto de chispas amarillas.
func _spark_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(0.8, 2.2)).timeout
		var p: Array = data.sparks.pick_random()
		var sp := Fx.particles(Fx.DUST, 14, 0.45, Vector2(0, -1), 80, 60, 160, Vector2(0, 420))
		sp.one_shot = true
		sp.explosiveness = 0.9
		sp.preprocess = 0.0
		sp.position = Vector2(p[0], p[1])
		sp.scale_amount_min = 1.0
		sp.scale_amount_max = 2.0
		sp.color_ramp = Fx.ramp(Color(1, 0.95, 0.5), Color(1, 0.6, 0.1, 0.0))
		sp.material = _add
		add_child(sp)
		sp.emitting = true
		var flash := _glow(Vector2(p[0], p[1]), Color(1, 0.9, 0.5, 0.8), 0.9)
		var tw := create_tween()
		tw.tween_property(flash, "modulate:a", 0.0, 0.25)
		tw.tween_callback(flash.queue_free)
		tw.tween_interval(0.6)
		tw.tween_callback(sp.queue_free)


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
	for r in data.get("grow_lights", []):
		_fx.draw_rect(Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1]), Color(0.85, 0.4, 1.0, grow))
	# Pantallas: gráficas que avanzan, texto que parpadea y el latido de la enfermería
	for s in data.get("screens", []):
		var r := Rect2(s[0], s[1], s[2] - s[0], s[3] - s[1])
		match s[4]:
			"chart":  # barrido suave que recorre la gráfica, siempre dentro del cristal
				var inner := r.grow(-2)
				var x := inner.position.x + fmod(_t * 18.0 + r.position.y, inner.size.x)
				_fx.draw_rect(Rect2(x, inner.position.y, minf(4.0, inner.end.x - x), inner.size.y), Color(0.6, 1, 0.95, 0.22))
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
			"bar":  # batería cargándose: los segmentos se encienden de izquierda a derecha
				var f := fmod(_t * 0.5, 1.25)
				var x0 := r.position.x + r.size.x * minf(f, 1.0)
				if x0 < r.end.x:
					_fx.draw_rect(Rect2(x0, r.position.y, r.end.x - x0, r.size.y), Color(0.05, 0.1, 0.12, 0.6))
	# Luces de estado de los marcos de las puertas
	for i in data.get("status_lights", []).size():
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
	var hint_label := Style.label(hint, 16, Style.WHITE, 5)
	hint_label.position = Vector2(16, 10)
	layer.add_child(hint_label)

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
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	var blocked := Mission.entry_blocked_reason(door.scene)  # p. ej. salir al campo durante una tormenta
	if blocked != "":
		_show_toast(blocked)
	elif ResourceLoader.exists(door.scene):
		_leaving = true
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		SceneChanger.go_to(door.scene)
	else:
		_show_toast("%s  ·  Coming soon" % door.name)


func _show_toast(text: String) -> void:
	_toast.text = text
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.2 + text.length() * 0.03)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _leave() -> void:
	var blocked := Mission.exit_blocked_reason()  # con tormenta moderada o intensa no se sale
	if blocked != "":
		_show_toast(blocked)
		return
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
