extends RefCounted
## Módulo del autoload Mission: la investigación (Mission.research).
## La investigación se divide en tres zonas (AP-1 33.33 %, AP-8 33.33 %, AP-9 33.34 %). Por cada zona:
##   1) extraer una muestra en la zona (24 h, el taladro trabaja solo) -> Mission.expedition.start_extraction()
##   2) llevarla a la base en el carro (1 hueco para muestras)
##   3) analizarla en el laboratorio: 72 h, +4 EU/h mientras dura. El análisis sigue solo mientras el
##      jugador hace otras cosas. La zona solo cuenta cuando el análisis termina.
## El astrofísico investiga y extrae más rápido (GameState "research_speed" / "extraction_speed").
## Números: data/mission/rules.json -> "research".
##
## Uso desde el laboratorio (Work Room):
##   Mission.research.start_analysis()      # analiza la siguiente muestra guardada. "" o el motivo
##   Mission.research.percent()             # investigación completada (0-100)

const LAB_LOAD := "lab"

var stored: Array[String] = []    # muestras en la base esperando análisis (id de zona)
var analysed: Array[String] = []  # zonas ya analizadas (cuentan para la investigación)
var analysis := {}                # {} o {"site", "hours_left", "hours_total"}


func reset() -> void:
	stored.clear()
	analysed.clear()
	analysis = {}
	Mission.set_extra_load(LAB_LOAD, 0.0)


func _r() -> Dictionary:
	return Mission.rules.research


## Porcentaje de investigación completado (0-100).
func percent() -> float:
	var total := 0.0
	for site in analysed:
		total += float(_r().zones.get(site, 0.0))
	return minf(total, 100.0)


func is_analysing() -> bool:
	return not analysis.is_empty()


## Progreso del análisis actual (0-1).
func analysis_progress() -> float:
	if analysis.is_empty():
		return 0.0
	return 1.0 - analysis.hours_left / analysis.hours_total


## Ya hay (o hubo) muestra de esa zona: no hace falta otra.
func has_sample_of(site: String) -> bool:
	return site in stored or site in analysed or analysis.get("site", "") == site \
		or site in Mission.expedition.cargo or Mission.expedition.extraction.get("site", "") == site


func start_blocked_reason() -> String:
	if is_analysing():
		return "The lab is already analysing a sample (%d h left)." % ceili(analysis.hours_left)
	if stored.is_empty():
		return "There are no samples to analyse. Bring one from AP-1, AP-8 or AP-9!"
	return ""


## Empieza a analizar la primera muestra guardada. La duración se fija al empezar (72 h con las
## penalizaciones de la tripulación y la velocidad del rol).
func start_analysis() -> String:
	var reason := start_blocked_reason()
	if reason != "":
		return reason
	var site: String = stored.pop_front()
	var hours := Mission.task_hours(_r().analysis_hours, "research")
	analysis = {"site": site, "hours_left": hours, "hours_total": hours}
	Mission.set_extra_load(LAB_LOAD, _r().lab_eu_per_hour)
	Mission.notify("The lab is analysing the %s sample. It will take %d hours." % [site, ceili(hours)])
	Mission.research_changed.emit()
	return ""


## Guarda en la base las muestras que trae el carro (lo llama Mission.expedition al volver).
func store(samples: Array) -> void:
	for s in samples:
		if not stored.has(s):
			stored.append(s)
	Mission.research_changed.emit()


# ---------------------------------------------------------------- paso del tiempo (lo llama Mission)

func tick(h: float) -> void:
	if analysis.is_empty():
		return
	analysis.hours_left -= h
	if analysis.hours_left <= 0.0:
		var site: String = analysis.site
		analysed.append(site)
		analysis = {}
		Mission.set_extra_load(LAB_LOAD, 0.0)
		Mission.notify("Analysis complete! The %s sample adds %.2f %% to your research (total %d %%)." % [
			site, float(_r().zones.get(site, 0.0)), roundi(percent())])
		Mission.research_changed.emit()
