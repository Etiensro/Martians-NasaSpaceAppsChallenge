extends Node2D
## Laboratorio (Work Room) -> cabina de bioseguridad: preparar una muestra de hielo para analizarla
## (scenes/interiores/estacion_ares1/modulos/sala_trabajo/analisis.tscn).
## Necesita una muestra guardada en la base (Mission.research: se trae de AP-1, AP-8 o AP-9).
## Pasos, como en un laboratorio de verdad (dentro de la cabina, para no contaminar la muestra):
##   1. TRANSFER  con las pinzas estériles, pasar cada trozo de hielo de la caja al matraz sin que se caiga
##               (si se cae, se contamina: vuelve a la caja y baja la calidad de la muestra).
##   2. HEAT      derretirlo con calor suave: mantener pulsado para calentar y soltar para enfriar. En la
##               zona verde se derrite; en la amarilla más rápido pero con riesgo; en la roja hierve y
##               los microbios y moléculas que buscamos se destruyen (falla si se queda ahí).
##   3. POUR      llevar el matraz a la caja de Petri estéril y verter el agua sin derramarla.
## Al terminar, el analizador del laboratorio empieza el análisis de 72 h (Mission.research.start_analysis).
## Si la calidad llega a 0, hay que empezar de nuevo.
## Assets: assets/interiores/estacion_ares1/sala_trabajo/lab/ (los genera tools/build_lab_medico.py).
## El fondo es la sala completa oscurecida (provisional) y el termómetro se dibuja por código (provisional).

const Style := preload("res://scripts/core/style.gd")
const Fx := preload("res://scripts/core/fx.gd")
const ExitArrow := preload("res://scripts/core/exit_arrow.gd")

const ROOM := "res://scenes/interiores/estacion_ares1/modulos/sala_trabajo/sala_trabajo.tscn"
const DIR := "res://assets/interiores/estacion_ares1/sala_trabajo/"
const LAB := DIR + "lab/"

const ICE_COUNT := 4
const TRAY := Vector2(250, 575)        # centro de la caja con el hielo
const PLATE := Vector2(640, 650)       # base de la parrilla (abajo al centro)
const DISH := Vector2(1010, 610)       # centro de la caja de Petri estéril
## Interior del matraz (donde se suelta el hielo), relativo a la esquina del sprite de la parrilla.
const MOUTH := Rect2(40, 0, 175, 235)
## Dónde quedan los trozos dentro del matraz (relativo a la esquina del sprite).
const IN_BEAKER := [Vector2(95, 205), Vector2(160, 205), Vector2(125, 180), Vector2(170, 170)]
## Pico del matraz al servir (relativo a la esquina de beaker_pour.png): de ahí caen las gotas.
const SPOUT := Vector2(262, 172)
const GRAB_RADIUS := 45.0

# Temperatura (°C) y fusión
const T_START := -20.0
const T_MIN := -20.0
const T_MAX := 100.0
const GREEN := 5.0            # desde aquí se derrite
const YELLOW := 45.0          # más rápido, pero hay que tener cuidado
const RED := 75.0             # hierve: la muestra se estropea
const HEAT_RATE := 26.0       # °C/s con el botón pulsado
const COOL_RATE := 14.0       # °C/s al soltar
const MELT_TIME := 9.0        # segundos en la zona verde para derretir todo
const BOIL_LIMIT := 1.5       # segundos seguidos en la zona roja antes de fallar
const POUR_TIME := 3.0        # segundos sirviendo para llenar la caja
const QUALITY_DROP := 10.0    # por cada trozo que se cae
const QUALITY_BOIL := 25.0    # por segundo hirviendo
const QUALITY_SPILL := 15.0   # por segundo derramando fuera de la caja

enum Stage { WAITING, TRANSFER, HEAT, POUR, DONE, FAILED }

var stage := Stage.TRANSFER
var quality := 100.0
var temperature := T_START
var melted := 0.0             # 0-1
var filled := 0.0             # 0-1

var _tex := {}                # nombre -> Texture2D
var _info: Dictionary         # tamaños y punta de las pinzas (lab.json)
var _plate := Sprite2D.new()
var _tray := Sprite2D.new()
var _dish := Sprite2D.new()
var _hand := Sprite2D.new()
var _pour := Sprite2D.new()
var _ice: Array[Sprite2D] = []          # trozos que quedan en la caja
var _in_beaker: Array[Sprite2D] = []    # trozos ya en el matraz
var _held: Sprite2D = null              # trozo que llevan las pinzas
var _bubbles: CPUParticles2D
var _steam: CPUParticles2D
var _drops: CPUParticles2D
var _exit := ExitArrow.new()
var _gauge := Node2D.new()
var _ui: CanvasLayer
var _title: Sprite2D
var _hint: Label
var _quality_bar: ProgressBar
var _quality_label: Label
var _melt_label: Sprite2D
var _melt_digits := Node2D.new()
var _banner: Sprite2D
var _banner_tw: Tween
var _pressing := false
var _boil_time := 0.0
var _was_red := false
var _leaving := false
var _t := 0.0


func _ready() -> void:
	_info = JSON.parse_string(FileAccess.get_file_as_string(LAB + "lab.json"))
	var bg := Sprite2D.new()
	bg.texture = load(DIR + "hub.png")
	bg.centered = false
	bg.modulate = Color(0.32, 0.38, 0.5)
	add_child(bg)
	_build_ui()
	_exit.position = Vector2(1200, 680)
	add_child(_exit)
	var reason := Mission.research.start_blocked_reason()
	if reason != "":
		_show_waiting(reason)
		return
	_build_bench()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN  # el cursor es la mano con las pinzas
	_set_stage(Stage.TRANSFER)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func tex(key: String) -> Texture2D:
	if not _tex.has(key):
		_tex[key] = load(LAB + key + ".png")
	return _tex[key]


# ---------------------------------------------------------------- montaje

func _build_bench() -> void:
	_tray.texture = tex("dish_empty")
	_tray.position = TRAY
	add_child(_tray)
	_dish.texture = tex("dish_empty")
	_dish.position = DISH
	add_child(_dish)
	_plate.centered = false
	add_child(_plate)
	_set_plate("plate_beaker_off")
	for i in ICE_COUNT:
		var s := Sprite2D.new()
		s.texture = tex("ice_%d" % (i % 5 + 1))
		s.position = _tray_spot(i)
		s.set_meta("home", s.position)
		add_child(s)
		_ice.append(s)
	_bubbles = Fx.particles(tex("bubble"), 14, 1.4, Vector2(0, -1), 15, 25, 60)
	_bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_bubbles.emission_rect_extents = Vector2(60, 10)
	_bubbles.emitting = false
	add_child(_bubbles)
	_steam = Fx.particles(Fx.PUFF, 18, 1.6, Vector2(0, -1), 25, 30, 70)
	_steam.scale_amount_min = 4.0
	_steam.scale_amount_max = 8.0
	_steam.color_ramp = Fx.ramp(Color(1, 1, 1, 0.5))
	_steam.emitting = false
	add_child(_steam)
	_drops = Fx.particles(tex("bubble"), 30, 0.7, Vector2(0, 1), 8, 40, 80, Vector2(0, 900))
	_drops.scale_amount_min = 0.6
	_drops.scale_amount_max = 1.0
	_drops.emitting = false
	_drops.z_index = 40
	add_child(_drops)
	_pour.texture = tex("beaker_pour")
	_pour.centered = false
	_pour.visible = false
	_pour.z_index = 45
	add_child(_pour)
	_hand.centered = false
	_hand.z_index = 50
	add_child(_hand)
	_gauge.draw.connect(_draw_gauge)
	add_child(_gauge)


## Posición de un trozo dentro de la caja de hielo (repartidos por su superficie).
func _tray_spot(i: int) -> Vector2:
	return TRAY + Vector2(-90 + i * 60, -12 + (i % 2) * 22)


## Cambia el dibujo de la parrilla (todas comparten la base abajo al centro).
func _set_plate(key: String) -> void:
	_plate.texture = tex(key)
	_plate.position = PLATE - Vector2(_plate.texture.get_width() / 2.0, _plate.texture.get_height())


func _plate_origin() -> Vector2:
	return PLATE - Vector2(tex("plate_beaker_off").get_width() / 2.0, tex("plate_beaker_off").get_height())


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	var hint_top := Style.label("Work Room  ·  Biosafety cabinet  ·  Esc: back", 15, Style.WHITE, 5)
	hint_top.position = Vector2(16, 10)
	_ui.add_child(hint_top)
	_title = Sprite2D.new()
	_title.texture = tex("txt_objective")
	_title.centered = false
	_title.position = Vector2(24, 44)
	_ui.add_child(_title)
	_hint = Style.label("", 19, Style.WHITE, 5)
	_hint.position = Vector2(24, 96)
	_hint.size = Vector2(900, 30)
	_ui.add_child(_hint)
	_quality_label = Style.label("SAMPLE QUALITY", 14, Style.WHITE, 4)
	_quality_label.position = Vector2(24, 132)
	_ui.add_child(_quality_label)
	_quality_bar = Style.progress_bar(220.0, 14.0)
	_quality_bar.position = Vector2(160, 136)
	_ui.add_child(_quality_bar)
	_melt_label = Sprite2D.new()
	_melt_label.texture = tex("txt_ice_melted")
	_melt_label.centered = false
	_melt_label.position = Vector2(PLATE.x - 170, 230)
	_melt_label.visible = false
	_ui.add_child(_melt_label)
	_melt_digits.position = Vector2(PLATE.x + 84, 232)
	_ui.add_child(_melt_digits)
	_banner = Sprite2D.new()
	_banner.position = Vector2(640, 300)
	_banner.modulate.a = 0.0
	_ui.add_child(_banner)


func _show_waiting(reason: String) -> void:
	stage = Stage.WAITING
	_title.visible = false
	_quality_label.visible = false
	_quality_bar.visible = false
	var w := Sprite2D.new()
	w.texture = tex("txt_waiting")
	w.position = Vector2(640, 320)
	add_child(w)
	var r := Style.label(reason, 20, Style.WHITE, 5)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.position = Vector2(140, 360)
	r.size = Vector2(1000, 40)
	_ui.add_child(r)


# ---------------------------------------------------------------- pasos

func _set_stage(s: Stage) -> void:
	stage = s
	match s:
		Stage.TRANSFER:
			_hint.text = "Use the tweezers: drag each piece of ice into the beaker. Don't drop it!"
		Stage.HEAT:
			_set_plate("plate_ice")
			temperature = T_START
			melted = 0.0
			_boil_time = 0.0
			_melt_label.visible = true
			_hint.text = "Hold the mouse button to heat, release to cool. Keep it in the GREEN zone!"
		Stage.POUR:
			_melt_label.visible = false
			_set_digits("")
			_bubbles.emitting = false
			_steam.emitting = false
			_set_plate("plate_off")
			_pour.visible = true
			_hint.text = "Hold the beaker over the clean Petri dish and hold the button to pour."
		Stage.DONE:
			_finish()


func _process(delta: float) -> void:
	_t += delta
	var mouse := get_global_mouse_position()
	_exit.hovered = _exit.hit(mouse)
	if stage == Stage.WAITING:
		return
	_quality_bar.value = quality
	match stage:
		Stage.TRANSFER:
			_process_transfer(mouse)
		Stage.HEAT:
			_process_heat(delta)
		Stage.POUR:
			_process_pour(delta, mouse)
	_update_hand(mouse)
	_gauge.queue_redraw()


func _process_transfer(mouse: Vector2) -> void:
	if _held:
		_held.position = mouse


func _process_heat(delta: float) -> void:
	temperature = clampf(temperature + (HEAT_RATE if _pressing else -COOL_RATE) * delta, T_MIN, T_MAX)
	if temperature >= GREEN:
		var speed := 1.6 if temperature >= YELLOW else 1.0
		melted = minf(melted + speed * delta / MELT_TIME, 1.0)
	if temperature >= RED:
		_boil_time += delta
		quality -= QUALITY_BOIL * delta
		if _boil_time >= BOIL_LIMIT or quality <= 0.0:
			_fail("You boiled the sample! Heat destroys the tiny life and molecules we are looking for.")
			return
		if not _was_red:
			_pop_banner("txt_warning")
	else:
		_boil_time = maxf(0.0, _boil_time - delta)
	_was_red = temperature >= RED
	# dibujo según la temperatura
	if temperature >= RED:
		_set_plate("plate_boiling")
	elif temperature >= GREEN or melted > 0.3:
		_set_plate("plate_melting")
	else:
		_set_plate("plate_ice")
	var top := PLATE - Vector2(0, 160)
	_bubbles.position = top
	_bubbles.emitting = temperature >= GREEN
	_steam.position = PLATE - Vector2(0, 330)
	_steam.emitting = temperature >= RED
	_set_digits("%d%%" % int(melted * 100.0))
	if melted >= 1.0:
		_pop_banner("txt_stage_complete")
		_set_stage(Stage.POUR)


func _process_pour(delta: float, mouse: Vector2) -> void:
	_pour.position = mouse - SPOUT
	var spout := mouse
	var over_dish := absf(spout.x - DISH.x) < 120.0 and spout.y < DISH.y and spout.y > DISH.y - 260.0
	_drops.position = spout
	_drops.emitting = _pressing
	if not _pressing:
		return
	if over_dish:
		filled = minf(filled + delta / POUR_TIME, 1.0)
		if filled >= 1.0:
			_drops.emitting = false
			_pour.visible = false
			_dish.texture = tex("dish_sample")
			_set_stage(Stage.DONE)
	else:
		quality -= QUALITY_SPILL * delta
		if _banner.modulate.a < 0.1:
			_pop_banner("txt_warning")
		if quality <= 0.0:
			_fail("Too much water was spilled. A scientist never wastes a sample!")


## La mano con las pinzas sigue al ratón (con la punta en el cursor); cerrada al pulsar.
func _update_hand(mouse: Vector2) -> void:
	_hand.visible = stage in [Stage.TRANSFER, Stage.HEAT, Stage.FAILED, Stage.DONE]
	var closed := _pressing or _held != null
	_hand.texture = tex("hand_closed" if closed else "hand_open")
	var tip: Array = _info.tip_closed if closed else _info.tip_open
	_hand.position = mouse - Vector2(tip[0] - 8, tip[1])


# ---------------------------------------------------------------- entrada

func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_cancel"):
		_back()
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var pressed: bool = event.pressed
	var p := get_global_mouse_position()
	_pressing = pressed
	if pressed and _exit.hit(p):
		_back()
		return
	match stage:
		Stage.TRANSFER:
			if pressed:
				_grab(p)
			else:
				_release(p)
		Stage.FAILED:
			if pressed:
				_retry()


func _grab(p: Vector2) -> void:
	for s in _ice:
		if s.position.distance_to(p) <= GRAB_RADIUS:
			_held = s
			_held.z_index = 30
			return


func _release(p: Vector2) -> void:
	if _held == null:
		return
	var piece := _held
	_held = null
	piece.z_index = 0
	var mouth := Rect2(_plate_origin() + MOUTH.position, MOUTH.size)
	if mouth.has_point(p):
		_ice.erase(piece)
		_in_beaker.append(piece)
		var spot: Vector2 = _plate_origin() + IN_BEAKER[(_in_beaker.size() - 1) % IN_BEAKER.size()]
		var tw := create_tween()
		tw.tween_property(piece, "position", spot, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(piece, "scale", Vector2.ONE * 0.8, 0.1)
		if _ice.is_empty():
			tw.tween_callback(_all_ice_in)
	else:
		# se cae: contaminada; la caja la recupera para volver a intentarlo
		quality = maxf(quality - QUALITY_DROP, 0.0)
		_pop_banner("txt_do_not_drop")
		var home: Vector2 = piece.get_meta("home")
		var tw := create_tween()
		tw.tween_property(piece, "position:y", 700.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(piece, "modulate:a", 0.0, 0.35)
		tw.tween_callback(piece.set_position.bind(home))
		tw.tween_property(piece, "modulate:a", 1.0, 0.3)
		if quality <= 0.0:
			_fail("The sample got contaminated. Handle it gently with the tweezers!")


func _all_ice_in() -> void:
	for s in _in_beaker:
		s.queue_free()
	_in_beaker.clear()
	_pop_banner("txt_stage_complete")
	_set_stage(Stage.HEAT)


# ---------------------------------------------------------------- fallar, terminar, salir

func _fail(why: String) -> void:
	stage = Stage.FAILED
	_bubbles.emitting = false
	_steam.emitting = false
	_drops.emitting = false
	_pop_banner("txt_failed", 99.0)
	_hint.text = why + "  Click to try again."


## Reintento: si hirvió, se repite el calentamiento con hielo nuevo; si no queda calidad, todo.
func _retry() -> void:
	if _banner_tw:
		_banner_tw.kill()
	_banner.modulate.a = 0.0
	if quality > 0.0 and filled == 0.0:
		_set_stage(Stage.HEAT)
		return
	SceneChanger.go_to(scene_file_path)


func _finish() -> void:
	stage = Stage.DONE
	_hint.text = "Sample ready! The lab analyzer takes it from here."
	_pop_banner("txt_well_done", 99.0)
	var reason := Mission.research.start_analysis()
	if reason != "":
		Mission.notify(reason)
	var sparkle := Fx.particles(Fx.GLINT, 24, 0.9, Vector2(0, -1), 180, 80, 200)
	sparkle.one_shot = true
	sparkle.explosiveness = 0.9
	sparkle.position = DISH
	sparkle.emitting = true
	add_child(sparkle)
	await get_tree().create_timer(3.0).timeout
	_back()


func _back() -> void:
	if _leaving:
		return
	_leaving = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	SceneChanger.go_to(ROOM)


# ---------------------------------------------------------------- textos y dibujo

## Letrero del centro (sprite de textos): aparece con un salto y se va solo tras `seconds`.
func _pop_banner(key: String, seconds := 1.4) -> void:
	_banner.texture = tex(key)
	_banner.visible = true
	_banner.scale = Vector2.ONE * 0.6
	if _banner_tw:
		_banner_tw.kill()  # el letrero nuevo sustituye al anterior
	var tw := create_tween()
	_banner_tw = tw
	tw.tween_property(_banner, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(_banner, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(seconds)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.3)


## Escribe un número con los dígitos dibujados (0-9, %, /, +, s).
func _set_digits(text: String) -> void:
	for c in _melt_digits.get_children():
		c.queue_free()
	var x := 0.0
	for ch in text:
		var key := {"%": "percent", "/": "slash", "+": "plus"}.get(ch, ch) as String
		var s := Sprite2D.new()
		s.texture = tex("digit_" + key)
		s.centered = false
		s.position = Vector2(x, 0)
		_melt_digits.add_child(s)
		x += s.texture.get_width() + 2


## Termómetro vertical junto a la parrilla (provisional, dibujado): azul, verde, amarillo y rojo.
func _draw_gauge() -> void:
	if stage != Stage.HEAT and not (stage == Stage.FAILED and melted > 0.0):
		return
	var r := Rect2(PLATE.x + 175, 350, 34, 280)
	var to_y := func(t: float) -> float: return r.end.y - (t - T_MIN) / (T_MAX - T_MIN) * r.size.y
	var bands := [[T_MIN, GREEN, Color("2e96f5")], [GREEN, YELLOW, Color("39d353")],
		[YELLOW, RED, Color("eafe07")], [RED, T_MAX, Color("e43700")]]
	_gauge.draw_rect(r.grow(5), Style.NAVY)
	for b in bands:
		var y0: float = to_y.call(b[1])
		var y1: float = to_y.call(b[0])
		_gauge.draw_rect(Rect2(r.position.x, y0, r.size.x, y1 - y0), b[2])
	var y: float = to_y.call(temperature)
	_gauge.draw_rect(Rect2(r.position.x - 10, y - 3, r.size.x + 20, 6), Style.WHITE)
	_gauge.draw_rect(Rect2(r.position.x - 10, y - 3, r.size.x + 20, 6), Style.NAVY, false, 2)
	_gauge.draw_string(Style.FONT_BODY, Vector2(r.position.x - 14, r.position.y - 12), "%d °C" % temperature,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Style.WHITE)
