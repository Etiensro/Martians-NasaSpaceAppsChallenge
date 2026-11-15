extends Node
## Autoload "GameState": todo lo que tiene que sobrevivir a un cambio de escena.
##   - Tripulación y rol elegido en la intro (data/intro/roles.json)
##   - Sitio elegido en el mapa general
##   - A qué puerta volver al salir de un edificio
## Los cambios de escena se hacen con el autoload SceneChanger.

# ---------------------------------------------------------------- escenas

const WORLD_MAP := "res://scenes/world_map.tscn"
const BASE_ZONE := "res://scenes/ap1_zone.tscn"
## Escena a la que salta la intro al terminar. Cámbiala cuando exista la de gestión de recursos.
const GAMEPLAY_SCENE := BASE_ZONE  # al terminar la intro se aparece directo en AP-1


## Escena de un sitio del mapa: "AP-8" -> res://scenes/ap8_zone.tscn
func site_scene(site_id: String) -> String:
	return "res://scenes/%s_zone.tscn" % site_id.replace("-", "").to_lower()


# ---------------------------------------------------------------- tripulación

const ROLES_FILE := "res://data/intro/roles.json"
const PORTRAITS := "res://assets/characters/portraits/%s%s.png"  # rol, "" o "_helmet"
## Sprites de cada tripulante (mismas animaciones: idle_*, walk_*, celebrate).
## Con casco (afuera) y sin casco (dentro de la base, en la intro): <id>_frames.tres / <id>_sin_casco_frames.tres
const ROLE_FRAMES := {
	"engineer": "res://assets/characters/ingeniero_frames.tres",
	"biologist": "res://assets/characters/biologo_frames.tres",
	"medic": "res://assets/characters/medico_frames.tres",
	"astrophysicist": "res://assets/characters/astrofisico_frames.tres",
}
const DEFAULT_FRAMES := "res://assets/characters/astronaut_frames.tres"

## Datos de roles.json: id -> {title, crew_name, color, perks, fact, modifiers}
var roles: Dictionary = {}
## Orden de los roles en la pantalla de selección.
var role_order: Array = []

## Id del rol elegido ("" = todavía sin elegir).
var selected_role := ""
## Datos del rol elegido (un elemento de `roles`).
var role_data: Dictionary = {}
## Tripulación: [{ "role": "medic", "name": "...", "state": "awake" | "cryo" }, ...]
var crew: Array[Dictionary] = []

## Sitio elegido en el mapa general.
var selected_site := "AP-1"


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ROLES_FILE))
	if data is Dictionary:
		roles = data.get("roles", {})
		role_order = data.get("order", roles.keys())
	else:
		push_error("No se pudo leer %s (¿JSON mal escrito?)" % ROLES_FILE)


## Guarda la elección del jugador: el rol elegido queda despierto, los demás en criosueño.
func choose_role(role_id: String) -> void:
	selected_role = role_id
	role_data = roles.get(role_id, {})
	crew.clear()
	for id in role_order:
		crew.append({
			"role": id,
			"name": roles[id].get("crew_name", id),
			"state": "awake" if id == role_id else "cryo",
		})


func role_color(role_id: String) -> Color:
	return Color.html(roles.get(role_id, {}).get("color", "#ffffff"))


## Nombre de pila de un tripulante (o del jugador si no se indica).
func first_name(role_id := "") -> String:
	var id := role_id if role_id != "" else selected_role
	return str(roles.get(id, {}).get("crew_name", "Commander")).get_slice(" ", 0)


## SpriteFrames de un rol (o del rol elegido si no se indica). Si no hay, el astronauta genérico.
## helmet = false: la versión sin casco (si existe).
func frames_for(role_id := "", helmet := true) -> SpriteFrames:
	var id := role_id if role_id != "" else selected_role
	var path: String = ROLE_FRAMES.get(id, DEFAULT_FRAMES)
	if not helmet:
		var bare := path.replace("_frames.tres", "_sin_casco_frames.tres")
		if ResourceLoader.exists(bare):
			path = bare
	return load(path)


## Retrato de un rol (sin casco o con casco), o null si no existe.
func portrait_for(role_id: String, helmet := false) -> Texture2D:
	var path := PORTRAITS % [role_id, "_helmet" if helmet else ""]
	return load(path) if ResourceLoader.exists(path) else null


## Multiplicador de una ventaja del rol elegido (1.0 si no aplica).
## Ej.: GameState.modifier("repair_speed") -> 1.5 para el Ingeniero.
func modifier(key: String) -> float:
	return float(role_data.get("modifiers", {}).get(key, 1.0))


# ---------------------------------------------------------------- edificios

## Al entrar a un edificio se guarda de dónde venías, para volver delante de su puerta.
var _return_scene := ""
var _return_position := Vector2.INF


## Entra a un interior y recuerda dónde dejar al jugador al salir.
func enter_building(interior_scene: String, door_position: Vector2) -> void:
	_return_scene = get_tree().current_scene.scene_file_path
	_return_position = door_position
	SceneChanger.go_to(interior_scene)


## Sale del interior a la zona por la que se entró (o a la base si no se sabe).
func leave_building() -> void:
	SceneChanger.go_to(_return_scene if _return_scene != "" else BASE_ZONE)


## La usa la zona al cargarse: si venimos de un edificio suyo, devuelve dónde aparecer
## (delante de la puerta) y lo olvida. Si no, devuelve Vector2.INF.
func take_return_position(zone_scene: String) -> Vector2:
	if zone_scene != _return_scene:
		return Vector2.INF
	var p := _return_position
	_return_scene = ""
	_return_position = Vector2.INF
	return p
