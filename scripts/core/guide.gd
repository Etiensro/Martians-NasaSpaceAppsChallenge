extends CanvasLayer
## Autoload "Guide": A.R.I.A., el robot que acompaña al jugador después de la intro.
##   - Abajo a la izquierda: el robot (mascota) con la barra de progreso de las tareas del día 1.
##   - Globo de diálogo con lecciones para niños (con capturas del juego) que salen una sola vez
##     cuando pasa algo: entrar a una escena, completar una tarea, terminar el día 1...
##   - Mientras se lee una lección, el juego se pausa (el reloj de la misión no corre).
##   - Clic en el robot: te dice qué conviene hacer ahora.
## Textos y disparadores: data/guide/guide.json. Capturas: assets/ui/guide/ (tools/build_guide_shots.py).

const Style := preload("res://scripts/core/style.gd")
const Fx := preload("res://scripts/core/fx.gd")
const DATA := "res://data/guide/guide.json"
const SHOTS := "res://assets/ui/guide/%s.png"
const ROBOT_FRAMES := preload("res://assets/characters/robot_frames.tres")
const PAUSED_SCENES := "res://scenes/intro/"
## En los minijuegos el robot se esconde para no tapar el juego.
const HIDDEN_IN := [
	"res://scenes/interiores/estacion_ares1/modulos/invernadero/sembrar.tscn",
	"res://scenes/interiores/estacion_ares1/modulos/invernadero/regar.tscn",
	"res://scenes/interiores/estacion_ares1/modulos/gimnasio/caminadora.tscn",
	"res://scenes/interiores/paneles_solares/minijuegos/",
]
const SHOW_DELAY := 1.0       # espera tras cambiar de escena (que termine el fundido)
const CHARS_PER_SECOND := 50.0

var data: Dictionary
var seen := {}                # id de lección -> true
var done := {}                # id de tarea -> true (se queda hecha aunque cambie el sol)
var _queue: Array = []        # lecciones por enseñar
var _pages: Array = []
var _page := 0
var _scene := ""
var _wait := 0.0
var _was_paused := false

var _box: PanelContainer
var _header: Label
var _bar: ProgressBar
var _task: Label
var _robot: AnimatedSprite2D
var _robot_area: Control
var _bubble: PanelContainer
var _text: Label
var _image: TextureRect
var _counter: Label
var _next: Button
var _typing: Tween
var _t := 0.0


func _init() -> void:
	layer = 45  # encima del HUD de la misión (40), debajo del fundido de SceneChanger (100)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_build_box()
	_build_bubble()
	_box.visible = false


# ---------------------------------------------------------------- interfaz

func _build_box() -> void:
	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", Style.box(Style.NAVY_SOFT, Style.NEON_YELLOW, 3, 10))
	_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_box.offset_left = 10
	_box.offset_right = 222
	_box.offset_top = -222
	_box.offset_bottom = -10
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_box.gui_input.connect(_on_box_input)
	_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_box.tooltip_text = ""
	add_child(_box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(col)
	_header = Style.brand_title("DAY 1 TASKS", 16, Style.WHITE)
	col.add_child(_header)
	_bar = Style.progress_bar(190, 12)
	col.add_child(_bar)
	_task = Style.label("", 13, Style.NEON_YELLOW, 0)
	_task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_task.custom_minimum_size = Vector2(190, 34)
	col.add_child(_task)
	# el robot, sobre un halo azul (su "fondo")
	_robot_area = Control.new()
	_robot_area.custom_minimum_size = Vector2(190, 118)
	_robot_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_robot_area)
	var halo := Sprite2D.new()
	halo.texture = Fx.GLOW
	halo.position = Vector2(95, 70)
	halo.scale = Vector2(2.8, 2.0)
	halo.modulate = Color(Style.BLUE_YONDER, 0.6)
	_robot_area.add_child(halo)
	_robot = AnimatedSprite2D.new()
	_robot.sprite_frames = ROBOT_FRAMES
	_robot.offset = Vector2(0, -47)
	_robot.position = Vector2(95, 132)
	_robot.scale = Vector2.ONE * 2.0
	_robot.play("idle_down")
	_robot_area.add_child(_robot)
	var click := Style.label("Click me for help!", 11, Color(1, 1, 1, 0.75), 3)
	click.position = Vector2(46, 0)
	_robot_area.add_child(click)


func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", Style.box(Color(Style.DEEP_BLUE, 0.96), Style.BLUE_YONDER, 3, 16))
	_bubble.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_bubble.offset_left = 232
	_bubble.offset_right = 1060
	_bubble.offset_top = -250
	_bubble.offset_bottom = -10
	_bubble.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bubble.visible = false
	add_child(_bubble)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_bubble.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	row.add_child(col)
	var name := Style.brand_title("A.R.I.A.", 22, Style.BLUE_YONDER)
	col.add_child(name)
	_text = Style.label("", 20, Style.WHITE, 0)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(300, 120)
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	col.add_child(_text)
	var bottom := HBoxContainer.new()
	col.add_child(bottom)
	_counter = Style.label("", 14, Color(1, 1, 1, 0.6), 0)
	_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_counter)
	_next = Button.new()
	_next.text = "NEXT  ▶"
	_next.custom_minimum_size = Vector2(150, 40)
	Style.brand_button(_next, true, 18)
	_next.pressed.connect(_advance)
	bottom.add_child(_next)
	_image = TextureRect.new()
	_image.custom_minimum_size = Vector2(384, 216)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_image)


# ---------------------------------------------------------------- estado

func _process(delta: float) -> void:
	_t += delta
	var scene := get_tree().current_scene
	var path := scene.scene_file_path if scene else ""
	if path.begins_with(PAUSED_SCENES):
		_reset()  # en el menú o la intro: la guía vuelve a empezar
		_box.visible = false
		_scene = path
		return
	if path != _scene:
		_scene = path
		_wait = SHOW_DELAY
		_queue_trigger("scene:" + path)
	var hidden := HIDDEN_IN.any(func(h): return path.begins_with(h))
	_box.visible = Mission.is_running() and not hidden and not _bubble.visible or _bubble.visible
	_check_tasks()
	_update_box()
	_robot.offset.y = -47 + sin(_t * (6.0 if _bubble.visible else 3.0)) * 2.0  # habla: se mueve más rápido
	if _wait > 0.0:
		_wait -= delta
	elif not _bubble.visible and not _queue.is_empty() and Mission.is_running() and not Mission.is_busy() \
			and not get_tree().paused and not hidden:
		_show_lesson(_queue.pop_front())


func _reset() -> void:
	if seen.is_empty() and done.is_empty():
		return
	seen.clear()
	done.clear()
	_queue.clear()
	_close()


func _tasks() -> Array:
	return data.get("tasks", [])


## Marca las tareas del día 1 que ya se cumplieron (una vez hechas, se quedan hechas).
func _check_tasks() -> void:
	if not Mission.is_running():
		return
	for t in _tasks():
		var id: String = t.id
		if done.has(id) or not _task_done(id):
			continue
		done[id] = true
		_queue_trigger("task:" + id)
		if done.size() == _tasks().size():
			_queue_trigger("all_tasks")
	if Mission.sol() >= 2:
		_queue_trigger("sol:2")


func _task_done(id: String) -> bool:
	match id:
		"fix_panels":
			return Mission.broken_count() == 0 and Mission.cut_cable_count() == 0
		"plant":
			return Mission.crops.is_growing() or GameState.greenhouse_step >= 1
		"water":
			return GameState.greenhouse_step >= 2
		"exercise":
			return Mission.exercised_today()
	return false


func _update_box() -> void:
	var total := _tasks().size()
	var day1 := Mission.sol() <= 1 and done.size() < total
	_bar.visible = day1
	if day1:
		_header.text = "DAY 1 TASKS  ·  %d %%" % roundi(100.0 * done.size() / total)
		_bar.value = 100.0 * done.size() / total
		for t in _tasks():
			if not done.has(t.id):
				_task.text = "▶ " + str(t.text)
				break
	else:
		_header.text = "A.R.I.A."
		_task.text = "Your robot helper"


## Pone en la cola la lección de ese disparador (si no se ha visto).
func _queue_trigger(trigger: String) -> void:
	for l in data.get("lessons", []):
		if l.trigger == trigger and not seen.has(l.id):
			seen[l.id] = true
			_queue.append(l)


# ---------------------------------------------------------------- lecciones

func _show_lesson(lesson: Dictionary) -> void:
	_open(lesson.pages)


## Abre el globo con una lista de páginas [{text, image?}] y pausa el juego.
func _open(pages: Array) -> void:
	_pages = pages
	_page = 0
	_was_paused = get_tree().paused
	get_tree().paused = true
	_bubble.visible = true
	_box.visible = true
	_show_page()


func _show_page() -> void:
	var p: Dictionary = _pages[_page]
	_text.text = _fill(str(p.text))
	var img := ""
	if p.has("image") and ResourceLoader.exists(SHOTS % p.image):
		img = SHOTS % p.image
	_image.visible = img != ""
	_image.texture = load(img) if img != "" else null
	_counter.text = "%d / %d" % [_page + 1, _pages.size()]
	_next.text = "NEXT  ▶" if _page < _pages.size() - 1 else "GOT IT!"
	_text.visible_ratio = 0.0
	if _typing:
		_typing.kill()
	_typing = create_tween()
	_typing.tween_property(_text, "visible_ratio", 1.0, maxf(_text.text.length() / CHARS_PER_SECOND, 0.1))
	_next.grab_focus()


func _advance() -> void:
	if _text.visible_ratio < 1.0:  # primero se termina de escribir
		if _typing:
			_typing.kill()
		_text.visible_ratio = 1.0
		return
	_page += 1
	if _page >= _pages.size():
		_close()
	else:
		_show_page()


func _close() -> void:
	if not _bubble.visible:
		return
	_bubble.visible = false
	get_tree().paused = _was_paused


func _unhandled_input(event: InputEvent) -> void:
	if _bubble.visible and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("ui_cancel"):
			_close()
		else:
			_advance()


## {player}, {role}, {perk1}, {perk2}
func _fill(text: String) -> String:
	var role: Dictionary = GameState.role_data
	if role.is_empty():
		role = GameState.roles.get(GameState.selected_role, {})
	var perks: Array = role.get("perks", ["", ""])
	return text.format({
		"player": GameState.first_name(),
		"role": str(role.get("title", "crew member")).to_lower(),
		"perk1": str(perks[0]) if perks.size() > 0 else "",
		"perk2": str(perks[1]) if perks.size() > 1 else "",
	})


# ---------------------------------------------------------------- ayuda (clic en el robot)

func _on_box_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and not _bubble.visible:
		_open([{"text": _help_text()}])


## Qué conviene hacer ahora, según el estado de la misión.
func _help_text() -> String:
	for t in _tasks():
		if Mission.sol() <= 1 and not done.has(t.id):
			return "Your next job: %s. %s" % [str(t.text).to_lower(), _where(t.id)]
	var tips: Array[String] = []
	if Mission.broken_count() + Mission.cut_cable_count() > 0:
		tips.append("Some solar panels are broken. Fix them in the SOLAR FIELD.")
	elif Mission.cleanliness() < 70.0:
		tips.append("The solar panels are dirty. Clean them in the SOLAR FIELD.")
	if Mission.crops.needs_water():
		tips.append("Your potatoes are thirsty. Water them in the GREENHOUSE.")
	elif not Mission.crops.is_growing() and GameState.greenhouse_step == 0:
		tips.append("Plant new potatoes in the GREENHOUSE.")
	if not Mission.exercised_today():
		tips.append("You haven't exercised today. Go to the GYM.")
	if Mission.crew.value_of("hunger") < 60.0:
		tips.append("Your FOOD bar is going down. Time to eat!")
	if Mission.crew.value_of("fatigue") > 60.0:
		tips.append("You look tired. Sleep in the CREW QUARTERS.")
	if Mission.crew.value_of("radiation") > 40.0:
		tips.append("Your RADIATION is high. Get a check-up in the INFIRMARY.")
	if tips.is_empty():
		return "Everything looks good! Keep going with the RESEARCH: take samples at AP-1, AP-8 and AP-9 and analyze them in the WORK ROOM."
	return " ".join(tips.slice(0, 2))


func _where(task_id: String) -> String:
	match task_id:
		"fix_panels":
			return "Go outside to the SOLAR PANELS and click SOLAR FIELD."
		"plant":
			return "Go to the GREENHOUSE in the station and click the SEED POTATOES."
		"water":
			return "In the GREENHOUSE, click the WATER TANK."
		"exercise":
			return "Go to the GYM in the station and click the TREADMILL."
	return ""
