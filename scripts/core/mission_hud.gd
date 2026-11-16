extends CanvasLayer
## HUD de la misión (lo crea el autoload Mission):
##   - arriba a la derecha: reloj, batería, barras de la tripulación (hambre, cansancio, radiación,
##     condición física), investigación y tormenta;
##   - abajo: mensajes de A.R.I.A. (Mission.notify);
##   - en el centro, mientras dura una actividad (dormir, viajar...): el cartel con el reloj adelantándose;
##   - al terminar la misión, el mensaje de Control de Misión que empieza el regreso (scripts/finales/).

const Style := preload("res://scripts/core/style.gd")
const MESSAGE_SECONDS := 5.0
const Final := preload("res://scripts/finales/final.gd")
const BAR_W := 150.0
## Barras de la tripulación: id en Mission.crew, nombre, si "más es mejor" y valor a partir del que se
## pinta en rojo (aviso).
const CREW_BARS := [
	["hunger", "FOOD", true, 40.0],
	["fatigue", "TIREDNESS", false, 50.0],
	["radiation", "RADIATION", false, 50.0],
	["fitness", "FITNESS", true, 50.0],
]
var _clock: Label
var _battery: Label
var _battery_bar: ProgressBar
var _crew_bars := {}        # id -> {bar, value}
var _research: Label
var _storm: Label
var _message_box: PanelContainer
var _message: Label
var _queue: Array[String] = []
var _message_left := 0.0
var _activity: Control
var _activity_title: Label
var _activity_time: Label
var _activity_bar: ProgressBar
var _over: Control


func _init() -> void:
	layer = 40


func _ready() -> void:
	_build_activity()  # primero: así las barras y los mensajes quedan encima del cartel y se ven cambiar
	_build_status()
	_build_messages()


func _build_status() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.box(Style.NAVY_SOFT, Style.BLUE_YONDER, 2, 10.0))
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -300
	panel.offset_right = -12
	panel.offset_top = 12
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	panel.add_child(col)
	_clock = Style.label("", 18, Style.WHITE, 0)
	col.add_child(_clock)
	_battery = Style.label("", 14, Style.WHITE, 0)
	col.add_child(_battery)
	_battery_bar = _bar(266.0, 8.0)
	col.add_child(_battery_bar)
	for b in CREW_BARS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		col.add_child(row)
		var name_l := Style.label(b[1], 12, Style.WHITE, 0)
		name_l.custom_minimum_size = Vector2(76, 0)
		row.add_child(name_l)
		var bar := _bar(BAR_W, 8.0)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var value := Style.label("", 12, Style.WHITE, 0)
		row.add_child(value)
		_crew_bars[b[0]] = {"bar": bar, "value": value}
	_research = Style.label("", 13, Style.CYAN, 0)
	col.add_child(_research)
	_storm = Style.label("", 14, Style.ROCKET_RED.lightened(0.3), 0)
	col.add_child(_storm)


func _bar(w: float, h: float) -> ProgressBar:
	var b := Style.progress_bar(w, h)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("background", Style.box(Color(1, 1, 1, 0.15), Color(0, 0, 0, 0), 0, 0))
	return b


func _set_bar_color(b: ProgressBar, warn: bool) -> void:
	var c := Style.ROCKET_RED if warn else Style.NEON_YELLOW
	b.add_theme_stylebox_override("fill", Style.box(c, c, 0, 0))


func _build_messages() -> void:
	_message_box = PanelContainer.new()
	_message_box.add_theme_stylebox_override("panel", Style.box(Style.NAVY_SOFT, Style.CYAN, 3, 16.0))
	_message_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_message_box.offset_left = -430
	_message_box.offset_right = 430
	_message_box.offset_top = -120
	_message_box.offset_bottom = -24
	_message_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_box.modulate.a = 0.0
	add_child(_message_box)
	var row := VBoxContainer.new()
	_message_box.add_child(row)
	row.add_child(Style.label("A.R.I.A.", 16, Style.CYAN, 0))
	_message = Style.label("", 19, Style.WHITE, 0)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_message)


## Cartel de actividad (dormir, viajar, chequeo...): oscurece la escena y enseña el reloj avanzando.
func _build_activity() -> void:
	_activity = ColorRect.new()
	(_activity as ColorRect).color = Color(Style.DEEP_BLUE, 0.75)
	_activity.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_activity.mouse_filter = Control.MOUSE_FILTER_STOP  # la escena no recibe clics mientras tanto
	_activity.visible = false
	add_child(_activity)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_activity.add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)
	_activity_title = Style.brand_title("", 44, Style.WHITE)
	_activity_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_activity_title)
	_activity_time = Style.brand_label("", 26, Style.NEON_YELLOW, 700)
	_activity_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_activity_time)
	_activity_bar = Style.progress_bar(420.0, 16.0)
	_activity_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_activity_bar)


func _process(delta: float) -> void:
	_update_activity()
	if not visible:
		return
	_clock.text = Mission.time_text()
	var net := Mission.net()
	_battery.text = "BATTERY  %d / %d EU   (%s%.1f EU/h)" % [Mission.battery, Mission.capacity(), "+" if net >= 0 else "", net]
	var ratio := Mission.battery / Mission.capacity()
	_battery_bar.value = ratio * 100.0
	_set_bar_color(_battery_bar, ratio <= 0.3)
	for b in CREW_BARS:
		var v: float = Mission.crew.value_of(b[0])
		var row: Dictionary = _crew_bars[b[0]]
		row.bar.value = v
		row.value.text = "%d" % v
		_set_bar_color(row.bar, v <= b[3] if b[2] else v >= b[3])
	var r := "RESEARCH  %d %%" % roundi(Mission.research.percent())
	if Mission.research.is_analysing():
		r += "   ·   lab %d %%" % roundi(Mission.research.analysis_progress() * 100.0)
	_research.text = r
	_storm.text = Mission.storm_text()
	_storm.visible = _storm.text != ""

	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_next_message()


func _update_activity() -> void:
	var a: Dictionary = Mission.activity
	_activity.visible = not a.is_empty()
	if a.is_empty():
		return
	_activity_title.text = a.label
	var done: float = a.total - a.left
	_activity_time.text = "%s  →  %s   (%s h)" % [Mission.clock_text(a.from), Mission.clock_text(a.from + a.total), _hours_text(a.total)]
	_activity_bar.value = 100.0 * done / a.total


static func _hours_text(h: float) -> String:
	return str(snappedf(h, 0.1)).trim_suffix(".0")


## Muestra un mensaje de A.R.I.A. (si ya hay uno, espera su turno).
func say(text: String) -> void:
	_queue.append(text)
	if _message_left <= 0.0:
		_next_message()


func _next_message() -> void:
	if _queue.is_empty():
		create_tween().tween_property(_message_box, "modulate:a", 0.0, 0.3)
		return
	_message.text = _queue.pop_front()
	_message_left = MESSAGE_SECONDS
	create_tween().tween_property(_message_box, "modulate:a", 1.0, 0.2)


## Fin de la misión: mensaje de Control de Misión (textos de data/mission/endings.json) con el botón
## que empieza el regreso a la Tierra (scenes/finales/). La puntuación sale al final del regreso.
func show_end(_reason: String) -> void:
	if _over:
		return
	var info: Dictionary = Final.reason()
	var emergency: bool = info.mood == "emergency"
	_over = ColorRect.new()
	(_over as ColorRect).color = Color(Style.DEEP_BLUE, 0.85)
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_over)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.add_child(center)
	var panel := PanelContainer.new()
	var accent := Style.ROCKET_RED if emergency else Style.NEON_YELLOW
	panel.add_theme_stylebox_override("panel", Style.box(Style.NAVY_SOFT, accent, 4, 28))
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)
	var from := Style.label("INCOMING MESSAGE FROM MISSION CONTROL  ·  EARTH", 16, Style.BLUE_YONDER, 0)
	from.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(from)
	var title := Style.brand_title(str(info.title), 52, accent)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var msg := Style.label(Final.fill(str(info.control)), 22, Style.WHITE, 0)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(700, 0)
	col.add_child(msg)
	var go := Button.new()
	go.text = "WAKE UP THE CREW"
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	Style.brand_button(go, true, 24)
	go.pressed.connect(_start_return)
	col.add_child(go)
	# aparece con un pequeño "pop" (como una transmisión que llega)
	panel.pivot_offset = panel.custom_minimum_size / 2.0
	panel.scale = Vector2(0.9, 0.9)
	_over.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_over, "modulate:a", 1.0, 0.35)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	go.grab_focus()


## ¿Se está enseñando el mensaje del final? (Mission deja el HUD visible mientras tanto)
func showing_end() -> bool:
	return _over != null


func _start_return() -> void:
	get_tree().paused = false
	_over.queue_free()
	_over = null
	SceneChanger.go_to(Final.WAKE)
