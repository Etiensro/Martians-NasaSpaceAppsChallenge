extends Node2D
## Minijuego de la caminadora (scenes/interiores/estacion_ares1/modulos/gimnasio/caminadora.tscn).
## Corredor infinito al estilo del juego del dinosaurio: el tripulante elegido corre por Marte en la
## pantalla de la caminadora y salta rocas (Espacio / ↑ / clic) y se agacha ante los
## meteoritos (↓).
## Objetivo: correr 2 horas de juego (RUN_SECONDS reales) sin caerse; la barra de la consola se llena.
## Si se cae antes de las 2 horas, el tiempo vuelve a 0:00 y hay que empezar otra vez. Al completarlas
## se puede seguir corriendo; la siguiente vez que se caiga vuelve al gimnasio.
## Esc: volver al gimnasio.

const Style := preload("res://scripts/core/style.gd")
const Fx := preload("res://scripts/core/fx.gd")
const Movement := preload("res://scripts/core/movement.gd")

const DIR := "res://assets/interiores/estacion_ares1/gimnasio/"
const GYM := "res://scenes/interiores/estacion_ares1/modulos/gimnasio/gimnasio.tscn"

const RUN_SECONDS := 15.0        # segundos reales que duran las 2 horas de ejercicio
const GAME_MINUTES := 120.0
const PLAYER_X := 150.0          # posición del corredor dentro de la pantalla
const PLAYER_SCALE := 1.15
const GRAVITY := 2700.0
const JUMP_SPEED := 980.0
const SPEED_START := 390.0       # px/s del suelo
const SPEED_MAX := 680.0
## La dificultad sube poco a poco: tarda RAMP_SECONDS (de la carrera actual) en llegar al máximo.
## Durante las 2 horas (RUN_SECONDS) solo se llega a una parte; después sigue subiendo despacio.
const RAMP_SECONDS := 60.0
const METEOR_AFTER := 2.5        # segundos corriendo antes de que salgan meteoritos
const RESTART_DELAY := 0.5       # tras caerse, espera antes de poder volver a empezar
## Obstáculos de suelo (se saltan) y de aire (hay que agacharse)
const GROUND_OBSTACLES := ["rock_m", "rocks"]
const AIR_OBSTACLES := ["meteor"]

enum State { READY, RUNNING, FALLEN }

var data: Dictionary
var state := State.READY
var progress := 0.0              # 0..1 de las 2 horas
var completed := false
var distance := 0.0
var speed := SPEED_START
var _run_time := 0.0             # segundos de la carrera actual (sin caerse)
var _fell_at := 0.0
var _fall_tw: Tween

var _field: Rect2                # pantalla donde se juega (coordenadas de pantalla)
var _ground_y := 0.0             # línea del suelo (local al campo)
var _clip := ColorRect.new()     # recorta todo lo del juego a la pantalla
var _floors: Array[Sprite2D] = []
var _floor_w := 0.0
var _obstacles: Array = []       # [{node, kind, air}]
var _spawn_in := 1.2
var _player: AnimatedSprite2D
var _vy := 0.0
var _on_ground := true
var _ducking := false
var _dust: CPUParticles2D
var _textures := {}
var _hud := Node2D.new()         # barra y tiempo de la consola
var _overlay: Label
var _overlay_sub: Label
var _dist_label: Label
var _done_label: Label
var _warn: Label                 # "DUCK!" cuando viene un meteorito
var _shake := 0.0
var _t := 0.0


func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(DIR + "gym.json"))
	var pf: Array = data.playfield
	_field = Rect2(pf[0], pf[1], pf[2] - pf[0], pf[3] - pf[1])
	_ground_y = data.ground_y - _field.position.y
	for name in data.obstacles:
		_textures[name] = load(DIR + name + ".png")

	var bg := Sprite2D.new()
	bg.texture = load(DIR + "treadmill_view.png")
	bg.centered = false
	add_child(bg)

	# Todo lo del juego va dentro de la pantalla de la caminadora (recortado)
	_clip.position = _field.position
	_clip.size = _field.size
	_clip.color = Color.WHITE  # solo sirve de máscara (no se dibuja)
	_clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_build_sky()
	_build_floor()
	_build_player()

	_hud.draw.connect(_draw_console)
	add_child(_hud)
	_build_ui()
	_set_overlay("PRESS SPACE TO START RUNNING", "Space / ↑ / click: jump the rocks  ·  ↓: duck under meteors  ·  Esc: back")


# ---------------------------------------------------------------- escenario

## Satélite que cruza el cielo despacio (decoración) y estrellas que titilan.
func _build_sky() -> void:
	var sat := Sprite2D.new()
	sat.texture = _textures.get("satellite")
	sat.position = Vector2(_field.size.x + 60, 170)  # por debajo del medidor
	sat.modulate = Color(1, 1, 1, 0.85)
	_clip.add_child(sat)
	var tw := create_tween().set_loops()
	tw.tween_property(sat, "position:x", -80.0, 26.0).from(_field.size.x + 60)
	var stars := Fx.particles(Fx.GLINT, 8, 2.0, Vector2.ZERO, 0, 0, 0)
	stars.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	stars.position = Vector2(_field.size.x / 2, _ground_y / 2 - 20)
	stars.emission_rect_extents = Vector2(_field.size.x / 2, _ground_y / 2 - 30)
	stars.scale_amount_min = 0.3
	stars.scale_amount_max = 0.6
	stars.color_ramp = Fx.ramp(Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0))
	stars.color_ramp.add_point(0.5, Color(1, 1, 1, 0.9))
	_clip.add_child(stars)


func _build_floor() -> void:
	var tex: Texture2D = load(DIR + "floor.png")
	_floor_w = tex.get_width()
	var copies := int(ceil(_field.size.x / _floor_w)) + 1
	for i in copies:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.position = Vector2(i * _floor_w, _ground_y - data.floor_top)
		_clip.add_child(s)
		_floors.append(s)


func _build_player() -> void:
	_player = AnimatedSprite2D.new()
	_player.sprite_frames = GameState.frames_for()  # el tripulante que eligió el jugador
	_player.offset = Vector2(0, -47)
	_player.scale = Vector2.ONE * PLAYER_SCALE
	_player.position = Vector2(PLAYER_X, _ground_y + 4)
	Movement.animate(_player, "idle", "side", false)
	_clip.add_child(_player)
	_dust = Fx.particles(Fx.PUFF, 10, 0.5, Vector2(-1, -0.4), 20, 60, 120)
	_dust.position = Vector2(PLAYER_X - 12, _ground_y + 2)
	_dust.scale_amount_min = 1.0
	_dust.scale_amount_max = 2.2
	_dust.color_ramp = Fx.ramp(Color(0.85, 0.5, 0.32, 0.7))
	_dust.emitting = false
	_clip.add_child(_dust)


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_overlay = Style.brand_title("", 34, Style.WHITE, 10)
	_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.position = Vector2(_field.position.x, _field.position.y + 120)
	_overlay.size = Vector2(_field.size.x, 46)
	layer.add_child(_overlay)
	_overlay_sub = Style.label("", 18, Style.NEON_YELLOW, 5)
	_overlay_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_sub.position = Vector2(_field.position.x, _field.position.y + 172)
	_overlay_sub.size = Vector2(_field.size.x, 26)
	layer.add_child(_overlay_sub)
	_dist_label = Style.label("", 16, Style.WHITE, 4)
	_dist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dist_label.position = Vector2(_field.end.x - 260, _field.position.y + 12)
	_dist_label.size = Vector2(244, 22)
	layer.add_child(_dist_label)
	_done_label = Style.brand_title("WORKOUT COMPLETE!", 30, Style.NEON_YELLOW, 10)
	_done_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_done_label.position = Vector2(_field.position.x, _field.position.y + 40)
	_done_label.size = Vector2(_field.size.x, 40)
	_done_label.modulate.a = 0.0
	layer.add_child(_done_label)
	_warn = Style.brand_title("DUCK ↓", 26, Style.NEON_YELLOW, 8)
	_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_warn.position = Vector2(_field.end.x - 180, 0)
	_warn.size = Vector2(164, 34)
	_warn.visible = false
	layer.add_child(_warn)
	var hint := Style.label("Treadmill  ·  Esc: back to the gym", 14, Style.WHITE, 4)
	hint.position = Vector2(16, 692)
	layer.add_child(hint)


func _set_overlay(title: String, sub: String) -> void:
	_overlay.text = title
	_overlay_sub.text = sub
	_overlay.visible = title != ""
	_overlay_sub.visible = sub != ""


## Barra de la consola: el arco de colores se va descubriendo hasta llegar al máximo, y debajo el tiempo.
func _draw_console() -> void:
	var g: Array = data.gauge
	var gr := Rect2(g[0], g[1], g[2] - g[0], g[3] - g[1])
	var x := gr.position.x + gr.size.x * progress
	var cover := Color(data.console_color)
	if progress < 1.0:
		_hud.draw_rect(Rect2(x, gr.position.y - 2, gr.end.x - x + 3, gr.size.y + 4), cover)
	_hud.draw_line(Vector2(x, gr.position.y - 4), Vector2(x, gr.end.y + 4), Style.WHITE, 3)
	if completed:
		_hud.draw_rect(gr.grow(4), Color(Style.NEON_YELLOW, 0.5 + 0.5 * sin(_t * 6.0)), false, 3)
	var c: Array = data.console
	var cr := Rect2(c[0], c[1], c[2] - c[0], c[3] - c[1])
	var minutes := GAME_MINUTES * progress
	var txt := "%d:%02d / 2:00 h" % [int(minutes / 60.0), int(minutes) % 60]
	var big := int(cr.size.y * 0.42)
	var small := maxi(int(cr.size.y * 0.22), 9)
	_hud.draw_string(Style.body_font(700), Vector2(cr.position.x, cr.position.y + big + 2), txt,
		HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, big, Style.NEON_YELLOW if completed else Style.WHITE)
	_hud.draw_string(Style.body_font(600), Vector2(cr.position.x, cr.position.y + big + small + 6),
		"COMPLETE" if completed else "WORKOUT TIME", HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, small, Color(1, 1, 1, 0.7))


# ---------------------------------------------------------------- juego

func _process(delta: float) -> void:
	_t += delta
	_hud.queue_redraw()
	_shake = move_toward(_shake, 0.0, delta * 30.0)
	_clip.position = _field.position + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	Audio.set_loop("gym_running", state == State.RUNNING)
	if state != State.RUNNING:
		return

	if not completed:
		progress = minf(progress + delta / RUN_SECONDS, 1.0)
		if progress >= 1.0:
			_complete()
	_run_time += delta
	speed = lerpf(SPEED_START, SPEED_MAX, _ramp())
	distance += speed * delta
	_dist_label.text = "Distance  %d m" % int(distance / 20.0)

	# suelo que se repite
	for f in _floors:
		f.position.x -= speed * delta
		if f.position.x <= -_floor_w:
			f.position.x += _floor_w * _floors.size()

	# salto / agacharse
	var down := Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)
	_ducking = _on_ground and down
	if not _on_ground:
		_vy += GRAVITY * delta * (3.0 if down else 1.0)  # ↓ en el aire: baja rápido para agacharse a tiempo
		_player.position.y += _vy * delta
		if _player.position.y >= _ground_y + 4:
			_player.position.y = _ground_y + 4
			_on_ground = true
			_vy = 0.0
	_player.scale = Vector2(PLAYER_SCALE * (1.15 if _ducking else 1.0), PLAYER_SCALE * (0.6 if _ducking else 1.0))
	_player.speed_scale = speed / SPEED_START * 1.4
	if _player.animation != "walk_side" or not _player.is_playing():
		_player.flip_h = false
		_player.play("walk_side")  # siempre corriendo (también al empezar y tras caerse)
	_dust.emitting = _on_ground

	# obstáculos
	_update_warning()
	_spawn_in -= delta
	if _spawn_in <= 0.0:
		_spawn()
	for o in _obstacles.duplicate():
		var n: Sprite2D = o.node
		n.position.x -= speed * delta * (1.1 if o.air else 1.0)
		if n.position.x < -120:
			n.queue_free()
			_obstacles.erase(o)
		elif _player_box().intersects(_hitbox(o)):
			_fall()
			return


func _spawn() -> void:
	var air := _run_time > METEOR_AFTER and randf() < lerpf(0.38, 0.45, _ramp())
	var kind: String = (AIR_OBSTACLES if air else GROUND_OBSTACLES).pick_random()
	var n := Sprite2D.new()
	n.texture = _textures[kind]
	var h: float = n.texture.get_height()
	n.position = Vector2(_field.size.x + 60, _ground_y - h / 2.0 + 2)
	if air:
		# a la altura de la cabeza: hay que agacharse (↓). Sale más lejos para que dé tiempo a ver el aviso
		n.position = Vector2(_field.size.x + 380, _ground_y - 100)
		var trail := Fx.particles(Fx.PUFF, 12, 0.4, Vector2(1, -0.3), 15, 40, 90)
		trail.scale_amount_min = 1.0
		trail.scale_amount_max = 2.2
		trail.color_ramp = Fx.ramp(Color(1, 0.6, 0.15, 0.85), Color(0.5, 0.2, 0.1, 0.0))
		trail.position = Vector2(12, -8)
		trail.local_coords = false
		n.add_child(trail)
	_clip.add_child(n)
	_clip.move_child(n, _floors[-1].get_index() + 1)  # delante del suelo, detrás del corredor
	_obstacles.append({"node": n, "kind": kind, "air": air})
	var gap := randf_range(lerpf(1.2, 0.85, _ramp()), lerpf(2.0, 1.5, _ramp())) * SPEED_START / speed
	_spawn_in = gap + (1.0 if air else 0.0)  # tras un meteorito no sale otra cosa enseguida


## 0 al empezar a correr, 1 cuando la dificultad está al máximo (sube suave).
func _ramp() -> float:
	return smoothstep(0.0, RAMP_SECONDS, _run_time)


func _player_box() -> Rect2:
	var h := 78.0 * (0.6 if _ducking else 1.0)
	return Rect2(_player.position.x - 18, _player.position.y - h, 36, h - 4)


func _box(n: Sprite2D) -> Rect2:
	var s := n.texture.get_size()
	return Rect2(n.position - s / 2.0, s)


## Zona que hace daño: en las rocas, la imagen un poco reducida; en el meteorito, solo la roca
## (abajo a la izquierda), no la estela de fuego.
func _hitbox(o: Dictionary) -> Rect2:
	var b := _box(o.node)
	if o.air:
		return Rect2(b.position.x + 4, b.position.y + b.size.y * 0.35, b.size.x * 0.6, b.size.y * 0.55)
	return b.grow(-6)


## Aviso parpadeante en el borde derecho mientras se acerca un meteorito.
func _update_warning() -> void:
	var show := false
	for o in _obstacles:
		if o.air and o.node.position.x > _field.size.x - 60:
			show = true
			_warn.position.y = _field.position.y + o.node.position.y - 16
	_warn.visible = show and fmod(_t, 0.4) < 0.28


func _jump() -> void:
	if state == State.READY or (state == State.FALLEN and _t - _fell_at >= RESTART_DELAY):
		_start()
		return
	if _on_ground:
		_on_ground = false
		_vy = -JUMP_SPEED


func _start() -> void:
	for o in _obstacles:
		o.node.queue_free()
	_obstacles.clear()
	if not completed:
		progress = 0.0
	distance = 0.0
	_run_time = 0.0
	speed = SPEED_START
	if _fall_tw:
		_fall_tw.kill()  # que la animación de la caída no siga moviendo al corredor
	_spawn_in = 1.2
	_player.position.y = _ground_y + 4
	_player.modulate = Color.WHITE
	_player.rotation = 0.0
	_on_ground = true
	_vy = 0.0
	state = State.RUNNING
	_set_overlay("", "")
	_player.play("walk_side")


## Choca: se cae y, si aún no completó las 2 horas, el tiempo vuelve a empezar.
func _fall() -> void:
	state = State.FALLEN
	_warn.visible = false
	_shake = 10.0
	_dust.emitting = false
	_player.stop()
	_fell_at = _t
	_fall_tw = create_tween()
	_fall_tw.tween_property(_player, "modulate", Color(1, 0.4, 0.4), 0.08)
	_fall_tw.tween_property(_player, "rotation", -0.5, 0.15)
	_fall_tw.parallel().tween_property(_player, "position:y", _ground_y + 4, 0.15)
	if completed:  # ya cumplió las 2 horas: no se pregunta nada, de vuelta al gimnasio
		SceneChanger.go_to(GYM, 0.6)
		return
	_set_overlay("YOU TRIPPED!", "Workout time resets to 0:00  ·  Space: try again to complete 2 hours")


## 2 horas completadas: festeja y se sigue corriendo hasta que se caiga (entonces vuelve al gimnasio).
func _complete() -> void:
	completed = true
	var tw := create_tween()
	tw.tween_property(_done_label, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.5)
	tw.tween_property(_done_label, "modulate:a", 0.0, 0.6)
	var confetti := Fx.particles(Fx.DUST, 60, 1.6, Vector2(0, -1), 70, 160, 320, Vector2(0, 400))
	confetti.one_shot = true
	confetti.explosiveness = 0.9
	confetti.preprocess = 0.0
	confetti.position = Vector2(_field.size.x / 2, _ground_y - 40)
	confetti.scale_amount_min = 2.0
	confetti.scale_amount_max = 4.0
	confetti.color_ramp = Fx.ramp(Style.NEON_YELLOW, Color(Style.BLUE_YONDER, 0.0))
	_clip.add_child(confetti)
	confetti.emitting = true
	# la sesión de ejercicio del sol (Mission.crew): +20 de condición física y el reloj avanza las 2 h
	# (menos lo que ya pasó corriendo en tiempo real)
	var why: String = await Mission.crew.exercise(RUN_SECONDS / Mission.rules.clock.real_seconds_per_hour)
	if why != "":
		Mission.notify(why)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		SceneChanger.go_to(GYM)
		return
	var jump: bool = (event is InputEventKey and event.pressed and not event.echo
		and event.keycode in [KEY_SPACE, KEY_UP, KEY_W]) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if jump:
		get_viewport().set_input_as_handled()
		_jump()
