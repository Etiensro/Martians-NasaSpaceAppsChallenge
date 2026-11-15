extends Node2D
## Minijuego SEMBRAR del invernadero (paso 1) (scenes/interiores/estacion_ares1/modulos/invernadero/sembrar.tscn).
## Vista cenital de las 3 camas con 24 huecos. Llevas una papa-semilla en la mano (el cursor): basta con
## pasar el mouse por un hueco vacío para sembrarlo. La barra de progreso debe llegar al 100 %; entonces
## salen los brotes, se desbloquea el paso 2 (regar) y se vuelve al invernadero. Esc: volver.

const Style := preload("res://scripts/core/style.gd")
const Fx := preload("res://scripts/core/fx.gd")

const DIR := "res://assets/interiores/estacion_ares1/invernadero/"
const GREENHOUSE := "res://scenes/interiores/estacion_ares1/modulos/invernadero/invernadero.tscn"
const HOLE_R := 24.0                      # radio para sembrar al pasar el mouse

var holes: Array[Vector2] = []
var planted: Array[bool] = []
var _seed_tex: Texture2D
var _hand := Sprite2D.new()               # papa en la mano (sigue al cursor)
var _fx := Node2D.new()
var _sprouts: Sprite2D
var _bar: ProgressBar
var _pct: Label
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
	_hand.texture = _seed_tex
	_hand.scale = Vector2.ONE * 1.4
	_hand.z_index = 50
	add_child(_hand)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)  # la papa hace de cursor
	_build_ui()
	_update_progress()


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_build_task_panel(layer, "STEP 1 · PLANT THE SEEDS")
	_hint = Style.label("Move the mouse over the holes to plant the seed potatoes  ·  Esc: back", 16, Style.WHITE, 5)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -560
	_hint.offset_right = 560
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


## Panel de arriba: título del paso y barra de progreso con su porcentaje.
func _build_task_panel(layer: CanvasLayer, title_text: String) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.box(Style.NAVY_SOFT, Style.NEON_YELLOW, 3, 14))
	panel.position = Vector2(440, 8)
	panel.custom_minimum_size = Vector2(400, 0)
	layer.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var title := Style.brand_title(title_text, 22, Style.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	_bar = Style.progress_bar(300, 18)
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_bar)
	_pct = Style.label("0 %", 18, Style.NEON_YELLOW, 0)
	row.add_child(_pct)


func _update_progress() -> void:
	var v := 100.0 * planted.count(true) / holes.size()
	create_tween().tween_property(_bar, "value", v, 0.15)
	_pct.text = "%d %%" % roundi(v)


# ---------------------------------------------------------------- juego

func _process(delta: float) -> void:
	_t += delta
	var m := get_global_mouse_position()
	_hand.position = m
	_hand.rotation = sin(_t * 8.0) * 0.08
	if not _finished:
		for i in holes.size():
			if not planted[i] and m.distance_to(holes[i]) <= HOLE_R:
				_plant(i)
	_fx.queue_redraw()


func _draw_fx() -> void:
	for i in holes.size():  # semillas sembradas (se desvanecen cuando salen los brotes)
		if planted[i] and _sprouts.modulate.a < 1.0:
			_fx.draw_texture(_seed_tex, holes[i] - _seed_tex.get_size() / 2.0, Color(1, 1, 1, 1.0 - _sprouts.modulate.a))
	if _finished:
		return
	for i in holes.size():  # huecos que faltan: anillo que late
		if not planted[i]:
			var pulse := 0.3 + 0.25 * sin(_t * 4.0 + i * 0.7)
			_fx.draw_arc(holes[i], HOLE_R - 2, 0, TAU, 24, Color(Style.NEON_YELLOW, pulse), 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _finished:
		get_viewport().set_input_as_handled()
		SceneChanger.go_to(GREENHOUSE)


## La papa cae al hueco: polvo de tierra, destello y la barra avanza.
func _plant(i: int) -> void:
	planted[i] = true
	var s := Sprite2D.new()
	s.texture = _seed_tex
	s.position = _hand.position
	s.scale = Vector2.ONE * 1.4
	add_child(s)
	var tw := create_tween().set_parallel()
	tw.tween_property(s, "position", holes[i], 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(s, "scale", Vector2.ONE, 0.12)
	tw.chain().tween_callback(s.queue_free)
	tw.chain().tween_callback(_puff.bind(holes[i], Color(0.55, 0.32, 0.18, 0.9), 10))
	_sparkle(holes[i] + Vector2(10, -10))
	_update_progress()
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
	s.position = at
	s.modulate = Color(1, 1, 0.7)
	s.scale = Vector2.ZERO
	add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector2.ONE * 2.4, 0.15)
	tw.parallel().tween_property(s, "rotation", 0.6, 0.4)
	tw.tween_property(s, "scale", Vector2.ZERO, 0.25)
	tw.tween_callback(s.queue_free)


## 100 %: salen los brotes, se desbloquea el paso 2 (regar) y vuelta al invernadero.
func _finish() -> void:
	_finished = true
	GameState.greenhouse_step = maxi(GameState.greenhouse_step, 1)
	_hint.text = "Great job! The seed potatoes are starting to sprout. Next step: water them."
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(_sprouts, "modulate:a", 1.0, 1.2)
	tw.parallel().tween_property(_done, "modulate:a", 1.0, 0.4)
	for k in holes.size():
		get_tree().create_timer(0.3 + 0.04 * k).timeout.connect(_sparkle.bind(holes[k] + Vector2(-10, 0)))
	tw.tween_interval(2.0)
	tw.tween_callback(_after_planting)


## Registra la tarea en Mission.crops (el reloj avanza lo que dura) y vuelve al invernadero.
func _after_planting() -> void:
	var why: String = await Mission.crops.plant()
	if why != "":
		Mission.notify(why)
	SceneChanger.go_to(GREENHOUSE)
