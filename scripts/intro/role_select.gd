extends Control
## PASO 4: selección de personaje. Muestra las 4 profesiones (GameState.roles, de
## data/intro/roles.json) con sus ventajas; el jugador elige una y confirma.
## Retrato sin casco; al pasar el ratón o elegirla, con casco.
## Emite role_chosen(role_id) al confirmar.

signal role_chosen(role_id: String)

const Style := preload("res://scripts/core/style.gd")
const CARD_SIZE := Vector2(272, 420)

var _group := ButtonGroup.new()
var _cards := {}       # role_id -> Button
var _portraits := {}   # role_id -> TextureRect
var _selected := ""
var _confirm: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.08, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)

	var title := Style.label("WHO STAYS AWAKE?", 46, Style.AMBER, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := Style.label("Pick the crew member who will run Ares Base during the storm.\nThe other three will sleep safely in the cryo pods.", 18, Style.WHITE, 4)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for id in GameState.role_order:
		row.add_child(_make_card(id, GameState.roles[id]))

	_confirm = Button.new()
	_confirm.text = "CHOOSE A CREW MEMBER"
	_confirm.disabled = true
	_confirm.custom_minimum_size = Vector2(520, 60)
	_confirm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	Style.style_button(_confirm, 24)
	_confirm.pressed.connect(func(): role_chosen.emit(_selected))
	col.add_child(_confirm)

	# Entrada: todo aparece y las tarjetas suben una tras otra
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)
	await get_tree().process_frame  # esperar a que el contenedor coloque las tarjetas
	var i := 0
	for id in GameState.role_order:
		var c: Button = _cards[id]
		var target_y := c.position.y
		c.position.y += 60
		c.modulate.a = 0.0
		var ct := create_tween().set_parallel()
		ct.tween_property(c, "position:y", target_y, 0.45).set_delay(0.1 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ct.tween_property(c, "modulate:a", 1.0, 0.3).set_delay(0.1 * i)
		i += 1
	_cards[GameState.role_order[0]].grab_focus()


func _make_card(id: String, r: Dictionary) -> Button:
	var color := GameState.role_color(id)
	var card := Button.new()
	card.toggle_mode = true
	card.button_group = _group
	card.custom_minimum_size = CARD_SIZE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_theme_stylebox_override("normal", Style.box(Style.NAVY_SOFT, color.darkened(0.45), 4))
	card.add_theme_stylebox_override("hover", Style.box(Color(0.09, 0.12, 0.27, 0.95), color, 4))
	card.add_theme_stylebox_override("focus", Style.box(Color(0, 0, 0, 0), Style.WHITE, 2))
	card.add_theme_stylebox_override("pressed", Style.box(color.darkened(0.7), Style.AMBER, 7))
	card.add_theme_stylebox_override("hover_pressed", Style.box(color.darkened(0.65), Style.AMBER, 7))
	card.toggled.connect(_on_card_toggled.bind(id))
	card.mouse_entered.connect(_hover.bind(id, true))
	card.mouse_exited.connect(_hover.bind(id, false))
	card.focus_entered.connect(_hover.bind(id, true))
	card.focus_exited.connect(_hover.bind(id, false))
	_cards[id] = card

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	card.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	margin.add_child(v)

	var portrait := TextureRect.new()
	portrait.texture = GameState.portrait_for(id)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(0, 110)
	v.add_child(portrait)
	_portraits[id] = portrait

	v.add_child(_card_label(r.get("title", id.to_upper()), 26, color, 6, true))
	v.add_child(_card_label(r.get("crew_name", ""), 16, Color(1, 1, 1, 0.75), 3, true))
	v.add_child(_card_label(r.get("tagline", ""), 17, Style.WHITE, 4, true))

	var line := ColorRect.new()
	line.color = Color(color, 0.6)
	line.custom_minimum_size = Vector2(0, 3)
	v.add_child(line)

	for perk in r.get("perks", []):
		v.add_child(_card_label("+ " + str(perk), 15, Color(0.75, 1, 0.75), 3))

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	if r.has("fact"):
		v.add_child(_card_label("Did you know? " + str(r.fact), 12, Color(0.75, 0.85, 1, 0.85), 3))

	_ignore_mouse(margin)  # que los clics lleguen a la tarjeta (el botón)
	return card


func _card_label(text: String, font_size: int, color: Color, outline: int, centered := false) -> Label:
	var l := Style.label(text, font_size, color, outline)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _ignore_mouse(n: Node) -> void:
	if n is Control:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)


func _hover(id: String, on: bool) -> void:
	var helmet := on or id == _selected
	_portraits[id].texture = GameState.portrait_for(id, helmet)
	var card: Button = _cards[id]
	card.pivot_offset = card.size / 2.0
	create_tween().tween_property(card, "scale", Vector2.ONE * (1.04 if on else 1.0), 0.12)


func _on_card_toggled(on: bool, id: String) -> void:
	if on:
		_select(id)


func _select(id: String) -> void:
	var prev := _selected
	_selected = id
	if prev != "" and prev != id:
		_hover(prev, false)
	_portraits[id].texture = GameState.portrait_for(id, true)
	_confirm.text = "CONFIRM: %s STAYS AWAKE" % GameState.first_name(id).to_upper()
	_confirm.disabled = false
	if get_viewport().gui_get_focus_owner() == _cards[id]:
		_confirm.grab_focus()  # con teclado: Enter elige y Enter otra vez confirma
