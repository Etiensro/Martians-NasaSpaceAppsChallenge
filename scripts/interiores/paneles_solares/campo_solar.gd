extends Node2D
## Campo solar, SOLAR FIELD (scenes/interiores/paneles_solares/minijuegos/campo_solar/campo_solar.tscn).
## Los 16 paneles en una sola pantalla; limpiar y reparar se hace en el mismo sitio:
##   - LIMPIAR: mantener el clic y pasar el ratón por encima de un panel (la brocha quita la arena).
##   - CAMBIAR UN PANEL ROTO: arrastrar un panel nuevo desde la caja de repuestos hasta el roto
##     (cuesta energía, ver rules.json -> energy.panel_repair_cost).
##   - RECONECTAR UN CABLE: arrastrar la punta suelta del cable hasta su conector.
## Cada fila de paneles va en serie hasta su caja de conexiones (a la derecha): un panel solo da
## energía si no está roto y el cable hasta la caja está entero.
## Cada cierto tiempo llega una ráfaga de viento que vuelve a ensuciar (más fuerte con tormenta leve).
## El estado vive en el autoload Mission; esta escena solo lo muestra y lo cambia.
##
## Arte PROVISIONAL dibujado por código. Cuando existan las imágenes (ver docs/PANELES_SOLARES.md),
## basta con ponerlas en assets/interiores/paneles_solares/campo_solar/ con los nombres de ART.

const Style := preload("res://scripts/core/style.gd")
const Fx := preload("res://scripts/core/fx.gd")
const ExitArrow := preload("res://scripts/core/exit_arrow.gd")

const HUB := "res://scenes/interiores/paneles_solares/paneles_solares.tscn"
const ART := "res://assets/interiores/paneles_solares/campo_solar/field_%s.png"  # ground, panel, panel_broken, crate
const GROUND := preload("res://assets/zones/ap1_ground.png")

const ORIGIN := Vector2(110, 96)      # esquina del primer panel
const PANEL := Vector2(180, 100)      # tamaño de cada panel
const GAP := Vector2(36, 34)          # separación (en el hueco horizontal va el cable)
const COMBINER_X := 990.0             # cajas de conexiones de cada fila
const CRATE := Rect2(110, 612, 210, 92)
const CELL := 4                       # px por "grano" de arena en pantalla
const BRUSH_RADIUS := 26.0
const BRUSH_POWER := 2.5              # cuánta arena quita por segundo (además del movimiento)
const PLUG_RADIUS := 30.0             # distancia para enganchar un cable a su conector
const GUST_WARNING := 3.0             # segundos de aviso antes de la ráfaga

var _dirt: Array[Image] = []          # alfa de la arena de cada panel (1 px = 1 grano)
var _dirt_tex: Array[ImageTexture] = []
var _sparks: Array[CPUParticles2D] = []        # paneles rotos
var _cable_sparks: Array[CPUParticles2D] = []  # cables cortados
var _wind: CPUParticles2D
var _art := {}                         # texturas definitivas que existan
var _exit := ExitArrow.new()
var _toast: Label
var _status: Label
var _drag := {}                        # {} | {"type": "panel"} | {"type": "cable", "k": k}
var _brushing := false
var _last_mouse := Vector2.ZERO
var _gust_in := 0.0
var _gust_warned := false
var _writing := false                  # true mientras esta escena escribe en Mission
var _celebrated := false
var _t := 0.0


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED  # para repetir el suelo provisional
	for key in ["ground", "panel", "panel_broken", "crate"]:
		if ResourceLoader.exists(ART % key):
			_art[key] = load(ART % key)
	for i in Mission.panel_count():
		var img := Image.create(int(PANEL.x / CELL), int(PANEL.y / CELL), false, Image.FORMAT_RGBA8)
		_dirt.append(img)
		_dirt_tex.append(ImageTexture.create_from_image(img))
		_fill_dirt(i, Mission.panels[i].dirt)
		_write_dirt(i)  # la suciedad de Mission pasa a ser exactamente la que se ve
		_sparks.append(_spark_emitter(_panel_rect(i).get_center()))
		_cable_sparks.append(_spark_emitter(_cable_gap_center(i)))
	_build_wind()
	_exit.position = Vector2(1180, 660)
	add_child(_exit)
	_build_ui()
	Mission.panels_changed.connect(_on_mission_panels)
	_on_mission_panels()
	_schedule_gust()


# ---------------------------------------------------------------- geometría

func _panel_rect(i: int) -> Rect2:
	var c := i % Mission.columns()
	@warning_ignore("integer_division")
	var r := i / Mission.columns()
	return Rect2(ORIGIN + Vector2(c * (PANEL.x + GAP.x), r * (PANEL.y + GAP.y)), PANEL)


## Tramo k: del lado derecho del panel k al siguiente panel (o a la caja de la fila).
func _cable_start(k: int) -> Vector2:
	var r := _panel_rect(k)
	return Vector2(r.end.x, r.position.y + r.size.y * 0.7)


func _cable_end(k: int) -> Vector2:
	var start := _cable_start(k)
	if k % Mission.columns() == Mission.columns() - 1:
		return Vector2(COMBINER_X, start.y)
	return Vector2(_panel_rect(k + 1).position.x, start.y)


## Punta suelta de un cable cortado (cuelga un poco).
func _loose_end(k: int) -> Vector2:
	return _cable_start(k) + Vector2(8, 16)


func _cable_gap_center(k: int) -> Vector2:
	return (_cable_start(k) + _cable_end(k)) / 2.0


func _panel_at(p: Vector2) -> int:
	for i in Mission.panel_count():
		if _panel_rect(i).has_point(p):
			return i
	return -1


# ---------------------------------------------------------------- arena

## Llena la arena de un panel con manchas irregulares cuya media es `dirt` (0-100).
func _fill_dirt(i: int, dirt: float) -> void:
	var img := _dirt[i]
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.12
	var base := dirt / 100.0
	# la amplitud de las manchas baja cerca de 0 y de 100 para no recortar: así la media sigue siendo
	# `dirt` y entrar al campo no limpia (ni ensucia) los paneles
	var spread := 0.45 * minf(minf(base, 1.0 - base) * 2.0, 1.0)
	for y in img.get_height():
		for x in img.get_width():
			var a := clampf(base + noise.get_noise_2d(x, y) * spread, 0.0, 1.0)
			img.set_pixel(x, y, _sand(a, x, y))
	_dirt_tex[i].update(img)


func _sand(a: float, x: int, y: int) -> Color:
	var tone := 0.92 + 0.08 * float((x * 7 + y * 13) % 5) / 4.0
	return Color(0.82 * tone, 0.52 * tone, 0.32 * tone, a)


func _mean_dirt(i: int) -> float:
	var img := _dirt[i]
	var total := 0.0
	for y in img.get_height():
		for x in img.get_width():
			total += img.get_pixel(x, y).a
	return 100.0 * total / (img.get_width() * img.get_height())


## Quita arena alrededor de `p` (pantalla). Devuelve true si había algo que limpiar.
func _brush(i: int, p: Vector2, amount: float) -> bool:
	var img := _dirt[i]
	var local := (p - _panel_rect(i).position) / CELL
	var rad := BRUSH_RADIUS / CELL
	var changed := false
	for y in range(maxi(0, int(local.y - rad)), mini(img.get_height(), int(local.y + rad) + 1)):
		for x in range(maxi(0, int(local.x - rad)), mini(img.get_width(), int(local.x + rad) + 1)):
			var d := Vector2(x, y).distance_to(local) / rad
			if d > 1.0:
				continue
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				c.a = maxf(0.0, c.a - amount * (1.2 - d))
				img.set_pixel(x, y, c)
				changed = true
	if changed:
		_dirt_tex[i].update(img)
		_write_dirt(i)
	return changed


## Añade arena en franjas horizontales (como la deja el viento).
func _add_sand(i: int, amount: float) -> void:
	var img := _dirt[i]
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.08
	for y in img.get_height():
		for x in img.get_width():
			var streak := 0.5 + noise.get_noise_2d(x * 0.3, y * 2.0)  # estiradas en horizontal
			var c := img.get_pixel(x, y)
			var a := clampf(c.a + amount / 100.0 * 2.0 * clampf(streak, 0.0, 1.0), 0.0, 1.0)
			img.set_pixel(x, y, _sand(a, x, y))
	_dirt_tex[i].update(img)
	_write_dirt(i)


func _write_dirt(i: int) -> void:
	_writing = true
	Mission.set_panel_dirt(i, _mean_dirt(i))
	_writing = false


## Si cambió algo desde fuera (sol nuevo, fin de tormenta), la arena de la pantalla lo sigue.
func _on_mission_panels() -> void:
	if _writing:
		return
	for i in Mission.panel_count():
		var extra: float = Mission.panels[i].dirt - _mean_dirt(i)
		if extra > 0.5:
			_add_sand(i, extra)
		_sparks[i].emitting = Mission.panels[i].broken
		_cable_sparks[i].emitting = not Mission.cables[i]


# ---------------------------------------------------------------- efectos

func _spark_emitter(at: Vector2) -> CPUParticles2D:
	var p := Fx.particles(Fx.GLINT, 10, 0.5, Vector2(0, -1), 70, 60, 160, Vector2(0, 400))
	p.preprocess = 0.0
	p.position = at
	p.explosiveness = 0.7
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.color_ramp = Fx.ramp(Color(1, 0.95, 0.5), Color(1, 0.5, 0.1, 0.0))
	p.emitting = false
	p.z_index = 20
	add_child(p)
	return p


func _build_wind() -> void:
	_wind = Fx.particles(Fx.STREAK, 60, 1.6, Vector2(1, 0.05), 3, 600, 900)
	_wind.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_wind.emission_rect_extents = Vector2(10, 320)
	_wind.position = Vector2(-20, 360)
	_wind.scale_amount_min = 2.0
	_wind.scale_amount_max = 4.0
	_wind.color = Color(1, 0.85, 0.65, 0.35)
	_wind.z_index = 30
	add_child(_wind)


func _schedule_gust() -> void:
	var rule := Mission.gust_rule()
	_gust_in = randf_range(rule.every_min, rule.every_max)
	_gust_warned = false


func _update_gust(delta: float) -> void:
	_gust_in -= delta
	if not _gust_warned and _gust_in <= GUST_WARNING:
		_gust_warned = true
		toast("Gust of wind incoming!", Style.NEON_YELLOW)
	var strong := _gust_in <= GUST_WARNING
	_wind.speed_scale = 2.2 if strong else 1.0
	_wind.modulate.a = 1.0 if strong else 0.45
	if _gust_in <= 0.0:
		_gust()
		_schedule_gust()


func _gust() -> void:
	var rule := Mission.gust_rule()
	var ids := range(Mission.panel_count())
	ids.shuffle()
	for i in ids.slice(0, int(rule.panels)):
		_add_sand(i, randf_range(rule.dirt_min, rule.dirt_max))
	toast("The wind brought sand back!", Style.WHITE)


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var hint := Style.label("Solar Field  ·  Hold click to brush the sand  ·  Drag new panels and cables  ·  Esc: back", 15, Style.WHITE, 5)
	hint.position = Vector2(16, 10)
	layer.add_child(hint)
	_status = Style.label("", 17, Style.WHITE, 5)
	_status.position = Vector2(350, 640)
	_status.size = Vector2(700, 60)
	layer.add_child(_status)
	_toast = Style.label("", 26, Style.WHITE, 8)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.position = Vector2(0, 46)
	_toast.size = Vector2(1280, 40)
	_toast.modulate.a = 0.0
	layer.add_child(_toast)


func toast(text: String, color := Style.WHITE) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _update_status() -> void:
	_status.text = "Clean: %d %%   ·   Working: %d / %d   ·   Power in: %.1f EU/h\nNew panel: %d EU" % [
		Mission.cleanliness(), Mission.working_panels(), Mission.panel_count(), Mission.generation(),
		Mission.rules.energy.panel_repair_cost]
	var all_good := Mission.cleanliness() >= 95.0 and Mission.working_panels() == Mission.panel_count()
	if all_good and not _celebrated:
		_celebrated = true
		toast("All panels clean and working. Great job!", Style.NEON_YELLOW)
	elif not all_good:
		_celebrated = false


# ---------------------------------------------------------------- entrada

func _process(delta: float) -> void:
	_t += delta
	var mouse := get_global_mouse_position()
	if _brushing and _drag.is_empty():
		var i := _panel_at(mouse)
		if i >= 0:
			_brush(i, mouse, BRUSH_POWER * delta + 0.02 * mouse.distance_to(_last_mouse))
	_last_mouse = mouse
	_update_gust(delta)
	_update_status()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		return
	if event is InputEventMouseMotion:
		_exit.hovered = _exit.hit(event.position)
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := get_global_mouse_position()
	if event.pressed:
		if _exit.hit(p):
			_back()
		elif CRATE.has_point(p):
			_drag = {"type": "panel"}
		elif _loose_cable_at(p) >= 0:
			_drag = {"type": "cable", "k": _loose_cable_at(p)}
		else:
			_brushing = true
			_last_mouse = p
	else:
		_brushing = false
		_drop(p)


func _loose_cable_at(p: Vector2) -> int:
	for k in Mission.panel_count():
		if not Mission.cables[k] and p.distance_to(_loose_end(k)) <= PLUG_RADIUS:
			return k
	return -1


func _drop(p: Vector2) -> void:
	if _drag.is_empty():
		return
	var drag := _drag
	_drag = {}
	if drag.type == "panel":
		var i := _panel_at(p)
		if i < 0:
			return
		if not Mission.panels[i].broken:
			toast("This panel isn't broken.", Style.WHITE)
		elif Mission.replace_panel(i):
			toast("New panel installed!", Style.NEON_YELLOW)
		else:
			toast("Not enough energy for a new panel.", Style.ROCKET_RED)
	elif drag.type == "cable":
		if p.distance_to(_cable_end(drag.k)) <= PLUG_RADIUS:
			Mission.repair_cable(drag.k)
			toast("Cable connected!", Style.NEON_YELLOW)


func _back() -> void:
	SceneChanger.go_to(HUB)


# ---------------------------------------------------------------- dibujo

func _draw() -> void:
	var font := Style.FONT_BODY
	if _art.has("ground"):
		draw_texture_rect(_art.ground, Rect2(0, 0, 1280, 720), false)
	else:  # provisional: el mismo suelo de AP-1, repetido y a escala de la zona (x3)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(3, 3))
		draw_texture_rect(GROUND, Rect2(0, 0, 1280 / 3.0, 720 / 3.0), true)
		draw_set_transform(Vector2.ZERO)

	# Cajas de conexiones y cable principal hacia la sala de energía
	var rows := Mission.rows()
	var bottom := _cable_start(Mission.panel_count() - 1).y
	draw_line(Vector2(COMBINER_X + 30, _cable_start(0).y), Vector2(COMBINER_X + 30, bottom + 60), Color("1c2333"), 8)
	draw_line(Vector2(COMBINER_X + 30, bottom + 60), Vector2(1280, bottom + 60), Color("1c2333"), 8)
	draw_string(font, Vector2(1060, bottom + 50), "TO POWER ROOM", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Style.WHITE)
	for r in rows:
		var y := _cable_start(r * Mission.columns()).y
		draw_rect(Rect2(COMBINER_X, y - 22, 60, 44), Color("3a4559"))
		draw_rect(Rect2(COMBINER_X, y - 22, 60, 44), Style.NAVY, false, 3)
		draw_circle(Vector2(COMBINER_X + 45, y - 10), 5, Color(0.4, 1, 0.5))

	# Paneles y, encima, sus cables (así se ven los conectores en los bordes)
	for i in Mission.panel_count():
		_draw_panel(i)
	for k in Mission.panel_count():
		_draw_cable(k)

	# Caja de repuestos
	if _art.has("crate"):
		draw_texture_rect(_art.crate, CRATE, false)
	else:
		draw_rect(CRATE, Color("8a6a3a"))
		draw_rect(CRATE, Style.NAVY, false, 4)
		draw_rect(Rect2(CRATE.position + Vector2(20, 18), Vector2(170, 56)), Color("1d4fa0"))
	draw_string_outline(font, CRATE.position + Vector2(0, -8), "SPARE PANELS", HORIZONTAL_ALIGNMENT_CENTER, CRATE.size.x, 15, 5, Style.NAVY)
	draw_string(font, CRATE.position + Vector2(0, -8), "SPARE PANELS", HORIZONTAL_ALIGNMENT_CENTER, CRATE.size.x, 15, Style.WHITE)

	_draw_drag()


func _draw_panel(i: int) -> void:
	var r := _panel_rect(i)
	var broken: bool = Mission.panels[i].broken
	draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.3))  # sombra
	var key := "panel_broken" if broken else "panel"
	if _art.has(key):
		draw_texture_rect(_art[key], r, false)
	else:
		_draw_placeholder_panel(r, broken)
	draw_texture_rect(_dirt_tex[i], r, false)
	# Luz de estado: verde = da energía, roja = no (roto o cable cortado)
	draw_circle(r.position + Vector2(r.size.x - 10, 10), 6, Color(0.4, 1, 0.5) if Mission.is_panel_working(i) else Style.ROCKET_RED)


func _draw_placeholder_panel(r: Rect2, broken: bool) -> void:
	draw_rect(r, Color("9aa3b5"))
	var glass := r.grow(-6)
	draw_rect(glass, Color("123a7a") if broken else Color("1d4fa0"))
	for c in range(1, 6):
		var x := glass.position.x + glass.size.x * c / 6.0
		draw_line(Vector2(x, glass.position.y), Vector2(x, glass.end.y), Color(0.45, 0.65, 1.0, 0.6), 2)
	for c in range(1, 3):
		var y := glass.position.y + glass.size.y * c / 3.0
		draw_line(Vector2(glass.position.x, y), Vector2(glass.end.x, y), Color(0.45, 0.65, 1.0, 0.6), 2)
	if broken:  # grietas
		var o := glass.get_center()
		for a in [0.3, 1.4, 2.5, 3.6, 4.9]:
			var mid := o + Vector2.from_angle(a) * 22 + Vector2(6, -4)
			draw_polyline(PackedVector2Array([o, mid, o + Vector2.from_angle(a + 0.25) * 60]), Color(0.85, 0.9, 1.0), 2)


func _draw_cable(k: int) -> void:
	var a := _cable_start(k)
	var b := _cable_end(k)
	var dark := Color("1c2333")
	draw_rect(Rect2(a + Vector2(-4, -6), Vector2(8, 12)), Color("5a6478"))  # conector
	draw_rect(Rect2(b + Vector2(-4, -6), Vector2(8, 12)), Color("5a6478"))
	if Mission.cables[k]:
		draw_line(a, b, dark, 5)
		return
	# Cortado: la punta suelta cuelga; el conector de destino parpadea
	if not (_drag.get("type", "") == "cable" and _drag.k == k):
		draw_polyline(PackedVector2Array([a, a + Vector2(4, 6), _loose_end(k)]), dark, 5)
		draw_circle(_loose_end(k), 6, Style.NEON_YELLOW if fmod(_t, 0.8) < 0.4 else Color("b0b8c8"))
	draw_line(b + Vector2(-10, 0), b, dark, 5)
	if fmod(_t, 0.8) < 0.4:
		draw_rect(Rect2(b + Vector2(-7, -9), Vector2(14, 18)), Style.NEON_YELLOW, false, 2)


func _draw_drag() -> void:
	var mouse := get_global_mouse_position()
	match _drag.get("type", ""):
		"panel":
			var r := Rect2(mouse - PANEL / 2.0, PANEL)
			if _art.has("panel"):
				draw_texture_rect(_art.panel, r, false, Color(1, 1, 1, 0.8))
			else:
				_draw_placeholder_panel(r, false)
			var target := _panel_at(mouse)
			if target >= 0 and Mission.panels[target].broken:
				draw_rect(_panel_rect(target).grow(4), Style.NEON_YELLOW, false, 4)
		"cable":
			var k: int = _drag.k
			draw_polyline(PackedVector2Array([_cable_start(k), mouse]), Color("1c2333"), 5)
			draw_circle(mouse, 7, Style.NEON_YELLOW)
		_:
			# Brocha: círculo bajo el ratón cuando está sobre un panel
			if _panel_at(mouse) >= 0:
				draw_arc(mouse, BRUSH_RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.8 if _brushing else 0.45), 2)
				draw_line(mouse + Vector2(10, -10), mouse + Vector2(34, -34), Color("8a5a2a"), 6)
