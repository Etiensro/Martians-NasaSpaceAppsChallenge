extends Node2D
## Colonia de AP-1: coloca los edificios y el vehículo (building.gd) y todos los efectos
## (luces, destellos de los paneles, viento con polvo, humo, vapor y rociadores).
## Lee assets/buildings/colony.json (lo genera tools/build_colony.py).

const COLONY := "res://assets/buildings/colony.json"
const Building := preload("res://scripts/building.gd")
const Fx := preload("res://scripts/core/fx.gd")
const SOLAR_ID := "paneles_grande"
const SOLAR_LOOKS := {
	"broken": "res://assets/buildings/paneles_averiados.png",
	"dirt": [  # [limpieza mínima, imagen]
		[90.0, "res://assets/buildings/paneles_grande.png"],
		[70.0, "res://assets/buildings/paneles sucios 1.png"],
		[40.0, "res://assets/buildings/paneles sucios 2.png"],
		[0.0, "res://assets/buildings/paneles sucios 3.png"],
	],
}

@export var player: Node2D
## Si está activado, se entra a los edificios con E (y al vehículo, que lleva al mapa general).
@export var doors_enabled := true
@export var wind := Vector2(1.0, 0.12)  # dirección del viento

var meta: Dictionary
var _glints: Array = []
var _vehicle: Building
var _add_mat := CanvasItemMaterial.new()


func _ready() -> void:
	y_sort_enabled = true
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	meta = JSON.parse_string(FileAccess.get_file_as_string(COLONY))
	for id in meta.buildings:
		var data: Dictionary = meta.buildings[id]
		if id == SOLAR_ID:
			data = data.duplicate()
			data.texture = _solar_texture()
		var b := Building.new()
		b.setup(data, meta.cell, player)
		b.doors_enabled = doors_enabled and data.get("enterable", true)
		add_child(b)
		for f in data.fx:
			_add_fx(f)
		if id != SOLAR_ID or Mission.cleanliness() >= 70.0:  # el sol solo brilla en paneles limpios
			_glints += data.get("glints", [])
	_add_vehicle()
	_add_wind()
	_add_vignette()
	if not _glints.is_empty():
		_glint_loop()


## Imagen del campo solar según su estado real (autoload Mission): limpio, tres niveles de
## suciedad o averiado (paneles rotos o cables cortados).
func _solar_texture() -> String:
	if Mission.broken_count() + Mission.cut_cable_count() > 0 and Mission.cleanliness() >= 70.0:
		return SOLAR_LOOKS.broken
	for look in SOLAR_LOOKS.dirt:
		if Mission.cleanliness() >= look[0]:
			return look[1]
	return SOLAR_LOOKS.dirt[-1][1]


## Punto de aparición del personaje (frente a la estación principal).
func spawn_point() -> Vector2:
	return Vector2(meta.spawn[0], meta.spawn[1])


# ---------------------------------------------------------------- vehículo

func _add_vehicle() -> void:
	var v: Dictionary = meta.vehicle
	_vehicle = Building.new()
	_vehicle.name = "Vehiculo"
	_vehicle.setup(v, meta.cell, player)
	_vehicle.doors_enabled = doors_enabled
	_vehicle.door_range = 90.0
	_vehicle.hint_text = "E: drive the vehicle (map)"
	_vehicle.hint_height = v.door[1] - v.pos[1] + v.size[1] + 55
	_vehicle.used.connect(_drive_away)
	add_child(_vehicle)
	# sombra (va con el vehículo, así no se queda en el suelo cuando se va)
	var shadow := Sprite2D.new()
	shadow.texture = load(v.texture)
	shadow.centered = false
	shadow.scale = Vector2.ONE * meta.cell
	shadow.position = Vector2(-v.size[0] / 2.0, -v.size[1]) + Vector2(5, 3) * meta.cell
	shadow.modulate = Color(0.12, 0.04, 0.02, 0.4)
	_vehicle.add_child(shadow)
	_vehicle.move_child(shadow, 0)
	# faros encendidos, parpadeo suave (también se van con el vehículo)
	var lamp := _light(_vehicle.position + Vector2(-v.size[0] * 0.18, -v.size[1] * 0.32), Color("fff07a"), 1.6, "pulse", 2.5)
	lamp.reparent(_vehicle)


## El astronauta sube al vehículo (vacío), arranca y sale por la izquierda; luego el mapa general.
func _drive_away() -> void:
	_vehicle.doors_enabled = false
	player.hide()
	player.set_process(false)
	var y := _vehicle.position.y
	var tw := create_tween()
	tw.tween_property(_vehicle, "position:y", y - 6, 0.08)  # pequeño salto al arrancar
	tw.tween_property(_vehicle, "position:y", y, 0.08)
	tw.tween_property(_vehicle, "position:x", -400.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_puffs(_vehicle.position + Vector2(60, -10), Color(0.85, 0.62, 0.48, 0.6), Vector2(1, -0.3), 12, 1.2, 60.0)
	await tw.finished
	SceneChanger.go_to(GameState.WORLD_MAP)


# ---------------------------------------------------------------- luces

func _light(at: Vector2, color: Color, size: float, mode: String, period: float) -> Sprite2D:
	var g := Sprite2D.new()
	g.texture = Fx.GLOW
	g.material = _add_mat
	g.modulate = color
	g.position = at
	g.scale = Vector2.ONE * size
	g.z_index = 50
	# punto central brillante
	var core := Sprite2D.new()
	core.texture = Fx.GLOW
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


## Halo sin punto central (resplandor de ventanas, tobera, hielo).
func _glow(at: Vector2, color: Color, size: float, period: float) -> void:
	_light(at, color, size, "pulse", period).get_child(0).visible = false


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
			_glow(at, Color(f.color, 0.7), f.get("size", 5.0) * 1.4, 3.5)
		"smoke":
			_puffs(at, Color(0.78, 0.74, 0.72, 0.55), Vector2(0, -1), 9, 4.0, 40.0)
		"steam":
			_puffs(at, Color(1, 1, 1, 0.5), Vector2(0, -1), 7, 2.5, 55.0)
		"mist":
			var p := Fx.particles(Fx.DUST, 40, 0.9, Vector2(1, -0.6), 25, 40, 90, Vector2(0, 90))
			_place(p, at, 2.0, 3.5, Fx.ramp(Color(0.75, 0.92, 1.0, 0.95)))
		"ice":  # trocitos de hielo saltando del taladro + brillo azul
			var p := Fx.particles(Fx.DUST, 18, 0.8, Vector2(0, -1), 60, 60, 130, Vector2(0, 260))
			_place(p, at, 3.0, 6.0, Fx.ramp(Color(0.8, 0.96, 1.0, 1.0), Color(0.55, 0.85, 1.0, 0.0)))
			_glow(at, Color("7fe6ff", 0.6), 2.2, 0.6)


# ---------------------------------------------------------------- partículas

## Humo o vapor que sube y se lo lleva el viento.
func _puffs(at: Vector2, color: Color, dir: Vector2, amount: int, life: float, speed: float) -> void:
	var p := Fx.particles(Fx.PUFF, amount, life, dir, 12, speed * 0.7, speed, wind * 25.0)
	p.scale_amount_curve = Fx.grow(0.6, 3.0)
	_place(p, at, 1.5, 2.5, Fx.ramp(color))


func _place(p: CPUParticles2D, at: Vector2, scale_min: float, scale_max: float, colors: Gradient) -> void:
	p.position = at
	p.scale_amount_min = scale_min
	p.scale_amount_max = scale_max
	p.color_ramp = colors
	p.z_index = 40
	add_child(p)


## Viento con polvo cruzando toda la zona: granos, ráfagas y nubes grandes y tenues.
func _add_wind() -> void:
	var view := Vector2(4200, 2300)  # cubre toda la zona
	# [textura, cantidad, escala mín, escala máx, color, velocidad]
	for layer in [[Fx.DUST, 280, 4.0, 7.0, Color(0.9, 0.66, 0.5, 0.8), 170.0],
			[Fx.STREAK, 45, 6.0, 9.0, Color(1, 0.88, 0.74, 0.35), 340.0],
			[Fx.PUFF, 6, 30.0, 45.0, Color(0.85, 0.6, 0.45, 0.10), 260.0]]:
		var speed: float = layer[5]
		var p := Fx.particles(layer[0], layer[1], view.x / speed, wind, 4, speed * 0.7, speed * 1.3)
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(10, view.y / 2)
		p.position = Vector2(-60, view.y / 2)
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
		s.texture = Fx.GLINT
		s.material = _add_mat
		s.position = Vector2(pt[0], pt[1])
		s.modulate = Color(0.85, 0.95, 1.0)
		s.scale = Vector2.ZERO
		s.z_index = 55
		add_child(s)
		var tw := create_tween()
		tw.tween_property(s, "scale", Vector2.ONE * randf_range(5.0, 9.0), 0.18)
		tw.parallel().tween_property(s, "rotation", 0.5, 0.45)
		tw.tween_property(s, "scale", Vector2.ZERO, 0.3)
		tw.tween_callback(s.queue_free)


# ---------------------------------------------------------------- viñeta (bordes un poco más oscuros: da profundidad)

func _add_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0.12, 0.03, 0.02, 0.55))
	grad.add_point(0.6, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 1.05)
	tex.gradient = grad
	var rect := TextureRect.new()
	rect.texture = tex
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	add_child(layer)
