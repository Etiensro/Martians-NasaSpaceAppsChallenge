extends Node2D
## Dormitorios (Crew Quarters) de la Estación Ares 1 (scenes/interiores/estacion_ares1/modulos/dormitorios/dormitorios.tscn).
## La litera del jugador brilla; con clic se abre el RELOJ para elegir cuántas horas dormir (1-24):
##   - Arrastrar la manecilla corta: el reloj enseña la hora a la que se despierta (cada vuelta = 12 h).
##   - Rueda del ratón, flechas o los botones − / +: ±1 h.  Enter o SLEEP: dormir.  Esc o BACK: volver.
## Al dormir se llama a `await Mission.crew.sleep(h)`: el reloj de la misión avanza en unos segundos y
## aquí las manecillas giran hasta la hora de despertar. El cansancio baja 9 por hora (rules.json).
## La flecha de abajo (o Esc) vuelve al centro de la estación.
## Fondos, manecillas y posiciones: assets/interiores/estacion_ares1/dormitorios/ (los genera
## tools/build_dormitorios.py).

const Style := preload("res://scripts/core/style.gd")
const Fx := preload("res://scripts/core/fx.gd")
const ExitArrow := preload("res://scripts/core/exit_arrow.gd")

const DIR := "res://assets/interiores/estacion_ares1/dormitorios/"
const STATION := "res://scenes/interiores/estacion_ares1/estacion_ares1.tscn"

var data: Dictionary
var _bunk: Rect2
var _hours := 8                # horas elegidas
var _drag_hours := 8.0         # valor continuo mientras se arrastra la manecilla
var _drag_angle := 0.0
var _dragging := false
var _sleeping := false
var _wake_at := 0.0            # Mission.hours al despertar (mientras se duerme)
var _hover := ""               # "bunk", "exit" o ""
var _leaving := false
var _t := 0.0

# cuarto
var _room := Node2D.new()
var _fx := Node2D.new()
var _glow := Node2D.new()
var _pointer := Node2D.new()
var _exit := ExitArrow.new()
var _room_ui := CanvasLayer.new()
var _toast: Label
var _add := CanvasItemMaterial.new()

# reloj
var _clock := Node2D.new()
var _sweep := Node2D.new()     # sector de las horas de sueño
var _hand_hour := Sprite2D.new()
var _hand_minute := Sprite2D.new()
var _clock_ui := CanvasLayer.new()
var _c := Vector2.ZERO         # centro de la esfera
var _r := 0.0                  # radio de la cara blanca
var _title: Label
var _wake_label: Label
var _tired_label: Label
var _note_label: Label
var _sleep_btn: Button
var _back_btn: Button
var _minus_btn: Button
var _plus_btn: Button


func _ready() -> void:
	# sigue animando mientras Mission pausa el árbol para adelantar el reloj (las manecillas giran)
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = JSON.parse_string(FileAccess.get_file_as_string(DIR + "dorm.json"))
	var b: Array = data.bunk
	_bunk = Rect2(b[0], b[1], b[2] - b[0], b[3] - b[1])
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_build_room()
	_build_clock()
	_show_clock(false)


# ---------------------------------------------------------------- cuarto

func _build_room() -> void:
	add_child(_room)
	var bg := Sprite2D.new()
	bg.texture = load(DIR + "room.png")
	bg.centered = false
	_room.add_child(bg)
	for i in data.lamps.size():
		var l: Array = data.lamps[i]
		var g := Sprite2D.new()
		g.texture = Fx.GLOW
		g.material = _add
		g.position = Vector2(l[0], l[1])
		g.scale = Vector2.ONE * float(l[3])
		g.modulate = Color(Color(l[2]), 0.55)
		_room.add_child(g)
		var tw := create_tween().set_loops()
		tw.tween_property(g, "modulate:a", 0.25, 1.1 + i * 0.13).set_trans(Tween.TRANS_SINE)
		tw.tween_property(g, "modulate:a", 0.55, 1.1 + i * 0.13).set_trans(Tween.TRANS_SINE)
	_fx.draw.connect(_draw_fx)
	_room.add_child(_fx)
	var motes := Fx.particles(Fx.DUST, 26, 9.0, Vector2(1, -0.3), 50, 4, 12)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.position = Vector2(640, 420)
	motes.emission_rect_extents = Vector2(600, 260)
	motes.scale_amount_min = 1.0
	motes.scale_amount_max = 2.0
	motes.color = Color(1, 0.95, 0.85, 0.25)
	_room.add_child(motes)
	_glow.draw.connect(_draw_glow)
	_room.add_child(_glow)
	_build_pointer()
	_exit.position = Vector2(data.exit[0], data.exit[1])
	_room.add_child(_exit)

	_room_ui.layer = 10
	add_child(_room_ui)
	var hint := Style.label("Crew Quarters  ·  Sleep to recover from tiredness  ·  Esc: back", 16, Style.WHITE, 5)
	hint.position = Vector2(16, 10)
	_room_ui.add_child(hint)
	var title := Style.brand_title("YOUR BUNK", 34, Style.WHITE, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(440, 44)
	title.position = Vector2(_bunk.get_center().x - 220, _bunk.position.y - 112)
	_room_ui.add_child(title)
	var sub := Style.label("Choose how long to sleep  ·  Click", 18, Style.NEON_YELLOW, 5)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(440, 26)
	sub.position = Vector2(_bunk.get_center().x - 220, _bunk.position.y - 70)
	_room_ui.add_child(sub)
	_toast = Style.label("", 24, Style.WHITE, 8)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.position = Vector2(0, 60)
	_toast.size = Vector2(1280, 40)
	_toast.modulate.a = 0.0
	_room_ui.add_child(_toast)


## Flecha que rebota encima de la litera: "¡aquí!"
func _build_pointer() -> void:
	_pointer.position = Vector2(_bunk.get_center().x, _bunk.position.y - 30)
	var tri := Polygon2D.new()
	tri.polygon = PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(0, 6)])
	tri.color = Style.NEON_YELLOW
	var line := Line2D.new()
	line.points = tri.polygon + PackedVector2Array([tri.polygon[0]])
	line.width = 3
	line.default_color = Style.NAVY
	tri.add_child(line)
	_pointer.add_child(tri)
	_room.add_child(_pointer)
	var tw := create_tween().set_loops()
	tw.tween_property(_pointer, "position:y", _pointer.position.y - 12, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_pointer, "position:y", _pointer.position.y, 0.45).set_trans(Tween.TRANS_SINE)


func _draw_fx() -> void:
	for i in data.blink.size():
		var l: Array = data.blink[i]
		if fmod(_t * (0.9 + i * 0.17) + i * 0.4, 2.0) < 1.1:
			_fx.draw_circle(Vector2(l[0], l[1]), 3, Color(l[2]))
			_fx.draw_circle(Vector2(l[0], l[1]), 7, Color(Color(l[2]), 0.25))
	for s in data.screens:
		var r := Rect2(s[0], s[1], s[2] - s[0], s[3] - s[1]).grow(-4)
		match s[4]:
			"heart":
				var pts := PackedVector2Array()
				for k in 16:
					var x := r.position.x + k * r.size.x / 15.0
					var step := (k + int(_t * 8.0)) % 16
					var beat := 9.0 if step == 7 else (-4.0 if step == 8 else 0.0)
					pts.append(Vector2(x, r.get_center().y - beat))
				_fx.draw_polyline(pts, Color(0.4, 1, 0.5, 0.9), 2)
			"text":
				var lines := int(fmod(_t * 2.5, 6.0))
				for k in lines:
					_fx.draw_rect(Rect2(r.position.x + 6, r.position.y + 8 + k * 12, 18 + (k * 23) % 50, 3), Color(0.5, 1, 0.6, 0.6))
			"stars":  # monitor apagado: estrellitas que titilan
				for k in 14:
					var p := r.position + Vector2(fmod(k * 37.3, r.size.x), fmod(k * 23.7, r.size.y))
					var a := 0.3 + 0.7 * absf(sin(_t * 1.3 + k))
					_fx.draw_rect(Rect2(p, Vector2(2, 2)), Color(0.8, 0.9, 1, a))


func _draw_glow() -> void:
	var on := _hover == "bunk"
	var a := 1.0 if on else 0.55 + 0.45 * sin(_t * 4.0)
	var c := Style.NEON_YELLOW
	_glow.draw_rect(_bunk, Color(c, (0.2 if on else 0.1) * a))
	_glow.draw_rect(_bunk.grow(3), Color(c, a), false, 4)
	for corner in [_bunk.position, Vector2(_bunk.end.x, _bunk.position.y), _bunk.end, Vector2(_bunk.position.x, _bunk.end.y)]:
		var dx := 20.0 if corner.x == _bunk.position.x else -20.0
		var dy := 20.0 if corner.y == _bunk.position.y else -20.0
		_glow.draw_line(corner, corner + Vector2(dx, 0), Style.WHITE, 4)
		_glow.draw_line(corner, corner + Vector2(0, dy), Style.WHITE, 4)


func _toast_text(text: String, color := Style.WHITE) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.0 + text.length() * 0.03)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


# ---------------------------------------------------------------- reloj

func _build_clock() -> void:
	var cd: Dictionary = data.clock
	_c = Vector2(cd.center[0], cd.center[1])
	_r = float(cd.radius)
	add_child(_clock)
	var bg := Sprite2D.new()
	bg.texture = load(DIR + "clock.png")
	bg.centered = false
	_clock.add_child(bg)
	_sweep.draw.connect(_draw_sweep)
	_clock.add_child(_sweep)
	for pair in [[_hand_hour, "hour"], [_hand_minute, "minute"], [Sprite2D.new(), "hub"]]:
		var s: Sprite2D = pair[0]
		var piv: Array = cd.pivots[pair[1]]
		s.texture = load(DIR + "hand_%s.png" % pair[1])
		s.centered = false
		s.offset = -Vector2(piv[0], piv[1])
		s.position = _c
		_clock.add_child(s)

	_clock_ui.layer = 10
	add_child(_clock_ui)
	var hint := Style.label("Drag the short hand to choose when to wake up  ·  Scroll or ←/→: ±1 h  ·  Enter: sleep  ·  Esc: back", 15, Style.WHITE, 5)
	hint.position = Vector2(16, 10)
	_clock_ui.add_child(hint)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.box(Color(Style.DEEP_BLUE, 0.88), Style.BLUE_YONDER, 3, 18.0))
	panel.position = Vector2(920, 210)
	panel.custom_minimum_size = Vector2(340, 0)
	_clock_ui.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	_title = Style.brand_title("", 34, Style.WHITE)
	col.add_child(_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	_minus_btn = _button("−", false, 22)
	_minus_btn.pressed.connect(func() -> void: _set_hours(_hours - 1))
	row.add_child(_minus_btn)
	_plus_btn = _button("+", false, 22)
	_plus_btn.pressed.connect(func() -> void: _set_hours(_hours + 1))
	row.add_child(_plus_btn)
	_wake_label = Style.brand_label("", 19, Style.WHITE, 600)
	col.add_child(_wake_label)
	_tired_label = Style.brand_label("", 19, Style.WHITE, 600)
	col.add_child(_tired_label)
	_note_label = Style.brand_label("", 16, Style.NEON_YELLOW, 500)
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_label.custom_minimum_size = Vector2(300, 0)
	col.add_child(_note_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	col.add_child(buttons)
	_sleep_btn = _button("SLEEP", true, 22)
	_sleep_btn.pressed.connect(_sleep)
	buttons.add_child(_sleep_btn)
	_back_btn = _button("BACK", false, 22)
	_back_btn.pressed.connect(func() -> void: _show_clock(false))
	buttons.add_child(_back_btn)


func _button(text: String, primary: bool, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	Style.brand_button(b, primary, size)
	return b


func _show_clock(on: bool) -> void:
	_clock.visible = on
	_clock_ui.visible = on
	_room.visible = not on
	_room_ui.visible = not on
	_dragging = false
	_hover = ""
	_exit.hovered = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if on:
		# propuesta: lo justo para quedar descansado (mínimo 1 h, máximo 12)
		var rate := -float(Mission.rules.crew.fatigue.asleep_per_hour)
		_set_hours(clampi(ceili(Mission.crew.fatigue / rate), 1, 12) if Mission.crew.fatigue > 0.0 else 1)


func _set_hours(h: int) -> void:
	var f: Dictionary = Mission.rules.crew.fatigue
	_hours = clampi(h, int(f.sleep_min_hours), int(f.sleep_max_hours))
	_drag_hours = _hours
	_update_panel()


func _update_panel() -> void:
	var f: Dictionary = Mission.rules.crew.fatigue
	var now := Mission.hour_of_day()
	_title.text = "SLEEP %d H" % _hours
	_wake_label.text = "Wake up at %s  ·  Sol %d" % [Mission.clock_text(now + _hours), Mission.sol() + int((now + _hours) / 24.0)]
	var tired := Mission.crew.fatigue
	var after := clampf(tired + float(f.asleep_per_hour) * _hours, 0.0, 100.0)
	_tired_label.text = "Tiredness  %d  →  %d" % [roundi(tired), roundi(after)]
	var needed := ceili(tired / -float(f.asleep_per_hour))
	if tired <= 0.0:
		_note_label.text = "You're already well rested."
	elif _hours > needed:
		_note_label.text = "You'll be fully rested after %d h. Sleeping longer uses mission time." % needed
	elif after >= 50.0:
		_note_label.text = "You'll still be tired: tasks stay slower."
	else:
		_note_label.text = "Sweet dreams!"
	_minus_btn.disabled = _hours <= int(f.sleep_min_hours)
	_plus_btn.disabled = _hours >= int(f.sleep_max_hours)


## Ángulo en el reloj de 12 h (0 = las 12, sentido horario) de una hora del día.
func _angle(h: float) -> float:
	return fmod(h, 12.0) / 12.0 * TAU


func _draw_sweep() -> void:
	var now := Mission.hour_of_day()
	var span := maxf(_wake_at - Mission.hours, 0.0) if _sleeping else float(_hours)
	var r := _r * 0.86
	var c := Style.BLUE_YONDER
	if span >= 12.0:  # más de una vuelta: el círculo entero más claro y el resto encima
		_sweep.draw_circle(_c, r, Color(c, 0.18))
	var rest := fmod(span, 12.0)
	if rest > 0.01:
		var a0 := _angle(now) - PI / 2.0
		var pts := PackedVector2Array([_c])
		var steps := maxi(2, int(rest * 6.0))
		for k in steps + 1:
			pts.append(_c + Vector2.from_angle(a0 + rest / 12.0 * TAU * k / steps) * r)
		_sweep.draw_colored_polygon(pts, Color(c, 0.3))
		_sweep.draw_polyline(pts.slice(1), Color(c, 0.9), 4)


func _update_hands() -> void:
	var now := Mission.hour_of_day()
	var shown := now if _sleeping else now + _hours
	_hand_hour.rotation = _angle(shown)
	_hand_minute.rotation = fmod(now, 1.0) * TAU


# ---------------------------------------------------------------- dormir

func _sleep() -> void:
	if _sleeping or Mission.is_busy():
		return
	_sleeping = true
	_wake_at = Mission.hours + _hours
	_sleep_btn.disabled = true
	_back_btn.disabled = true
	_minus_btn.disabled = true
	_plus_btn.disabled = true
	_note_label.text = "Zzz..."
	var before := Mission.crew.fatigue
	await Mission.crew.sleep(_hours)
	_sleeping = false
	_sleep_btn.disabled = false
	_back_btn.disabled = false
	if Mission.over:
		return
	_show_clock(false)
	var h := Mission.hour_of_day()
	var greeting := "Good morning" if h >= 5.0 and h < 12.0 else ("Good afternoon" if h >= 12.0 and h < 19.0 else "Good evening")
	_toast_text("%s! Tiredness %d → %d" % [greeting, roundi(before), roundi(Mission.crew.fatigue)], Style.NEON_YELLOW)


# ---------------------------------------------------------------- entrada y animación

func _process(delta: float) -> void:
	_t += delta
	if _clock.visible:
		_update_hands()
		_sweep.queue_redraw()
		if not _sleeping:
			_wake_label.text = "Wake up at %s  ·  Sol %d" % [Mission.clock_text(Mission.hour_of_day() + _hours),
				Mission.sol() + int((Mission.hour_of_day() + _hours) / 24.0)]
	else:
		_fx.queue_redraw()
		_glow.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or _sleeping or get_tree().paused:
		return
	if _clock.visible:
		_clock_input(event)
	else:
		_room_input(event)


func _room_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var p: Vector2 = event.position
		_hover = "exit" if _exit.hit(p) else ("bunk" if _bunk.has_point(p) else "")
		_exit.hovered = _hover == "exit"
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if _hover != "" else Input.CURSOR_ARROW)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		if _exit.hit(p):
			_leave()
		elif _bunk.has_point(p):
			_show_clock(true)
	elif event.is_action_pressed("ui_cancel"):
		_leave()


func _clock_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_show_clock(false)
	elif event.is_action_pressed("ui_accept"):
		_sleep()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_up"):
		_set_hours(_hours + 1)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_down"):
		_set_hours(_hours - 1)
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_hours(_hours + 1)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_hours(_hours - 1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var p: Vector2 = event.position
			_dragging = event.pressed and p.distance_to(_c) <= _r * 1.15
			if _dragging:
				_drag_angle = _mouse_angle(p)
	elif event is InputEventMouseMotion:
		var p: Vector2 = event.position
		Input.set_default_cursor_shape(Input.CURSOR_DRAG if _dragging or p.distance_to(_c) <= _r * 1.15 else Input.CURSOR_ARROW)
		if _dragging and p.distance_to(_c) > 12.0:
			var a := _mouse_angle(p)
			_drag_hours = clampf(_drag_hours + wrapf(a - _drag_angle, -PI, PI) / TAU * 12.0,
				float(Mission.rules.crew.fatigue.sleep_min_hours), float(Mission.rules.crew.fatigue.sleep_max_hours))
			_drag_angle = a
			var h := roundi(_drag_hours)
			if h != _hours:
				_hours = h
				_update_panel()


## Ángulo del ratón respecto al centro del reloj (0 = las 12, sentido horario).
func _mouse_angle(p: Vector2) -> float:
	var d := p - _c
	return atan2(d.x, -d.y)


func _leave() -> void:
	_leaving = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	SceneChanger.go_to(STATION)
