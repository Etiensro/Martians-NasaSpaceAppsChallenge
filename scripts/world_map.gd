extends Node2D
## Mapa general de Arcadia Planitia: selección de sitio (AP-1, AP-8, AP-9).
## Los recursos los genera tools/build_world_map.py (assets/world/).
## Pasar el ratón por un sitio lo resalta y muestra su descripción; clic para ir a ese sitio.
## El astronauta aparece junto al sitio donde está el jugador y camina hasta el elegido.

const Movement := preload("res://scripts/core/movement.gd")
const Style := preload("res://scripts/core/style.gd")
const SITES_FILE := "res://assets/world/world_sites.json"
const ASTRO_SCALE := 0.6
const WALK_SPEED := 350.0  # px/s al caminar por el mapa

@onready var background: Sprite2D = $Fondo
@onready var markers: Node2D = $Marcadores
@onready var camera: Camera2D = $Camera2D
@onready var info: Label = $HUD/Panel/Info

var meta: Dictionary
var px_scale := 4.0
var title_scale := 2.0
var _hovered := ""
var _nodes := {}     # id -> {root, rect, stand}
var _astro: AnimatedSprite2D
var _travelling := false


func _ready() -> void:
	meta = JSON.parse_string(FileAccess.get_file_as_string(SITES_FILE))
	px_scale = meta.scale
	title_scale = meta.get("title_scale", px_scale)
	background.scale = Vector2.ONE * px_scale
	for id in meta.sites:
		_build_marker(id, meta.sites[id])
	_build_astronaut()
	_fit_camera()
	get_viewport().size_changed.connect(_fit_camera)
	_set_info("")


func _build_marker(id: String, s: Dictionary) -> void:
	var root := Node2D.new()
	root.name = id
	root.position = Vector2(s.x, s.y) * px_scale
	markers.add_child(root)

	# Los iconos dibujados a mano van a x4 (como el mapa); los de Gemini traen su propio detalle (x1)
	var icon_scale: float = s.get("icon_scale", px_scale)
	var icon := Sprite2D.new()
	icon.texture = load("res://assets/world/icon_%s.png" % id)
	icon.scale = Vector2.ONE * icon_scale
	icon.offset = Vector2(0, -icon.texture.get_height() / 2.0)  # apoyado en el punto
	root.add_child(icon)
	var icon_size: Vector2 = icon.texture.get_size() * icon_scale

	var title := Sprite2D.new()
	title.texture = load("res://assets/world/title_%s.png" % id)
	title.scale = Vector2.ONE * title_scale
	var title_h := title.texture.get_height() * title_scale
	var below: bool = s.get("label", "above") == "below"
	if below:  # título debajo del icono (cuando arriba no cabe en el mapa)
		title.position = Vector2(0, title_h / 2.0 + 3 * px_scale)
	else:
		title.position = Vector2(0, -icon_size.y - title_h / 2.0)
	root.add_child(title)

	# El icono flota suavemente
	var tw := create_tween().set_loops()
	tw.tween_property(icon, "position:y", -px_scale * 1.5, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(icon, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_SINE)

	# Zona de clic: icono + título
	var w := maxf(icon_size.x, title.texture.get_width() * title_scale)
	var h := icon_size.y + title_h
	var top := -icon_size.y if below else -h
	# "stand": dónde se para el astronauta (a la izquierda del icono, a ras de suelo)
	_nodes[id] = {"root": root, "rect": Rect2(-w / 2, top, w, h + px_scale * 3),
		"stand": root.position + Vector2(-icon_size.x / 2 - 14, 4)}


## Astronauta en el sitio actual, con una flecha que rebota encima.
func _build_astronaut() -> void:
	var current := GameState.selected_site if _nodes.has(GameState.selected_site) else str(_nodes.keys()[0])
	_astro = AnimatedSprite2D.new()
	_astro.sprite_frames = GameState.frames_for()
	_astro.scale = Vector2.ONE * ASTRO_SCALE
	_astro.offset = Vector2(0, -47)  # pies en el punto
	_astro.position = _nodes[current].stand
	_astro.z_index = 5
	_astro.play("idle_down")
	add_child(_astro)

	var arrow := Node2D.new()
	arrow.position = Vector2(0, -105)
	var corners := PackedVector2Array([Vector2(-9, -8), Vector2(9, -8), Vector2(0, 4)])
	var tri := Polygon2D.new()
	tri.polygon = corners
	tri.color = Style.AMBER
	var outline := Line2D.new()
	outline.points = corners + PackedVector2Array([corners[0]])
	outline.width = 3
	outline.default_color = Style.NAVY
	arrow.add_child(tri)
	arrow.add_child(outline)
	_astro.add_child(arrow)
	var tw := create_tween().set_loops()
	tw.tween_property(arrow, "position:y", -115.0, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(arrow, "position:y", -105.0, 0.4).set_trans(Tween.TRANS_SINE)


func _unhandled_input(event: InputEvent) -> void:
	if _travelling:
		return
	if event is InputEventMouseMotion:
		_update_hover(get_global_mouse_position())
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_update_hover(get_global_mouse_position())
		if _hovered != "":
			_go_to(_hovered)


func _update_hover(point: Vector2) -> void:
	var found := ""
	for id in _nodes:
		var n: Dictionary = _nodes[id]
		if n.rect.has_point(n.root.to_local(point)):
			found = id
	if found == _hovered:
		return
	if _hovered != "":
		_scale_marker(_hovered, 1.0)
	_hovered = found
	if found != "":
		_scale_marker(found, 1.15)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if found != "" else Input.CURSOR_ARROW)
	_set_info(found)


func _scale_marker(id: String, s: float) -> void:
	create_tween().tween_property(_nodes[id].root, "scale", Vector2.ONE * s, 0.12)


func _set_info(id: String) -> void:
	if id == "":
		info.text = "ARCADIA PLANITIA, MARS  ·  Choose a site to explore"
	else:
		var s: Dictionary = meta.sites[id]
		info.text = "%s  ·  %s  —  %s   (click to go)" % [s.title, s.subtitle, s.description]


## El astronauta camina hasta el sitio elegido, celebra y se carga la zona.
func _go_to(id: String) -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_travelling = true
	var target: Vector2 = _nodes[id].stand
	if _astro.position.distance_to(target) > 4:
		await Movement.walk_to(_astro, target, WALK_SPEED).finished
		_astro.flip_h = false
		_astro.play("celebrate")
		await get_tree().create_timer(0.35).timeout
	GameState.selected_site = id
	SceneChanger.go_to(GameState.site_scene(id))


func _fit_camera() -> void:
	var size: Vector2 = background.texture.get_size() * px_scale
	var vp := get_viewport_rect().size
	var z := maxf(vp.x / size.x, vp.y / size.y)  # cubrir toda la pantalla, sin franjas
	camera.zoom = Vector2(z, z)
	camera.position = size / 2
