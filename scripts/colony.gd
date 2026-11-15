extends Node2D
## Colonia de AP-1: coloca los edificios, el vehículo y todos los efectos
## (luces, destellos de los paneles, viento con polvo, humo, vapor y rociadores).
## Lee assets/buildings/colony.json (lo genera tools/build_colony.py).

const COLONY := "res://assets/buildings/colony.json"
const BUILDING := preload("res://scripts/building.gd")
const GLOW := preload("res://assets/fx/glow.png")
const GLINT := preload("res://assets/fx/glint.png")
const DUST := preload("res://assets/fx/dust.png")
const STREAK := preload("res://assets/fx/streak.png")
const PUFF := preload("res://assets/fx/puff.png")

@export var player: Node2D
## Si está activado, se entra a los edificios con E (y al vehículo, que lleva al mapa general).
@export var doors_enabled := true
@export var wind := Vector2(1.0, 0.12)  # dirección del viento

const WORLD_MAP := "res://scenes/world_map.tscn"

var meta: Dictionary
var _glints: Array = []
var _vehicle_door := Vector2.INF
var _vehicle_hint: Label
var _add_mat := CanvasItemMaterial.new()


func _ready() -> void:
	y_sort_enabled = true
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	meta = JSON.parse_string(FileAccess.get_file_as_string(COLONY))
	for id in meta.buildings:
		var b := BUILDING.new()
		b.building_id = id
		b.player = player
		b.doors_enabled = doors_enabled and meta.buildings[id].get("enterable", true)
		add_child(b)
		for f in meta.buildings[id].fx:
			_add_fx(f)
		_glints += meta.buildings[id].get("glints", [])
	_add_vehicle()
	_add_wind()
	_add_vignette()
	if not _glints.is_empty():
		_glint_loop()


## Punto de aparición del personaje (frente a la estación principal).
func spawn_point() -> Vector2:
	return Vector2(meta.spawn[0], meta.spawn[1])


func _add_vehicle() -> void:
	var v: Dictionary = meta.vehicle
	var s := Sprite2D.new()
	s.texture = load(v.texture)
	s.centered = false
	s.scale = Vector2.ONE * meta.cell
	s.position = Vector2(-v.size[0] / 2.0, -v.size[1])
	var node := Node2D.new()
	node.name = "Vehiculo"
	node.position = Vector2(v.pos[0], v.pos[1])
	node.add_child(s)
	add_child(node)
	_vehicle_door = Vector2(v.door[0], v.door[1])
	_vehicle_hint = Label.new()
	_vehicle_hint.text = "E: subir al vehículo (mapa)"
	_vehicle_hint.add_theme_font_size_override("font_size", 48)
	_vehicle_hint.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.18))
	_vehicle_hint.add_theme_constant_override("outline_size", 12)
	_vehicle_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vehicle_hint.size = Vector2(900, 70)
	_vehicle_hint.position = Vector2(-450, -v.size[1] - 90)
	_vehicle_hint.z_index = 100
	_vehicle_hint.visible = false
	node.add_child(_vehicle_hint)
	# faros encendidos, parpadeo suave
	_light(node.position + Vector2(-v.size[0] * 0.18, -v.size[1] * 0.32), Color("fff07a"), 1.6, "pulse", 2.5)


# ---------------------------------------------------------------- luces

func _light(at: Vector2, color: Color, size: float, mode: String, period: float) -> Sprite2D:
	var g := Sprite2D.new()
	g.texture = GLOW
	g.material = _add_mat
	g.modulate = color
	g.position = at
	g.scale = Vector2.ONE * size
	g.z_index = 50
	# punto central brillante
	var core := Sprite2D.new()
	core.texture = GLOW
	core.material = _add_mat
	core.scale = Vector2.ONE * 0.22
	core.modulate = Color(1, 1, 1, 0.9)
	g.add_child(core)
	add_child(g)
	var tw := create_tween().set_loops()
	match mode:
		"blink":  # encendido/apagado
			tw.tween_property(g, "modulate:a", 0.05, 0.05).set_delay(period * 0.5)
			tw.tween_property(g, "modulate:a", 1.0, 0.05).set_delay(period * 0.5)
		"beacon":  # destello fuerte y rápido, como baliza
			tw.tween_property(g, "scale", Vector2.ONE * size * 1.8, 0.12)
			tw.tween_property(g, "scale", Vector2.ONE * size * 0.6, 0.5)
			tw.tween_interval(period - 0.62)
		_:  # pulso suave
			tw.tween_property(g, "modulate:a", 0.45, period * 0.5).set_trans(Tween.TRANS_SINE)
			tw.tween_property(g, "modulate:a", 1.0, period * 0.5).set_trans(Tween.TRANS_SINE)
	return g


func _add_fx(f: Dictionary) -> void:
	var at := Vector2(f.at[0], f.at[1])
	match f.type:
		"beacon":
			_light(at, Color(f.color), 2.2, "beacon", 1.2)
		"blink":
			_light(at, Color(f.color), 1.4, "blink", f.get("period", 1.5))
		"door_light":
			_light(at, Color(f.color), 2.2, "pulse", 2.0)
		"glow":
			var g := _light(at, Color(f.color, 0.7), f.get("size", 5.0) * 1.4, "pulse", 3.5)
			g.get_child(0).visible = false
		"smoke":
			_puffs(at, Color(0.78, 0.74, 0.72, 0.55), Vector2(0, -1), 9, 4.0, 40.0)
		"steam":
			_puffs(at, Color(1, 1, 1, 0.5), Vector2(0, -1), 7, 2.5, 55.0)
		"mist":
			_mist(at)
		"ice":
			_ice(at)


# ---------------------------------------------------------------- partículas

func _puffs(at: Vector2, color: Color, dir: Vector2, amount: int, life: float, speed: float) -> void:
	var p := CPUParticles2D.new()
	p.texture = PUFF
	p.position = at
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.direction = dir
	p.spread = 12
	p.initial_velocity_min = speed * 0.7
	p.initial_velocity_max = speed
	p.gravity = wind * 25.0  # el viento se lleva el humo
	p.scale_amount_min = 1.5
	p.scale_amount_max = 2.5
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6)); curve.add_point(Vector2(1, 3.0))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, color); grad.set_color(1, Color(color, 0.0))
	p.color_ramp = grad
	p.z_index = 40
	add_child(p)


func _mist(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.texture = DUST
	p.position = at
	p.amount = 40
	p.lifetime = 0.9
	p.preprocess = 1.0
	p.direction = Vector2(1, -0.6)
	p.spread = 25
	p.initial_velocity_min = 40
	p.initial_velocity_max = 90
	p.gravity = Vector2(0, 90)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.5
	var grad := Gradient.new()
	grad.set_color(0, Color(0.75, 0.92, 1.0, 0.95)); grad.set_color(1, Color(0.75, 0.92, 1.0, 0.0))
	p.color_ramp = grad
	p.z_index = 40
	add_child(p)


func _ice(at: Vector2) -> void:
	# trocitos de hielo saltando del taladro + brillo azul
	var p := CPUParticles2D.new()
	p.texture = DUST
	p.position = at
	p.amount = 18
	p.lifetime = 0.8
	p.preprocess = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 60
	p.initial_velocity_min = 60
	p.initial_velocity_max = 130
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	var grad := Gradient.new()
	grad.set_color(0, Color(0.8, 0.96, 1.0, 1.0)); grad.set_color(1, Color(0.55, 0.85, 1.0, 0.0))
	p.color_ramp = grad
	p.z_index = 40
	add_child(p)
	var g := _light(at, Color("7fe6ff", 0.6), 2.2, "pulse", 0.6)
	g.get_child(0).visible = false


func _near_vehicle() -> bool:
	return doors_enabled and player != null and player.visible and _vehicle_door != Vector2.INF 		and player.position.distance_to(_vehicle_door) <= 90.0


func _process(_delta: float) -> void:
	if _vehicle_hint:
		_vehicle_hint.visible = _near_vehicle()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_E and _near_vehicle():
		get_viewport().set_input_as_handled()
		_drive_away()


## El astronauta sube al vehículo (vacío), arranca y sale por la izquierda; luego el mapa general.
func _drive_away() -> void:
	set_process(false)
	_vehicle_hint.visible = false
	player.hide()
	player.set_process(false)
	var car: Node2D = get_node("Vehiculo")
	var tw := create_tween()
	tw.tween_property(car, "position:y", car.position.y - 6, 0.08)  # pequeño salto al arrancar
	tw.tween_property(car, "position:y", car.position.y, 0.08)
	tw.tween_property(car, "position:x", -400.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_puffs(car.position + Vector2(60, -10), Color(0.85, 0.62, 0.48, 0.6), Vector2(1, -0.3), 12, 1.2, 60.0)
	await tw.finished
	get_tree().change_scene_to_file(WORLD_MAP)


func _add_wind() -> void:
	var view := Rect2(0, 0, 4200, 2300)  # cubre toda la zona
	for layer in [[DUST, 280, 4.0, 7.0, Color(0.9, 0.66, 0.5, 0.8), 170.0], [STREAK, 45, 6.0, 9.0, Color(1, 0.88, 0.74, 0.35), 340.0], [PUFF, 6, 30.0, 45.0, Color(0.85, 0.6, 0.45, 0.10), 260.0]]:
		var p := CPUParticles2D.new()
		p.texture = layer[0]
		p.amount = layer[1]
		p.lifetime = view.size.x / layer[5]
		p.preprocess = p.lifetime
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(10, view.size.y / 2)
		p.position = Vector2(-60, view.size.y / 2)
		p.direction = wind
		p.spread = 4
		p.gravity = Vector2.ZERO
		p.initial_velocity_min = layer[5] * 0.7
		p.initial_velocity_max = layer[5] * 1.3
		p.scale_amount_min = layer[2]
		p.scale_amount_max = layer[3]
		p.color = layer[4]
		p.z_index = 60
		add_child(p)


# ---------------------------------------------------------------- destellos de los paneles

func _glint_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(0.08, 0.3)).timeout
		var pt: Array = _glints.pick_random()
		var s := Sprite2D.new()
		s.texture = GLINT
		s.material = _add_mat
		s.position = Vector2(pt[0], pt[1])
		s.modulate = Color(0.85, 0.95, 1.0)
		s.scale = Vector2.ZERO
		s.z_index = 55
		add_child(s)
		var big := randf_range(5.0, 9.0)
		var tw := create_tween()
		tw.tween_property(s, "scale", Vector2.ONE * big, 0.18)
		tw.parallel().tween_property(s, "rotation", 0.5, 0.45)
		tw.tween_property(s, "scale", Vector2.ZERO, 0.3)
		tw.tween_callback(s.queue_free)


# ---------------------------------------------------------------- viñeta (bordes un poco más oscuros: da profundidad)

func _add_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 1.05)
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0)); grad.set_color(1, Color(0.12, 0.03, 0.02, 0.55))
	grad.add_point(0.6, Color(0, 0, 0, 0))
	tex.gradient = grad
	var rect := TextureRect.new()
	rect.texture = tex
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	add_child(layer)
