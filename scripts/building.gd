extends Node2D
## Algo de la colonia con puerta: un edificio o el vehículo. Lo crea colony.gd con su bloque
## de assets/buildings/colony.json (sprite, posición, tamaño, puerta e interior).
## Cerca de la puerta aparece el aviso; con E se usa:
##   - si tiene "interior", se entra a esa escena;
##   - si no, se emite `used` (el vehículo lo usa para irse al mapa).
## El nodo se coloca donde el objeto toca el suelo y se corta en franjas para que el
## personaje pase por detrás o por delante según su altura (y_sort).

signal used

const Style := preload("res://scripts/core/style.gd")
const SLICE := 6  # ancho de cada franja (px de la textura)
const GAP := 2    # filas vacías que separan dos tramos de una franja

var player: Node2D
var info: Dictionary
var door_range := 80.0
var hint_text := ""
var hint_height := 195.0  # a qué altura sobre la puerta va el aviso
var doors_enabled := true

var _hint: Label
var _door := Vector2.ZERO


## Llamar antes de add_child().
func setup(data: Dictionary, cell: float, the_player: Node2D) -> void:
	info = data
	player = the_player
	position = Vector2(info.pos[0], info.pos[1])
	_door = Vector2(info.door[0], info.door[1])
	_build_slices(load(info.texture), cell)


func _ready() -> void:
	if hint_text == "":
		hint_text = "E: enter · %s" % info.get("name", "")
	_hint = Style.world_hint(hint_text, _door - position - Vector2(0, hint_height))
	add_child(_hint)


func _process(_delta: float) -> void:
	_hint.visible = _usable()
	if _hint.visible:  # cerrado ahora (p. ej. sin energía auxiliar): con E, A.R.I.A. explica por qué
		var blocked := Mission.entry_blocked_reason(info.get("interior", ""))
		_hint.text = "LOCKED · E: why?" if blocked != "" else hint_text
		_hint.modulate = Color(1, 0.6, 0.5) if blocked != "" else Color.WHITE


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_E and _usable():
		get_viewport().set_input_as_handled()
		if info.get("interior", "") != "":
			var blocked := Mission.entry_blocked_reason(info.interior)
			if blocked != "":
				Mission.notify(blocked)
				return
			GameState.enter_building(info.interior, _door + Vector2(0, 40))
		else:
			used.emit()


## ¿El jugador está lo bastante cerca para usarlo? (el panel del carro lo usa para aparecer)
func can_use() -> bool:
	return _usable()


func _usable() -> bool:
	return doors_enabled and player != null and player.visible \
		and player.position.distance_to(_door) <= door_range


## Cambia la imagen sin rehacer las franjas (la nueva debe tener el mismo tamaño y silueta).
## colony.gd lo usa para el campo solar según su suciedad.
func set_texture(tex: Texture2D) -> void:
	for holder in get_children():
		for s in holder.get_children():
			if s is Sprite2D:
				s.texture = tex


## Profundidad correcta: la imagen se corta en franjas verticales y cada tramo continuo de
## cada franja se ordena (y_sort) por su propio punto más bajo. Así el personaje queda delante
## de un módulo trasero y detrás de uno delantero, aunque sean parte de la misma imagen.
func _build_slices(tex: Texture2D, cell: float) -> void:
	y_sort_enabled = true
	var img := tex.get_image()
	var w := img.get_width()
	var h := img.get_height()
	var origin := Vector2(-info.size[0] / 2.0, -info.size[1])  # esquina sup. izq. (local)
	for sx in range(0, w, SLICE):
		var sw := mini(SLICE, w - sx)
		# filas con algo opaco en esta franja
		var rows := PackedByteArray()
		rows.resize(h)
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
