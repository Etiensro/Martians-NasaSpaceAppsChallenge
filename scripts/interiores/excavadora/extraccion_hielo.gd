extends Node2D
## Extracción de hielo, ICE DRILL CONTROL (scenes/interiores/excavadora/minijuegos/extraccion_hielo/extraccion_hielo.tscn).
## Se abre desde la consola del vestíbulo de la excavadora (excavadora.tscn). El jugador maneja el rover
## a distancia: lo que se ve es la cámara del rover en el campo de hielo de AP-1, de perfil.
##   - A/D o flechas: mover el rover (si la broca está abajo, primero la sube).
##   - Mantener Espacio o el clic: taladrar. La broca baja por el subsuelo; al tocar un depósito de hielo
##     lo agrieta (entero → grieta 1 → grieta 2 → partido → esquirlas) y al romperlo suma su hielo.
##   - El calor sube mientras se taladra (más en el hielo) y baja al soltar. Si llega a 100 la broca se
##     sobrecalienta y se bloquea hasta que se enfría.
## Al llenar el medidor de hielo se asegura el núcleo y empieza la extracción de la muestra de AP-1:
## Mission.expedition.start_extraction(), que trabaja sola 24 h menos lo que ya se jugó aquí.
## Salir antes (Esc o la flecha) no guarda nada.
##
## Assets en assets/interiores/excavadora/extraccion_hielo/ (pixel art a resolución nativa; el recorte de
## cada sprite está en sprites.json). Todo se dibuja a 384x216 dentro de `_world`, escalado ×3.

const Style := preload("res://scripts/core/style.gd")
const Fx := preload("res://scripts/core/fx.gd")
const Movement := preload("res://scripts/core/movement.gd")
const ExitArrow := preload("res://scripts/core/exit_arrow.gd")

const HUB := "res://scenes/interiores/excavadora/excavadora.tscn"
const DIR := "res://assets/interiores/excavadora/extraccion_hielo/"

const SCALE := 3.0
const VIEW := Vector2(384, 216)            # px nativos de la cámara
const FEED := Vector2(64, 36)              # esquina de la pantalla en 1280x720 (384x216 ×3 = 1152x648)
const GROUND_Y := 100.0                    # línea del suelo en fondo_hielo_nativo.png
const MAX_DEPTH := 110.0                   # hasta dónde baja la broca (roca madre)

const ROVER_CELL := Vector2(80, 64)
const ROVER_FEET := Vector2(40, 62)        # punto de la celda que pisa el suelo (ruedas en y = 62)
const ROVER_TIP := {1: 65.0, -1: 14.0}     # x de la punta de la broca al taladrar (derecha / izquierda)
const ROVER_MIN_X := 40.0
const ROVER_MAX_X := 344.0
const BIT := Vector2(11, 48)               # broca_vertical.png: 4 cuadros que apuntan hacia abajo

## Depósitos de hielo: fila en hielo_depositos.png, caja visible dentro de la celda de 72x56,
## hielo que da al romperse (el medidor se llena con 100) y segundos de taladro para romperlo.
const DEPOSITS := {
	"small": {"row": 0, "box": Rect2(24, 36, 24, 16), "ice": 20.0, "hp": 1.2},
	"medium": {"row": 1, "box": Rect2(16, 27, 39, 24), "ice": 30.0, "hp": 2.0},
	"large": {"row": 2, "box": Rect2(6, 13, 56, 37), "ice": 45.0, "hp": 3.0},
}
const LAYOUT := ["large", "medium", "medium", "small"]  # 125 de hielo: sobra un poco para elegir
const DEPOSIT_CELL := Vector2(72, 56)

const ROVER_SPEED := 70.0      # px nativos por segundo
const DRILL_SPEED := 30.0      # bajada de la broca por tierra
const RETRACT_SPEED := 120.0
const HEAT_SOIL := 20.0        # calor por segundo taladrando tierra
const HEAT_ICE := 28.0         # ... taladrando hielo
const COOLING := 32.0          # enfriamiento por segundo sin taladrar
const UNLOCK_HEAT := 35.0      # tras sobrecalentarse, se puede volver a taladrar por debajo de esto
const ANIM_FPS := 12.0

enum Row { FORWARD, BACKWARD, DRILL_RIGHT, DRILL_LEFT }
enum Fx6 { DUST, SPARKS, ICE_FLASH }  # filas de efectos.png

var _world := Node2D.new()     # todo lo de la cámara, en px nativos
var _holes := Node2D.new()     # agujeros que deja la broca
var _rover := Sprite2D.new()
var _bit := Sprite2D.new()
var _shaft := Node2D.new()     # tubo de la broca entre el suelo y la punta
var _overlay := Node2D.new()   # marco de la pantalla y líneas de barrido
var _chips: CPUParticles2D     # trocitos que salta la broca
var _ice_fill := Sprite2D.new()
var _heat_fill := Sprite2D.new()
var _ice_label: Label
var _heat_label: Label
var _status: Label
var _toast: Label
var _rec: Label
var _exit := ExitArrow.new()

var _deposits: Array[Dictionary] = []
var _hole_rects: Array[Rect2] = []
var _x := 70.0                 # posición del rover (px nativos)
var _dir := 1                  # 1 derecha, -1 izquierda
var _depth := 0.0              # cuánto ha bajado la broca bajo el suelo
var _heat := 0.0
var _ice := 0.0
var _locked := false           # sobrecalentada
var _mouse_drill := false
var _done := false
var _played := 0.0             # segundos reales jugados (cuentan como horas ya trabajadas)
var _anim := 0.0
var _dust_in := 0.0
var _t := 0.0


func _ready() -> void:
	_world.position = FEED
	_world.scale = Vector2.ONE * SCALE
	add_child(_world)

	var bg := Sprite2D.new()
	bg.texture = load(DIR + "fondo_hielo_nativo.png")
	bg.centered = false
	_world.add_child(bg)
	_holes.draw.connect(_draw_holes)
	_world.add_child(_holes)
	_place_deposits()
	_shaft.draw.connect(_draw_shaft)
	_world.add_child(_shaft)
	_bit.texture = load(DIR + "broca_vertical.png")
	_bit.centered = false
	_bit.region_enabled = true
	_bit.visible = false
	_world.add_child(_bit)
	_rover.texture = load(DIR + "rover.png")
	_rover.centered = false
	_rover.region_enabled = true
	_world.add_child(_rover)
	_build_chips()
	_build_meters()

	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_exit.position = Vector2(1170, 640)
	add_child(_exit)
	_build_ui()
	_update_rover(0.0, false, false)

	var why := Mission.expedition.extract_blocked_reason()
	if why != "":
		_toast_text(why, Style.ROCKET_RED)


# ---------------------------------------------------------------- montaje

## Reparte los depósitos en franjas a lo ancho del campo, enterrados a distintas profundidades.
func _place_deposits() -> void:
	var tex: Texture2D = load(DIR + "hielo_depositos.png")
	var kinds := LAYOUT.duplicate()
	kinds.shuffle()
	var slot := (ROVER_MAX_X - ROVER_MIN_X + 40.0) / kinds.size()
	for i in kinds.size():
		var rule: Dictionary = DEPOSITS[kinds[i]]
		var box: Rect2 = rule.box
		var cx := ROVER_MIN_X - 20.0 + slot * (i + 0.5) + randf_range(-slot * 0.2, slot * 0.2)
		var top := randf_range(GROUND_Y + 16.0, minf(GROUND_Y + 70.0, GROUND_Y + MAX_DEPTH - box.size.y - 4.0))
		var world_box := Rect2(Vector2(roundf(cx - box.size.x / 2.0), roundf(top)), box.size)
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.hframes = 5
		s.vframes = 3
		s.frame = int(rule.row) * 5
		s.position = world_box.position - box.position
		_world.add_child(s)
		_deposits.append({"sprite": s, "box": world_box, "row": int(rule.row), "ice": float(rule.ice),
			"hp": float(rule.hp), "left": float(rule.hp), "broken": false})


func _build_chips() -> void:
	_chips = Fx.particles(load(DIR + "hielo_esquirlas.png"), 10, 0.5, Vector2(0, -1), 70, 25, 60, Vector2(0, 160))
	var mat := CanvasItemMaterial.new()
	mat.particles_animation = true
	mat.particles_anim_h_frames = 8
	mat.particles_anim_v_frames = 1
	_chips.material = mat
	_chips.anim_offset_max = 1.0
	_chips.preprocess = 0.0
	_chips.scale_amount_min = 0.5
	_chips.scale_amount_max = 0.8
	_chips.emitting = false
	_world.add_child(_chips)


## Medidores de ui.png (marco + relleno recortado) arriba a la izquierda de la cámara.
func _build_meters() -> void:
	var ui: Texture2D = load(DIR + "ui.png")
	for m in [["icono_hielo", Rect2(0, 18, 96, 8), _ice_fill, 6.0], ["icono_taladro", Rect2(0, 28, 96, 8), _heat_fill, 24.0]]:
		var icon := Sprite2D.new()
		icon.texture = ui
		icon.centered = false
		icon.region_enabled = true
		icon.region_rect = Rect2(0, 38, 16, 14) if m[0] == "icono_hielo" else Rect2(20, 38, 16, 14)
		icon.position = Vector2(6, m[3] + 1)
		_world.add_child(icon)
		# el interior del marco es opaco (no transparente como dice el LEEME): el relleno va encima
		var frame := Sprite2D.new()
		frame.texture = ui
		frame.centered = false
		frame.region_enabled = true
		frame.region_rect = Rect2(0, 0, 104, 16)
		frame.position = Vector2(24, m[3])
		_world.add_child(frame)
		var fill: Sprite2D = m[2]
		fill.texture = ui
		fill.centered = false
		fill.region_enabled = true
		fill.region_rect = m[1]
		fill.position = Vector2(28, m[3] + 4)
		_world.add_child(fill)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var hint := Style.label("Ice Drill  ·  A/D: move the rover  ·  Hold Space or click: drill  ·  Watch the heat!  ·  Esc: back", 15, Style.WHITE, 5)
	hint.position = Vector2(16, 8)
	layer.add_child(hint)
	_ice_label = Style.label("", 16, Style.WHITE, 5)
	_ice_label.position = FEED + Vector2(136, 7) * SCALE
	layer.add_child(_ice_label)
	_heat_label = Style.label("", 16, Style.WHITE, 5)
	_heat_label.position = FEED + Vector2(136, 25) * SCALE
	layer.add_child(_heat_label)
	_rec = Style.label("●  REC   ROVER CAM · AP-1 ICE FIELD", 14, Style.WHITE, 4)
	_rec.position = FEED + Vector2(12, 648 - 30)
	layer.add_child(_rec)
	_status = Style.label("", 16, Style.WHITE, 5)
	_status.position = Vector2(64, 688)
	_status.size = Vector2(1000, 28)
	layer.add_child(_status)
	_toast = Style.label("", 26, Style.WHITE, 8)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.position = Vector2(0, 150)
	_toast.size = Vector2(1280, 40)
	_toast.modulate.a = 0.0
	layer.add_child(_toast)


# ---------------------------------------------------------------- juego

func _process(delta: float) -> void:
	_t += delta
	_played += delta
	var move := 0.0 if _done else Movement.input_vector().x
	var want_drill := not _done and (Input.is_key_pressed(KEY_SPACE) or _mouse_drill)
	var drilling := false
	var moving := false

	if move != 0.0:
		if _depth > 0.0:  # primero se sube la broca
			_depth = maxf(_depth - RETRACT_SPEED * delta, 0.0)
		else:
			_dir = 1 if move > 0.0 else -1
			var nx := clampf(_x + move * ROVER_SPEED * delta, ROVER_MIN_X, ROVER_MAX_X)
			moving = nx != _x
			_x = nx
	elif want_drill and not _locked:
		drilling = true
		_drill(delta)

	if not drilling:
		_heat = maxf(_heat - COOLING * delta, 0.0)
		if _locked and _heat <= UNLOCK_HEAT:
			_locked = false
			_toast_text("Drill cooled down. Keep going!", Style.NEON_YELLOW)
	_chips.emitting = drilling and _deposit_at(_tip()) >= 0

	_dust_in -= delta
	if _dust_in <= 0.0 and (moving or (drilling and _deposit_at(_tip()) < 0)):
		_dust_in = 0.22
		var at := Vector2(_x - 30.0 * _dir, GROUND_Y - 6.0) if moving else Vector2(_tip().x, GROUND_Y - 6.0)
		_burst(Fx6.DUST, at)

	_update_rover(delta, moving, drilling)
	_update_meters()
	_holes.queue_redraw()
	_shaft.queue_redraw()
	_overlay.queue_redraw()


## Un paso de taladro: baja por la tierra o va rompiendo el depósito que toca la punta.
func _drill(delta: float) -> void:
	var hit := _deposit_at(_tip())
	if hit >= 0:
		_heat += HEAT_ICE * delta
		_hit_deposit(hit, delta)
	else:
		_heat += HEAT_SOIL * delta
		var before := _depth
		_depth = minf(_depth + DRILL_SPEED * delta, MAX_DEPTH)
		# no atravesar un depósito: la punta se queda en su borde de arriba
		var now := _deposit_at(_tip())
		if now >= 0:
			var box: Rect2 = _deposits[now].box
			_depth = maxf(before, box.position.y + 1.0 - GROUND_Y)
		_dig_hole()
		if _depth >= MAX_DEPTH and fmod(_t, 0.4) < delta:
			_burst(Fx6.SPARKS, _tip())
	_chips.position = _tip()
	if _heat >= 100.0:
		_heat = 100.0
		_locked = true
		_burst(Fx6.SPARKS, _tip())
		_burst(Fx6.SPARKS, Vector2(_tip().x, GROUND_Y - 4.0))
		_toast_text("The drill overheated! Release it to cool down.", Style.ROCKET_RED)


func _hit_deposit(i: int, delta: float) -> void:
	var d := _deposits[i]
	d.left = maxf(float(d.left) - delta, 0.0)
	var s: Sprite2D = d.sprite
	var damage := 1.0 - float(d.left) / float(d.hp)
	s.frame = int(d.row) * 5 + mini(int(damage * 4.0), 3)  # entero, grieta 1, grieta 2, partido
	s.offset = Vector2(randf_range(-0.6, 0.6), 0) if fmod(_t, 0.1) < 0.05 else Vector2.ZERO
	if d.left > 0.0:
		return
	d.broken = true
	s.frame = int(d.row) * 5 + 4  # esquirlas
	s.offset = Vector2.ZERO
	var box: Rect2 = d.box
	_burst(Fx6.ICE_FLASH, box.get_center())
	_shatter(box.get_center())
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(s, "modulate:a", 0.0, 0.6)
	_ice = minf(_ice + float(d.ice), 100.0)
	if _ice >= 100.0:
		_finish()
	else:
		_toast_text("+%d ice!" % int(d.ice), Color("7fe8ff"))


## Índice del depósito sin romper que contiene `p`, o -1.
func _deposit_at(p: Vector2) -> int:
	for i in _deposits.size():
		var box: Rect2 = _deposits[i].box
		if not _deposits[i].broken and box.has_point(p):
			return i
	return -1


func _tip() -> Vector2:
	return Vector2(_x - ROVER_FEET.x + float(ROVER_TIP[_dir]), GROUND_Y + _depth)


func _dig_hole() -> void:
	var x := roundf(_tip().x) - 3.0
	var r := Rect2(x, GROUND_Y, 6.0, _depth)
	for k in _hole_rects.size():
		if _hole_rects[k].position.x == x:
			_hole_rects[k] = _hole_rects[k].merge(r)
			return
	_hole_rects.append(r)


func _finish() -> void:
	_done = true
	_mouse_drill = false
	_burst(Fx6.ICE_FLASH, Vector2(_x, GROUND_Y - 30.0))
	var played_hours := _played / float(Mission.rules.clock.real_seconds_per_hour)
	var why := Mission.expedition.start_extraction(played_hours)
	# si se pudo, A.R.I.A. ya avisa de las horas que faltan; si no, se enseña el motivo
	_toast_text("Ice core secured!" if why == "" else why, Style.NEON_YELLOW)
	await get_tree().create_timer(3.5).timeout
	_back()


func _back() -> void:
	set_process(false)
	SceneChanger.go_to(HUB)


# ---------------------------------------------------------------- animación y efectos

func _update_rover(delta: float, moving: bool, drilling: bool) -> void:
	var row: int
	if _depth > 0.0 or drilling:
		row = Row.DRILL_RIGHT if _dir == 1 else Row.DRILL_LEFT
	else:
		row = Row.FORWARD if _dir == 1 else Row.BACKWARD
	if moving or drilling:
		_anim += delta * ANIM_FPS
	var col := int(_anim) % 6 if (moving or drilling) else 0
	_rover.region_rect = Rect2(Vector2(col, row) * ROVER_CELL, ROVER_CELL)
	_rover.position = Vector2(roundf(_x), GROUND_Y) - ROVER_FEET

	# broca: solo se ve la parte que está bajo el suelo
	_bit.visible = _depth > 0.5
	if _bit.visible:
		var h := minf(_depth, BIT.y)
		var f := int(_t * 16.0) % 4 if drilling else 0
		_bit.region_rect = Rect2(f * BIT.x, BIT.y - h, BIT.x, h)
		_bit.position = Vector2(roundf(_tip().x - BIT.x / 2.0), GROUND_Y + _depth - h)


func _update_meters() -> void:
	_ice_fill.region_rect.size.x = roundf(96.0 * _ice / 100.0)
	_heat_fill.region_rect.size.x = roundf(96.0 * _heat / 100.0)
	var hot := _locked or _heat >= 75.0
	_heat_fill.modulate = Color(1, 0.55, 0.45) if hot and fmod(_t, 0.4) < 0.2 else Color.WHITE
	_ice_label.text = "ICE  %d %%" % int(_ice)
	_heat_label.text = "OVERHEATED" if _locked else "HEAT  %d %%" % int(_heat)
	_heat_label.add_theme_color_override("font_color", Style.ROCKET_RED if hot else Style.WHITE)
	_rec.modulate.a = 1.0 if fmod(_t, 1.2) < 0.8 else 0.35
	var left := _deposits.filter(func(d: Dictionary) -> bool: return not d.broken).size()
	_status.text = "Depth: %.1f m   ·   Ice deposits left: %d   ·   %s" % [
		_depth / 10.0, left, Mission.time_text()]


## Efecto de efectos.png (6 cuadros, no se repite) centrado en `at`.
func _burst(row: int, at: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = load(DIR + "efectos.png")
	s.hframes = 6
	s.vframes = 3
	s.frame = row * 6
	s.position = at.round()
	_world.add_child(s)
	var tw := create_tween()
	tw.tween_method(func(f: float) -> void: s.frame = row * 6 + int(f), 0.0, 5.99, 0.45)
	tw.tween_callback(s.queue_free)


## Lluvia de esquirlas al romper un depósito.
func _shatter(at: Vector2) -> void:
	var p := _chips.duplicate() as CPUParticles2D
	p.one_shot = true
	p.amount = 16
	p.explosiveness = 0.95
	p.spread = 100.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.position = at
	_world.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


func _toast_text(text: String, color := Style.WHITE) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.4 + text.length() * 0.03)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


# ---------------------------------------------------------------- dibujo

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Style.DEEP_BLUE)


func _draw_holes() -> void:
	for r in _hole_rects:
		_holes.draw_rect(r, Color(0.16, 0.07, 0.06, 0.85))
		_holes.draw_rect(Rect2(r.position.x, r.position.y, 1, r.size.y), Color(0.08, 0.03, 0.03, 0.9))


## Tubo de la broca entre el brazo del rover (en el suelo) y la broca, cuando baja más que su largo.
func _draw_shaft() -> void:
	if _depth <= BIT.y:
		return
	var x := roundf(_tip().x) - 2.0
	var r := Rect2(x, GROUND_Y, 4, _depth - BIT.y)
	_shaft.draw_rect(r, Color(0.55, 0.6, 0.68))
	_shaft.draw_rect(Rect2(r.position.x, r.position.y, 1, r.size.y), Color(0.85, 0.88, 0.95))
	_shaft.draw_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), Color(0.25, 0.28, 0.36))


## Marco de la pantalla de la cámara y líneas de barrido (aspecto de monitor).
func _draw_overlay() -> void:
	var feed := Rect2(FEED, VIEW * SCALE)
	for y in range(int(feed.position.y), int(feed.end.y), 3):
		_overlay.draw_line(Vector2(feed.position.x, y), Vector2(feed.end.x, y), Color(0, 0, 0, 0.07))
	var sweep := feed.position.y + fmod(_t * 90.0, feed.size.y)
	_overlay.draw_rect(Rect2(feed.position.x, sweep, feed.size.x, 6), Color(1, 1, 1, 0.03))
	_overlay.draw_rect(feed.grow(3), Style.BLUE_YONDER, false, 3)
	# esquinas tipo visor
	for c in [feed.position, Vector2(feed.end.x, feed.position.y), feed.end, Vector2(feed.position.x, feed.end.y)]:
		var dx := 22.0 if c.x == feed.position.x else -22.0
		var dy := 22.0 if c.y == feed.position.y else -22.0
		_overlay.draw_line(c, c + Vector2(dx, 0), Style.WHITE, 3)
		_overlay.draw_line(c, c + Vector2(0, dy), Style.WHITE, 3)


# ---------------------------------------------------------------- entrada

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		return
	if event is InputEventMouseMotion:
		_exit.hovered = _exit.hit(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _exit.hit(event.position):
			_back()
		else:
			_mouse_drill = event.pressed and not _done
