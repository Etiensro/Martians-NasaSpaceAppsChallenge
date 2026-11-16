extends Node
## Autoload "Mission": el sistema base del juego. Lleva el tiempo de la misión y todo lo que depende
## de él, en todas las escenas (se para en el menú y la intro). Reglas y números: data/mission/rules.json.
## Documentación completa (para cualquiera que lo vaya a tocar): docs/SISTEMAS_DE_MISION.md.
##
## Lo que vive aquí:
##   - Reloj: 1 minuto real = 1 hora de juego. sol() / hour_of_day() / time_text().
##   - Actividades: run_activity() / run_task() adelantan el reloj rápido (dormir, chequeo, viajes...),
##     con todas las barras y eventos actualizándose hora a hora.
##   - Tareas: task_hours(base, tipo) aplica las penalizaciones de hambre, cansancio, radiación,
##     condición física y la velocidad del rol.
##   - Energía: batería, generación de los paneles, consumo de los sistemas (apagables o no).
##   - Paneles: 16 paneles con suciedad y roturas, y sus cables. Tormentas con aviso, encierro y daños.
##   - Despensa (pantry_meals), puntuación (score()) y fin de la misión.
## Y sus módulos (scripts/core/mission/):
##   Mission.crew        hambre, cansancio, radiación, condición física; comer, dormir, ejercicio, chequeo
##   Mission.crops       cultivo de papas del invernadero
##   Mission.research    muestras y análisis en el laboratorio (% de investigación)
##   Mission.expedition  carro explorador y viajes a AP-8 / AP-9
##
## Ejemplos para otros módulos:
##   await Mission.crew.sleep(8)                  # dormir 8 h (el reloj avanza 8 h en unos segundos)
##   Mission.task_hours(4.0, "repair")            # 4 h de reparación con las penalizaciones actuales
##   await Mission.run_task("Fixing", 2.0, "repair", 0.25)  # tarea de 2 h; 0.25 h ya jugadas en tiempo real
##   Mission.spend(20)                            # gasto puntual de energía. false si no alcanza
##   Mission.set_extra_load("lab", 4)             # consumo extra mientras dure (0 para quitarlo)
##   Mission.is_on("greenhouse")                  # ¿está encendido el invernadero?
##   Mission.notify("...")                        # mensaje de A.R.I.A. en pantalla

signal hour_passed
signal sol_started(sol: int)
signal storm_warning(type: String, hours_left: float)
signal storm_started(type: String)
signal storm_ended(type: String)
signal systems_changed
signal panels_changed
@warning_ignore("unused_signal")  # la emiten los módulos de scripts/core/mission/
signal crew_changed
@warning_ignore("unused_signal")  # la emiten los módulos de scripts/core/mission/
signal crops_changed
@warning_ignore("unused_signal")  # la emiten los módulos de scripts/core/mission/
signal research_changed
@warning_ignore("unused_signal")  # la emiten los módulos de scripts/core/mission/
signal expedition_changed
signal activity_started(label: String, hours: float)
signal activity_finished(label: String)
signal mission_over(reason: String)

const RULES_FILE := "res://data/mission/rules.json"
const Hud := preload("res://scripts/core/mission_hud.gd")
const Crew := preload("res://scripts/core/mission/crew.gd")
const Crops := preload("res://scripts/core/mission/crops.gd")
const Research := preload("res://scripts/core/mission/research.gd")
const Expedition := preload("res://scripts/core/mission/expedition.gd")
## Escenas donde el reloj está parado (menú e intro).
const PAUSED_SCENES := "res://scenes/intro/"
## Escenas donde ya estás a salvo cuando empieza una tormenta fuerte.
const STATION_SCENES := "res://scenes/interiores/estacion_ares1/"
const PANEL_FIELD := "res://scenes/interiores/paneles_solares/minijuegos/campo_solar/campo_solar.tscn"
const STATION := "res://scenes/interiores/estacion_ares1/estacion_ares1.tscn"
const ICE_DRILL := "res://scenes/interiores/excavadora/minijuegos/extraccion_hielo/extraccion_hielo.tscn"
## Motivos de fin de misión (los usa el HUD para el texto).
const END_REASONS := ["complete", "energy", "hunger", "fatigue", "radiation"]

var rules: Dictionary
var hours := 0.0              # horas de juego desde el inicio de la misión
var battery := 0.0            # EU
var systems_on := {}          # id -> bool
var extra_loads := {}         # id -> EU/h
var panels: Array = []        # [{ "dirt": 0..100, "broken": bool }], fila por fila
var cables: Array = []        # bool por tramo: índice = fila * columnas + columna (tramo a la derecha del panel)
var storm := {}               # vacío o { "type", "starts_at", "ends_at", "active" }
var pantry_meals := 0         # comidas en la despensa de la base
var over := false
var end_reason := ""
var activity := {}            # actividad en curso: {} o {"label", "total", "left", "state", "rate"}

var crew: Crew
var crops: Crops
var research: Research
var expedition: Expedition

var _protected_until := 0.0   # sin tormentas hasta esta hora
var _last_hour := 0
var _hud: Hud


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # sigue funcionando mientras una actividad pausa la escena
	rules = JSON.parse_string(FileAccess.get_file_as_string(RULES_FILE))
	crew = Crew.new()
	crops = Crops.new()
	research = Research.new()
	expedition = Expedition.new()
	_hud = Hud.new()
	add_child(_hud)
	reset()


## Empieza una misión nueva (lo llama la pantalla de fin de misión al volver al menú).
func reset() -> void:
	if not activity.is_empty():
		_finish_activity()
	hours = 0.0
	_last_hour = 0
	over = false
	end_reason = ""
	battery = rules.energy.start
	systems_on.clear()
	for id in rules.energy.systems:
		systems_on[id] = true
	extra_loads.clear()
	panels.clear()
	cables.clear()
	for i in panel_count():
		# la tormenta del aterrizaje (intro) deja los paneles sucios: hay que limpiarlos para tener energía
		var dirt := randf_range(rules.panels.start_dirt_min, rules.panels.start_dirt_max)
		panels.append({"dirt": dirt, "broken": false})
		cables.append(true)
	# ... y algunos rotos: hay que cambiarlos en el campo solar
	_damage_panels(int(rules.panels.start_broken), int(rules.panels.start_cut_cables))
	storm = {}
	pantry_meals = int(rules.food.start_meals)
	# periodo de protección también al empezar, para aprender a jugar antes de la primera tormenta
	_protected_until = rules.storms.protection_sols * 24.0
	crew.reset()
	crops.reset()
	research.reset()
	expedition.reset()


## Busca en una tabla [[umbral, valor], ...] (de mayor a menor umbral) la primera fila con
## umbral <= `value` y devuelve su valor. Lo usan las penalizaciones.
func tier(table: Array, value: float) -> float:
	for row in table:
		if value >= row[0]:
			return row[1]
	return table[-1][1]


# ---------------------------------------------------------------- reloj

## El reloj corre: hay misión y no estamos en el menú ni en la intro.
func is_running() -> bool:
	var scene := get_tree().current_scene
	return not over and scene != null and not scene.scene_file_path.begins_with(PAUSED_SCENES)


func _process(delta: float) -> void:
	_hud.visible = is_running() or over
	if not activity.is_empty():
		_process_activity(delta)
	elif is_running() and not get_tree().paused:
		advance_hours(delta / rules.clock.real_seconds_per_hour)


## Avanza el reloj (y todo lo que depende de él) `h` horas de juego, en pasos de 15 min para que
## las tormentas, el cambio de sol y los avisos ocurran a su hora.
func advance_hours(h: float) -> void:
	while h > 0.0 and not over:
		var step := minf(h, 0.25)
		battery = clampf(battery + net() * step, 0.0, rules.energy.capacity)
		crew.tick(step, location())
		research.tick(step)
		expedition.tick(step)
		hours += step
		h -= step
		while _last_hour < int(hours):
			_last_hour += 1
			_on_hour(_last_hour)
		if battery <= 0.0:
			_end("energy")
		elif crew.abandon_reason() != "":
			_end(crew.abandon_reason())


func sol() -> int:
	return int(rules.clock.start_sol) + int((rules.clock.start_hour + hours) / 24.0)


## Sols que faltan para terminar la misión (para la puntuación).
func sols_left() -> int:
	return maxi(0, int(rules.clock.mission_sols) - sol() + 1)


## ¿Ya hubo una sesión de ejercicio en el sol actual? (solo se permite una al día)
func exercised_today() -> bool:
	return not crew.can_exercise()


func hour_of_day() -> float:
	return fmod(rules.clock.start_hour + hours, 24.0)


func time_text() -> String:
	return "SOL %d  ·  %s" % [sol(), clock_text(hour_of_day())]


## "08:30" a partir de una hora del día (puede pasar de 24).
func clock_text(h: float) -> String:
	h = fmod(h, 24.0)
	return "%02d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)]


func _on_hour(hour_index: int) -> void:
	hour_passed.emit()
	if (int(rules.clock.start_hour) + hour_index) % 24 == 0:  # medianoche: empieza un sol nuevo
		_on_new_sol()
	# durante la tormenta la arena se va acumulando: leve poco, moderada más, intensa mucho
	if storm_active():
		add_dirt_all(float(storm_rule().get("dirt", 0)) / float(storm_rule().hours))
	_update_storm()
	# por si al empezar la tormenta había un fundido en curso (SceneChanger ignora el cambio) o el
	# jugador vuelve de una expedición: con encierro, cada hora se comprueba que esté dentro
	if is_lockdown():
		_send_inside()


func _on_new_sol() -> void:
	add_dirt_all(rules.panels.dirt_per_sol)
	crew.on_new_sol(sol() - 1)
	crops.on_new_sol()
	sol_started.emit(sol())
	if sol() > int(rules.clock.mission_sols):
		_end("complete")
		return
	if storm.is_empty() and hours >= _protected_until and randf() < rules.storms.daily_chance:
		schedule_storm()


# ---------------------------------------------------------------- ubicación

## "inside" (dentro de un edificio) o "outside" (zonas, mapa, campo solar, viajando en el carro).
## Decide la radiación por hora. Las escenas exteriores están en rules.json -> locations.outside.
func location() -> String:
	if activity.get("state", {}).has("location"):
		return activity.state.location
	var scene := get_tree().current_scene
	if scene == null:
		return "inside"
	for prefix in rules.locations.outside:
		if scene.scene_file_path.begins_with(prefix):
			return "outside"
	return "inside"


# ---------------------------------------------------------------- tareas y actividades

## Multiplicador de duración de una tarea según el estado de la tripulación y el rol.
## Tipos: "general", "physical", "repair", "maintenance", "excavation" (físicas: también la condición
## física), "research", "medical", "fixed" (sin penalizaciones). Ver rules.json -> tasks.
func task_multiplier(kind := "general") -> float:
	if kind in rules.tasks.no_penalty_kinds:
		return 1.0
	var m := crew.hunger_multiplier() * crew.fatigue_multiplier() * crew.radiation_multiplier()
	if kind in rules.tasks.physical_kinds:
		m *= crew.fitness_multiplier()
	var speed_key: String = rules.tasks.role_speed.get(kind, "")
	if speed_key != "":
		m /= GameState.modifier(speed_key)
	return m


## Horas de juego que dura de verdad una tarea de `base_hours` horas.
## Ej.: 4 h con hambre 10-30 (x1.35), cansancio 80+ (x1.35) y radiación 50-74 (x1.15) = 8.38 h.
func task_hours(base_hours: float, kind := "general") -> float:
	return base_hours * task_multiplier(kind)


## Hace una tarea: calcula su duración con task_hours() y adelanta el reloj lo que falte.
## `already_played_hours`: horas de juego que ya pasaron mientras se jugaba el minijuego. Corrutina.
func run_task(label: String, base_hours: float, kind := "general", already_played_hours := 0.0) -> void:
	await run_activity(label, task_hours(base_hours, kind) - already_played_hours)


## Adelanta el reloj `h` horas en unos segundos reales, con la escena pausada y un cartel en pantalla
## (todas las barras y eventos se actualizan hora a hora). Corrutina: `await Mission.run_activity(...)`.
## `state`: {"asleep": true} para dormir, {"location": "outside"} para un viaje.
func run_activity(label: String, h: float, state := {}) -> void:
	while not activity.is_empty():  # una actividad a la vez
		await activity_finished
	if h <= 0.0 or over:
		return
	var secs := clampf(h * rules.clock.skip_seconds_per_hour, rules.clock.skip_min_seconds, rules.clock.skip_max_seconds)
	activity = {"label": label, "total": h, "left": h, "state": state, "rate": h / secs, "from": hour_of_day()}
	crew.asleep = state.get("asleep", false)
	get_tree().paused = true
	activity_started.emit(label, h)
	await activity_finished


func is_busy() -> bool:
	return not activity.is_empty()


func _process_activity(delta: float) -> void:
	var step := minf(activity.rate * delta, activity.left)
	activity.left -= step
	advance_hours(step)
	if activity.is_empty():  # la misión terminó durante el paso (_end ya cerró la actividad)
		return
	if activity.left <= 0.0 or over:
		_finish_activity()


func _finish_activity() -> void:
	var label: String = activity.label
	activity = {}
	crew.asleep = false
	get_tree().paused = false
	activity_finished.emit(label)


# ---------------------------------------------------------------- energía y sistemas

func capacity() -> float:
	return rules.energy.capacity


## EU/h que entran ahora: máximo x (paneles que funcionan / total) x (limpieza / 100), menos la tormenta.
func generation() -> float:
	var rate: float = rules.energy.max_generation
	rate *= float(working_panels()) / panel_count()
	rate *= cleanliness() / 100.0
	if storm_active():
		rate *= 1.0 - storm_rule().solar_loss
	return rate


## EU/h que salen ahora: sistemas encendidos + consumos extra (laboratorio...).
## El ingeniero gasta menos (GameState "energy_drain").
func consumption() -> float:
	var total := 0.0
	for id in systems_on:
		if systems_on[id]:
			total += rules.energy.systems[id].eu_per_hour
	for id in extra_loads:
		total += extra_loads[id]
	return total * GameState.modifier("energy_drain")


func net() -> float:
	return generation() - consumption()


## Horas hasta vaciar (si se gasta más de lo que entra) o llenar la batería; INF si no cambia.
func hours_to_empty() -> float:
	return battery / -net() if net() < 0.0 else INF


func hours_to_full() -> float:
	return (capacity() - battery) / net() if net() > 0.0 else INF


func system_ids() -> Array:
	return rules.energy.systems.keys()


func system_rule(id: String) -> Dictionary:
	return rules.energy.systems.get(id, {})


func is_on(id: String) -> bool:
	return systems_on.get(id, false)


## Motivo por el que ahora no se puede cambiar un sistema ("" si se puede). Soporte vital y cápsulas
## nunca; el invernadero no se apaga con papas creciendo.
func switch_blocked_reason(id: String) -> String:
	var rule := system_rule(id)
	if not rule.get("switchable", false):
		return rule.get("locked_message", "This system can't be turned off.")
	if id == "greenhouse" and is_on(id) and crops.is_growing():
		return rule.get("locked_message", "")
	return ""


func can_switch(id: String) -> bool:
	return system_rule(id).get("switchable", false)


## Enciende o apaga un sistema. Devuelve false si ahora no se puede (ver switch_blocked_reason).
func set_system(id: String, on: bool) -> bool:
	if switch_blocked_reason(id) != "":
		return false
	systems_on[id] = on
	systems_changed.emit()
	return true


func set_extra_load(id: String, eu_per_hour: float) -> void:
	if eu_per_hour <= 0.0:
		extra_loads.erase(id)
	else:
		extra_loads[id] = eu_per_hour


## Gasto puntual de energía. Devuelve false (y no gasta) si no alcanza.
func spend(eu: float) -> bool:
	if battery < eu:
		return false
	battery -= eu
	return true


## Sistemas que una tormenta dejó dañados ("greenhouse", "rover").
func damaged_systems() -> Array[String]:
	var out: Array[String] = []
	if crops.damaged:
		out.append("greenhouse")
	if expedition.damaged:
		out.append("rover")
	return out


## Repara el invernadero dañado por una tormenta: 10 EU y 2 h (tarea de reparación). Corrutina.
## El carro se repara con Mission.expedition.repair().
func repair_greenhouse() -> String:
	if not crops.damaged:
		return "The greenhouse isn't damaged."
	if not spend(rules.energy.system_repair_cost):
		return "Not enough energy for the repair."
	crops.damaged = false
	crops_changed.emit()
	await run_task("Repairing the greenhouse", rules.energy.system_repair_hours, "repair")
	return ""


# ---------------------------------------------------------------- paneles

func columns() -> int:
	return int(rules.panels.columns)


func rows() -> int:
	return int(rules.panels.rows)


func panel_count() -> int:
	return columns() * rows()


## Limpieza media de los paneles (0-100), como la barra del documento.
func cleanliness() -> float:
	var dirt := 0.0
	for p in panels:
		dirt += p.dirt
	return 100.0 - dirt / panel_count()


## Un panel da energía si no está roto y el cable hasta la caja de su fila está entero.
func is_panel_working(i: int) -> bool:
	if panels[i].broken:
		return false
	var row_start := i - i % columns()
	for k in range(i, row_start + columns()):
		if not cables[k]:
			return false
	return true


func working_panels() -> int:
	var n := 0
	for i in panel_count():
		if is_panel_working(i):
			n += 1
	return n


func broken_count() -> int:
	return panels.filter(func(p): return p.broken).size()


func cut_cable_count() -> int:
	return cables.count(false)


func set_panel_dirt(i: int, dirt: float) -> void:
	panels[i].dirt = clampf(dirt, 0.0, 100.0)
	panels_changed.emit()


func add_dirt_all(amount: float) -> void:
	for p in panels:
		p.dirt = clampf(p.dirt + amount, 0.0, 100.0)
	panels_changed.emit()


## Cambia un panel roto por uno nuevo. Cuesta energía (reparación del documento).
func replace_panel(i: int) -> bool:
	if not panels[i].broken or not spend(rules.energy.panel_repair_cost):
		return false
	panels[i].broken = false
	panels[i].dirt = 0.0  # el panel nuevo llega limpio
	panels_changed.emit()
	return true


func repair_cable(k: int) -> void:
	cables[k] = true
	panels_changed.emit()


## Rompe `broken` paneles sanos y corta `cut` cables enteros, al azar.
func _damage_panels(broken: int, cut: int) -> void:
	var ok := range(panel_count()).filter(func(i): return not panels[i].broken)
	ok.shuffle()
	for i in ok.slice(0, broken):
		panels[i].broken = true
	var intact := range(cables.size()).filter(func(k): return cables[k])
	intact.shuffle()
	for k in intact.slice(0, cut):
		cables[k] = false
	panels_changed.emit()


## Daños al terminar una tormenta: paneles y cables, y según su intensidad invernadero y carro.
## (La suciedad no va aquí: se suma hora a hora mientras dura, en _on_hour.)
func _storm_damage(rule: Dictionary) -> void:
	_damage_panels(int(rule.broken_panels), int(rule.cut_cables))
	var damages: Array = rule.get("damages", [])
	if "greenhouse" in damages:
		crops.damaged = true
		crops_changed.emit()
	if "rover" in damages:
		expedition.damaged = true
		expedition_changed.emit()


# ---------------------------------------------------------------- tormentas

func storm_active() -> bool:
	return storm.get("active", false)


func storm_rule() -> Dictionary:
	return rules.storms.types.get(storm.get("type", ""), {})


## Durante una tormenta moderada o intensa no se puede salir de la estación.
func is_lockdown() -> bool:
	return storm_active() and storm_rule().get("lockdown", false)


## Texto corto para el HUD ("" si no hay tormenta).
func storm_text() -> String:
	if storm.is_empty():
		return ""
	var kind: String = storm_rule().name
	if storm.active:
		return "%s dust storm  ·  %d h left" % [kind, ceili(storm.ends_at - hours)]
	return "%s dust storm in %d h" % [kind, ceili(storm.starts_at - hours)]


## Programa una tormenta (tipo al azar según su probabilidad si no se indica).
## `in_hours` < 0: con el aviso normal del documento (6 h o un poco más).
func schedule_storm(type := "", in_hours := -1.0) -> void:
	if type == "":
		var roll := randf()
		for t in rules.storms.types:
			roll -= rules.storms.types[t].chance
			type = t
			if roll < 0.0:
				break
	if in_hours < 0.0:
		in_hours = rules.storms.warning_hours + randf_range(0.0, 6.0)
	var rule: Dictionary = rules.storms.types[type]
	storm = {"type": type, "starts_at": hours + in_hours, "ends_at": hours + in_hours + rule.hours, "active": false}
	storm_warning.emit(type, in_hours)
	var extra := " You won't be able to go outside." if rule.lockdown else ""
	notify("Dust storm warning! A %s storm arrives in %d hours.%s" % [rule.name.to_lower(), ceili(in_hours), extra])
	_update_storm()


func _update_storm() -> void:
	if storm.is_empty():
		return
	if not storm.active and hours >= storm.starts_at:
		storm.active = true
		storm_started.emit(storm.type)
		if storm_rule().lockdown:
			notify("The %s storm is here! Going back inside the station." % storm_rule().name.to_lower())
			_send_inside()
		else:
			notify("A light dust storm is here. Solar power is lower.")
	elif storm.active and hours >= storm.ends_at:
		var type: String = storm.type
		var rule := storm_rule()
		storm = {}
		_protected_until = hours + rules.storms.protection_sols * 24.0
		_storm_damage(rule)
		storm_ended.emit(type)
		var text := "The storm is over."
		if int(rule.get("broken_panels", 0)) > 0 or int(rule.get("cut_cables", 0)) > 0:
			text += " Solar panels are dirty and broken: clean them, replace them and fix the cables."
		elif float(rule.get("dirt", 0)) >= 30.0:
			text += " The solar panels are covered in sand: clean them!"
		else:
			text += " The solar panels got a bit dusty."
		var damages: Array = rule.get("damages", [])
		if "rover" in damages:
			text += " Repair the greenhouse and the rover too."
		elif "greenhouse" in damages:
			text += " Repair the greenhouse too."
		notify(text)


## Con encierro: lleva al jugador a la estación (salvo que ya esté dentro, de expedición o en una actividad).
func _send_inside() -> void:
	var scene := get_tree().current_scene
	if scene == null or not activity.is_empty() or expedition.is_away():
		return
	if scene.scene_file_path.begins_with(STATION_SCENES) or scene.scene_file_path.begins_with(PAUSED_SCENES):
		return
	GameState.start_inside(STATION, GameState.BASE_ZONE, "estacion")  # al salir: delante de la estación


## Motivo por el que no se puede entrar a una escena ahora ("" si se puede).
func entry_blocked_reason(scene_path: String) -> String:
	if scene_path.begins_with(STATION_SCENES) and not is_on("auxiliary"):
		return "Auxiliary power is OFF. Turn it on in the Power Room first."
	if scene_path == PANEL_FIELD and is_lockdown():
		return "It's too dangerous to go outside during the storm."
	if scene_path == ICE_DRILL:
		return expedition.extract_blocked_reason()  # ya hay muestra de AP-1 o el taladro está trabajando
	return ""


## Motivo por el que no se puede salir de la estación ahora ("" si se puede).
func exit_blocked_reason() -> String:
	if is_lockdown():
		return "There's a %s dust storm outside. Stay in until it passes." % storm_rule().name.to_lower()
	return ""


## Ráfagas del minijuego de paneles: más seguidas y fuertes con tormenta leve.
func gust_rule() -> Dictionary:
	return rules.gusts.storm if storm_active() else rules.gusts.calm


# ---------------------------------------------------------------- puntuación y final

## Puntuación del documento: P = 10·I + H + (100 − C) + E/10 + F + D. Devuelve cada parte y "total".
func score() -> Dictionary:
	var s := {
		"research": research.percent() * rules.score.research_weight,
		"hunger": crew.hunger,
		"rest": 100.0 - crew.fatigue,
		"energy": battery / rules.score.energy_divisor,
		"fitness": crew.fitness,
		"sols_left": float(sols_left()),
	}
	var total := 0.0
	for k in s:
		total += s[k]
	s.total = roundi(total)
	return s


## Mensaje de A.R.I.A. en pantalla.
func notify(text: String) -> void:
	_hud.say(text)


func _end(reason: String) -> void:
	if over:
		return
	over = true
	end_reason = reason
	if not activity.is_empty():
		_finish_activity()
	get_tree().paused = true  # la escena se congela detrás de la pantalla final (el HUD sigue activo)
	mission_over.emit(reason)
	_hud.show_over(reason, score())


# ---------------------------------------------------------------- atajos de prueba (solo en el editor)
# Ctrl+1 tormenta ya (leve -> moderada -> intensa)   Ctrl+2 +1 hora         Ctrl+3 +1 sol
# Ctrl+4 daños de tormenta intensa                   Ctrl+5 dormir 8 h      Ctrl+6 comer
# Ctrl+7 chequeo médico                              Ctrl+8 ejercicio       Ctrl+9 muestra de AP-1 guardada (probar el laboratorio)
# Ctrl+0 imprime el estado en la consola

var _debug_storm := 0


func _unhandled_key_input(event: InputEvent) -> void:
	# solo desde el editor y con la misión en marcha (en el menú o la intro mandaría al jugador a la estación)
	if not OS.has_feature("editor") or not is_running() or is_busy():
		return
	if not event.pressed or event.echo or not event.ctrl_pressed:
		return
	match event.keycode:
		KEY_1:
			var types: Array = rules.storms.types.keys()
			schedule_storm(types[_debug_storm % types.size()], 0.0)
			_debug_storm += 1
		KEY_2:
			advance_hours(1.0)
		KEY_3:
			advance_hours(24.0)
		KEY_4:
			add_dirt_all(rules.storms.types.intense.dirt)
			_storm_damage(rules.storms.types.intense)
		KEY_5:
			crew.sleep(8)
		KEY_6:
			var why := crew.eat()
			notify(why if why != "" else "Yum! Hunger +%d." % rules.crew.hunger.per_meal)
		KEY_7:
			crew.medical_checkup()
		KEY_8:
			crew.exercise()
		KEY_9:
			research.store(["AP-1"])
			notify("Debug: AP-1 sample stored. Prepare it in the Work Room.")
		KEY_0:
			print(debug_text())


## Estado completo en texto (Ctrl+0 lo imprime). Útil para depurar.
func debug_text() -> String:
	return "%s | battery %.0f (net %.2f) | hunger %.1f fatigue %.1f radiation %.1f fitness %.1f | pantry %d | crops %s %.0f%% | research %.2f%% %s | site %s | task x%.2f" % [
		time_text(), battery, net(), crew.hunger, crew.fatigue, crew.radiation, crew.fitness, pantry_meals,
		("dead" if crops.dead else "growing") if crops.planted else "-", crops.progress() * 100.0, research.percent(),
		research.analysis, expedition.site, task_multiplier("physical")]
