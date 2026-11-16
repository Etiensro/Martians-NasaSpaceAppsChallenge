extends Node2D
## Invernadero de la Estación Ares 1 (scenes/interiores/estacion_ares1/modulos/invernadero/invernadero.tscn).
## Las tareas siguen al cultivo (Mission.crops.next_task()): 1) sembrar (semillas), 2) regar cada sol
## (tanque de agua), 3) cosechar a los 8 sols (camas). Si las papas mueren se quedan secas en las camas hasta
## que termina su ciclo; entonces el paso 3 es limpiar las camas (el mismo minijuego, sin papas).
## El paso actual se marca con un contorno que late y una flecha. La flecha de abajo (o Esc) vuelve a la estación.
## Las camas se ven según el cultivo (vacías, sanas, débiles, marchitas o muertas) y la tarjeta de abajo a la
## derecha enseña la planta, los sols y las papas que dará la cosecha.
## Fondo y zonas: assets/interiores/estacion_ares1/invernadero/ (los preparó el equipo, ver tools/invernadero/);
## plantas y macetas: plantas/ (tools/build_plantas.py).

const Style := preload("res://scripts/core/style.gd")
const Fx := preload("res://scripts/core/fx.gd")
const ExitArrow := preload("res://scripts/core/exit_arrow.gd")

const DIR := "res://assets/interiores/estacion_ares1/invernadero/"
const PLANTS := DIR + "plantas/"
const STATION := "res://scenes/interiores/estacion_ares1/estacion_ares1.tscn"
const GAMES := "res://scenes/interiores/estacion_ares1/modulos/invernadero/%s.tscn"

## Pasos, en orden: id del lugar, nombre (lo ve el jugador), tarea, minijuego ("" = aún no existe)
const SPOTS := [
	["semillas", "SEED POTATOES", "Plant the seed potatoes", "sembrar"],
	["tanque_agua", "WATER TANK", "Water the sprouts", "regar"],
	["camas", "GROW BEDS", "Harvest the potatoes", "cosechar"],
]
## Tarea de Mission.crops -> lugar que la hace
const TASK_SPOT := {"plant": "semillas", "water": "tanque_agua", "harvest": "camas", "clear": "camas"}
const STAGE_NAMES := ["Healthy", "Weak", "Wilting", "Dead"]
const STAGE_COLORS := [Color("7be05a"), Color("eafe07"), Color("ff9a3c"), Color("e43700")]
const BEDS := Rect2(124, 398, 1044, 212)          # las 3 camas juntas (cosecha)
const TANK_WATER := Rect2(162, 150, 56, 146)      # ventana del tanque de agua
const SCREENS := [Rect2(568, 130, 44, 54), Rect2(622, 130, 44, 54), Rect2(676, 130, 44, 54)]
const PANEL_LIGHTS := [Vector2(574, 203), Vector2(594, 203), Vector2(614, 203), Vector2(634, 203),
	Vector2(654, 203), Vector2(674, 203), Vector2(694, 203), Vector2(714, 203)]
const VALVES := [Vector2(354, 372), Vector2(713, 372), Vector2(1073, 372)]
const DRIPS := [Vector2(312, 392), Vector2(642, 392), Vector2(985, 392)]  # boquillas sobre las camas

var layout: Dictionary
var _spots := {}            # id -> {rect, name, sub, game, step}
var _hover := ""
var _add := CanvasItemMaterial.new()
var _fx := Node2D.new()
var _glow := Node2D.new()
var _exit := ExitArrow.new()
var _banner: Label
var _sub: Label
var _toast: Label
var _beds := Sprite2D.new()  # capa de las camas: vacías o plantas marchitas (nada = plantas sanas del fondo)
var _step_rows: Array = []   # [label, barra] de cada paso
var _card_icon: TextureRect
var _card_title: Label
var _card_lines: Label
var _t := 0.0
var _leaving := false


func _ready() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string(DIR + "invernadero_layout.json"))
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var st: Dictionary = layout.estaciones
	for k in SPOTS.size():
		var s: Array = SPOTS[k]
		var r := BEDS
		if st.has(s[0]):
			var e: Dictionary = st[s[0]]
			r = Rect2(e.x, e.y, e.w, e.h)
		_spots[s[0]] = {"rect": r, "name": s[1], "sub": s[2], "game": s[3], "step": k}

	var bg := Sprite2D.new()
	bg.texture = load(DIR + "invernadero_base.png")
	bg.centered = false
	add_child(bg)
	_beds.centered = false
	add_child(_beds)

	_build_grow_lights()
	_build_tank()
	_build_valves()
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_build_motes()
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	_exit.position = Vector2(640, 676)
	add_child(_exit)
	_build_ui()
	Mission.crops_changed.connect(_refresh)
	_refresh()
	_drip_loop()


# ---------------------------------------------------------------- efectos

## Luz de cultivo (morada y rosa) que baja de cada lámpara a su cama y respira despacio.
func _build_grow_lights() -> void:
	var i := 0
	for l in layout.lamparas:
		var top := Rect2(l.x, l.y + l.h, l.w, 6)
		var beam := Polygon2D.new()
		beam.polygon = PackedVector2Array([top.position, Vector2(top.end.x, top.position.y),
			Vector2(top.end.x + 14, 560), Vector2(top.position.x - 14, 560)])
		beam.vertex_colors = PackedColorArray([Color(0.85, 0.45, 1, 0.16), Color(0.85, 0.45, 1, 0.16),
			Color(1, 0.4, 0.7, 0.0), Color(1, 0.4, 0.7, 0.0)])
		beam.material = _add
		add_child(beam)
		var tw := create_tween().set_loops()
		tw.tween_property(beam, "modulate:a", 0.55, 1.6 + i * 0.3).set_trans(Tween.TRANS_SINE)
		tw.tween_property(beam, "modulate:a", 1.0, 1.6 + i * 0.3).set_trans(Tween.TRANS_SINE)
		var g := _halo(Vector2(l.x + l.w / 2.0, l.y + l.h), Color(0.9, 0.5, 1.0, 0.6), Vector2(l.w / 60.0, 0.9))
		var tw2 := create_tween().set_loops()
		tw2.tween_property(g, "modulate:a", 0.3, 1.2 + i * 0.2)
		tw2.tween_property(g, "modulate:a", 0.6, 1.2 + i * 0.2)
		i += 1
	for x in [320.0, 640.0, 962.0]:  # tubos del techo
		_halo(Vector2(x, 20), Color(0.85, 0.95, 1.0, 0.5), Vector2(3.5, 0.6))


## Burbujas que suben dentro del tanque de agua.
func _build_tank() -> void:
	var mask := ColorRect.new()
	mask.position = TANK_WATER.position
	mask.size = TANK_WATER.size
	mask.color = Color.WHITE  # solo máscara
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mask)
	var b := Fx.particles(Fx.PUFF, 10, 2.4, Vector2(0, -1), 8, 30, 60)
	b.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	b.emission_rect_extents = Vector2(TANK_WATER.size.x / 2 - 6, 2)
	b.position = Vector2(TANK_WATER.size.x / 2, TANK_WATER.size.y)
	b.scale_amount_min = 0.4
	b.scale_amount_max = 0.8
	b.color = Color(0.8, 0.95, 1.0, 0.7)
	mask.add_child(b)


## Las válvulas rojas de la tubería laten.
func _build_valves() -> void:
	for i in VALVES.size():
		var g := _halo(VALVES[i], Color(1, 0.3, 0.25, 0.7), Vector2.ONE * 0.7)
		var tw := create_tween().set_loops()
		tw.tween_property(g, "modulate:a", 0.15, 0.9 + i * 0.2)
		tw.tween_property(g, "modulate:a", 0.7, 0.9 + i * 0.2)


func _halo(at: Vector2, color: Color, size: Vector2) -> Sprite2D:
	var g := Sprite2D.new()
	g.texture = Fx.GLOW
	g.material = _add
	g.position = at
	g.scale = size
	g.modulate = color
	add_child(g)
	return g


func _build_motes() -> void:
	var m := Fx.particles(Fx.DUST, 30, 9.0, Vector2(0.4, -1), 40, 4, 10)
	m.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	m.position = Vector2(640, 420)
	m.emission_rect_extents = Vector2(560, 200)
	m.scale_amount_min = 1.0
	m.scale_amount_max = 2.0
	m.color = Color(0.85, 1.0, 0.75, 0.3)  # polen verdoso
	add_child(m)


## Gotas que caen de vez en cuando de las boquillas de riego sobre las camas.
func _drip_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(0.6, 1.6)).timeout
		var p: Vector2 = DRIPS.pick_random()
		var d := ColorRect.new()
		d.size = Vector2(3, 5)
		d.color = Color(0.55, 0.85, 1.0)
		d.position = p
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(d)
		var tw := create_tween()
		tw.tween_property(d, "position:y", p.y + 34, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(d.queue_free)


func _draw_fx() -> void:
	for i in SCREENS.size():  # pantallas del panel: barrido que baja
		var r: Rect2 = SCREENS[i]
		var y := r.position.y + fmod(_t * 26.0 + i * 17.0, r.size.y)
		_fx.draw_rect(Rect2(r.position.x, y, r.size.x, 2), Color(0.6, 1, 0.8, 0.3))
	for i in PANEL_LIGHTS.size():  # botones del panel
		if fmod(_t * 1.3 + i * 0.41, 2.0) < 0.9:
			_fx.draw_rect(Rect2(PANEL_LIGHTS[i] - Vector2(4, 3), Vector2(8, 6)),
				Color(0.4, 1, 0.5, 0.75) if i % 3 else Color(1, 0.45, 0.35, 0.75))


func _draw_glow() -> void:
	# paso actual: contorno que late y flecha que rebota (aunque no tenga el cursor encima)
	var cur := _current_spot()
	if cur != "" and cur != _hover:
		var cr: Rect2 = _spots[cur].rect
		var pa := 0.45 + 0.45 * sin(_t * 4.0)
		_glow.draw_rect(cr.grow(3), Color(Style.NEON_YELLOW, pa), false, 3)
	if cur != "":
		var cr2: Rect2 = _spots[cur].rect
		var tip := Vector2(cr2.get_center().x, cr2.position.y - 6 + sin(_t * 6.0) * 6.0)
		_glow.draw_colored_polygon(PackedVector2Array([tip + Vector2(-14, -18), tip + Vector2(14, -18), tip]), Style.NEON_YELLOW)
		_glow.draw_polyline(PackedVector2Array([tip + Vector2(-14, -18), tip + Vector2(14, -18), tip, tip + Vector2(-14, -18)]), Style.NAVY, 2)
	if _hover == "" or _hover == "exit":
		return
	var r: Rect2 = _spots[_hover].rect
	var a := 0.75 + 0.25 * sin(_t * 6.0)
	var c := Style.NEON_YELLOW
	_glow.draw_rect(r, Color(c, 0.12 * a))
	_glow.draw_rect(r.grow(3), Color(c, a), false, 4)
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var dx := 18.0 if corner.x == r.position.x else -18.0
		var dy := 18.0 if corner.y == r.position.y else -18.0
		_glow.draw_line(corner, corner + Vector2(dx, 0), Style.WHITE, 4)
		_glow.draw_line(corner, corner + Vector2(0, dy), Style.WHITE, 4)


# ---------------------------------------------------------------- UI e interacción

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var hint := Style.label("Greenhouse  ·  Click what you want to do  ·  Esc: back", 16, Style.WHITE, 5)
	hint.position = Vector2(16, 10)
	layer.add_child(hint)
	_banner = _top_label(Style.brand_title("", 38, Style.WHITE, 10), 34)
	layer.add_child(_banner)
	_sub = _top_label(Style.label("", 18, Style.NEON_YELLOW, 5), 80)
	layer.add_child(_sub)
	_toast = _top_label(Style.label("", 22, Style.WHITE, 6), 116)
	layer.add_child(_toast)
	_build_steps(layer)
	_build_card(layer)


## Panel de pasos (abajo a la izquierda): cada tarea con su barra; la actual resaltada.
func _build_steps(layer: CanvasLayer) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.box(Style.NAVY_SOFT, Style.NEON_YELLOW, 3, 12))
	panel.position = Vector2(150, 600)
	layer.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	var title := Style.brand_title("GREENHOUSE TASKS", 18, Style.WHITE)
	col.add_child(title)
	for k in SPOTS.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		col.add_child(row)
		var l := Style.label("", 15, Style.WHITE, 0)
		l.custom_minimum_size = Vector2(250, 0)
		row.add_child(l)
		var bar := Style.progress_bar(110, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		_step_rows.append([l, bar])


## Tarjeta de la planta (abajo a la derecha): maceta según la etapa, sols y papas esperadas.
func _build_card(layer: CanvasLayer) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.box(Style.NAVY_SOFT, Style.NEON_YELLOW, 3, 10))
	panel.position = Vector2(800, 586)
	panel.custom_minimum_size = Vector2(320, 0)
	layer.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	_card_icon = TextureRect.new()
	_card_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_card_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card_icon.custom_minimum_size = Vector2(88, 88)
	row.add_child(_card_icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	_card_title = Style.brand_title("", 18, Style.WHITE)
	col.add_child(_card_title)
	_card_lines = Style.label("", 15, Style.WHITE, 0)
	col.add_child(_card_lines)


## Vuelve a pintar camas, pasos y tarjeta con el estado de Mission.crops (también al empezar un sol).
func _refresh() -> void:
	var c = Mission.crops
	var st: int = c.stage()
	if not c.planted:
		_beds.texture = load(PLANTS + "camas_vacias.png")
	elif st > 0:
		_beds.texture = load(PLANTS + "camas_%d.png" % st)
	else:
		_beds.texture = null  # plantas sanas: las del fondo

	# pasos
	var task: String = c.next_task()
	var texts := ["Plant the seed potatoes", "Water the potatoes today",
		"Clear the dead plants" if c.dead else "Harvest the potatoes"]
	var done := [c.planted, c.is_growing() and (c.watered_today or c.is_ready()), false]
	var bars := [1.0 if c.planted else 0.0, 1.0 if done[1] else 0.0,
		clampf(c.age / c.grow_sols(), 0.0, 1.0) if c.dead else c.progress()]
	_spots.camas.sub = texts[2]
	for k in SPOTS.size():
		var current: bool = TASK_SPOT.get(task, "") == SPOTS[k][0]
		var l: Label = _step_rows[k][0]
		l.text = ("✓ " if done[k] else "") + "%d. %s" % [k + 1, texts[k]]
		l.add_theme_color_override("font_color", Style.NEON_YELLOW if current else (Style.WHITE if done[k] else Color(1, 1, 1, 0.5)))
		var bar: ProgressBar = _step_rows[k][1]
		bar.value = bars[k] * 100.0

	# tarjeta
	_card_icon.visible = c.planted
	if c.planted:
		_card_icon.texture = load(PLANTS + "maceta_%d.png" % st)
	var lines := []
	if not c.planted:
		_card_title.text = "BEDS EMPTY"
		lines.append("Plant seed potatoes to grow food.")
		if c.last_harvest > 0:
			lines.append("Last harvest: %d potatoes" % c.last_harvest)
	elif c.dead:
		_card_title.text = "POTATOES: DEAD"
		lines.append("They got no water for %d sols." % c.rule().dies_after_dry_sols)
		lines.append("Clear the beds now!" if c.can_clear() else "Clear them in %d sols." % c.sols_to_clear())
	else:
		_card_title.text = "POTATOES: %s" % STAGE_NAMES[st].to_upper()
		if c.is_ready():
			lines.append("Ready to harvest!")
		else:
			lines.append("Growing: sol %d of %d" % [mini(int(c.growth) + 1, ceili(c.grow_sols())), ceili(c.grow_sols())])
		var lost := roundi((1.0 - c.yield_ratio()) * 100.0)
		lines.append("Harvest: %d potatoes%s" % [c.expected_harvest(), "" if lost == 0 else "  (-%d %%)" % lost])
		if c.needs_water():
			lines.append("Needs water today!")
	_card_title.add_theme_color_override("font_color", STAGE_COLORS[st] if c.planted else Style.WHITE)
	_card_lines.text = "
".join(lines)


## Lugar del paso actual ("" si ahora no hay nada que hacer: regado y creciendo, o planta muerta esperando).
func _current_spot() -> String:
	return TASK_SPOT.get(Mission.crops.next_task(), "")


## Motivo por el que ahora no se puede usar un lugar ("" si se puede).
func _blocked(id: String) -> String:
	var c = Mission.crops
	match id:
		"semillas":
			return c.plant_blocked_reason()
		"tanque_agua":
			return c.water_blocked_reason()
		"camas":
			if c.next_task() in ["harvest", "clear"]:
				return ""
			if not c.planted:
				return "Nothing is planted yet. Start with the seed potatoes."
			if c.dead:
				return c.plant_blocked_reason()
			return "The potatoes need %d more sols to grow." % c.sols_to_harvest()
	return ""


func _top_label(l: Label, top: float) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	l.offset_left = -500
	l.offset_right = 500
	l.offset_top = top
	l.modulate.a = 0.0
	return l


func _process(delta: float) -> void:
	_t += delta
	_fx.queue_redraw()
	_glow.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event is InputEventMouseMotion:
		_set_hover(_hit(get_global_mouse_position()))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := _hit(get_global_mouse_position())
		if id == "exit":
			_go(STATION)
		elif id != "":
			_use(id)
	elif event.is_action_pressed("ui_cancel"):
		_go(STATION)


func _hit(p: Vector2) -> String:
	if _exit.hit(p) or Rect2(0, 160, 56, 480).has_point(p):  # flecha o puerta de la izquierda
		return "exit"
	for id in _spots:
		if _spots[id].rect.has_point(p):
			return id
	return ""


func _set_hover(id: String) -> void:
	if id == _hover:
		return
	_hover = id
	_exit.hovered = id == "exit"
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if id != "" else Input.CURSOR_ARROW)
	var shown := id != "" and id != "exit"
	if shown:
		_banner.text = _spots[id].name
		_sub.text = "%s  ·  %s" % [_spots[id].sub, "Not now" if _blocked(id) != "" else "Click to start"]
	var tw := create_tween().set_parallel()
	tw.tween_property(_banner, "modulate:a", 1.0 if shown else 0.0, 0.15)
	tw.tween_property(_sub, "modulate:a", 1.0 if shown else 0.0, 0.15)


func _use(id: String) -> void:
	var why := _blocked(id)
	if why != "":
		_show_toast(why)
		return
	_go(GAMES % _spots[id].game)


func _show_toast(text: String) -> void:
	_toast.text = text
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.0)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _go(scene: String) -> void:
	_leaving = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	SceneChanger.go_to(scene)
