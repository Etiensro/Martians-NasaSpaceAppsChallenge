extends Node2D
## PASO 1 + 2 de la intro: menú principal y cinemática de la tormenta.
## - De fondo, la colonia real de AP-1 (mismo suelo y edificios que scenes/ap1_zone.tscn), con viento.
## - Panel de la izquierda con la marca NASA Space Apps (logo, Fira Sans / Overpass, colores).
## - "START MISSION": la UI desaparece, aparecen franjas de cine, la cámara se aleja y
##   se desplaza hacia la tormenta que se acerca; luego fundido a negro -> interior de la base.
## - "VIEW REPOSITORY": abre el repo de GitHub.

const Style := preload("res://scripts/core/style.gd")
const Colony := preload("res://scripts/colony.gd")
const Sandstorm := preload("res://scripts/intro/sandstorm.gd")
const WindLayer := preload("res://scripts/intro/wind_layer.gd")

const NEXT_SCENE := "res://scenes/intro/base_interior.tscn"
const REPO_URL := "https://github.com/Etiensro/Martians-NasaSpaceAppsChallenge"

@export var cinematic_duration := 9.0

## Ancho del panel de marca (izquierda) y margen interior.
const PANEL_W := 520.0
const PAD := 48.0

## Encuadre del menú: la base queda a la derecha del panel.
const MENU_CAM_POS := Vector2(600, 920)
const MENU_ZOOM := 0.45
## Encuadre final de la cinemática: toda la zona AP-1 con la tormenta entrando por la derecha.
const END_CAM_POS := Vector2(2300, 1104)
const END_ZOOM := 0.33
const STORM_Y := 1104.0
const STORM_START_X := 6500.0
const STORM_END_X := 3500.0  # se queda en el horizonte: todavía hay tiempo

var camera := Camera2D.new()
var storm: Sandstorm
var wind: WindLayer
var ui := Control.new()
var cine_layer := CanvasLayer.new()
var _bar_top := ColorRect.new()
var _bar_bottom := ColorRect.new()
var _caption: Label
var _start_btn: Button
var _shake := 0.0
var _t := 0.0
var _in_cinematic := false
var _leaving := false


func _ready() -> void:
	_build_world()
	_build_ui()
	_build_cinematic_layer()
	_start_btn.grab_focus()


# ---------------------------------------------------------------- mundo

func _build_world() -> void:
	Colony.add_ground(self)  # suelo de AP-1 (el mismo que ap1_zone.tscn)

	# Colonia de AP-1 (edificios, vehículo, luces, viento); sin jugador ni puertas
	var colony := Colony.new()
	colony.doors_enabled = false
	add_child(colony)

	storm = Sandstorm.new()
	storm.position = Vector2(STORM_START_X, STORM_Y)
	add_child(storm)

	camera.position = MENU_CAM_POS
	camera.zoom = Vector2.ONE * MENU_ZOOM
	add_child(camera)
	camera.make_current()

	wind = WindLayer.new()
	wind.intensity = 0.3
	add_child(wind)


# ---------------------------------------------------------------- UI (marca NASA Space Apps)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # logo y letras suaves (el mundo sigue pixelado)
	layer.add_child(ui)

	# Panel con el degradado de la marca: el texto y el logo nunca van sobre el suelo "ruidoso"
	var panel := TextureRect.new()
	panel.texture = Style.brand_gradient(0.7)
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_right = PANEL_W
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(panel)
	var edge := ColorRect.new()  # filo amarillo del panel (acento)
	edge.color = Style.NEON_YELLOW
	edge.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	edge.offset_left = PANEL_W
	edge.offset_right = PANEL_W + 4
	ui.add_child(edge)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	margin.offset_right = PANEL_W
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, PAD)
	ui.add_child(margin)
	var col := VBoxContainer.new()
	margin.add_child(col)

	# Logo arriba a la izquierda (versión horizontal, blanca, sobre azul)
	if ResourceLoader.exists(Style.LOGO_SPACE_APPS):
		var logo := TextureRect.new()
		logo.texture = load(Style.LOGO_SPACE_APPS)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		logo.custom_minimum_size = Vector2(220, 220 * 189.0 / 480.0)
		logo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		col.add_child(logo)

	var top_space := Control.new()
	top_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(top_space)

	# Título y subtítulos, todo alineado al mismo margen izquierdo que el logo
	col.add_child(Style.brand_title("Martians", 76))
	var mission := Style.brand_label("MISSION ARES 1", 30, Style.BLUE_YONDER, 600)
	col.add_child(mission)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	col.add_child(gap)
	var tagline := Style.brand_label("One storm. One astronaut awake.
Every choice counts.", 20, Style.WHITE, 400)
	col.add_child(tagline)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 32)
	col.add_child(spacer)

	_start_btn = Button.new()
	_start_btn.text = "START MISSION"
	_start_btn.custom_minimum_size = Vector2(0, 60)
	Style.brand_button(_start_btn, true, 24)
	_start_btn.pressed.connect(_on_start)
	col.add_child(_start_btn)
	# Pequeño "latido" del botón principal para llamar la atención de los peques
	_start_btn.resized.connect(func(): _start_btn.pivot_offset = _start_btn.size / 2.0)
	var tw := create_tween().set_loops()
	tw.tween_property(_start_btn, "scale", Vector2.ONE * 1.03, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_start_btn, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)

	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 12)
	col.add_child(gap2)

	var repo_btn := Button.new()
	repo_btn.text = "VIEW REPOSITORY"
	repo_btn.custom_minimum_size = Vector2(0, 52)
	Style.brand_button(repo_btn, false, 20)
	repo_btn.pressed.connect(func(): OS.shell_open(REPO_URL))
	col.add_child(repo_btn)

	var bottom_space := Control.new()
	bottom_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(bottom_space)

	col.add_child(Style.brand_label("NASA Space Apps Challenge  ·  Junior Astronaut Mission Trainer", 13, Color(1, 1, 1, 0.75), 400))


func _build_cinematic_layer() -> void:
	cine_layer.layer = 20
	add_child(cine_layer)
	for bar in [_bar_top, _bar_bottom]:
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cine_layer.add_child(bar)
	_caption = Style.brand_label("", 26, Style.WHITE, 600)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.modulate.a = 0.0
	cine_layer.add_child(_caption)
	_layout_bars(0.0)
	get_viewport().size_changed.connect(func(): _layout_bars(_bar_top.size.y))


func _layout_bars(h: float) -> void:
	var vp := get_viewport_rect().size
	_bar_top.position = Vector2.ZERO
	_bar_top.size = Vector2(vp.x, h)
	_bar_bottom.position = Vector2(0, vp.y - h)
	_bar_bottom.size = Vector2(vp.x, h)
	_caption.position = Vector2(0, vp.y - 58)
	_caption.size = Vector2(vp.x, 40)


# ---------------------------------------------------------------- cinemática

func _on_start() -> void:
	if _in_cinematic:
		return
	_in_cinematic = true
	_start_btn.disabled = true

	# 1) La interfaz se desvanece
	var tw := create_tween()
	tw.tween_property(ui, "modulate:a", 0.0, 0.6)
	# Franjas de cine
	tw.parallel().tween_method(_layout_bars, 0.0, 70.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	ui.visible = false

	# 2) Cámara: se aleja de la base y se desplaza hacia la tormenta, que avanza
	var d := cinematic_duration
	var cam := create_tween().set_parallel()
	cam.tween_property(camera, "zoom", Vector2.ONE * END_ZOOM, d).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam.tween_property(camera, "position", END_CAM_POS, d).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam.tween_property(storm, "position:x", STORM_END_X, d).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	cam.tween_property(storm, "intensity", 0.55, d)
	cam.tween_property(wind, "intensity", 0.45, d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	cam.tween_property(self, "_shake", 1.5, d).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# Textos y salida encadenados en un Tween (si el nodo se libera al saltar, el Tween muere con él)
	_show_caption("SOL 112  ·  ARCADIA PLANITIA, MARS", 0.3, 2.2)
	var seq := create_tween()
	seq.tween_interval(d * 0.5)
	seq.tween_callback(_show_caption.bind("A massive dust storm is coming...", 0.0, d * 0.5))
	seq.tween_interval(d * 0.5)
	seq.tween_callback(_go_inside)


func _show_caption(text: String, delay: float, hold: float) -> void:
	if _leaving:
		return
	_caption.text = text
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(_caption, "modulate:a", 1.0, 0.4)
	tw.tween_interval(maxf(hold - 0.8, 0.1))
	tw.tween_property(_caption, "modulate:a", 0.0, 0.4)


func _go_inside() -> void:
	if _leaving:
		return
	_leaving = true
	var tw := create_tween().set_parallel()
	tw.tween_property(wind, "intensity", 0.55, 1.4)
	tw.tween_property(self, "_shake", 2.0, 1.4)
	SceneChanger.go_to(NEXT_SCENE, 1.6)


func _process(delta: float) -> void:
	_t += delta
	if not _in_cinematic:
		# Deriva lenta de la cámara en el menú para que la escena "respire"
		camera.position = MENU_CAM_POS + Vector2(sin(_t * 0.25) * 18.0, cos(_t * 0.2) * 10.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake


func _unhandled_input(event: InputEvent) -> void:
	# Durante la cinemática: Esc / Espacio / clic la saltan
	if not _in_cinematic or _leaving:
		return
	var skip: bool = event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept") \
		or (event is InputEventMouseButton and event.pressed)
	if skip:
		get_viewport().set_input_as_handled()
		_go_inside()
