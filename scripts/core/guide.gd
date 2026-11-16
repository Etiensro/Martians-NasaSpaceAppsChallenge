extends CanvasLayer
## Autoload "Guide": A.R.I.A., el robot que acompaña al jugador después de la intro.
##   - Abajo a la izquierda: botón pequeño con el robot y una barrita del progreso del día.
##     Al hacer clic se abre/cierra la lista de tareas: el día 1, las 4 tareas para aprender la
##     rutina; después, la rutina diaria (✓ lo que está bien, ! lo que hay que cuidar).
##     Debajo, la sección de comida: comidas en la despensa, barra de hambre y botón EAT
##     (solo sale dentro de la base principal, la Estación Ares 1; espera de rules.json crew.hunger.meal_cooldown_hours entre comidas).
##   - Lecciones muy cortas (con capturas del juego) que salen una sola vez cuando pasa algo:
##     entrar a una escena, completar una tarea, terminar el día 1... Mientras habla, el juego se pausa.
##   - Cambia según dónde estés: en una expedición (AP-8 / AP-9) la lista enseña los pasos de la zona
##     (paneles, taladro, esperar la muestra, volver) y las lecciones de la base (tareas del día 1, el
##     polvo de cada mañana...) esperan a que vuelvas. Cada lección puede llevar "where": "base" o "zone".
## Textos y disparadores: data/guide/guide.json. Capturas: assets/ui/guide/ (tools/build_guide_shots.py).

const Style := preload("res://scripts/core/style.gd")
const Fx := preload("res://scripts/core/fx.gd")
const DATA := "res://data/guide/guide.json"
const SHOTS := "res://assets/ui/guide/%s.png"
const ROBOT_FRAMES := preload("res://assets/characters/robot_frames.tres")
const PAUSED_SCENES := "res://scenes/intro/"
## Base principal: aquí (y solo aquí) sale la sección de comida.
const BASE_SCENES := "res://scenes/interiores/estacion_ares1/"
## En los minijuegos el robot se esconde para no tapar el juego.
const HIDDEN_IN := [
	"res://scenes/interiores/estacion_ares1/modulos/invernadero/sembrar.tscn",
	"res://scenes/interiores/estacion_ares1/modulos/invernadero/regar.tscn",
	"res://scenes/interiores/estacion_ares1/modulos/gimnasio/caminadora.tscn",
	"res://scenes/interiores/paneles_solares/minijuegos/",
]
const SHOW_DELAY := 1.0       # espera tras cambiar de escena (que termine el fundido)
const CHARS_PER_SECOND := 45.0
const BUTTON := Vector2(76, 86)

var data: Dictionary
var seen := {}                # id de lección -> true
var done := {}                # id de tarea del día 1 -> true (se queda hecha)
var _queue: Array = []
var _pages: Array = []
var _page := 0
var _scene := ""
var _wait := 0.0
var _was_paused := false

var _button: PanelContainer   # robot pequeño (botón)
var _robot: AnimatedSprite2D
var _mini_bar: ProgressBar
var _badge: Label
var _list: PanelContainer     # lista de tareas (se abre con el botón)
var _list_title: Label
var _list_bar: ProgressBar
var _list_rows: VBoxContainer
var _food: VBoxContainer      # sección de comida (dentro de la lista; solo en la estación)
var _food_meals: Label
var _food_bar: ProgressBar
var _food_note: Label
var _eat: Button
var _bubble: PanelContainer
var _text: Label
var _image: TextureRect
var _next: Button
var _typing: Tween
var _t := 0.0


func _init() -> void:
	layer = 45  # encima del HUD de la misión (40), debajo del fundido de SceneChanger (100)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_build_button()
	_build_list()
	_build_bubble()


# ---------------------------------------------------------------- interfaz

func _build_button() -> void:
	_button = PanelContainer.new()
	_button.add_theme_stylebox_override("panel", Style.box(Style.NAVY_SOFT, Style.NEON_YELLOW, 2, 4))
	_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_button.offset_left = 10
	_button.offset_right = 10 + BUTTON.x
	_button.offset_top = -10 - BUTTON.y
	_button.offset_bottom = -10
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_button.tooltip_text = "A.R.I.A. · Your tasks"
	_button.gui_input.connect(_on_button_input)
	_button.visible = false
	add_child(_button)
	var area := Control.new()
	area.custom_minimum_size = BUTTON - Vector2(8, 8)
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.add_child(area)
	var halo := Sprite2D.new()
	halo.texture = Fx.GLOW
	halo.position = Vector2(34, 34)
	halo.scale = Vector2.ONE * 1.1
	halo.modulate = Color(Style.BLUE_YONDER, 0.5)
	area.add_child(halo)
	_robot = AnimatedSprite2D.new()
	_robot.sprite_frames = ROBOT_FRAMES
	_robot.offset = Vector2(0, -47)
	_robot.position = Vector2(34, 64)
	_robot.play("idle_down")
	area.add_child(_robot)
	_mini_bar = Style.progress_bar(60, 6)
	_mini_bar.position = Vector2(4, 70)
	_mini_bar.custom_minimum_size = Vector2(60, 6)
	_mini_bar.size = Vector2(60, 6)
	area.add_child(_mini_bar)
	_badge = Style.label("", 12, Style.NAVY, 0)  # cuántas cosas faltan
	_badge.add_theme_stylebox_override("normal", Style.box(Style.NEON_YELLOW, Style.NEON_YELLOW, 0, 3))
	_badge.position = Vector2(44, -2)
	area.add_child(_badge)


func _build_list() -> void:
	_list = PanelContainer.new()
	_list.add_theme_stylebox_override("panel", Style.box(Color(Style.DEEP_BLUE, 0.95), Style.NEON_YELLOW, 2, 12))
	_list.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_list.offset_left = 10
	_list.offset_right = 290
	_list.offset_bottom = -16 - BUTTON.y
	_list.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_list.visible = false
	add_child(_list)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_list.add_child(col)
	_list_title = Style.brand_title("", 16, Style.WHITE)
	col.add_child(_list_title)
	_list_bar = Style.progress_bar(250, 10)
	col.add_child(_list_bar)
	_list_rows = VBoxContainer.new()
	_list_rows.add_theme_constant_override("separation", 3)
	col.add_child(_list_rows)
	_build_food(col)


## Sección de comida: cuántas comidas quedan, el hambre y el botón para comer.
func _build_food(parent: VBoxContainer) -> void:
	_food = VBoxContainer.new()
	_food.add_theme_constant_override("separation", 6)
	parent.add_child(_food)
	var col := _food
	var line := ColorRect.new()
	line.color = Color(Style.NEON_YELLOW, 0.5)
	line.custom_minimum_size = Vector2(0, 2)
	col.add_child(line)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Style.brand_title("FOOD", 16, Style.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_food_meals = Style.label("", 15, Style.NEON_YELLOW, 0)
	head.add_child(_food_meals)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	row.add_child(Style.label("Hunger", 14, Style.WHITE, 0))
	_food_bar = Style.progress_bar(180, 10)
	_food_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_food_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_food_bar)
	_eat = Button.new()
	_eat.custom_minimum_size = Vector2(0, 34)
	Style.brand_button(_eat, true, 15)
	_eat.pressed.connect(_on_eat)
	col.add_child(_eat)
	_food_note = Style.label("", 13, Color(1, 1, 1, 0.7), 0)
	_food_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_food_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_food_note)


func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", Style.box(Color(Style.DEEP_BLUE, 0.96), Style.BLUE_YONDER, 2, 12))
	_bubble.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_bubble.offset_left = 20 + BUTTON.x
	_bubble.offset_right = 20 + BUTTON.x + 560
	_bubble.offset_bottom = -10
	_bubble.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bubble.visible = false
	add_child(_bubble)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_bubble.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	_text = Style.label("", 18, Style.WHITE, 0)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(250, 60)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	col.add_child(_text)
	_next = Button.new()
	_next.custom_minimum_size = Vector2(110, 32)
	_next.size_flags_horizontal = Control.SIZE_SHRINK_END
	Style.brand_button(_next, true, 15)
	_next.pressed.connect(_advance)
	col.add_child(_next)
	_image = TextureRect.new()
	_image.custom_minimum_size = Vector2(256, 144)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_image)


# ---------------------------------------------------------------- estado

func _process(delta: float) -> void:
	_t += delta
	var scene := get_tree().current_scene
	var path := scene.scene_file_path if scene else ""
	if path.begins_with(PAUSED_SCENES):
		_reset()  # en el menú o la intro: la guía vuelve a empezar
		_button.visible = false
		_list.visible = false
		_scene = path
		return
	if path != _scene:
		_scene = path
		_wait = SHOW_DELAY
		_list.visible = false
		_queue_trigger("scene:" + path)
	var hidden := HIDDEN_IN.any(func(h): return path.begins_with(h))
	_button.visible = (Mission.is_running() and not hidden) or _bubble.visible
	if not _button.visible:
		_list.visible = false
	_check_tasks()
	_update_button()
	if _list.visible:
		_fill_list()
	_robot.offset.y = -47 + sin(_t * (8.0 if _bubble.visible else 3.0)) * 1.5  # cuando habla se mueve más
	if _wait > 0.0:
		_wait -= delta
	elif not _bubble.visible and not _queue.is_empty() and Mission.is_running() and not Mission.is_busy() and not SceneChanger.is_busy() \
			and not get_tree().paused and not hidden:
		for i in _queue.size():  # la primera lección que corresponde a donde estás; las demás esperan
			if _fits_here(_queue[i]):
				_open(_queue.pop_at(i).pages)
				break


func _reset() -> void:
	if seen.is_empty() and done.is_empty():
		return
	seen.clear()
	done.clear()
	_queue.clear()
	_close()


## ¿Estás de expedición (AP-8 / AP-9 o viajando)? Entonces la guía habla de la zona, no de la base.
func _away() -> bool:
	return Mission.expedition.is_away()


## ¿Esta lección corresponde a donde estás ahora? "where": "base", "zone" o "any". Sin "where", las
## lecciones de entrar a una escena valen allí mismo y las demás (tareas, mañanas) son de la base.
func _fits_here(lesson: Dictionary) -> bool:
	var where: String = lesson.get("where", "any" if str(lesson.trigger).begins_with("scene:") else "base")
	match where:
		"base":
			return not _away()
		"zone":
			return _away()
	return true


func _tasks() -> Array:
	return data.get("tasks", [])


func _day1() -> bool:
	return Mission.sol() <= 1 and done.size() < _tasks().size() and not _away()


## Marca las tareas del día 1 que ya se cumplieron (una vez hechas, se quedan hechas).
func _check_tasks() -> void:
	if not Mission.is_running():
		return
	for t in _tasks():
		if done.has(t.id) or not _task_done(t.id):
			continue
		done[t.id] = true
		_queue_trigger("task:" + str(t.id))
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


## Rutina diaria: ¿está bien ese punto ahora mismo?
func _routine_ok(id: String) -> bool:
	match id:
		"panels":
			return Mission.cleanliness() >= 90.0 and Mission.broken_count() + Mission.cut_cable_count() == 0
		"potatoes":
			return not Mission.crops.needs_water() and (Mission.crops.is_growing() or Mission.crops.is_ready())
		"exercise":
			return Mission.exercised_today()
		"food":
			return Mission.crew.value_of("hunger") >= 70.0
		"sleep":
			return Mission.crew.value_of("fatigue") < 50.0
		"radiation":
			return Mission.crew.value_of("radiation") < 25.0
	return true


## Pasos de la expedición en la zona: ¿ya está hecho?
func _step_done(id: String) -> bool:
	var ex := Mission.expedition
	match id:
		"panels":
			return ex.zone_panels_clean or ex.extracted_here
		"drill":
			return ex.is_extracting() or ex.extracted_here
		"sample":
			return ex.extracted_here
	return false


## [[texto, hecho]] de lo que se enseña en la lista.
func _items() -> Array:
	var out := []
	if _away():  # expedición: los pasos de la zona y cuidarse con lo que hay en el carro
		for st in data.get("expedition", []):
			out.append([str(st.text), _step_done(st.id)])
		if Mission.crew.value_of("hunger") < 70.0:
			out.append(["Eat a meal in your rover", false])
		if Mission.crew.value_of("fatigue") >= 50.0:
			out.append(["Sleep in your rover", false])
	elif _day1():
		for t in _tasks():
			out.append([str(t.text), done.has(t.id)])
	else:
		for r in data.get("routine", []):
			var ok := _routine_ok(r.id)
			out.append([str(r.ok if ok else r.todo), ok])
	return out


func _update_button() -> void:
	var items := _items()
	var ok := items.filter(func(i): return i[1]).size()
	_mini_bar.value = 100.0 * ok / maxi(items.size(), 1)
	var left := items.size() - ok
	_badge.text = " %d " % left
	_badge.visible = left > 0


func _fill_list() -> void:
	var items := _items()
	var ok := items.filter(func(i): return i[1]).size()
	if _away():
		_list_title.text = "%s MISSION  ·  %d / %d" % [Mission.expedition.site, ok, items.size()]
	elif _day1():
		_list_title.text = "DAY 1  ·  %d / %d" % [ok, items.size()]
	else:
		_list_title.text = "TODAY  ·  SOL %d" % Mission.sol()
	_list_bar.value = 100.0 * ok / maxi(items.size(), 1)
	while _list_rows.get_child_count() < items.size():
		_list_rows.add_child(Style.label("", 15, Style.WHITE, 0))
	for i in _list_rows.get_child_count():
		var l: Label = _list_rows.get_child(i)
		l.visible = i < items.size()
		if l.visible:
			var it: Array = items[i]
			l.text = ("✓  " if it[1] else "!  ") + str(it[0])
			l.add_theme_color_override("font_color", Color(1, 1, 1, 0.55) if it[1] else Style.NEON_YELLOW)
	_fill_food()


## Solo se come dentro de la base principal (la Estación Ares 1 y sus módulos).
func _at_base() -> bool:
	return not Mission.expedition.is_away() and _scene.begins_with(BASE_SCENES)


## Motivo por el que no se puede comer ahora ("" si se puede).
func _eat_blocked() -> String:
	var wait := Mission.crew.hours_until_meal()
	if wait > 0.0:
		return "Next meal in %d h." % ceili(wait)
	return Mission.crew.eat_blocked_reason()


func _fill_food() -> void:
	_food.visible = _at_base()  # fuera de la estación no sale la sección de comida
	if not _food.visible:
		return
	_food_meals.text = "%d meals left" % Mission.pantry_meals
	_food_bar.value = Mission.crew.value_of("hunger")
	var why := _eat_blocked()
	_eat.disabled = why != "" or Mission.is_busy()
	_eat.text = "EAT A MEAL" if why == "" else "CAN'T EAT NOW"
	_food_note.text = why if why != "" else "You can eat once every %d hours." % int(Mission.rules.crew.hunger.meal_cooldown_hours)


func _on_eat() -> void:
	var why := Mission.crew.eat() if _eat_blocked() == "" else _eat_blocked()
	Mission.notify(why if why != "" else "Yum! A hot potato meal. Hunger +%d." % int(Mission.rules.crew.hunger.per_meal))
	_fill_food()


func _on_button_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and not _bubble.visible:
		_list.visible = not _list.visible
		get_viewport().set_input_as_handled()


## Pone en la cola la lección de ese disparador (si no se ha visto).
func _queue_trigger(trigger: String) -> void:
	for l in data.get("lessons", []):
		if l.trigger == trigger and not seen.has(l.id):
			seen[l.id] = true
			_queue.append(l)


# ---------------------------------------------------------------- lecciones

## Abre el globo con una lista de páginas [{text, image?}] y pausa el juego.
func _open(pages: Array) -> void:
	_pages = pages
	_page = 0
	_was_paused = get_tree().paused
	get_tree().paused = true
	_list.visible = false
	_bubble.visible = true
	_button.visible = true
	_show_page()


func _show_page() -> void:
	var p: Dictionary = _pages[_page]
	_text.text = _fill(str(p.text))
	var img := ""
	if p.has("image") and ResourceLoader.exists(SHOTS % p.image):
		img = SHOTS % p.image
	_image.visible = img != ""
	_image.texture = load(img) if img != "" else null
	_next.text = "NEXT ▶" if _page < _pages.size() - 1 else "OK!"
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
	if not _bubble.visible:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


## {player}, {role}, {perk1}, {perk2}
func _fill(text: String) -> String:
	var role: Dictionary = GameState.role_data
	if role.is_empty():
		role = GameState.roles.get(GameState.selected_role, {})
	var perks: Array = role.get("perks", ["", ""])
	return text.format({
		"player": GameState.first_name(),
		"role": str(role.get("title", "crew member")).to_lower(),
		"perk1": str(perks[0]).to_lower() if perks.size() > 0 else "",
		"perk2": str(perks[1]).to_lower() if perks.size() > 1 else "",
	})
