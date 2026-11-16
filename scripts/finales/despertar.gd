extends Node2D
## Final, paso 1: DESPERTAR A LA TRIPULACIÓN (scenes/finales/despertar.tscn).
## La misma sala de criosueño de la intro (scripts/intro/interior_room.gd): los 3 compañeros siguen
## congelados en sus cápsulas. Haz clic en cada cápsula: el hielo se derrite, sale el tripulante y dice
## algo según el final (data/mission/endings.json -> wake_lines). Con los 3 despiertos, todos van a la nave
## (scenes/finales/despegue.tscn). En una evacuación ("emergency") suena la alarma, como en la intro.

const Style := preload("res://scripts/core/style.gd")
const Fx := preload("res://scripts/core/fx.gd")
const Movement := preload("res://scripts/core/movement.gd")
const Room := preload("res://scripts/intro/interior_room.gd")
const BaseInterior := preload("res://scripts/intro/base_interior.gd")
const Final := preload("res://scripts/finales/final.gd")
const RobotScene := preload("res://scenes/robot.tscn")

const WALK_SPEED := 190.0
const EXIT := Vector2(640, 760)            # por donde salen todos hacia la nave (abajo)

var room: Room
var light := CanvasModulate.new()
var crew := {}                              # id -> AnimatedSprite2D
var sleepers := {}                          # índice de cápsula -> id (los que faltan por despertar)
var me: AnimatedSprite2D
var _over := Node2D.new()                   # contorno de la cápsula bajo el ratón
var _hover := -1
var _awake := 0
var _lines: Array = []
var _spoken := 0
var _caption: Label
var _count: Label
var _t := 0.0
var _alarm := false
var _done := false


func _ready() -> void:
	_alarm = Final.mood() == "emergency"
	_lines = Final.data().wake_lines.get(Final.mood(), [])
	room = Room.new()
	room.alarm = _alarm
	add_child(room)
	add_child(light)
	for i in GameState.role_order.size():
		var id: String = GameState.role_order[i]
		var a := _astronaut(id)
		if id == GameState.selected_role:
			a.position = BaseInterior.PLAYER_SPOT
			Movement.animate(a, "idle", "up", false)
			me = a
		else:  # congelado dentro de su cápsula, como lo dejó la intro
			a.position = room.pod_inside(i)
			a.scale = Vector2.ONE * BaseInterior.POD_SCALE
			a.modulate = BaseInterior.FROZEN
			a.play("idle_down")
			a.stop()
			room.set_pod_frost(1.0, i)
			room.set_pod_label(i, GameState.first_name(id))
			sleepers[i] = id
	var robot: Node2D = RobotScene.instantiate()
	robot.position = Room.ROBOT_POS
	robot.scale = Vector2.ONE * BaseInterior.CREW_SCALE
	robot.target = me
	add_child(robot)
	_over.z_index = 30
	_over.draw.connect(_draw_over)
	add_child(_over)
	_build_ui()


func _astronaut(id: String) -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = GameState.frames_for(id, false)  # dentro de la base: sin casco
	a.offset = Vector2(0, -47)                          # los pies en la posición del nodo
	a.scale = Vector2.ONE * BaseInterior.CREW_SCALE
	add_child(a)
	crew[id] = a
	return a


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var back := ColorRect.new()  # franja oscura: el texto no se mezcla con los pizarrones de la sala
	back.color = Color(Style.DEEP_BLUE, 0.88)
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	back.offset_bottom = 128
	layer.add_child(back)
	var title := Style.brand_title(str(Final.reason().title), 44,
		Style.ROCKET_RED if _alarm else Style.NEON_YELLOW, 10)
	_top(layer, title, 14)
	_caption = Style.label("Click each cryo pod to wake up your crew", 22, Style.WHITE, 6)
	_top(layer, _caption, 66)
	_count = Style.label("", 18, Style.NEON_YELLOW, 5)
	_top(layer, _count, 98)
	_update_count()


func _top(layer: CanvasLayer, l: Label, top: float) -> void:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	l.offset_left = -600
	l.offset_right = 600
	l.offset_top = top
	layer.add_child(l)


func _update_count() -> void:
	_count.text = "Crew awake: %d / %d" % [_awake, _awake + sleepers.size()]


# ---------------------------------------------------------------- juego

func _pod_rect(i: int) -> Rect2:
	return Rect2(Room.POD_POS[i] - Vector2(Room.POD_SIZE.x / 2.0, 0), Room.POD_SIZE)


func _process(delta: float) -> void:
	_t += delta
	var c := Color.WHITE
	if _alarm:  # luz roja que late, como la alarma de la intro
		c = c.lerp(Color(1, 0.5, 0.45), 0.25 + 0.25 * sin(_t * 7.0))
	light.color = c
	if not _done:
		var m := get_global_mouse_position()
		_hover = -1
		for i in sleepers:
			if _pod_rect(i).grow(10).has_point(m):
				_hover = i
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if _hover >= 0 else Input.CURSOR_ARROW)
	_over.queue_redraw()


func _draw_over() -> void:
	if _done:
		return
	for i in sleepers:  # las que faltan: contorno que late; la del ratón, más fuerte
		var a := 0.9 if i == _hover else 0.35 + 0.3 * sin(_t * 4.0 + i)
		_over.draw_rect(_pod_rect(i).grow(6), Color(Style.NEON_YELLOW, a), false, 4 if i == _hover else 2)
		var tip := Vector2(Room.POD_POS[i].x, Room.POD_POS[i].y - 12 + sin(_t * 6.0 + i) * 5.0)
		_over.draw_colored_polygon(PackedVector2Array([tip + Vector2(-12, -16), tip + Vector2(12, -16), tip]),
			Color(Style.NEON_YELLOW, a))


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _hover >= 0:
		_wake(_hover)


## La cápsula se abre: se derrite la escarcha, sale vapor y el tripulante camina a su sitio y habla.
func _wake(i: int) -> void:
	var id: String = sleepers[i]
	sleepers.erase(i)
	_hover = -1
	var a: AnimatedSprite2D = crew[id]
	_steam(Room.POD_POS[i] + Vector2(0, Room.POD_SIZE.y * 0.5))
	var tw := create_tween()
	tw.tween_method(room.set_pod_frost.bind(i), 1.0, 0.0, 0.9)
	tw.parallel().tween_property(a, "modulate", Color.WHITE, 0.9)
	tw.tween_callback(room.set_pod_label.bind(i, ""))
	tw.tween_property(a, "position", room.pod_entry(i), 0.5)
	tw.parallel().tween_property(a, "scale", Vector2.ONE * BaseInterior.CREW_SCALE, 0.5)
	tw.tween_callback(a.play.bind("walk_down"))
	var spot: Vector2 = BaseInterior.STAND.get(id, [Vector2(640, 480)])[0]
	tw.tween_callback(_walk_and_talk.bind(a, spot))
	_awake += 1
	_update_count()
	if sleepers.is_empty():
		_all_awake()


func _walk_and_talk(a: AnimatedSprite2D, spot: Vector2) -> void:
	var tw := Movement.walk_to(a, spot, WALK_SPEED)
	tw.tween_callback(_react.bind(a))


func _react(a: AnimatedSprite2D) -> void:
	if Final.mood() == "victory":
		a.play("celebrate")
	else:
		Movement.animate(a, "idle", "down", false)
	if not _lines.is_empty():
		_say(a, Final.fill(str(_lines[_spoken % _lines.size()])))
		_spoken += 1


## Bocadillo sobre la cabeza que sube y se desvanece.
func _say(a: AnimatedSprite2D, text: String) -> void:
	var l := Style.label(text, 16, Style.WHITE, 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(260, 24)
	l.position = a.position + Vector2(-130, -150)
	l.z_index = 40
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 16, 2.6)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(1.8)
	tw.tween_callback(l.queue_free)


func _steam(at: Vector2) -> void:
	var p := Fx.particles(Fx.PUFF, 18, 1.2, Vector2(0, -1), 70, 30, 70)
	p.one_shot = true
	p.explosiveness = 0.8
	p.position = at
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color_ramp = Fx.ramp(Color(0.85, 0.95, 1.0, 0.8))
	p.z_index = 25
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)


## Todos despiertos: van juntos a la nave (salen por abajo) y empieza el despegue.
func _all_awake() -> void:
	_done = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	await get_tree().create_timer(3.4).timeout
	_caption.text = "Everyone is awake! To the ship!" if not _alarm else "Everyone is awake! Hurry to the ship!"
	_count.text = ""
	var delay := 0.0
	for id in crew:
		Movement.walk_to(crew[id], EXIT + Vector2(randf_range(-60, 60), 0), WALK_SPEED * (1.4 if _alarm else 1.0), delay)
		delay += 0.25
	await get_tree().create_timer(2.6).timeout
	SceneChanger.go_to(Final.LAUNCH, 0.8)
