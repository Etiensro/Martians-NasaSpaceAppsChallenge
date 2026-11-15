extends Node2D
## Minijuego REGAR del invernadero (scenes/interiores/estacion_ares1/modulos/invernadero/regar.tscn).
## Vista cenital de las 3 camas con 24 brotes. Mantén el clic sobre un brote para regarlo con la regadera:
## el medidor se llena y hay que soltar dentro de la zona verde.
##   - Poca agua  -> tierra húmeda y burbuja de "sed": se puede seguir regando.
##   - En la zona -> tierra empapada y burbuja de "perfecto": brote listo.
##   - Demasiada  -> tierra encharcada y burbuja de "ahogada": se seca un momento y hay que repetir.
## Al regar bien los 24, los brotes crecen y se vuelve al invernadero. Esc: volver.
## Sprites y anclas: assets/interiores/estacion_ares1/invernadero/riego_layout.json (los hizo el equipo).

const Style := preload("res://scripts/core/style.gd")
const Fx := preload("res://scripts/core/fx.gd")

const DIR := "res://assets/interiores/estacion_ares1/invernadero/"
const GREENHOUSE := "res://scenes/interiores/estacion_ares1/modulos/invernadero/invernadero.tscn"
const POUR_SPEED := 0.42      # medidor lleno por segundo
const ZONE_SIZE := 0.2        # alto de la zona verde (parte del medidor)
const PICK_R := 26.0          # radio para elegir un brote
const DRAIN_TIME := 1.4       # lo que tarda en secarse una planta ahogada

enum S { DRY, THIRSTY, OK, DROWNED }

var lay: Dictionary
var plants: Array = []        # {pos, level, lo, hi, state, soil, bubble, sprout}
var _sel := -1                # planta que se está regando
var _pouring := false
var _hover := -1
var _tex := {}
var _can := Sprite2D.new()
var _rain := Sprite2D.new()
var _meter := Control.new()
var _water: NinePatchRect
var _zone: NinePatchRect
var _arrow: TextureRect
var _grown: Sprite2D
var _fx := Node2D.new()
var _counter: Label
var _hint: Label
var _done: Label
var _add := CanvasItemMaterial.new()
var _t := 0.0
var _finished := false


func _ready() -> void:
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	lay = JSON.parse_string(FileAccess.get_file_as_string(DIR + "riego_layout.json"))
	for n in ["regadera", "efectos_riego", "tierra_mojada", "burbujas"]:
		_tex[n] = load(DIR + n + ".png")
	var holes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "huecos_layout.json"))

	var bg := Sprite2D.new()
	bg.texture = load(DIR + "fondo_vacio.png")
	bg.centered = false
	add_child(bg)
	_grown = Sprite2D.new()  # plantas grandes: aparece al terminar
	_grown.texture = load(DIR + "fondo_plantas.png")
	_grown.centered = false
	_grown.modulate.a = 0.0
	_grown.z_index = 5
	add_child(_grown)

	var brote: Texture2D = load(DIR + "brote_1280.png")
	var bc: Array = lay.anclas.brote_centro_hueco
	for cama in holes.camas:
		for h in cama.huecos:
			var pos := Vector2(h.x, h.y)
			var soil := _frame_sprite("tierra_mojada", "humeda", pos, lay.anclas.tierra_mojada_centro)
			soil.visible = false
			var sprout := Sprite2D.new()
			sprout.texture = brote
			sprout.centered = false
			sprout.position = pos - Vector2(bc[0], bc[1])
			add_child(sprout)
			var lo := randf_range(0.45, 0.72)
			plants.append({"pos": pos, "level": 0.0, "lo": lo, "hi": lo + ZONE_SIZE, "state": S.DRY,
				"soil": soil, "sprout": sprout, "bubble": null})
	_fx.draw.connect(_draw_fx)
	_fx.z_index = 6
	add_child(_fx)

	_rain.texture = _atlas("efectos_riego", "lluvia_1")
	_rain.centered = false
	_rain.visible = false
	_rain.z_index = 8
	add_child(_rain)
	_can.texture = _atlas("regadera", "reposo")
	_can.centered = false
	_can.visible = false
	_can.z_index = 9
	add_child(_can)
	_build_meter()
	_build_ui()
	_update_counter()


# ---------------------------------------------------------------- sprites del equipo

func _frame(sheet: String, name: String) -> Dictionary:
	for f in lay.hojas[sheet].frames:
		if f.nombre == name:
			return f
	return {}


func _atlas(sheet: String, name: String) -> AtlasTexture:
	var f := _frame(sheet, name)
	var a := AtlasTexture.new()
	a.atlas = _tex[sheet]
	a.region = Rect2(f.x, f.y, f.w, f.h)
	return a


## Sprite de un cuadro de una hoja, con su "ancla" colocada sobre `at`.
func _frame_sprite(sheet: String, name: String, at: Vector2, anchor: Array) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _atlas(sheet, name)
	s.centered = false
	s.position = at - Vector2(anchor[0], anchor[1])
	add_child(s)
	return s


func _set_frame(s: Sprite2D, sheet: String, name: String) -> void:
	s.texture = _atlas(sheet, name)


# ---------------------------------------------------------------- medidor

func _build_meter() -> void:
	var m: Dictionary = lay.medidor
	var win: Dictionary = m.ventana_agua
	_meter.size = Vector2(m.tamano[0], m.tamano[1])
	_meter.visible = false
	_meter.z_index = 20
	_meter.scale = Vector2.ONE * 1.3
	add_child(_meter)
	var frame := TextureRect.new()
	frame.texture = load(DIR + "medidor_marco.png")
	_meter.add_child(frame)
	_water = NinePatchRect.new()
	_water.texture = load(DIR + "medidor_agua.png")
	_water.patch_margin_top = m.agua_nine_patch.margen_arriba
	_water.position = Vector2(win.x, win.y + win.h)
	_water.size = Vector2(win.w, 0)
	_meter.add_child(_water)
	_zone = NinePatchRect.new()
	_zone.texture = load(DIR + "medidor_zona_verde.png")
	_zone.patch_margin_top = m.zona_nine_patch.margen_arriba
	_zone.patch_margin_bottom = m.zona_nine_patch.margen_abajo
	_meter.add_child(_zone)
	var shine := TextureRect.new()
	shine.texture = load(DIR + "medidor_brillo.png")
	_meter.add_child(shine)
	_arrow = TextureRect.new()
	_arrow.texture = load(DIR + "medidor_flecha.png")
	_meter.add_child(_arrow)


func _update_meter() -> void:
	if _sel < 0:
		_meter.visible = false
		return
	var p: Dictionary = plants[_sel]
	var win: Dictionary = lay.medidor.ventana_agua
	_meter.visible = true
	# a la derecha de la planta, sin salirse de la pantalla
	var at: Vector2 = p.pos + Vector2(40, -150)
	at.x = clampf(at.x, 8, 1280 - _meter.size.x * _meter.scale.x - 8)
	at.y = clampf(at.y, 8, 720 - _meter.size.y * _meter.scale.y - 8)
	_meter.position = at
	var h := float(win.h)
	var lvl := clampf(p.level, 0.0, 1.0)
	_water.size.y = h * lvl
	_water.position.y = win.y + h - _water.size.y
	_zone.texture = load(DIR + ("medidor_zona_roja.png" if p.state == S.DROWNED else "medidor_zona_verde.png"))
	_zone.position = Vector2(win.x - 4, win.y + h * (1.0 - p.hi))
	_zone.size = Vector2(28, h * ZONE_SIZE)
	_arrow.position = Vector2(win.x + win.w + 2, win.y + h * (1.0 - lvl) - 8)


# ---------------------------------------------------------------- UI

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
	var title := Style.brand_title("WATER THE SPROUTS", 26, Style.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_counter = Style.label("", 18, Style.NEON_YELLOW, 0)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_counter)
	_hint = Style.label("Hold the click on a sprout to water it  ·  Release inside the GREEN zone  ·  Esc: back", 16, Style.WHITE, 5)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -560
	_hint.offset_right = 560
	_hint.offset_top = -34
	_hint.offset_bottom = -10
	layer.add_child(_hint)
	_done = Style.brand_title("WATERING COMPLETE!", 48, Style.NEON_YELLOW, 12)
	_done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_done.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_done.offset_left = -500
	_done.offset_right = 500
	_done.offset_top = -40
	_done.offset_bottom = 30
	_done.modulate.a = 0.0
	layer.add_child(_done)


func _update_counter() -> void:
	var ok := 0
	for p in plants:
		if p.state == S.OK:
			ok += 1
	_counter.text = "Sprouts watered:  %d / %d" % [ok, plants.size()]


# ---------------------------------------------------------------- juego

func _process(delta: float) -> void:
	_t += delta
	if _finished:
		return
	var m := get_global_mouse_position()
	_hover = _plant_at(m) if not _pouring else _sel
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if _hover >= 0 else Input.CURSOR_ARROW)
	if _pouring and _sel >= 0:
		var p: Dictionary = plants[_sel]
		p.level += POUR_SPEED * delta
		if p.level > 1.0:  # se desborda: cuenta como soltar
			_release()
		else:
			_update_soil(p)
			var k := int(_t * 10.0) % 3
			_set_frame(_can, "regadera", "vertiendo_%d" % (k + 1))
			_set_frame(_rain, "efectos_riego", "lluvia_%d" % (int(_t * 12.0) % 4 + 1))
	# los brotes regados se mecen un poco
	for i in plants.size():
		var sp: Sprite2D = plants[i].sprout
		sp.skew = sin(_t * 2.0 + i) * (0.06 if plants[i].state == S.OK else 0.02)
	_update_meter()
	_fx.queue_redraw()


func _draw_fx() -> void:
	if _finished:
		return
	for i in plants.size():
		var p: Dictionary = plants[i]
		if p.state == S.OK:
			continue
		var on := i == _hover or i == _sel
		var a := 0.9 if on else 0.22 + 0.12 * sin(_t * 3.0 + i)
		_fx.draw_arc(p.pos + Vector2(0, -6), PICK_R, 0, TAU, 28, Color(0.55, 0.85, 1.0, a), 3.0 if on else 1.5)


func _plant_at(pos: Vector2) -> int:
	for i in plants.size():
		var st: int = plants[i].state
		if st != S.OK and st != S.DROWNED and pos.distance_to(plants[i].pos + Vector2(0, -6)) <= PICK_R:
			return i
	return -1


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		SceneChanger.go_to(GREENHOUSE)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var i := _plant_at(get_global_mouse_position())
			if i >= 0:
				_start_pour(i)
		elif _pouring:
			_release()


func _start_pour(i: int) -> void:
	_sel = i
	_pouring = true
	var p: Dictionary = plants[i]
	_clear_bubble(p)
	var rose: Array = lay.anclas.regadera_roseta
	var rain_at: Array = lay.anclas.lluvia_planta
	var top: Vector2 = p.pos - Vector2(0, 58)  # la roseta queda arriba de la lluvia
	_can.position = top - Vector2(rose[0], rose[1])
	_can.visible = true
	_rain.position = p.pos - Vector2(rain_at[0], rain_at[1])
	_rain.visible = true
	_can.scale = Vector2.ONE * 0.8
	create_tween().tween_property(_can, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)


## Soltar: se evalúa cuánta agua recibió la planta.
func _release() -> void:
	_pouring = false
	_can.visible = false
	_rain.visible = false
	var i := _sel
	var p: Dictionary = plants[i]
	if p.level < p.lo:
		p.state = S.THIRSTY
		_bubble(p, "sed")
	elif p.level <= p.hi:
		p.state = S.OK
		_bubble(p, "perfecto")
		_ripple(p.pos)
		_sparkle(p.pos + Vector2(8, -18))
		_sel = -1
		_update_counter()
		var done := true
		for q in plants:
			if q.state != S.OK:
				done = false
		if done:
			_finish()
	else:
		p.state = S.DROWNED
		_bubble(p, "ahogada")
		_ripple(p.pos)
		_drain(i)
	_update_soil(p)


## Una planta ahogada se seca poco a poco y se puede volver a regar desde cero.
func _drain(i: int) -> void:
	var p: Dictionary = plants[i]
	var tw := create_tween()
	tw.tween_interval(DRAIN_TIME)
	tw.tween_callback(func():
		p.level = 0.0
		p.state = S.DRY
		var lo := randf_range(0.45, 0.72)
		p.lo = lo
		p.hi = lo + ZONE_SIZE
		_clear_bubble(p)
		_update_soil(p)
		if _sel == i:
			_sel = -1)


func _update_soil(p: Dictionary) -> void:
	var soil: Sprite2D = p.soil
	soil.visible = p.level > 0.02
	var name := "humeda"
	if p.state == S.DROWNED or p.level > p.hi:
		name = "encharcada"
	elif p.level >= p.lo:
		name = "empapada"
	_set_frame(soil, "tierra_mojada", name)


func _bubble(p: Dictionary, name: String) -> void:
	_clear_bubble(p)
	var b := _frame_sprite("burbujas", name, p.pos - Vector2(0, 22), lay.anclas.burbuja_punta)
	b.z_index = 10
	var base := b.position
	b.position = base + Vector2(0, 8)
	b.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(b, "position", base, 0.18).set_trans(Tween.TRANS_BACK)
	tw.tween_property(b, "modulate:a", 1.0, 0.12)
	p.bubble = b
	if name == "perfecto":  # la de "perfecto" se va sola
		var out := create_tween()
		out.tween_interval(1.1)
		out.tween_property(b, "modulate:a", 0.0, 0.4)
		out.tween_callback(_clear_bubble.bind(p))


func _clear_bubble(p: Dictionary) -> void:
	if p.bubble and is_instance_valid(p.bubble):
		p.bubble.queue_free()
	p.bubble = null


## Ondas en la tierra mojada (los 4 cuadros de "ondas").
func _ripple(at: Vector2) -> void:
	var s := _frame_sprite("efectos_riego", "ondas_1", at, lay.anclas.ondas_centro)
	s.z_index = 7
	var tw := create_tween()
	for k in range(2, 5):
		tw.tween_interval(0.08)
		tw.tween_callback(_set_frame.bind(s, "efectos_riego", "ondas_%d" % k))
	tw.tween_property(s, "modulate:a", 0.0, 0.2)
	tw.tween_callback(s.queue_free)


func _sparkle(at: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = Fx.GLINT
	s.material = _add
	s.position = at
	s.modulate = Color(0.85, 1, 0.75)
	s.scale = Vector2.ZERO
	s.z_index = 11
	add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector2.ONE * 2.4, 0.15)
	tw.parallel().tween_property(s, "rotation", 0.6, 0.4)
	tw.tween_property(s, "scale", Vector2.ZERO, 0.25)
	tw.tween_callback(s.queue_free)


## Todos regados: los brotes crecen (fundido a las plantas grandes) y vuelta al invernadero.
func _finish() -> void:
	_finished = true
	_meter.visible = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_hint.text = "The sprouts are growing into strong potato plants!"
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(_grown, "modulate:a", 1.0, 1.4)
	tw.parallel().tween_property(_done, "modulate:a", 1.0, 0.4)
	for k in plants.size():
		get_tree().create_timer(0.6 + 0.05 * k).timeout.connect(_sparkle.bind(plants[k].pos + Vector2(-6, -14)))
	tw.tween_interval(2.0)
	tw.tween_callback(SceneChanger.go_to.bind(GREENHOUSE))
