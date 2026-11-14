extends PanelContainer
## Caja de diálogo estilo RPG con retrato, nombre y texto que se escribe letra a letra.
## Uso:
##   await box.say("A.R.I.A.", Color.CYAN, "Hello!", portrait_tex, portrait_material)
## Clic / Espacio / Enter: completa el texto; si ya está completo, pasa a la siguiente línea.

signal advanced

const Style := preload("res://scripts/intro/intro_style.gd")

@export var chars_per_second := 45.0

var _portrait := TextureRect.new()
var _name: Label
var _text: Label
var _arrow: Label
var _typing := false
var _tween: Tween


func _ready() -> void:
	add_theme_stylebox_override("panel", Style.box(Style.NAVY_SOFT, Style.AMBER, 4, 18))
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = 40
	offset_right = -40
	offset_top = -200
	offset_bottom = -24
	mouse_filter = Control.MOUSE_FILTER_STOP

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	add_child(row)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", Style.box(Color(0.1, 0.13, 0.25), Style.WHITE, 3, 4))
	frame.custom_minimum_size = Vector2(140, 140)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(frame)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(_portrait)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	_name = Style.label("", 24, Style.AMBER, 6)
	col.add_child(_name)
	_text = Style.label("", 22, Style.WHITE, 4)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	col.add_child(_text)

	var bottom := HBoxContainer.new()
	col.add_child(bottom)
	var hint := Style.label("Click / Space: continue    Esc: skip", 13, Color(1, 1, 1, 0.5), 3)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(hint)
	_arrow = Style.label("▼", 20, Style.AMBER, 4)
	bottom.add_child(_arrow)
	var tw := create_tween().set_loops()
	tw.tween_property(_arrow, "modulate:a", 0.2, 0.4)
	tw.tween_property(_arrow, "modulate:a", 1.0, 0.4)


## Muestra una línea y espera a que el jugador avance.
func say(speaker: String, color: Color, text: String, portrait: Texture2D = null, portrait_material: Material = null) -> void:
	show()
	_name.text = speaker
	_name.add_theme_color_override("font_color", color)
	_portrait.texture = portrait
	_portrait.material = portrait_material
	_text.text = text
	_text.visible_ratio = 0.0
	_arrow.visible = false
	_typing = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_text, "visible_ratio", 1.0, maxf(text.length() / chars_per_second, 0.1))
	_tween.tween_callback(_finish_typing)
	await advanced


## Avanza desde fuera (p. ej. al saltar la escena).
func force_advance() -> void:
	_finish_typing()
	advanced.emit()


func _finish_typing() -> void:
	if _tween:
		_tween.kill()
	_text.visible_ratio = 1.0
	_typing = false
	_arrow.visible = true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_press()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		_press()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_press()  # clic en cualquier parte de la pantalla también avanza


func _press() -> void:
	if _typing:
		_finish_typing()
	else:
		advanced.emit()
