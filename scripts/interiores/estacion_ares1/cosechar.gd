extends Node2D
## Minijuego COSECHAR del invernadero (paso 3) (scenes/interiores/estacion_ares1/modulos/invernadero/cosechar.tscn).
## Vista cenital de las 3 camas con las 24 plantas. Haz clic en una planta y arrástrala HACIA ARRIBA para
## arrancarla: salen sus papas y vuelan al saco. Las papas que salen son las de la cosecha de verdad
## (Mission.crops.expected_harvest(): 24 x rendimiento x rol), repartidas entre las plantas, así que con
## menos rendimiento hay plantas sin papas. La planta se ve sana, débil o marchita según Mission.crops.stage().
## Si las papas murieron, es el mismo minijuego para LIMPIAR las camas: plantas secas y ninguna papa.
## Al arrancar las 24 se llama a Mission.crops.harvest() (o clear()) y se vuelve al invernadero. Esc: volver.
## Plantas: assets/interiores/estacion_ares1/invernadero/plantas/ (tools/build_plantas.py).

const Style := preload("res://scripts/core/style.gd")
const Fx := preload("res://scripts/core/fx.gd")

const DIR := "res://assets/interiores/estacion_ares1/invernadero/"
const GREENHOUSE := "res://scenes/interiores/estacion_ares1/modulos/invernadero/invernadero.tscn"
const SACK := Vector2(1186, 628)          # saco pintado en el fondo (abajo a la derecha)
const PULL := 46.0                        # px que hay que arrastrar hacia arriba para arrancar
const GRAB_R := 30.0                      # radio para agarrar una planta

var clearing := false                     # true = planta muerta: limpiar las camas, sin papas
var plants: Array = []                    # {pos, sprite, potatoes, pulled}
var _potato_tex: Texture2D
var _grab := -1                           # planta agarrada
var _grab_y := 0.0                        # altura del ratón al agarrarla
var _hover := -1
var _count := 0
var _fx := Node2D.new()
var _bar: ProgressBar
var _pct: Label
var _counter: Label
var _hint: Label
var _done: Label
var _add := CanvasItemMaterial.new()
var _t := 0.0
var _finished := false


func _ready() -> void:
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var task: String = Mission.crops.next_task()
	if task != "harvest" and task != "clear":  # nada que cosechar ni limpiar (p. ej. escena abierta sola)
		SceneChanger.go_to(GREENHOUSE)
		return
	clearing = task == "clear"
	_potato_tex = load(DIR + "semilla_32.png")
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "plantas/plantas.json")).planta
	var anchor := Vector2(info.centro_hueco[0], info.centro_hueco[1])
	var plant_tex: Texture2D = load(DIR + "plantas/planta_%d.png" % Mission.crops.stage())

	var bg := Sprite2D.new()
	bg.texture = load(DIR + "fondo_vacio.png")
	bg.centered = false
	add_child(bg)
	_fx.draw.connect(_draw_fx)
	add_child(_fx)

	var holes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "huecos_layout.json"))
	for cama in holes.camas:
		for h in cama.huecos:
			var pos := Vector2(h.x, h.y)
			var s := Sprite2D.new()
			s.texture = plant_tex
			s.centered = false
			s.offset = -anchor  # el hueco queda en la posición del sprite (para estirarlo desde ahí)
			s.position = pos
			s.z_index = 2
			add_child(s)
			plants.append({"pos": pos, "sprite": s, "potatoes": 0, "pulled": false})
	_share_potatoes(0 if clearing else Mission.crops.expected_harvest())
	_build_ui()
	_update_progress()


## Reparte las papas de la cosecha entre las plantas (al azar las que sobran o las que faltan).
func _share_potatoes(total: int) -> void:
	var order := range(plants.size())
	order.shuffle()
	for k in total:
		plants[order[k % plants.size()]].potatoes += 1


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.box(Style.NAVY_SOFT, Style.NEON_YELLOW, 3, 14))
	panel.position = Vector2(440, 8)
	panel.custom_minimum_size = Vector2(400, 0)
	layer.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var title := Style.brand_title("STEP 3 · CLEAR THE BEDS" if clearing else "STEP 3 · HARVEST", 22, Style.WHITE)
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

	if not clearing:  # contador de papas a la izquierda del saco
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", Style.box(Style.NAVY_SOFT, Style.NEON_YELLOW, 3, 8))
		box.position = SACK + Vector2(-250, 0)
		layer.add_child(box)
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 8)
		box.add_child(row2)
		var icon := TextureRect.new()
		icon.texture = _potato_tex
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row2.add_child(icon)
		row2.add_child(Style.label("POTATOES", 16, Style.WHITE, 0))
		_counter = Style.brand_title("0", 26, Style.NEON_YELLOW)
		_counter.custom_minimum_size = Vector2(36, 0)
		row2.add_child(_counter)

	var text := "The plants died. Click a dry plant and drag it UP to pull it out" if clearing \
		else "Click a plant and drag it UP to pull out the potatoes"
	_hint = Style.label(text + "  ·  Esc: back", 16, Style.WHITE, 5)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -560
	_hint.offset_right = 560
	_hint.offset_top = -34
	_hint.offset_bottom = -10
	layer.add_child(_hint)
	_done = Style.brand_title("", 48, Style.NEON_YELLOW, 12)
	_done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_done.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_done.offset_left = -560
	_done.offset_right = 560
	_done.offset_top = -40
	_done.offset_bottom = 30
	_done.modulate.a = 0.0
	layer.add_child(_done)


func _update_progress() -> void:
	var pulled := plants.filter(func(p): return p.pulled).size()
	var v := 100.0 * pulled / plants.size()
	create_tween().tween_property(_bar, "value", v, 0.15)
	_pct.text = "%d %%" % roundi(v)


# ---------------------------------------------------------------- juego

func _process(delta: float) -> void:
	_t += delta
	if _finished:
		return
	var m := get_global_mouse_position()
	if _grab >= 0:
		var lift := clampf(_grab_y - m.y, 0.0, PULL)
		var s: Sprite2D = plants[_grab].sprite
		s.position = plants[_grab].pos + Vector2(sin(_t * 40.0) * lift * 0.05, -lift * 0.35)  # tira y tiembla
		s.scale = Vector2(1.0 - lift / PULL * 0.12, 1.0 + lift / PULL * 0.25)
		if lift >= PULL:
			_pull(_grab)
	else:
		_hover = _plant_at(m)
		Input.set_default_cursor_shape(Input.CURSOR_DRAG if _hover >= 0 else Input.CURSOR_ARROW)
	_fx.queue_redraw()


func _plant_at(p: Vector2) -> int:
	var best := -1
	var best_d := GRAB_R
	for i in plants.size():
		if plants[i].pulled:
			continue
		var d: float = p.distance_to(plants[i].pos + Vector2(0, -6))
		if d <= best_d:
			best_d = d
			best = i
	return best


func _draw_fx() -> void:
	if _finished:
		return
	var i := _grab if _grab >= 0 else _hover
	if i >= 0:  # anillo en la planta que se agarra
		var a := 0.55 + 0.35 * sin(_t * 6.0)
		_fx.draw_arc(plants[i].pos, GRAB_R, 0, TAU, 32, Color(Style.NEON_YELLOW, a), 3.0)
		_fx.draw_colored_polygon(PackedVector2Array([plants[i].pos + Vector2(-8, -GRAB_R - 26),
			plants[i].pos + Vector2(8, -GRAB_R - 26), plants[i].pos + Vector2(0, -GRAB_R - 38)]),
			Color(Style.NEON_YELLOW, a))  # flechita: hacia arriba


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_back()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_grab = _plant_at(get_global_mouse_position())
			_grab_y = get_global_mouse_position().y
		elif _grab >= 0:  # se soltó antes de arrancarla: vuelve a su sitio
			_settle(_grab)
			_grab = -1


func _settle(i: int) -> void:
	var s: Sprite2D = plants[i].sprite
	var tw := create_tween().set_parallel()
	tw.tween_property(s, "position", plants[i].pos, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "scale", Vector2.ONE, 0.2)


## Arranca la planta: sale volando hacia arriba, polvo de tierra y sus papas saltan al saco.
func _pull(i: int) -> void:
	var p: Dictionary = plants[i]
	p.pulled = true
	_grab = -1
	var s: Sprite2D = p.sprite
	var tw := create_tween().set_parallel()
	tw.tween_property(s, "position:y", p.pos.y - 70, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(s, "rotation", randf_range(-0.5, 0.5), 0.4)
	tw.tween_property(s, "modulate:a", 0.0, 0.4).set_delay(0.15)
	tw.chain().tween_callback(s.queue_free)
	_puff(p.pos, Color(0.55, 0.32, 0.18, 0.9), 14)
	for k in p.potatoes:
		_potato(p.pos, k)
	if p.potatoes == 0 and not clearing:
		_float_text(p.pos, "no potatoes", Color(1, 0.75, 0.5))
	_update_progress()
	if plants.all(func(q): return q.pulled):
		_finish()


## Una papa salta del hueco y vuela al saco; al llegar suma al contador.
func _potato(from: Vector2, k: int) -> void:
	var s := Sprite2D.new()
	s.texture = _potato_tex
	s.position = from
	s.z_index = 5
	add_child(s)
	var top := from + Vector2(randf_range(-30, 30) + k * 14, -50 - k * 10)
	var tw := create_tween()
	tw.tween_property(s, "position", top, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_interval(0.1 + 0.08 * k)
	tw.tween_property(s, "position", SACK, 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(s, "scale", Vector2.ONE * 0.6, 0.55)
	tw.tween_callback(_potato_in.bind(s))


func _potato_in(s: Sprite2D) -> void:
	s.queue_free()
	_count += 1
	_counter.text = str(_count)
	_counter.pivot_offset = _counter.size / 2.0
	var tw := create_tween()
	tw.tween_property(_counter, "scale", Vector2.ONE * 1.3, 0.06)
	tw.tween_property(_counter, "scale", Vector2.ONE, 0.12)
	_sparkle(SACK + Vector2(randf_range(-20, 20), -20))


func _float_text(at: Vector2, text: String, color: Color) -> void:
	var l := Style.label(text, 14, color, 4)
	l.position = at + Vector2(-40, -40)
	l.z_index = 10
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 24, 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9)
	tw.tween_callback(l.queue_free)


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
	s.z_index = 11
	add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector2.ONE * 2.4, 0.15)
	tw.parallel().tween_property(s, "rotation", 0.6, 0.4)
	tw.tween_property(s, "scale", Vector2.ZERO, 0.25)
	tw.tween_callback(s.queue_free)


## 24 arrancadas: cartel con el resultado, se registra la tarea y vuelta al invernadero.
func _finish() -> void:
	_finished = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if clearing:
		_done.text = "BEDS CLEARED!"
		_hint.text = "The beds are ready. Plant new seed potatoes and water them every sol!"
	else:
		var total: int = Mission.crops.expected_harvest()
		_done.text = "HARVEST: %d POTATOES!" % total
		var lost := roundi((1.0 - Mission.crops.yield_ratio()) * 100.0)
		_hint.text = "Perfect harvest! Every potato is one meal." if lost == 0 \
			else "Missed waterings cost you %d %% of the harvest. Water every sol!" % lost
	var tw := create_tween()
	tw.tween_interval(1.2)  # deja que lleguen las últimas papas
	tw.tween_property(_done, "modulate:a", 1.0, 0.4)
	tw.tween_interval(2.4)
	tw.tween_callback(_after)


## Registra la tarea en Mission.crops (el reloj avanza lo que dura) y vuelve al invernadero.
func _after() -> void:
	var why := ""
	if clearing:
		why = await Mission.crops.clear()
	else:
		why = await Mission.crops.harvest()
	if why != "":
		Mission.notify(why)
	SceneChanger.go_to(GREENHOUSE)


func _go_back() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	SceneChanger.go_to(GREENHOUSE)
