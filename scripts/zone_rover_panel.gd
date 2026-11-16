extends CanvasLayer
## Panel del carro en AP-8 / AP-9 (lo crea expedition_site.gd). Aparece al acercarse al carro:
##   EAT A MEAL      come de lo que se cargó en el carro (Mission.crew.eat, espera de 5 h entre comidas)
##   − [8 h] +  SLEEP  dormir dentro del carro las horas que elija el jugador (1-24, rules.json
##                     crew.fatigue). Al acercarse propone lo que le falta a la muestra (Mission.crew.sleep)
##   DRIVE BACK (E)  volver directo a Ares 1, solo cuando la muestra está lista (Mission.expedition)

const Style := preload("res://scripts/core/style.gd")
const DEFAULT_SLEEP := 8

var vehicle: Node2D          # building.gd del carro
var drive: Callable          # lo mismo que pulsar E junto al carro

var _box: PanelContainer
var _status: Label
var _buttons := {}
var _working := false
var _hours := DEFAULT_SLEEP     # horas de sueño elegidas
var _hours_label: Label
var _shown := false


func _ready() -> void:
	layer = 10
	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", Style.box(Color(Style.DEEP_BLUE, 0.9), Style.NEON_YELLOW, 3, 16.0))
	_box.position = Vector2(860, 186)
	_box.custom_minimum_size = Vector2(400, 0)
	_box.visible = false
	add_child(_box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_box.add_child(col)
	col.add_child(Style.brand_title("YOUR ROVER", 28, Style.WHITE))
	_status = Style.brand_label("", 16, Style.WHITE, 600)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(360, 0)
	col.add_child(_status)
	for id in ["eat", "less", "more", "sleep", "drive"]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		Style.brand_button(b, id == "drive", 18)
		b.pressed.connect(_on_pressed.bind(id))
		_buttons[id] = b
	col.add_child(_buttons.eat)
	# dormir: − [8 h] + y el botón
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	for id in ["less", "more"]:
		_buttons[id].text = "−" if id == "less" else "+"
		_buttons[id].alignment = HORIZONTAL_ALIGNMENT_CENTER
		_buttons[id].custom_minimum_size = Vector2(44, 0)
	row.add_child(_buttons.less)
	_hours_label = Style.brand_label("", 18, Style.WHITE, 700)
	_hours_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hours_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hours_label.custom_minimum_size = Vector2(60, 0)
	row.add_child(_hours_label)
	row.add_child(_buttons.more)
	_buttons.sleep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_buttons.sleep)
	col.add_child(_buttons.drive)


func _process(_delta: float) -> void:
	var near: bool = vehicle != null and vehicle.can_use()
	_box.visible = near and not _working and not Mission.is_busy()
	if near and not _shown:  # al acercarse: propone dormir lo que le falta a la muestra
		var ex := Mission.expedition
		_hours = clampi(ceili(ex.extraction.hours_left) if ex.is_extracting() else DEFAULT_SLEEP, _min_h(), _max_h())
	_shown = near
	if _box.visible:
		_refresh()


func _refresh() -> void:
	var ex := Mission.expedition
	var sample := "Sample: READY!" if ex.extracted_here else \
		("Sample: drilling, %d h left" % ceili(ex.extraction.hours_left) if ex.is_extracting() else "Sample: not started")
	_status.text = "Food in the rover: %d meals\n%s" % [ex.meals_loaded, sample]

	var why := Mission.crew.eat_blocked_reason()
	if why == "":
		_buttons.eat.text = "EAT A MEAL"
	elif Mission.crew.hours_until_meal() > 0.0:
		_buttons.eat.text = "EAT  ·  next meal in %d h" % ceili(Mission.crew.hours_until_meal())
	else:
		_buttons.eat.text = "EAT  ·  no food left"
	_buttons.eat.disabled = why != ""
	_hours_label.text = "%d h" % _hours
	_buttons.less.disabled = _hours <= _min_h()
	_buttons.more.disabled = _hours >= _max_h()
	_buttons.sleep.text = "SLEEP IN THE ROVER"
	var leave := ex.travel_blocked_reason(ex.home())
	_buttons.drive.text = "DRIVE BACK TO ARES 1  (E)" if leave == "" else "DRIVE BACK  ·  get the sample first"
	_buttons.drive.disabled = leave != ""


func _min_h() -> int:
	return int(Mission.rules.crew.fatigue.sleep_min_hours)


func _max_h() -> int:
	return int(Mission.rules.crew.fatigue.sleep_max_hours)


func _on_pressed(id: String) -> void:
	if _working or Mission.is_busy():
		return
	match id:
		"drive":
			drive.call()
		"eat":
			var why := Mission.crew.eat()
			Mission.notify("Yum! You feel better." if why == "" else why)
		"less", "more":
			_hours = clampi(_hours + (1 if id == "more" else -1), _min_h(), _max_h())
		"sleep":
			_working = true
			_box.visible = false
			await Mission.crew.sleep(_hours)
			_working = false
