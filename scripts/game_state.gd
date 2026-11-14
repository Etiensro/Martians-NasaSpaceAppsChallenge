extends Node
## Estado global del juego (autoload "GameState").
## - selected_site: qué sitio eligió el jugador en el mapa general.
## - selected_role / role_data / crew: los define la intro (scenes/intro/) al elegir personaje.

## Escena a la que salta la intro al terminar (escena principal de jugabilidad).
## Cámbiala aquí cuando exista la escena de gestión de recursos.
const GAMEPLAY_SCENE := "res://scenes/world_map.tscn"
const ROLES_FILE := "res://data/intro/roles.json"

var selected_site := "AP-1"

## Id del rol elegido: "engineer", "biologist", "medic" o "astrophysicist" ("" = sin elegir).
var selected_role := ""
## Datos completos del rol elegido (copiados de roles.json): title, crew_name, perks, modifiers...
var role_data: Dictionary = {}
## Tripulación: [{ "role": "medic", "name": "Lena Lindqvist", "state": "awake" | "cryo" }, ...]
var crew: Array[Dictionary] = []


## Carga roles.json (lo usan la intro y, si quiere, la jugabilidad).
func load_roles() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(ROLES_FILE))
	return parsed if parsed is Dictionary else {}


## Guarda la elección del jugador: el rol elegido queda despierto, los demás en criosueño.
func choose_role(role_id: String) -> void:
	var data := load_roles()
	var roles: Dictionary = data.get("roles", {})
	selected_role = role_id
	role_data = roles.get(role_id, {})
	crew.clear()
	for id in data.get("order", roles.keys()):
		crew.append({
			"role": id,
			"name": roles[id].get("crew_name", id),
			"state": "awake" if id == role_id else "cryo",
		})


## Multiplicador de una ventaja del rol elegido (1.0 si no aplica).
## Ej.: GameState.modifier("repair_speed") -> 1.5 para el Ingeniero.
func modifier(key: String) -> float:
	return float(role_data.get("modifiers", {}).get(key, 1.0))
