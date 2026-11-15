extends Node2D
## PASO 1 + 2 de la intro: menú principal y cinemática de la tormenta.
## - Vista cenital de la Base Ares 1 sobre el suelo marciano, con viento y polvo de fondo.
## - "START MISSION": la UI desaparece, aparecen franjas de cine, la cámara se aleja y
##   se desplaza hacia la tormenta que se acerca; luego fundido a negro -> interior de la base.
## - "VIEW REPOSITORY": abre el repo de GitHub.
## Todo el arte es provisional; los puntos para enchufar arte final están marcados con @export.

const Style := preload("res://scripts/core/style.gd")
const BaseExterior := preload("res://scripts/intro/base_exterior.gd")
const Sandstorm := preload("res://scripts/intro/sandstorm.gd")
const WindLayer := preload("res://scripts/intro/wind_layer.gd")

const NEXT_SCENE := "res://scenes/intro/base_interior.tscn"
const REPO_URL := "https://github.com/Etiensro/Martians-NasaSpaceAppsChallenge"
## Si existen estos PNG se muestran como logos; si no, aparece un recuadro provisional.
const LOGO_SLOTS := [
	["res://assets/ui/logo_nasa.png", "NASA LOGO"],
	["res://assets/ui/logo_space_apps.png", "SPACE APPS LOGO"],
]

@export var ground_texture: Texture2D = preload("res://assets/zones/ap1_ground.png")
@export var ground_cell := 3.0             # igual que ap1_zone.tscn
@export var base_texture: Texture2D        # base vista desde arriba (sustituye el dibujo provisional)
@export var title_texture: Texture2D       # logo del juego (opcional, sustituye al texto)
@export var title_font: Font               # fuente pixel (opcional)
@export var cinematic_duration := 5.5

## Encuadre del menú: la base queda a la derecha, la UI a la izquierda.
const MENU_CAM_POS := Vector2(-330, 20)
const MENU_ZOOM := 1.05
## Encuadre final de la cinemática: lejos, mirando hacia la tormenta.
const END_CAM_POS := Vector2(1150, -60)
const END_ZOOM := 0.3
const STORM_START_X := 2500.0
const STORM_END_X := 1900.0

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
	# Suelo marciano repetido (mismo PNG que la zona AP-1)
	var ground := Sprite2D.new()
	ground.texture = ground_texture
	ground.centered = false
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.region_enabled = true
	var world_size := Vector2(14000, 9000)
	ground.region_rect = Rect2(Vector2.ZERO, world_size / ground_cell)
	ground.scale = Vector2.ONE * ground_cell
	ground.position = -world_size / 2.0
	ground.modulate = Color(1, 0.95, 0.9)
	add_child(ground)

	var base := BaseExterior.new()
	base.base_texture = base_texture
	add_child(base)

	# Rover estacionado junto a la base (asset del equipo, si está)
	var rover_path := "res://assets/vehicles/rover_frames.tres"
	if ResourceLoader.exists(rover_path):
		var rover := AnimatedSprite2D.new()
		rover.sprite_frames = load(rover_path)
		rover.position = Vector2(160, 250)
		if rover.sprite_frames.has_animation("idle_side"):
			rover.play("idle_side")
		add_child(rover)

	storm = Sandstorm.new()
	storm.position = Vector2(STORM_START_X, 0)
	add_child(storm)

	camera.position = MENU_CAM_POS
	camera.zoom = Vector2.ONE * MENU_ZOOM
	add_child(camera)
	camera.make_current()

	wind = WindLayer.new()
	wind.intensity = 0.3
	add_child(wind)


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)

	# Logos arriba a la izquierda
	var logos := HBoxContainer.new()
	logos.position = Vector2(28, 22)
	logos.add_theme_constant_override("separation", 16)
	ui.add_child(logos)
	for slot in LOGO_SLOTS:
		logos.add_child(_logo(slot[0], slot[1]))

	# Bloque central izquierdo: título + botones
	var col := VBoxContainer.new()
	col.position = Vector2(70, 170)
	col.add_theme_constant_override("separation", 10)
	ui.add_child(col)

	if title_texture:
		var tr := TextureRect.new()
		tr.texture = title_texture
		tr.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		col.add_child(tr)
	else:
		var title := Style.label("MARTIANS", 96, Style.AMBER, 14)
		if title_font:
			title.add_theme_font_override("font", title_font)
		col.add_child(title)
	col.add_child(Style.label("MISSION  ARES 1", 34, Style.CYAN, 8))
	col.add_child(Style.label("One storm. One astronaut awake. Every choice counts.", 18, Style.WHITE, 5))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 36)
	col.add_child(spacer)

	_start_btn = Button.new()
	_start_btn.text = "START MISSION"
	_start_btn.custom_minimum_size = Vector2(380, 66)
	Style.style_button(_start_btn, 30)
	_start_btn.pressed.connect(_on_start)
	col.add_child(_start_btn)

	var repo_btn := Button.new()
	repo_btn.text = "VIEW REPOSITORY"
	repo_btn.custom_minimum_size = Vector2(380, 52)
	Style.style_button(repo_btn, 22)
	repo_btn.pressed.connect(func(): OS.shell_open(REPO_URL))
	col.add_child(repo_btn)

	# Pequeño "latido" del botón principal para llamar la atención de los peques
	_start_btn.pivot_offset = _start_btn.custom_minimum_size / 2.0
	var tw := create_tween().set_loops()
	tw.tween_property(_start_btn, "scale", Vector2.ONE * 1.04, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_start_btn, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)

	var footer := Style.label("NASA Space Apps Challenge  ·  Junior Astronaut Mission Trainer", 14, Color(1, 1, 1, 0.85), 4)
	footer.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	footer.offset_left = 28
	footer.offset_top = -46
	footer.offset_bottom = -20
	ui.add_child(footer)


func _logo(path: String, placeholder: String) -> Control:
	if ResourceLoader.exists(path):
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(150, 72)
		return tr
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Style.box(Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.6), 2))
	p.custom_minimum_size = Vector2(150, 72)
	var l := Style.label(placeholder, 13, Color(1, 1, 1, 0.8), 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


func _build_cinematic_layer() -> void:
	cine_layer.layer = 20
	add_child(cine_layer)
	for bar in [_bar_top, _bar_bottom]:
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cine_layer.add_child(bar)
	_caption = Style.label("", 26, Style.WHITE, 6)
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
	cam.tween_property(storm, "position:x", STORM_END_X, d + 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	cam.tween_property(storm, "intensity", 1.0, d)
	cam.tween_property(wind, "intensity", 0.75, d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	cam.tween_property(self, "_shake", 9.0, d).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

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
	tw.tween_property(wind, "intensity", 1.0, 0.9)
	tw.tween_property(self, "_shake", 14.0, 0.9)
	SceneChanger.go_to(NEXT_SCENE, 1.0)


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
