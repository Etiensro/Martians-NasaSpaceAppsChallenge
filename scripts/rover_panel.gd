extends CanvasLayer
## Panel del carro explorador en AP-1 (lo crea colony.gd). Aparece al acercarse al carro con botones
## para prepararlo antes de una expedición a AP-8 o AP-9 (reglas en Mission.expedition):
##   INSPECT 2 h → MAINTENANCE 2 h (después de inspeccionar) → REPAIR 4 h (solo si una tormenta intensa
##   lo dañó, cuesta energía) → LOAD FOOD 1 h (el jugador elige de 1 a 6 comidas con − / +; se enseña la
##   cantidad recomendada, pero no es obligatoria) → DRIVE TO MAP.
## El estado (inspección, mantenimiento, comida) vive en Mission.expedition: no se pierde al ir y volver del mapa.
## Cada tarea solo enseña el cartel de Mission con el tiempo pasando (Mission.run_task): no hay minijuego.
## Las horas que enseñan los botones ya llevan las penalizaciones de hambre, cansancio y radiación.

const Style := preload("res://scripts/core/style.gd")
const DESTINATIONS := ["AP-8", "AP-9"]

var vehicle: Node2D          # building.gd del carro (para saber si el jugador está cerca)
var drive: Callable          # lo que hace "DRIVE TO MAP" (igual que pulsar E)

var _box: PanelContainer
var _status: Label
var _ready_label: Label
var _buttons := {}           # id -> Button
var _meals_label: Label
var _need_label: Label
var _meals := 1              # comidas elegidas para el carro
var _working := false
var _shown := false


func _ready() -> void:
	layer = 10
	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", Style.box(Color(Style.DEEP_BLUE, 0.9), Style.NEON_YELLOW, 3, 16.0))
	_box.position = Vector2(860, 186)  # a la derecha, debajo del HUD: el carro está a la izquierda de AP-1
	_box.custom_minimum_size = Vector2(400, 0)
	_box.visible = false
	add_child(_box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_box.add_child(col)
	col.add_child(Style.brand_title("EXPLORER ROVER", 28, Style.WHITE))
	_status = Style.brand_label("", 16, Style.WHITE, 600)
	col.add_child(_status)
	for id in ["inspect", "maintain", "repair"]:
		_buttons[id] = _button(id, false)
		col.add_child(_buttons[id])
	# comida: − [n meals] + y el botón de cargar
	var food := HBoxContainer.new()
	food.add_theme_constant_override("separation", 8)
	col.add_child(food)
	for id in ["less", "more"]:
		var b := _button(id, false)
		b.text = "−" if id == "less" else "+"
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(44, 0)
		_buttons[id] = b
	food.add_child(_buttons.less)
	_meals_label = Style.brand_label("", 18, Style.WHITE, 700)
	_meals_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meals_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_meals_label.custom_minimum_size = Vector2(92, 0)
	food.add_child(_meals_label)
	food.add_child(_buttons.more)
	_buttons.food = _button("food", false)
	_buttons.food.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	food.add_child(_buttons.food)
	_need_label = Style.brand_label("", 14, Style.WHITE, 500)
	col.add_child(_need_label)
	_ready_label = Style.brand_label("", 15, Style.WHITE, 600)
	_ready_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ready_label.custom_minimum_size = Vector2(350, 0)
	col.add_child(_ready_label)
	_buttons.drive = _button("drive", true)
	col.add_child(_buttons.drive)


func _button(id: String, primary: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	Style.brand_button(b, primary, 18)
	b.pressed.connect(_on_pressed.bind(id))
	return b


func _process(_delta: float) -> void:
	var near: bool = vehicle != null and vehicle.can_use()
	var show := near and not _working and not Mission.is_busy()
	_box.visible = show
	if near and not _shown:  # al acercarse: propone lo que ya lleva o lo que pide el viaje más largo
		_set_meals(maxi(Mission.expedition.meals_loaded, food_target()))
	_shown = near
	if show:
		_refresh()


# ---------------------------------------------------------------- estado

## Comidas recomendadas para el viaje más largo (lo que se propone al acercarse).
func food_target() -> int:
	var need := 0
	for dest in DESTINATIONS:
		need = maxi(need, Mission.expedition.meals_needed(dest))
	return need


## Máximo que se puede elegir: 6 (lo que cabe en el carro) o lo que haya entre carro y despensa.
func max_meals() -> int:
	return mini(int(Mission.rules.expeditions.max_meals), Mission.expedition.meals_loaded + Mission.pantry_meals)


func _set_meals(n: int) -> void:
	_meals = clampi(n, 1, maxi(max_meals(), 1))


func _hours(base_key: String, kind: String) -> String:
	var h := Mission.task_hours(float(Mission.rules.expeditions[base_key]), kind)
	return ("%d h" % h) if is_equal_approx(h, roundf(h)) else ("%.1f h" % h)


func _refresh() -> void:
	var ex := Mission.expedition
	_status.text = "Food in the rover: %d / %d   ·   Pantry: %d meals" % [ex.meals_loaded, Mission.rules.expeditions.max_meals, Mission.pantry_meals]

	var b: Button = _buttons.inspect
	b.text = "INSPECTED  ·  OK" if ex.inspected else "INSPECT  ·  %s" % _hours("inspection_hours", "maintenance")
	b.disabled = ex.inspected

	b = _buttons.repair
	b.visible = ex.damaged
	b.text = "REPAIR (storm damage)  ·  %s  ·  %d EU" % [_hours("repair_hours", "repair"), Mission.rules.energy.system_repair_cost]

	b = _buttons.maintain
	if ex.maintained:
		b.text = "MAINTENANCE  ·  OK"
	elif not ex.inspected:
		b.text = "MAINTENANCE  ·  inspect first"
	elif ex.damaged:
		b.text = "MAINTENANCE  ·  repair first"
	else:
		b.text = "MAINTENANCE  ·  %s" % _hours("maintenance_hours", "maintenance")
	b.disabled = ex.maintained or not ex.inspected or ex.damaged

	_meals = clampi(_meals, 1, maxi(max_meals(), 1))
	_meals_label.text = "%d meal%s" % [_meals, "" if _meals == 1 else "s"]
	_buttons.less.disabled = _meals <= 1
	_buttons.more.disabled = _meals >= max_meals()
	b = _buttons.food
	if max_meals() == 0:
		b.text = "PANTRY EMPTY"
		b.disabled = true
	elif _meals == ex.meals_loaded:
		b.text = "LOADED  ·  OK"
		b.disabled = true
	else:
		b.text = "%s  ·  %s" % ["LOAD" if _meals > ex.meals_loaded else "UNLOAD", _hours("prepare_hours", "general")]
		b.disabled = false
	_need_label.text = "Recommended: %s" % "  ·  ".join(DESTINATIONS.map(
		func(d: String) -> String: return "%d meals for %s" % [ex.meals_needed(d), d]))

	var lines: Array[String] = []
	var all_ready := true
	for dest in DESTINATIONS:
		var problems := ex.departure_problems(dest)
		all_ready = all_ready and problems.is_empty()
		var line := "READY" if problems.is_empty() else problems[0]
		if problems.is_empty() and ex.meals_loaded < ex.meals_needed(dest):  # aviso, no bloquea
			line += "  (only %d meals: you may go hungry)" % ex.meals_loaded
		lines.append("%s: %s" % [dest, line])
	_ready_label.text = "\n".join(lines)
	_ready_label.add_theme_color_override("font_color", Style.NEON_YELLOW if all_ready else Style.WHITE)
	_buttons.drive.text = "DRIVE TO MAP  (E)"


# ---------------------------------------------------------------- acciones

func _on_pressed(id: String) -> void:
	if _working or Mission.is_busy():
		return
	if id == "drive":
		drive.call()
		return
	if id == "less" or id == "more":
		_set_meals(_meals + (1 if id == "more" else -1))
		return
	_working = true
	_box.visible = false
	var ex := Mission.expedition
	var why := ""
	match id:
		"inspect":
			why = await ex.inspect()
		"maintain":
			why = await ex.maintain()
		"repair":
			why = await ex.repair()
		"food":
			why = await ex.load_meals(_meals)
	if why != "":
		Mission.notify(why)
	_working = false
