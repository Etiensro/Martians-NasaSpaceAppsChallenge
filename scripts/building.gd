extends Node2D
## Edificio de la colonia con puerta. Lee su configuración de assets/buildings/colony.json
## (la genera tools/build_colony.py): sprite, posición y puerta.
## Al acercarse a la puerta aparece "E: entrar"; con E se carga su mini mundo (interior).
## El nodo se coloca donde el edificio toca el suelo, para que el personaje pase
## por detrás o por delante según su altura (y_sort).

const COLONY := "res://assets/buildings/colony.json"

@export var building_id := "estacion_principal"
@export var player: Node2D
@export var door_range := 80.0  # px de mundo
## Si está desactivado, la puerta no muestra el aviso ni deja entrar.
@export var doors_enabled := true

var info: Dictionary
var _hint: Label
var _door := Vector2.ZERO


func _ready() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(COLONY))
	info = meta.buildings[building_id]
	var cell: float = meta.cell
	position = Vector2(info.pos[0], info.pos[1])
	_door = Vector2(info.door[0], info.door[1])

	_build_slices(load(info.texture), cell)

	# Texto de la puerta (grande, porque la cámara de la zona está alejada)
	_hint = Label.new()
	_hint.text = "E: entrar · %s" % info.name
	_hint.add_theme_font_size_override("font_size", 48)
	_hint.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.18))
	_hint.add_theme_constant_override("outline_size", 12)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.size = Vector2(900, 70)
	_hint.position = _door - position - Vector2(450, 230)
	_hint.z_index = 100
	_hint.visible = false
	add_child(_hint)


func _process(_delta: float) -> void:
	_hint.visible = doors_enabled and _near_door()


func _unhandled_key_input(event: InputEvent) -> void:
	if doors_enabled and event.pressed and not event.echo and event.keycode == KEY_E and _near_door():
		get_viewport().set_input_as_handled()
		enter()


func _near_door() -> bool:
	return player != null and player.visible and player.position.distance_to(_door) <= door_range


func enter() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs:
		# Para volver justo delante de la puerta al salir
		gs.return_scene = get_tree().current_scene.scene_file_path
		gs.return_position = _door + Vector2(0, 40)
	get_tree().change_scene_to_file(info.interior)


## Profundidad correcta: el edificio se corta en franjas verticales y cada tramo continuo de
## cada franja se ordena (y_sort) por su propio punto más bajo. Así el personaje queda delante
## de un módulo trasero y detrás de uno delantero, aunque sean parte de la misma imagen.
const SLICE := 6        # ancho de cada franja (px de la textura)
const GAP := 2          # filas vacías que separan dos tramos

func _build_slices(tex: Texture2D, cell: float) -> void:
	y_sort_enabled = true
	var img := tex.get_image()
	var w := img.get_width()
	var h := img.get_height()
	var origin := Vector2(-info.size[0] / 2.0, -info.size[1])  # esquina sup. izq. (local)
	for sx in range(0, w, SLICE):
		var sw := mini(SLICE, w - sx)
		# filas con algo opaco en esta franja
		var rows := PackedByteArray(); rows.resize(h)
		for y in h:
			for x in range(sx, sx + sw):
				if img.get_pixel(x, y).a > 0.5:
					rows[y] = 1
					break
		var y := 0
		while y < h:
			if rows[y] == 0:
				y += 1
				continue
			var top := y
			var empty := 0
			while y < h and empty <= GAP:
				empty = 0 if rows[y] == 1 else empty + 1
				y += 1
			var bottom := y - empty  # exclusivo
			_add_slice(tex, Rect2(sx, top, sw, bottom - top), origin, cell)


func _add_slice(tex: Texture2D, region: Rect2, origin: Vector2, cell: float) -> void:
	var holder := Node2D.new()
	# el nodo se coloca en la base del tramo: ese es el punto que usa el y_sort
	holder.position = origin + Vector2(region.position.x, region.end.y) * cell
	var s := Sprite2D.new()
	s.texture = tex
	s.region_enabled = true
	s.region_rect = region
	s.centered = false
	s.scale = Vector2.ONE * cell
	s.position = Vector2(0, -region.size.y * cell)
	holder.add_child(s)
	add_child(holder)
