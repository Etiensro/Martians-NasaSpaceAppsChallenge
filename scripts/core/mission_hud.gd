extends CanvasLayer
## HUD de la misión (lo crea el autoload Mission): reloj, batería y tormenta arriba a la derecha,
## mensajes de A.R.I.A. abajo y la pantalla de fin de misión.

const Style := preload("res://scripts/core/style.gd")
const MESSAGE_SECONDS := 5.0
const MAIN_MENU := "res://scenes/intro/main_menu.tscn"

var _clock: Label
var _battery: Label
var _bar: ColorRect
var _bar_fill: ColorRect
var _storm: Label
var _message_box: PanelContainer
var _message: Label
var _queue: Array[String] = []
var _message_left := 0.0
var _over: Control


func _init() -> void:
	layer = 40


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.box(Style.NAVY_SOFT, Style.BLUE_YONDER, 2, 10.0))
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -300
	panel.offset_right = -12
	panel.offset_top = 12
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	_clock = Style.label("", 18, Style.WHITE, 0)
	col.add_child(_clock)
	_battery = Style.label("", 15, Style.WHITE, 0)
	col.add_child(_battery)
	_bar = ColorRect.new()
	_bar.custom_minimum_size = Vector2(0, 8)
	_bar.color = Color(1, 1, 1, 0.15)
	col.add_child(_bar)
	_bar_fill = ColorRect.new()
	_bar_fill.size = Vector2(0, 8)
	_bar.add_child(_bar_fill)
	_storm = Style.label("", 14, Style.ROCKET_RED.lightened(0.3), 0)
	col.add_child(_storm)

	# Mensajes de A.R.I.A.
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


func _process(delta: float) -> void:
	if not visible:
		return
	_clock.text = Mission.time_text()
	var net := Mission.net()
	_battery.text = "BATTERY  %d / %d EU   (%s%.1f EU/h)" % [Mission.battery, Mission.capacity(), "+" if net >= 0 else "", net]
	var ratio := Mission.battery / Mission.capacity()
	_bar_fill.size = Vector2(_bar.size.x * ratio, 8)
	_bar_fill.color = Style.NEON_YELLOW if ratio > 0.3 else Style.ROCKET_RED
	_storm.text = Mission.storm_text()
	_storm.visible = _storm.text != ""

	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_next_message()


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


## Pantalla de fin de misión (batería vacía o 60 sols cumplidos).
func show_over(reason: String) -> void:
	if _over:
		return
	_over = ColorRect.new()
	_over.color = Color(Style.DEEP_BLUE, 0.92)
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_over)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	center.add_child(col)
	var won := reason == "complete"
	var title := Style.brand_title("MISSION COMPLETE" if won else "MISSION OVER", 56, Style.NEON_YELLOW if won else Style.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var text := "You kept Ares Base running until the end of the mission!" if won \
		else "The battery ran out. Without power, the base can't keep the crew safe."
	var sub := Style.label(text, 22, Style.WHITE, 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var again := Button.new()
	again.text = "BACK TO MENU"
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	Style.style_button(again, 24)
	again.pressed.connect(_back_to_menu)
	col.add_child(again)


func _back_to_menu() -> void:
	_over.queue_free()
	_over = null
	Mission.reset()
	SceneChanger.go_to(MAIN_MENU)
