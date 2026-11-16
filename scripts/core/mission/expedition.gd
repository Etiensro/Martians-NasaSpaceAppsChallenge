extends RefCounted
## Módulo del autoload Mission: el carro explorador y las expediciones a AP-8 y AP-9 (Mission.expedition).
## Antes de salir de AP-1 hay que tener (departure_problems):
##   - el carro inspeccionado (2 h) y con mantenimiento (2 h), y reparado si una tormenta intensa lo dañó (4 h);
##   - la comida la decide el jugador (máximo 6 en el carro; prepararla 1 h). meals_needed() solo es
##     la cantidad recomendada (3 por sol de viaje): si se lleva menos, se pasa hambre durante la expedición;
##   - energía suficiente para que la base aguante la ausencia;
##   - hueco para la muestra y ninguna tormenta activa.
## Viajes (a 10 km/h): AP-8 6 h 30 min, AP-9 6 h (ida; la vuelta igual). Durante el viaje se está fuera
## (radiación +4/h). En la zona: limpiar sus paneles y poner el taladro a extraer la muestra (24 h). El
## taladro trabaja solo (como el laboratorio): mientras, el jugador puede dormir y comer en la mini base.
## No se puede volver hasta que termine la extracción.
## Al volver a AP-1 la muestra pasa al laboratorio (Mission.research) y la comida que sobra a la despensa.
## Números: data/mission/rules.json -> "expeditions".
##
## Uso:
##   Mission.expedition.travel_blocked_reason("AP-8")  # "" o el motivo (el mapa general lo enseña)
##   await Mission.expedition.travel("AP-8")           # adelanta el reloj del viaje (luego cambiar de escena)
##   await Mission.expedition.inspect() / maintain() / repair() / load_meals(5)
##   Mission.expedition.start_extraction()             # en la zona (o en AP-1 para su muestra)
##   Mission.expedition.mark_zone_panels_clean()       # lo llama el minijuego de paneles de la zona

var site := "AP-1"               # dónde están el jugador y el carro
var meals_loaded := 0
var cargo: Array[String] = []    # muestras en el carro
var inspected := false
var maintained := false
var damaged := false             # tormenta intensa: hay que repararlo antes de salir
var extracted_here := false      # ya se extrajo la muestra en la zona actual
var zone_panels_clean := false   # paneles de la mini base de la zona limpios (para poder extraer)
var extraction := {}             # taladro trabajando: {} o {"site", "hours_left", "hours_total"}


func reset() -> void:
	site = home()
	meals_loaded = 0
	cargo.clear()
	inspected = false
	maintained = false
	damaged = false
	extracted_here = false
	zone_panels_clean = false
	extraction = {}


func _r() -> Dictionary:
	return Mission.rules.expeditions


func home() -> String:
	return _r().home


func is_away() -> bool:
	return site != home()


## Horas de viaje entre dos sitios (entre dos zonas se pasa por la base).
func travel_hours(from: String, to: String) -> float:
	if from == to:
		return 0.0
	return float(_r().travel_hours.get(from, 0.0)) + float(_r().travel_hours.get(to, 0.0))


## Horas totales de una expedición desde la base: ida + extracción + vuelta.
func trip_hours(dest: String) -> float:
	return travel_hours(home(), dest) * 2.0 + Mission.task_hours(Mission.rules.research.extraction_hours, "excavation")


## Comidas recomendadas para toda la expedición (3 por sol, como mucho las que caben en el carro).
## Es solo una recomendación: no impide salir.
func meals_needed(dest: String) -> int:
	return mini(ceili(trip_hours(dest) / 24.0 * _r().meals_per_sol), _r().max_meals)


## Lista de lo que falta para salir de la base hacia `dest` (vacía si se puede salir).
func departure_problems(dest: String) -> Array[String]:
	var out: Array[String] = []
	if Mission.storm_active():
		out.append("There's a dust storm. Wait until it passes.")
	if damaged:
		out.append("The rover was damaged by the storm: repair it first.")
	if not inspected:
		out.append("Inspect the rover first (2 h).")
	elif not maintained:
		out.append("Do the rover's maintenance first (2 h).")
	var net := Mission.net()
	if net < 0.0 and Mission.battery + net * trip_hours(dest) <= 0.0:
		out.append("The battery won't last while you're away. Save energy or clean the panels.")
	if cargo.size() >= _r().sample_slots:
		out.append("The rover is full: bring the sample to the lab first.")
	if Mission.research.has_sample_of(dest):
		out.append("You already have the %s sample." % dest)
	return out


## Motivo por el que no se puede viajar ahora de `site` a `dest` ("" si se puede).
func travel_blocked_reason(dest: String) -> String:
	if dest == site:
		return ""
	if Mission.is_lockdown():
		return Mission.exit_blocked_reason()
	if not extraction.is_empty():
		return "The drill is still working (%d h left). Wait for the sample!" % ceili(extraction.hours_left)
	if is_away() and not extracted_here:
		return "You can't go back until the sample extraction is finished."
	if not is_away():
		var problems := departure_problems(dest)
		if not problems.is_empty():
			return problems[0]
	return ""


## Viaja a `dest`: el reloj avanza las horas del viaje (fuera de la base). Corrutina; después la
## escena que llama cambia a la zona. Devuelve "" o el motivo por el que no se pudo.
func travel(dest: String) -> String:
	if dest == site:  # volver al mismo sitio desde el mapa no es un viaje: no se toca el carro
		return ""
	var reason := travel_blocked_reason(dest)
	if reason != "":
		return reason
	var hours := travel_hours(site, dest)
	await Mission.run_activity("Driving to %s" % dest, hours, {"location": "outside"})
	if Mission.over:
		return "The mission is over."
	site = dest
	extracted_here = false
	zone_panels_clean = false
	if not is_away():  # de vuelta en la base
		Mission.research.store(cargo)
		cargo.clear()
		Mission.pantry_meals += meals_loaded
		meals_loaded = 0
		inspected = false
		maintained = false
		Mission.notify("Welcome back to Ares 1! Take the sample to the lab to analyse it.")
	Mission.expedition_changed.emit()
	return ""


# ---------------------------------------------------------------- preparación del carro (corrutinas)

func inspect() -> String:
	if is_away():
		return "You can only inspect the rover at the base."
	inspected = true
	Mission.expedition_changed.emit()
	await Mission.run_task("Inspecting the rover", _r().inspection_hours, "maintenance")
	if damaged:
		Mission.notify("The inspection found storm damage. The rover needs a repair.")
	return ""


func maintain() -> String:
	if not inspected:
		return "Inspect the rover first."
	if damaged:
		return "Repair the rover first."
	maintained = true
	Mission.expedition_changed.emit()
	await Mission.run_task("Rover maintenance", _r().maintenance_hours, "maintenance")
	return ""


func repair() -> String:
	if not damaged:
		return "The rover isn't damaged."
	if not Mission.spend(Mission.rules.energy.system_repair_cost):
		return "Not enough energy to repair the rover."
	damaged = false
	Mission.expedition_changed.emit()
	await Mission.run_task("Repairing the rover", _r().repair_hours, "repair")
	return ""


## Carga `meals` comidas de la despensa en el carro (máximo 6). Tarda 1 h.
func load_meals(meals: int) -> String:
	if is_away():
		return "You can only load food at the base."
	meals = clampi(meals, 0, _r().max_meals)
	var extra := meals - meals_loaded
	if extra > Mission.pantry_meals:
		return "There are only %d meals in the pantry." % Mission.pantry_meals
	Mission.pantry_meals -= extra
	meals_loaded = meals
	Mission.expedition_changed.emit()
	await Mission.run_task("Preparing food and supplies", _r().prepare_hours, "general")
	return ""


# ---------------------------------------------------------------- en la zona

func mark_zone_panels_clean() -> void:
	zone_panels_clean = true
	Mission.expedition_changed.emit()


func is_extracting() -> bool:
	return not extraction.is_empty()


## Progreso de la extracción actual (0-1).
func extraction_progress() -> float:
	if extraction.is_empty():
		return 0.0
	return 1.0 - extraction.hours_left / extraction.hours_total


func extract_blocked_reason() -> String:
	if is_extracting():
		return "The drill is already working (%d h left)." % ceili(extraction.hours_left)
	if extracted_here or Mission.research.has_sample_of(site):
		return "You already have the sample from %s." % site
	if is_away() and _r().zone_panels_before_extraction and not zone_panels_clean:
		return "Clean the solar panels of the mini base first: the drill needs their power."
	if is_away() and cargo.size() >= _r().sample_slots:
		return "The rover has no room for another sample."
	return ""


## Pone el taladro a extraer la muestra de la zona actual: 24 h (tarea de excavación, fijada al
## empezar). Trabaja solo; al terminar, la muestra va al carro (o directa al laboratorio en AP-1).
## `already_played_hours`: horas que ya pasaron jugando el minijuego de extracción (se restan).
## Devuelve "" o el motivo.
func start_extraction(already_played_hours := 0.0) -> String:
	var reason := extract_blocked_reason()
	if reason != "":
		return reason
	var hours := maxf(Mission.task_hours(Mission.rules.research.extraction_hours, "excavation") - already_played_hours, 1.0)
	extraction = {"site": site, "hours_left": hours, "hours_total": hours}
	if is_away():
		Mission.notify("The drill is working. The sample will be ready in %d hours: rest in the mini base meanwhile." % ceili(hours))
	else:
		Mission.notify("The drill is working. The AP-1 sample will be ready in %d hours: you can do other tasks meanwhile." % ceili(hours))
	Mission.expedition_changed.emit()
	return ""


# ---------------------------------------------------------------- paso del tiempo (lo llama Mission)

func tick(h: float) -> void:
	if extraction.is_empty():
		return
	extraction.hours_left -= h
	if extraction.hours_left > 0.0:
		return
	var at: String = extraction.site
	extraction = {}
	extracted_here = true
	if at != home():
		cargo.append(at)
		Mission.notify("Sample extracted! Bring it back to Ares 1 to analyse it.")
	else:
		Mission.research.store([at])
		Mission.notify("Sample extracted! Take it to the lab to analyse it.")
	Mission.expedition_changed.emit()
