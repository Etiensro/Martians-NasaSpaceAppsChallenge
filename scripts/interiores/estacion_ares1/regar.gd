extends Node2D
## Minijuego REGAR del invernadero (paso 2) (scenes/interiores/estacion_ares1/modulos/invernadero/regar.tscn).
## Vista cenital de las 3 camas con 24 brotes, regados por COLUMNAS (6 columnas de 4 brotes).
## Pasa el mouse por una columna: la regadera riega y el medidor sube. Haz CLIC justo cuando el agua esté
## en la zona verde para cerrar la regadera:
##   - Clic antes de la zona -> tierra húmeda y burbuja de "sed": vuelve a regar para llegar.
##   - Clic en la zona       -> tierra empapada y burbuja de "perfecto": columna lista.
##   - Clic tarde o no clic  -> tierra encharcada y burbuja de "ahogada": se seca y hay que repetir.
## Si sacas el mouse de la columna sin hacer clic, la regadera se detiene y el agua se queda como está.
## La barra de progreso debe llegar al 100 %; entonces los brotes crecen, se desbloquea el paso 3 y se vuelve
## al invernadero. Esc: volver.
## Sprites y anclas: assets/interiores/estacion_ares1/invernadero/riego_layout.json (los hizo el equipo).

const Style := preload("res://scripts/core/style.gd")
const Fx := preload("res://scripts/core/fx.gd")

const DIR := "res://assets/interiores/estacion_ares1/invernadero/"
const GREENHOUSE := "res://scenes/interiores/estacion_ares1/modulos/invernadero/invernadero.tscn"
const POUR_SPEED := 0.42      # medidor lleno por segundo
const ZONE_SIZE := 0.2        # alto de la zona verde (parte del medidor)
const DRAIN_TIME := 1.4       # lo que tarda en secarse una columna ahogada

enum S { DRY, THIRSTY, OK, DROWNED }

var lay: Dictionary
var plants: Array = []        # {pos, soil, sprout, bubble}
var rows: Array = []          # columnas: {plants: [índices], rect, level, lo, hi, state}
var _sel := -1                # columna que se está regando
var _tex := {}
var _can := Sprite2D.new()
var _rains: Array[Sprite2D] = []
var _meter := Control.new()
var _water: NinePatchRect
var _zone: NinePatchRect
var _arrow: TextureRect
var _grown: Sprite2D
var _fx := Node2D.new()
var _bar: ProgressBar
var _pct: Label
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
	_grown = Sprite2D.new()  # plantas grandes: aparecen al terminar
	_grown.texture = load(DIR + "fondo_plantas.png")
	_grown.centered = false
	_grown.modulate.a = 0.0
	_grown.z_index = 5
	add_child(_grown)

	var brote: Texture2D = load(DIR + "brote_1280.png")
	var bc: Array = lay.anclas.brote_centro_hueco
	for cama in holes.camas:
		var by_row := {}
		for h in cama.huecos:
			var pos := Vector2(h.x, h.y)
			var soil := _frame_sprite("tierra_mojada", "humeda", pos, lay.anclas.tierra_mojada_centro)
			soil.visible = false
			var sprout := Sprite2D.new()
			sprout.texture = brote
			sprout.centered = false
			sprout.position = pos - Vector2(bc[0], bc[1])
			add_child(sprout)
			plants.append({"pos": pos, "soil": soil, "sprout": sprout, "bubble": null})
			if not by_row.has(h.col):
				by_row[h.col] = []
			by_row[h.col].append(plants.size() - 1)
		for f in by_row:
			var idx: Array = by_row[f]
			var r := Rect2(plants[idx[0]].pos, Vector2.ZERO)
			for i in idx:
				r = r.expand(plants[i].pos)
			var row := {"plants": idx, "rect": r.grow_individual(36, 34, 36, 30), "level": 0.0, "state": S.DRY}
			_new_zone(row)
			rows.append(row)
	_fx.draw.connect(_draw_fx)
	_fx.z_index = 6
	add_child(_fx)

	for k in 4:  # una lluvia por brote de la columna
		var rain := Sprite2D.new()
		rain.texture = _atlas("efectos_riego", "lluvia_1")
		rain.centered = false
		rain.visible = false
		rain.z_index = 8
		add_child(rain)
		_rains.append(rain)
	_can.texture = _atlas("regadera", "reposo")
	_can.centered = false
	_can.visible = false
	_can.z_index = 9
	add_child(_can)
	_build_meter()
	_build_ui()
	_update_progress()


func _new_zone(row: Dictionary) -> void:
	var lo := randf_range(0.45, 0.72)
	row.lo = lo
	row.hi = lo + ZONE_SIZE


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
	var row: Dictionary = rows[_sel]
	var win: Dictionary = lay.medidor.ventana_agua
	_meter.visible = true
	# a la derecha de la columna, sin salirse de la pantalla
	var r: Rect2 = row.rect
	var at := Vector2(r.end.x + 6, r.get_center().y - _meter.size.y * _meter.scale.y / 2.0)
	at.x = clampf(at.x, 8, 1280 - _meter.size.x * _meter.scale.x - 8)
	at.y = clampf(at.y, 8, 720 - _meter.size.y * _meter.scale.y - 8)
	_meter.position = at
	var h := float(win.h)
	var lvl := clampf(row.level, 0.0, 1.0)
	_water.size.y = h * lvl
	_water.position.y = win.y + h - _water.size.y
	_zone.texture = load(DIR + ("medidor_zona_roja.png" if row.state == S.DROWNED else "medidor_zona_verde.png"))
	_zone.position = Vector2(win.x - 4, win.y + h * (1.0 - row.hi))
	_zone.size = Vector2(28, h * ZONE_SIZE)
	_arrow.position = Vector2(win.x + win.w + 2, win.y + h * (1.0 - lvl) - 8)


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
	var title := Style.brand_title("STEP 2 · WATER THE SPROUTS", 22, Style.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 10)
	col.add_child(bar_row)
	_bar = Style.progress_bar(300, 18)
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(_bar)
	_pct = Style.label("0 %", 18, Style.NEON_YELLOW, 0)
	bar_row.add_child(_pct)
	_hint = Style.label("Move the mouse over a column to water it  ·  CLICK when the water is in the GREEN zone  ·  Esc: back", 16, Style.WHITE, 5)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -600
	_hint.offset_right = 600
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


func _update_progress() -> void:
	var ok := 0
	for row in rows:
		if row.state == S.OK:
			ok += 1
	var v := 100.0 * ok / rows.size()
	create_tween().tween_property(_bar, "value", v, 0.2)
	_pct.text = "%d %%" % roundi(v)


# ---------------------------------------------------------------- juego

func _process(delta: float) -> void:
	_t += delta
	if _finished:
		return
	var under := _row_at(get_global_mouse_position())
	if _sel >= 0 and under != _sel:
		_pause()              # el mouse salió de la columna sin hacer clic: se detiene
	if _sel < 0 and under >= 0:
		_start_pour(under)    # entró a una columna sin regar
	if _sel >= 0:
		var row: Dictionary = rows[_sel]
		row.level += POUR_SPEED * delta
		if row.level > 1.0:   # se desborda: no hizo clic a tiempo
			_release()
		else:
			_update_soil(row)
			_set_frame(_can, "regadera", "vertiendo_%d" % (int(_t * 10.0) % 3 + 1))
			for rain in _rains:
				_set_frame(rain, "efectos_riego", "lluvia_%d" % (int(_t * 12.0) % 4 + 1))
	for i in plants.size():  # los brotes se mecen un poco
		var sp: Sprite2D = plants[i].sprout
		sp.skew = sin(_t * 2.0 + i) * 0.04
	_update_meter()
	_fx.queue_redraw()


func _draw_fx() -> void:
	if _finished:
		return
	for i in rows.size():  # columnas por regar: recuadro que late; la activa, más fuerte
		var row: Dictionary = rows[i]
		if row.state == S.OK:
			continue
		var on := i == _sel
		var a := 0.9 if on else 0.2 + 0.12 * sin(_t * 3.0 + i)
		var c := Color(1, 0.45, 0.4) if row.state == S.DROWNED else Color(0.55, 0.85, 1.0)
		_fx.draw_rect(row.rect, Color(c, a), false, 3.0 if on else 1.5)


func _row_at(pos: Vector2) -> int:
	for i in rows.size():
		var st: int = rows[i].state
		if st != S.OK and st != S.DROWNED and rows[i].rect.has_point(pos):
			return i
	return -1


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		SceneChanger.go_to(GREENHOUSE)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _sel >= 0:
		_release()  # clic: se cierra la regadera y se evalúa


## Sale de la columna sin clic: la regadera se va y el agua se queda como está (si ya pasó la zona, se ahoga).
func _pause() -> void:
	var row: Dictionary = rows[_sel]
	if row.level > row.hi:
		_release()
		return
	_sel = -1
	_hide_can()
	if row.level > 0.02:
		row.state = S.THIRSTY
		_bubbles(row, "sed")


func _hide_can() -> void:
	_can.visible = false
	for rain in _rains:
		rain.visible = false


func _start_pour(i: int) -> void:
	_sel = i
	var row: Dictionary = rows[i]
	for k in row.plants:
		_clear_bubble(plants[k])
	var rose: Array = lay.anclas.regadera_roseta
	var rain_at: Array = lay.anclas.lluvia_planta
	var r: Rect2 = row.rect
	_can.position = Vector2(r.get_center().x, r.position.y - 22) - Vector2(rose[0], rose[1])
	_can.visible = true
	_can.scale = Vector2.ONE * 0.8
	create_tween().tween_property(_can, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	for k in _rains.size():
		var rain := _rains[k]
		rain.visible = k < row.plants.size()
		if rain.visible:
			rain.position = plants[row.plants[k]].pos - Vector2(rain_at[0], rain_at[1])


## Clic (o se desbordó): se evalúa cuánta agua recibió la columna.
func _release() -> void:
	var i := _sel
	_sel = -1
	_hide_can()
	var row: Dictionary = rows[i]
	if row.level < row.lo:
		row.state = S.THIRSTY
		_bubbles(row, "sed")
	elif row.level <= row.hi:
		row.state = S.OK
		_bubbles(row, "perfecto")
		for k in row.plants:
			_ripple(plants[k].pos)
			_sparkle(plants[k].pos + Vector2(8, -18))
		_update_progress()
		if rows.all(func(r): return r.state == S.OK):
			_finish()
	else:
		row.state = S.DROWNED
		_bubbles(row, "ahogada")
		for k in row.plants:
			_ripple(plants[k].pos)
		_drain(row)
	_update_soil(row)


## Una columna ahogada se seca poco a poco y se puede volver a regar desde cero (otra zona verde).
func _drain(row: Dictionary) -> void:
	var tw := create_tween()
	tw.tween_interval(DRAIN_TIME)
	tw.tween_callback(func():
		row.level = 0.0
		row.state = S.DRY
		_new_zone(row)
		for k in row.plants:
			_clear_bubble(plants[k])
		_update_soil(row))


func _update_soil(row: Dictionary) -> void:
	var name := "humeda"
	if row.state == S.DROWNED or row.level > row.hi:
		name = "encharcada"
	elif row.level >= row.lo:
		name = "empapada"
	for k in row.plants:
		var soil: Sprite2D = plants[k].soil
		soil.visible = row.level > 0.02
		_set_frame(soil, "tierra_mojada", name)


func _bubbles(row: Dictionary, name: String) -> void:
	for k in row.plants:
		var p: Dictionary = plants[k]
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


## 100 %: los brotes crecen (fundido a las plantas grandes), se desbloquea el paso 3 y vuelta al invernadero.
func _finish() -> void:
	_finished = true
	_meter.visible = false
	GameState.greenhouse_step = maxi(GameState.greenhouse_step, 2)
	_hint.text = "The sprouts are growing into strong potato plants!"
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(_grown, "modulate:a", 1.0, 1.4)
	tw.parallel().tween_property(_done, "modulate:a", 1.0, 0.4)
	for k in plants.size():
		get_tree().create_timer(0.6 + 0.05 * k).timeout.connect(_sparkle.bind(plants[k].pos + Vector2(-6, -14)))
	tw.tween_interval(2.0)
	tw.tween_callback(_after_watering)


## Registra la tarea en Mission.crops (el reloj avanza lo que dura) y vuelve al invernadero.
func _after_watering() -> void:
	var why: String = await Mission.crops.water()
	if why != "":
		Mission.notify(why)
	SceneChanger.go_to(GREENHOUSE)
