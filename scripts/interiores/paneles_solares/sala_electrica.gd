extends Node2D
## Sala eléctrica, POWER ROOM (scenes/interiores/paneles_solares/minijuegos/sala_electrica/sala_electrica.tscn).
## La zona de los interruptores de la pared se marca con un rectángulo amarillo; al hacer clic se
## abre la placa con un interruptor por sistema y un monitor con el balance de energía.
##   - Soporte vital y cápsulas criogénicas: no se pueden apagar (A.R.I.A. explica por qué).
##   - Invernadero y luces/auxiliares: se encienden y apagan (Mission.set_system). El invernadero no se
##     apaga con papas creciendo; los auxiliares piden confirmación (Mission.switch_blocked_reason).
## Los sistemas, sus consumos y sus mensajes están en data/mission/rules.json.
## Imágenes: assets/interiores/paneles_solares/sala_electrica/ (las genera tools/build_power_room.py).
## Flecha de abajo o Esc: volver al vestíbulo de los paneles.

const Style := preload("res://scripts/core/style.gd")
const ExitArrow := preload("res://scripts/core/exit_arrow.gd")

const DIR := "res://assets/interiores/paneles_solares/sala_electrica/"
const HUB := "res://scenes/interiores/paneles_solares/paneles_solares.tscn"
const BREAKER_ON := preload("res://assets/interiores/paneles_solares/sala_electrica/breaker_on.png")
const BREAKER_OFF := preload("res://assets/interiores/paneles_solares/sala_electrica/breaker_off.png")
const PLATE := preload("res://assets/interiores/paneles_solares/sala_electrica/breaker_plate.png")
const MONITOR := preload("res://assets/interiores/paneles_solares/sala_electrica/monitor.png")
const COLUMN_W := 190.0

var _wall := Rect2()            # zona de los interruptores en la pared
var _wall_box := Node2D.new()
var _exit := ExitArrow.new()
var _hover_wall := false
var _t := 0.0
var _leaving := false

var _overlay: Control           # placa abierta (null si está cerrada)
var _breakers := {}             # id -> TextureButton
var _monitor_text: Label


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(DIR + "power_room.json"))
	var w: Array = data.breaker_wall
	_wall = Rect2(w[0], w[1], w[2] - w[0], w[3] - w[1])

	var bg := Sprite2D.new()
	bg.texture = load(DIR + "power_room.png")
	bg.centered = false
	add_child(bg)
	_wall_box.draw.connect(_draw_wall_box)
	add_child(_wall_box)
	_exit.position = Vector2(640, 652)
	add_child(_exit)

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var hint := Style.label("Power Room  ·  Click the breaker panel  ·  Esc: back", 16, Style.WHITE, 5)
	hint.position = Vector2(16, 10)
	layer.add_child(hint)


func _process(delta: float) -> void:
	_t += delta
	_wall_box.queue_redraw()
	if _overlay:
		_update_overlay()


## Rectángulo amarillo que late sobre los interruptores de la pared.
func _draw_wall_box() -> void:
	if _overlay:
		return
	var a := 0.55 + 0.45 * sin(_t * 4.0)
	var r := _wall.grow(6.0 if _hover_wall else 0.0)
	_wall_box.draw_rect(r, Color(Style.NEON_YELLOW, 0.12 * a + (0.12 if _hover_wall else 0.0)))
	_wall_box.draw_rect(r, Color(Style.NEON_YELLOW, a), false, 4)
	var font := Style.FONT_BODY
	_wall_box.draw_string_outline(font, r.position + Vector2(0, -12), "BREAKER PANEL", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, 6, Style.NAVY)
	_wall_box.draw_string(font, r.position + Vector2(0, -12), "BREAKER PANEL", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Style.NEON_YELLOW)


# ---------------------------------------------------------------- entrada

func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_cancel"):
		if _overlay:
			_close()
		else:
			_back()
		get_viewport().set_input_as_handled()
		return
	if _overlay:
		return
	if event is InputEventMouseMotion:
		var p := get_global_mouse_position()
		_hover_wall = _wall.has_point(p)
		_exit.hovered = _exit.hit(p)
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if _hover_wall or _exit.hovered else Input.CURSOR_ARROW)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p := get_global_mouse_position()
		if _wall.has_point(p):
			_open()
		elif _exit.hit(p):
			_back()


func _back() -> void:
	_leaving = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	SceneChanger.go_to(HUB)


# ---------------------------------------------------------------- placa de interruptores

func _open() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	layer.add_child(dim)
	_overlay = dim

	var plate := TextureRect.new()
	plate.texture = PLATE
	plate.position = (Vector2(1280, 720) - PLATE.get_size()) / 2.0
	plate.mouse_filter = Control.MOUSE_FILTER_STOP  # clics en la placa no la cierran
	_overlay.add_child(plate)

	var title := Style.brand_title("Power control", 30, Style.WHITE, 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 44)
	title.size = Vector2(PLATE.get_width(), 40)
	plate.add_child(title)

	var ids := Mission.system_ids()
	var left := (PLATE.get_width() - COLUMN_W * ids.size()) / 2.0
	for i in ids.size():
		plate.add_child(_breaker_column(ids[i], Vector2(left + i * COLUMN_W, 92)))

	var monitor := TextureRect.new()
	monitor.texture = MONITOR
	monitor.position = Vector2((PLATE.get_width() - MONITOR.get_width()) / 2.0, 388)
	plate.add_child(monitor)
	_monitor_text = Style.brand_label("", 15, Color("8fe3ff"), 600)
	_monitor_text.position = MONITOR.get_size() * Vector2(0.12, 0.2)
	_monitor_text.size = MONITOR.get_size() * Vector2(0.76, 0.6)
	_monitor_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	monitor.add_child(_monitor_text)

	var close := Button.new()
	close.text = "CLOSE"
	Style.brand_button(close, false, 18)
	close.position = Vector2(PLATE.get_width() - 150, 40)
	close.pressed.connect(_close)
	plate.add_child(close)

	_overlay.modulate.a = 0.0
	create_tween().tween_property(_overlay, "modulate:a", 1.0, 0.2)
	_update_overlay()


## Un interruptor con su nombre, su consumo y (si no se puede apagar) el aviso "ALWAYS ON".
func _breaker_column(id: String, at: Vector2) -> Control:
	var rule := Mission.system_rule(id)
	var col := VBoxContainer.new()
	col.position = at
	col.custom_minimum_size = Vector2(COLUMN_W, 0)
	col.add_theme_constant_override("separation", 4)

	var b := TextureButton.new()
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(_on_breaker.bind(id))
	col.add_child(b)
	_breakers[id] = b

	var name_l := Style.label(str(rule.get("name", id)).to_upper(), 15, Style.WHITE, 4)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.custom_minimum_size = Vector2(COLUMN_W, 0)
	col.add_child(name_l)
	var use := Style.label("%d EU/h" % rule.get("eu_per_hour", 0), 14, Style.CYAN, 4)
	use.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(use)
	if not Mission.can_switch(id):
		var lock := Style.label("ALWAYS ON", 13, Style.NEON_YELLOW, 4)
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(lock)
	return col


func _on_breaker(id: String) -> void:
	var rule := Mission.system_rule(id)
	var blocked := Mission.switch_blocked_reason(id)  # soporte vital, cápsulas, invernadero con papas
	if blocked != "":
		Mission.notify(blocked)
		_shake(_breakers[id])
		return
	var on := not Mission.is_on(id)
	if not on and rule.has("confirm_off"):  # el documento pide confirmar antes de apagar los auxiliares
		_confirm(rule.confirm_off, _switch.bind(id, on))
		return
	_switch(id, on)


func _switch(id: String, on: bool) -> void:
	var rule := Mission.system_rule(id)
	Mission.set_system(id, on)
	if not on and rule.has("off_message"):
		Mission.notify(rule.off_message)


func _shake(b: TextureButton) -> void:
	var x := b.position.x
	var tw := create_tween()
	for dx in [8.0, -8.0, 5.0, 0.0]:
		tw.tween_property(b, "position:x", x + dx, 0.05)


## Ventana de confirmación encima de la placa: "TURN OFF" ejecuta `on_yes`, "CANCEL" la cierra.
func _confirm(text: String, on_yes: Callable) -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", Style.box(Style.NAVY, Style.NEON_YELLOW, 3, 22.0))
	box.custom_minimum_size = Vector2(520, 0)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	box.add_child(col)
	var msg := Style.brand_label(text, 20, Style.WHITE, 500)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(476, 0)
	col.add_child(msg)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	col.add_child(row)
	var yes := Button.new()
	yes.text = "TURN OFF"
	Style.brand_button(yes, true, 18)
	yes.pressed.connect(func():
		box.queue_free()
		on_yes.call())
	row.add_child(yes)
	var no := Button.new()
	no.text = "CANCEL"
	Style.brand_button(no, false, 18)
	no.pressed.connect(box.queue_free)
	row.add_child(no)
	box.reset_size()
	box.position = (Vector2(1280, 720) - box.size) / 2.0


func _update_overlay() -> void:
	for id in _breakers:
		_breakers[id].texture_normal = BREAKER_ON if Mission.is_on(id) else BREAKER_OFF
	var net := Mission.net()
	var future := "Battery stable"
	if net < 0.0:
		future = "Battery lasts %d h" % Mission.hours_to_empty()
	elif net > 0.0:
		future = "Battery full in %d h" % Mission.hours_to_full()
	_monitor_text.text = "BATTERY  %d / %d EU\nIN  %.1f EU/h   OUT  %.1f EU/h\n%s" % [
		Mission.battery, Mission.capacity(), Mission.generation(), Mission.consumption(), future]


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()  # clic fuera de la placa


func _close() -> void:
	if not _overlay:
		return
	var layer := _overlay.get_parent()
	_overlay = null
	_breakers.clear()
	layer.queue_free()
