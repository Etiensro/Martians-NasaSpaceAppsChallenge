extends Node2D
## Enfermería -> escáner corporal SCAN-MO-TRON 2000 (scenes/interiores/estacion_ares1/modulos/enfermeria/escaneo.tscn).
## El astronauta está sobre la plataforma; al hacer clic empieza el escaneo (un rayo verde lo recorre
## de la cabeza a los pies durante SCAN_SECONDS). Al terminar se aplica el chequeo médico de la misión
## (Mission.crew.medical_checkup): 20 EU (el médico no gasta), 4 h de juego y radiación −30.
## Sin energía suficiente la plataforma se pone roja y A.R.I.A. explica por qué.
## Assets: assets/interiores/estacion_ares1/enfermeria/scan/ (los genera tools/build_lab_medico.py).
## El personaje es el sprite del rol elegido sin casco (GameState.frames_for).

const Style := preload("res://scripts/core/style.gd")
const Fx := preload("res://scripts/core/fx.gd")
const ExitArrow := preload("res://scripts/core/exit_arrow.gd")

const ROOM := "res://scenes/interiores/estacion_ares1/modulos/enfermeria/enfermeria.tscn"
const DIR := "res://assets/interiores/estacion_ares1/enfermeria/"
const SCAN := DIR + "scan/"

const SCAN_SECONDS := 6.0              # lo que dice la pantalla: "SCANNING IN PROGRESS... 6s"
const PAD := Vector2(400, 600)         # base de la plataforma (abajo, a la izquierda del centro)
const PAD_SCALE := 0.9
const PAD_FRAMES := ["pad_1", "pad_2", "pad_3", "pad_4"]   # escaneando (llamas verdes)
const ASTRO_SCALE := 3.4
const MONITOR := Vector2(720, 190)     # esquina de la pantalla SCAN-MO-TRON (debajo del HUD)
const FRAME := Vector2(722, 432)       # esquina del marco con la barra de progreso

enum State { IDLE, SCANNING, CHECKUP, BLOCKED }

var state := State.IDLE

var _tex := {}
var _pad := Sprite2D.new()
var _astro := AnimatedSprite2D.new()
var _beam := Sprite2D.new()
var _glow := Sprite2D.new()
var _monitor := Sprite2D.new()
var _frame := Sprite2D.new()
var _bar := TextureProgressBar.new()
var _complete := Sprite2D.new()
var _heart := Sprite2D.new()
var _warning := Sprite2D.new()
var _id_value: Label
var _height_value: Label
var _status_value: Label
var _hint: Label
var _result: Label
var _exit := ExitArrow.new()
var _scan_t := 0.0
var _hover := false
var _leaving := false


func _ready() -> void:
	var bg := Sprite2D.new()
	bg.texture = load(DIR + "hub.png")
	bg.centered = false
	bg.modulate = Color(0.3, 0.36, 0.46)
	add_child(bg)
	_build_scanner()
	_build_screens()
	_build_ui()
	_exit.position = Vector2(1200, 680)
	add_child(_exit)
	_set_idle()


func tex(key: String) -> Texture2D:
	if not _tex.has(key):
		_tex[key] = load(SCAN + key + ".png")
	return _tex[key]


# ---------------------------------------------------------------- montaje

func _build_scanner() -> void:
	_pad.centered = false
	_pad.scale = Vector2.ONE * PAD_SCALE
	add_child(_pad)
	_set_pad("pad_0")
	_astro.sprite_frames = GameState.frames_for("", false)
	_astro.scale = Vector2.ONE * ASTRO_SCALE
	_astro.position = PAD + Vector2(0, -150 - 30 * ASTRO_SCALE)
	_astro.play("idle_down")
	add_child(_astro)
	_glow.texture = tex("beam_glow")
	_glow.modulate.a = 0.0
	_glow.scale = Vector2(1.2, 0.6)
	add_child(_glow)
	_beam.texture = tex("beam")
	_beam.visible = false
	add_child(_beam)


func _build_screens() -> void:
	_monitor.texture = tex("monitor")
	_monitor.centered = false
	_monitor.position = MONITOR
	add_child(_monitor)
	var m := _monitor.texture.get_size()
	# a la derecha de las etiquetas impresas en la pantalla (PATIENT ID / HEIGHT / STATUS)
	_id_value = _screen_label(MONITOR + Vector2(m.x * 0.455, m.y * 0.355), Style.WHITE)
	_height_value = _screen_label(MONITOR + Vector2(m.x * 0.345, m.y * 0.53), Style.WHITE)
	_status_value = _screen_label(MONITOR + Vector2(m.x * 0.345, m.y * 0.705), Color("3dff7a"))
	_id_value.text = GameState.first_name().to_upper() if GameState.selected_role != "" else "ASTRONAUT"
	_height_value.text = str(GameState.role_data.get("height", "--"))
	_heart.texture = tex("icon_heart")
	_heart.position = MONITOR + Vector2(-40, 40)
	add_child(_heart)
	var beat := create_tween().set_loops()
	beat.tween_property(_heart, "scale", Vector2.ONE * 1.15, 0.12)
	beat.tween_property(_heart, "scale", Vector2.ONE, 0.25)
	beat.tween_interval(0.5)
	_warning.texture = tex("icon_warning")
	_warning.position = MONITOR + Vector2(-40, 110)
	_warning.visible = false
	add_child(_warning)

	_frame.texture = tex("progress_frame")
	_frame.centered = false
	_frame.position = FRAME
	_frame.visible = false
	add_child(_frame)
	var f := _frame.texture.get_size()
	_bar.texture_under = tex("bar_empty")
	_bar.texture_progress = tex("bar_full")
	_bar.nine_patch_stretch = true
	_bar.position = FRAME + Vector2(f.x * 0.045, f.y * 0.1)
	_bar.size = Vector2(f.x * 0.91, f.y * 0.3)
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.visible = false
	add_child(_bar)
	_complete.texture = tex("scan_complete")
	_complete.position = FRAME + f / 2.0  # sustituye al marco al terminar
	_complete.scale = Vector2.ONE * 1.4
	_complete.visible = false
	add_child(_complete)


func _screen_label(at: Vector2, color: Color) -> Label:
	var l := Style.label("", 22, color, 0)
	l.position = at
	add_child(l)
	return l


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var top := Style.label("Infirmary  ·  Body scanner  ·  Esc: back", 15, Style.WHITE, 5)
	top.position = Vector2(16, 10)
	layer.add_child(top)
	_hint = Style.label("", 20, Style.WHITE, 5)
	_hint.position = Vector2(24, 44)
	_hint.size = Vector2(720, 60)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(_hint)
	_result = Style.label("", 20, Style.WHITE, 5)
	_result.position = Vector2(24, 104)
	_result.size = Vector2(600, 90)
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(_result)


## Las plataformas tienen alturas distintas (por las llamas): todas comparten la base.
func _set_pad(key: String) -> void:
	_pad.texture = tex(key)
	var s := _pad.texture.get_size() * PAD_SCALE
	_pad.position = PAD - Vector2(s.x / 2.0, s.y)


func _pad_rect() -> Rect2:
	var s := tex("pad_0").get_size() * PAD_SCALE
	return Rect2(PAD.x - s.x / 2.0, PAD.y - s.y - 320, s.x, s.y + 320)  # plataforma + astronauta


# ---------------------------------------------------------------- estados

func _set_idle() -> void:
	state = State.IDLE
	_set_pad("pad_0")
	_beam.visible = false
	_status_value.text = "READY"
	var cost := Mission.crew.checkup_energy()
	_hint.text = "Click the scanner to start your check-up  (%d EU · %d h · radiation −%d)" % [
		cost, Mission.rules.crew.radiation.checkup_hours, Mission.rules.crew.radiation.checkup_reduction]


func _start() -> void:
	var reason := Mission.crew.checkup_blocked_reason()
	if reason != "":
		state = State.BLOCKED
		_set_pad("pad_red")
		_warning.visible = true
		_status_value.text = "ERROR"
		_status_value.add_theme_color_override("font_color", Style.ROCKET_RED)
		Mission.notify(reason)
		_hint.text = reason
		return
	state = State.SCANNING
	_scan_t = 0.0
	_warning.visible = false
	_complete.visible = false
	_frame.visible = true
	_bar.visible = true
	_bar.value = 0.0
	_beam.visible = true
	_result.text = ""
	_status_value.text = "SCANNING..."
	_status_value.add_theme_color_override("font_color", Color("3dff7a"))
	_hint.text = "Stand still... the scanner checks how much radiation your body received."


func _process(delta: float) -> void:
	Audio.set_loop("scanning", state == State.SCANNING)
	var mouse := get_global_mouse_position()
	_exit.hovered = _exit.hit(mouse)
	var over := state == State.IDLE and _pad_rect().has_point(mouse)
	if over != _hover:
		_hover = over
		_pad.modulate = Color(1.25, 1.25, 1.25) if over else Color.WHITE
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if over else Input.CURSOR_ARROW)
	if state == State.SCANNING:
		_scan(delta)


## El rayo baja y sube por el cuerpo (dos pasadas) mientras la plataforma brilla.
func _scan(delta: float) -> void:
	_scan_t += delta
	var k := _scan_t / SCAN_SECONDS
	_bar.value = minf(k, 1.0)
	_set_pad(PAD_FRAMES[int(_scan_t * 8.0) % PAD_FRAMES.size()])
	var head := _astro.position.y - 40.0 * ASTRO_SCALE
	var feet := PAD.y - 140.0
	var wave := 0.5 - 0.5 * cos(k * TAU * 2.0)   # 0 -> 1 -> 0 -> 1 -> 0
	_beam.position = Vector2(PAD.x, lerpf(head, feet, wave))
	_glow.position = _beam.position
	_glow.modulate.a = 0.35
	if _scan_t >= SCAN_SECONDS:
		_finish_scan()


func _finish_scan() -> void:
	state = State.CHECKUP
	_beam.visible = false
	_glow.modulate.a = 0.0
	_set_pad("pad_0")
	_frame.visible = false
	_bar.visible = false
	_complete.visible = true
	_status_value.text = "COMPLETE"
	_sparkles()
	var before := Mission.crew.radiation
	var cost := Mission.crew.checkup_energy()
	await get_tree().create_timer(0.8).timeout
	# el chequeo de la misión: gasta energía y adelanta el reloj lo que falta de las 4 h
	var played: float = SCAN_SECONDS / Mission.rules.clock.real_seconds_per_hour
	var why: String = await Mission.crew.medical_checkup(played)
	if why != "":
		Mission.notify(why)
		_set_idle()
		return
	var after := Mission.crew.radiation
	_status_value.text = "HEALTHY" if after < 50.0 else "HIGH RADIATION"
	_result.text = "Radiation  %d → %d\nEnergy used: %d EU" % [roundi(before), roundi(after), roundi(cost)]
	await get_tree().create_timer(1.5).timeout
	_frame.visible = false
	_bar.visible = false
	_complete.visible = false
	_set_idle()


func _sparkles() -> void:
	for i in 10:
		var s := Sprite2D.new()
		s.texture = tex("sparkle")
		s.position = _astro.position + Vector2(randf_range(-90, 90), randf_range(-150, 120))
		s.scale = Vector2.ZERO
		add_child(s)
		var tw := create_tween()
		tw.tween_interval(i * 0.05)
		tw.tween_property(s, "scale", Vector2.ONE * randf_range(0.6, 1.2), 0.2)
		tw.parallel().tween_property(s, "position:y", s.position.y - 40.0, 0.6)
		tw.tween_property(s, "modulate:a", 0.0, 0.3)
		tw.tween_callback(s.queue_free)


# ---------------------------------------------------------------- entrada

func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_cancel"):
		_back()
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := get_global_mouse_position()
	if _exit.hit(p):
		_back()
	elif state in [State.IDLE, State.BLOCKED] and _pad_rect().has_point(p):
		_warning.visible = false
		_start()


func _back() -> void:
	if state in [State.SCANNING, State.CHECKUP]:
		return  # no se sale a mitad del escaneo
	_leaving = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	SceneChanger.go_to(ROOM)
