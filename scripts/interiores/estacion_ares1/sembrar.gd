extends Node2D
## Minijuego SEMBRAR del invernadero (scenes/interiores/estacion_ares1/modulos/invernadero/sembrar.tscn).
## Vista cenital de las 3 camas con 24 huecos. Clic en el saco para tomar una papa-semilla y clic en un
## hueco vacío para sembrarla; así hasta llenar los 24. Al terminar salen los brotes y se vuelve al
## invernadero. Esc / clic derecho: suelta la semilla (o sale si no llevas ninguna).

const Style := preload("res://scripts/core/style.gd")
const Fx := preload("res://scripts/core/fx.gd")

const DIR := "res://assets/interiores/estacion_ares1/invernadero/"
const GREENHOUSE := "res://scenes/interiores/estacion_ares1/modulos/invernadero/invernadero.tscn"
const SACK := Rect2(1124, 566, 140, 140)  # saco de papas-semilla (pintado en el fondo)
const HOLE_R := 22.0                      # radio para acertar en un hueco

var holes: Array[Vector2] = []
var planted: Array[bool] = []
var _holding := false
var _hover_hole := -1
var _seed_tex: Texture2D
var _cursor_seed := Sprite2D.new()
var _fx := Node2D.new()
var _sprouts: Sprite2D
var _counter: Label
var _hint: Label
var _done: Label
var _add := CanvasItemMaterial.new()
var _t := 0.0
var _finished := false


func _ready() -> void:
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "huecos_layout.json"))
	for cama in data.camas:
		for h in cama.huecos:
			holes.append(Vector2(h.x, h.y))
			planted.append(false)
	_seed_tex = load(DIR + "semilla_32.png")

	var bg := Sprite2D.new()
	bg.texture = load(DIR + "fondo_vacio.png")
	bg.centered = false
	add_child(bg)
	_sprouts = Sprite2D.new()  # fondo con brotes: aparece al terminar
	_sprouts.texture = load(DIR + "fondo_brotes.png")
	_sprouts.centered = false
	_sprouts.modulate.a = 0.0
	add_child(_sprouts)
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_cursor_seed.texture = _seed_tex
	_cursor_seed.scale = Vector2.ONE * 1.4
	_cursor_seed.visible = false
	_cursor_seed.z_index = 50
	add_child(_cursor_seed)
	_build_ui()
	_update_counter()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.box(Style.NAVY_SOFT, Style.NEON_YELLOW, 3, 14))
	panel.position = Vector2(470, 8)
	panel.custom_minimum_size = Vector2(340, 0)
	layer.add_child(panel)
	var col := VBoxContainer.new()
	panel.add_child(col)
	var title := Style.brand_title("PLANT THE SEEDS", 26, Style.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_counter = Style.label("", 18, Style.NEON_YELLOW, 0)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_counter)
	_hint = Style.label("", 16, Style.WHITE, 5)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -500
	_hint.offset_right = 500
	_hint.offset_top = -34
	_hint.offset_bottom = -10
	layer.add_child(_hint)
	_done = Style.brand_title("PLANTING COMPLETE!", 48, Style.NEON_YELLOW, 12)
	_done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_done.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_done.offset_left = -500
	_done.offset_right = 500
	_done.offset_top = -40
	_done.offset_bottom = 30
	_done.modulate.a = 0.0
	layer.add_child(_done)


func _update_counter() -> void:
	_counter.text = "Seed potatoes planted:  %d / %d" % [planted.count(true), holes.size()]
	_hint.text = ("Click an empty hole to plant it  ·  Right click: drop it" if _holding
		else "Click the sack to take a seed potato  ·  Esc: back")


# ---------------------------------------------------------------- dibujo

func _draw_fx() -> void:
	# semillas ya sembradas
	for i in holes.size():
		if planted[i] and _sprouts.modulate.a < 1.0:
			_fx.draw_texture(_seed_tex, holes[i] - _seed_tex.get_size() / 2.0, Color(1, 1, 1, 1.0 - _sprouts.modulate.a))
	if _finished:
		return
	# saco: brilla mientras no llevas semilla
	if not _holding:
		var a := 0.55 + 0.45 * sin(_t * 5.0)
		_fx.draw_rect(SACK.grow(3), Color(Style.NEON_YELLOW, a), false, 4)
		var bob := sin(_t * 6.0) * 6.0
		var tip := Vector2(SACK.get_center().x, SACK.position.y - 12 + bob)
		_fx.draw_colored_polygon(PackedVector2Array([tip + Vector2(-14, -18), tip + Vector2(14, -18), tip]), Style.NEON_YELLOW)
	else:
		# huecos libres: anillo suave; el que está bajo el cursor, más fuerte
		for i in holes.size():
			if planted[i]:
				continue
			var on := i == _hover_hole
			var pulse := 0.25 + 0.15 * sin(_t * 4.0 + i)
			_fx.draw_arc(holes[i], HOLE_R + (4.0 if on else 0.0), 0, TAU, 24,
				Color(Style.NEON_YELLOW, 1.0 if on else pulse), 3.0 if on else 2.0)


# ---------------------------------------------------------------- interacción

func _process(delta: float) -> void:
	_t += delta
	var m := get_global_mouse_position()
	_cursor_seed.position = m + Vector2(0, -4)
	_cursor_seed.rotation = sin(_t * 8.0) * 0.08
	_hover_hole = _hole_at(m) if _holding else -1
	if not _finished:
		var over := (_holding and _hover_hole >= 0) or (not _holding and SACK.has_point(m))
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if over else Input.CURSOR_ARROW)
	_fx.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_RIGHT):
		get_viewport().set_input_as_handled()
		if _holding:
			_set_holding(false)
		elif event.is_action_pressed("ui_cancel"):
			_leave()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_global_mouse_position()
		if not _holding and SACK.has_point(m):
			_take_seed()
		elif _holding:
			var i := _hole_at(m)
			if i >= 0:
				_plant(i)


func _hole_at(p: Vector2) -> int:
	for i in holes.size():
		if not planted[i] and p.distance_to(holes[i]) <= HOLE_R:
			return i
	return -1


func _take_seed() -> void:
	_set_holding(true)
	_puff(get_global_mouse_position(), Color(0.75, 0.6, 0.4, 0.8), 6)


func _set_holding(v: bool) -> void:
	_holding = v
	_cursor_seed.visible = v
	if v:  # pequeño "pop" al tomarla
		_cursor_seed.scale = Vector2.ONE * 0.6
		create_tween().tween_property(_cursor_seed, "scale", Vector2.ONE * 1.4, 0.15).set_trans(Tween.TRANS_BACK)
	_update_counter()


## La semilla cae al hueco: polvo de tierra, destello y contador.
func _plant(i: int) -> void:
	_set_holding(false)
	var s := Sprite2D.new()
	s.texture = _seed_tex
	s.position = get_global_mouse_position()
	s.scale = Vector2.ONE * 1.4
	add_child(s)
	var tw := create_tween().set_parallel()
	tw.tween_property(s, "position", holes[i], 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(s, "scale", Vector2.ONE, 0.16)
	await tw.finished
	s.queue_free()
	planted[i] = true
	_puff(holes[i], Color(0.55, 0.32, 0.18, 0.9), 10)
	_sparkle(holes[i])
	_update_counter()
	_counter.pivot_offset = _counter.size / 2.0
	var bump := create_tween()
	bump.tween_property(_counter, "scale", Vector2.ONE * 1.12, 0.08)
	bump.tween_property(_counter, "scale", Vector2.ONE, 0.12)
	if planted.count(false) == 0:
		_finish()


func _puff(at: Vector2, color: Color, amount: int) -> void:
	var p := Fx.particles(Fx.PUFF, amount, 0.5, Vector2(0, -1), 180, 30, 80, Vector2(0, 120))
	p.one_shot = true
	p.explosiveness = 0.95
	p.preprocess = 0.0
	p.position = at
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.8
	p.color_ramp = Fx.ramp(color)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func _sparkle(at: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = Fx.GLINT
	s.material = _add
	s.position = at + Vector2(10, -10)
	s.modulate = Color(1, 1, 0.7)
	s.scale = Vector2.ZERO
	add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector2.ONE * 2.4, 0.15)
	tw.parallel().tween_property(s, "rotation", 0.6, 0.4)
	tw.tween_property(s, "scale", Vector2.ZERO, 0.25)
	tw.tween_callback(s.queue_free)


## Los 24 sembrados: salen los brotes (fundido), destellos por todas las camas y vuelta al invernadero.
func _finish() -> void:
	_finished = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_hint.text = "Great job! The seed potatoes are starting to sprout."
	var tw := create_tween()
	tw.tween_property(_sprouts, "modulate:a", 1.0, 1.2)
	tw.parallel().tween_property(_done, "modulate:a", 1.0, 0.4)
	for k in holes.size():
		get_tree().create_timer(0.04 * k).timeout.connect(_sparkle.bind(holes[k] + Vector2(-10, 0)))
	tw.tween_interval(2.2)
	tw.tween_callback(_leave)


func _leave() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	SceneChanger.go_to(GREENHOUSE)
