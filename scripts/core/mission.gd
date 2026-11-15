extends Node
## Autoload "Mission": el tiempo y la energía de la misión, que siguen corriendo en todas las
## escenas del juego (no en el menú ni en la intro).
##   - Reloj: 1 minuto real = 1 hora de juego. Sol y hora con sol() / hour_of_day() / time_text().
##   - Batería (EU): generación de los paneles menos el consumo de los sistemas encendidos.
##   - Sistemas: soporte vital y cápsulas (siempre encendidos), invernadero y auxiliares (apagables).
##   - Paneles: 16 paneles con suciedad (0-100) y roturas, y los cables que los unen.
##   - Tormentas: aviso previo, reducción de la energía solar, encierro en la estación y daños.
## Todos los números están en data/mission/rules.json (valores del documento del equipo).
##
## Para otros módulos:
##   Mission.advance_hours(2.0)          # una actividad que dura 2 h (p. ej. el gimnasio)
##   Mission.spend(20)                   # gasto puntual de energía (escáner médico)
##   Mission.set_extra_load("lab", 4)    # consumo extra mientras dure (0 para quitarlo)
##   Mission.is_on("greenhouse")         # ¿está encendido el invernadero?
##   Mission.notify("...")               # mensaje de A.R.I.A. en pantalla

signal hour_passed
signal sol_started(sol: int)
signal storm_warning(type: String, hours_left: float)
signal storm_started(type: String)
signal storm_ended(type: String)
signal systems_changed
signal panels_changed
signal mission_over(reason: String)

const RULES_FILE := "res://data/mission/rules.json"
const Hud := preload("res://scripts/core/mission_hud.gd")
## Escenas donde el reloj está parado (menú e intro).
const PAUSED_SCENES := "res://scenes/intro/"
## Escenas que no se interrumpen al empezar una tormenta fuerte (ya estás dentro, o de expedición).
const STAY_IN_SCENES := ["res://scenes/interiores/estacion_ares1/", "res://scenes/ap8_zone.tscn", "res://scenes/ap9_zone.tscn"]
const PANEL_FIELD := "res://scenes/interiores/paneles_solares/minijuegos/campo_solar/campo_solar.tscn"
const STATION := "res://scenes/interiores/estacion_ares1/estacion_ares1.tscn"

var rules: Dictionary
var hours := 0.0              # horas de juego desde el inicio de la misión
var battery := 0.0            # EU
var systems_on := {}          # id -> bool
var extra_loads := {}         # id -> EU/h
var panels: Array = []        # [{ "dirt": 0..100, "broken": bool }], fila por fila
var cables: Array = []        # bool por tramo: índice = fila * columnas + columna (tramo a la derecha del panel)
var storm := {}               # vacío o { "type", "starts_at", "ends_at", "active" }
var over := false

var _protected_until := 0.0   # sin tormentas hasta esta hora
var _last_hour := 0
var _hud: Hud


func _ready() -> void:
	rules = JSON.parse_string(FileAccess.get_file_as_string(RULES_FILE))
	_hud = Hud.new()
	add_child(_hud)
	reset()


## Empieza una misión nueva (lo llama el menú principal).
func reset() -> void:
	hours = 0.0
	_last_hour = 0
	over = false
	battery = rules.energy.start
	systems_on.clear()
	for id in rules.energy.systems:
		systems_on[id] = true
	extra_loads.clear()
	panels.clear()
	cables.clear()
	for i in panel_count():
		panels.append({"dirt": 0.0, "broken": false})
		cables.append(true)
	storm = {}
	# periodo de protección también al empezar, para aprender a jugar antes de la primera tormenta
	_protected_until = rules.storms.protection_sols * 24.0


# ---------------------------------------------------------------- reloj

func is_running() -> bool:
	var scene := get_tree().current_scene
	return not over and scene != null and not scene.scene_file_path.begins_with(PAUSED_SCENES)


func _process(delta: float) -> void:
	_hud.visible = is_running() or over
	if is_running():
		advance_hours(delta / rules.clock.real_seconds_per_hour)


## Avanza el reloj (y todo lo que depende de él) `h` horas de juego.
func advance_hours(h: float) -> void:
	while h > 0.0 and not over:
		var step := minf(h, 0.25)  # pasos cortos: las tormentas y el cambio de sol ocurren a su hora
		battery = clampf(battery + net() * step, 0.0, rules.energy.capacity)
		hours += step
		h -= step
		while _last_hour < int(hours):
			_last_hour += 1
			_on_hour(_last_hour)
		if battery <= 0.0:
			_end("energy")


func sol() -> int:
	return int(rules.clock.start_sol) + int((rules.clock.start_hour + hours) / 24.0)


func hour_of_day() -> float:
	return fmod(rules.clock.start_hour + hours, 24.0)


func time_text() -> String:
	var h := hour_of_day()
	return "SOL %d  ·  %02d:%02d" % [sol(), int(h), int(fmod(h, 1.0) * 60.0)]


func _on_hour(hour_index: int) -> void:
	hour_passed.emit()
	if (int(rules.clock.start_hour) + hour_index) % 24 == 0:  # medianoche: empieza un sol nuevo
		_on_new_sol()
	_update_storm()


func _on_new_sol() -> void:
	add_dirt_all(rules.panels.dirt_per_sol)
	sol_started.emit(sol())
	if sol() > int(rules.clock.mission_sols):
		_end("complete")
		return
	if storm.is_empty() and hours >= _protected_until and randf() < rules.storms.daily_chance:
		schedule_storm()


# ---------------------------------------------------------------- energía y sistemas

func capacity() -> float:
	return rules.energy.capacity


## EU/h que entran ahora: según la limpieza, cuántos paneles funcionan y si hay tormenta.
func generation() -> float:
	var clean := cleanliness()
	var rate := 0.0
	for tier in rules.energy.generation_by_cleanliness:
		if clean >= tier[0]:
			rate = tier[1]
			break
	rate *= float(working_panels()) / panel_count()
	if storm_active():
		rate *= 1.0 - storm_rule().solar_loss
	return rate


## EU/h que salen ahora: sistemas encendidos + consumos extra (laboratorio...).
func consumption() -> float:
	var total := 0.0
	for id in systems_on:
		if systems_on[id]:
			total += rules.energy.systems[id].eu_per_hour
	for id in extra_loads:
		total += extra_loads[id]
	return total


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


func can_switch(id: String) -> bool:
	return system_rule(id).get("switchable", false)


## Enciende o apaga un sistema. Devuelve false si ese sistema no se puede apagar.
func set_system(id: String, on: bool) -> bool:
	if not can_switch(id):
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


# ---------------------------------------------------------------- paneles

func columns() -> int:
	return int(rules.panels.columns)


func panel_count() -> int:
	return int(rules.panels.columns) * int(rules.panels.rows)


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
	panels_changed.emit()
	return true


func repair_cable(k: int) -> void:
	cables[k] = true
	panels_changed.emit()


func _damage_panels(broken: int, cut: int) -> void:
	add_dirt_all(rules.panels.dirt_per_storm)
	var ok := range(panel_count()).filter(func(i): return not panels[i].broken)
	ok.shuffle()
	for i in ok.slice(0, broken):
		panels[i].broken = true
	var intact := range(cables.size()).filter(func(k): return cables[k])
	intact.shuffle()
	for k in intact.slice(0, cut):
		cables[k] = false
	panels_changed.emit()


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
		_damage_panels(int(rule.broken_panels), int(rule.cut_cables))
		storm_ended.emit(type)
		notify("The storm is over. Check the solar panels: they need cleaning and repairs.")


func _send_inside() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for prefix in STAY_IN_SCENES:
		if scene.scene_file_path.begins_with(prefix):
			return
	GameState.start_inside(STATION, GameState.BASE_ZONE, "estacion")  # al salir: delante de la estación


## Motivo por el que no se puede entrar a una escena ahora ("" si se puede).
func entry_blocked_reason(scene_path: String) -> String:
	if scene_path.begins_with("res://scenes/interiores/estacion_ares1/") and not is_on("auxiliary"):
		return "Auxiliary power is OFF. Turn it on in the Power Room first."
	if scene_path == PANEL_FIELD and is_lockdown():
		return "It's too dangerous to go outside during the storm."
	return ""


## Motivo por el que no se puede salir de la estación ahora ("" si se puede).
func exit_blocked_reason() -> String:
	if is_lockdown():
		return "There's a %s dust storm outside. Stay in until it passes." % storm_rule().name.to_lower()
	return ""


## Ráfagas del minijuego de paneles: más seguidas y fuertes con tormenta leve.
func gust_rule() -> Dictionary:
	return rules.gusts.storm if storm_active() else rules.gusts.calm


# ---------------------------------------------------------------- mensajes y final

## Mensaje de A.R.I.A. en pantalla.
func notify(text: String) -> void:
	_hud.say(text)


func _end(reason: String) -> void:
	if over:
		return
	over = true
	mission_over.emit(reason)
	_hud.show_over(reason)


# ---------------------------------------------------------------- atajos de prueba (solo en el editor)
# Ctrl+1: tormenta ahora (leve -> moderada -> intensa)   Ctrl+2: +1 hora
# Ctrl+3: +1 sol                                         Ctrl+4: daños de tormenta intensa en los paneles

var _debug_storm := 0


func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event.pressed or event.echo or not event.ctrl_pressed:
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
			var r: Dictionary = rules.storms.types.intense
			_damage_panels(int(r.broken_panels), int(r.cut_cables))
