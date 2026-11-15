extends Node2D
## Mapa general de Arcadia Planitia: selección de sitio (AP-1, AP-8, AP-9).
## Los recursos los genera tools/build_world_map.py.
## Pasar el ratón por un sitio lo resalta y muestra su descripción; clic para ir a ese sitio.
## El astronauta aparece junto al sitio donde está el jugador y camina hasta el sitio elegido.

## Escena de cada sitio
const SITE_SCENES := {
	"AP-1": "res://scenes/ap1_zone.tscn",
	"AP-8": "res://scenes/ap8_zone.tscn",
	"AP-9": "res://scenes/ap9_zone.tscn",
}
const ASTRO_FRAMES := preload("res://assets/characters/astronaut_frames.tres")
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
var _arrow: Node2D
var _travelling := false


func _ready() -> void:
	meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/world_sites.json"))
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

	# Animación: el icono flota suavemente
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


## Astronauta en el sitio actual, con una flecha "TÚ" que rebota encima.
func _build_astronaut() -> void:
	var gs := get_node_or_null("/root/GameState")
	var current: String = gs.selected_site if gs else "AP-1"
	if not _nodes.has(current):
		current = _nodes.keys()[0]
	_astro = AnimatedSprite2D.new()
	_astro.sprite_frames = gs.frames_for() if gs and gs.selected_role != "" else ASTRO_FRAMES
	_astro.scale = Vector2.ONE * ASTRO_SCALE
	_astro.offset = Vector2(0, -47)  # pies en el punto
	_astro.position = _nodes[current].stand
	_astro.z_index = 5
	_astro.play("idle_down")
	add_child(_astro)

	_arrow = Node2D.new()
	_arrow.position = Vector2(0, -105)
	var tri := Polygon2D.new()
	tri.polygon = PackedVector2Array([Vector2(-9, -8), Vector2(9, -8), Vector2(0, 4)])
	tri.color = Color(1, 0.84, 0.27)
	var outline := Line2D.new()
	outline.points = PackedVector2Array([Vector2(-9, -8), Vector2(9, -8), Vector2(0, 4), Vector2(-9, -8)])
	outline.width = 3
	outline.default_color = Color(0.05, 0.07, 0.18)
	_arrow.add_child(tri)
	_arrow.add_child(outline)
	_astro.add_child(_arrow)
	var tw := create_tween().set_loops()
	tw.tween_property(_arrow, "position:y", -115.0, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_arrow, "position:y", -105.0, 0.4).set_trans(Tween.TRANS_SINE)


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
		info.text = "ARCADIA PLANITIA, MARTE  ·  Elige un sitio para explorar"
	else:
		var s: Dictionary = meta.sites[id]
		info.text = "%s  ·  %s  —  %s   (clic para ir)" % [s.title, s.subtitle, s.description]


func _go_to(id: String) -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_travelling = true
	# El astronauta camina hasta el sitio elegido antes de entrar
	var target: Vector2 = _nodes[id].stand
	var delta := target - _astro.position
	if delta.length() > 4:
		if absf(delta.x) > absf(delta.y):
			_astro.play("walk_side")
			_astro.flip_h = delta.x < 0
		else:
			_astro.play("walk_down" if delta.y > 0 else "walk_up")
		var tw := create_tween()
		tw.tween_property(_astro, "position", target, delta.length() / WALK_SPEED)
		await tw.finished
		_astro.flip_h = false
		_astro.play("celebrate")
		await get_tree().create_timer(0.35).timeout
	var gs := get_node_or_null("/root/GameState")
	if gs:
		gs.selected_site = id
	get_tree().change_scene_to_file(SITE_SCENES[id])


func _fit_camera() -> void:
	var size: Vector2 = background.texture.get_size() * px_scale
	var vp := get_viewport_rect().size
	var z := maxf(vp.x / size.x, vp.y / size.y)  # cubrir toda la pantalla, sin franjas
	camera.zoom = Vector2(z, z)
	camera.position = size / 2
