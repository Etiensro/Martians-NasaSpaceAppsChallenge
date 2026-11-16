extends RefCounted
## Datos del final de la misión, compartidos por el HUD (mensaje de Control de Misión) y las escenas
## del regreso (scripts/finales/). Textos en data/mission/endings.json; ver docs/FINALES.md.
##
##   const Final := preload("res://scripts/finales/final.gd")
##   Final.reason()   # textos del motivo actual (Mission.end_reason): mood, title, control, arrival, tip
##   Final.medal()    # medalla según las zonas analizadas: zones, name, color, text
##   Final.fill(t)    # cambia {player} por el nombre

const FILE := "res://data/mission/endings.json"
## Escenas del regreso, en orden.
const WAKE := "res://scenes/finales/despertar.tscn"
const LAUNCH := "res://scenes/finales/despegue.tscn"
const EARTH := "res://scenes/finales/tierra.tscn"

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	return _data


static func reason() -> Dictionary:
	var reasons: Dictionary = data().reasons
	return reasons.get(Mission.end_reason, reasons.complete)


static func mood() -> String:
	return str(reason().mood)


static func zones_done() -> int:
	return Mission.research.analysed.size()


static func medal() -> Dictionary:
	for m in data().medals:
		if zones_done() >= int(m.zones):
			return m
	return data().medals.back()


static func fill(text: String) -> String:
	return text.replace("{player}", GameState.first_name())
