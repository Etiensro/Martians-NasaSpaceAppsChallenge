extends Node
## Estado global del juego (autoload "GameState").
## - selected_site: qué sitio eligió el jugador en el mapa general.
## - selected_role / role_data / crew: los define la intro (scenes/intro/) al elegir personaje.
## - return_scene / return_position: al entrar a un edificio, para volver delante de su puerta.

## Escena a la que salta la intro al terminar (escena principal de jugabilidad).
## Cámbiala aquí cuando exista la escena de gestión de recursos.
const GAMEPLAY_SCENE := "res://scenes/world_map.tscn"
const ROLES_FILE := "res://data/intro/roles.json"

## Sitio elegido en el mapa general.
var selected_site := "AP-1"

## Al entrar a un edificio se guarda de dónde venías, para volver al salir.
var return_scene := ""
var return_position := Vector2.INF

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


## Sprites de cada tripulante (mismas animaciones que el astronauta: idle_*, walk_*, celebrate).
const ROLE_FRAMES := {
	"engineer": "res://assets/characters/ingeniero_frames.tres",
	"biologist": "res://assets/characters/biologo_frames.tres",
	"medic": "res://assets/characters/medico_frames.tres",
	"astrophysicist": "res://assets/characters/astrofisico_frames.tres",
}
const DEFAULT_FRAMES := "res://assets/characters/astronaut_frames.tres"


## SpriteFrames de un rol (o del rol elegido si no se indica). Si no hay, el astronauta genérico.
func frames_for(role_id := "") -> SpriteFrames:
	var id := role_id if role_id != "" else selected_role
	return load(ROLE_FRAMES.get(id, DEFAULT_FRAMES))


## Retrato de un rol (sin casco o con casco), o null si no existe.
func portrait_for(role_id: String, helmet := false) -> Texture2D:
	var path := "res://assets/characters/portraits/%s%s.png" % [role_id, "_helmet" if helmet else ""]
	return load(path) if ResourceLoader.exists(path) else null


## Multiplicador de una ventaja del rol elegido (1.0 si no aplica).
## Ej.: GameState.modifier("repair_speed") -> 1.5 para el Ingeniero.
func modifier(key: String) -> float:
	return float(role_data.get("modifiers", {}).get(key, 1.0))
