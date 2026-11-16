extends Node2D
## Final, paso 2: DESPEGUE (scenes/finales/despegue.tscn).
## La colonia de AP-1 (colony.gd, sin jugador ni puertas) con la nave que ya está allí (edificio "nave").
## Para que despegue se cambia por nave_vuelo.png (la misma sin la sombra de la plataforma, de
## tools/build_nave_vuelo.py) y sus luces se mueven con ella.
## La tripulación sube, cuenta atrás 3-2-1, se enciende el motor (fuego y humo) y la nave sube hasta salir
## de la pantalla con sus luces. Luego, el viaje a la Tierra (scenes/finales/tierra.tscn).

const Style := preload("res://scripts/core/style.gd")
const Fx := preload("res://scripts/core/fx.gd")
const Colony := preload("res://scripts/colony.gd")
const Final := preload("res://scripts/finales/final.gd")

const SHIP := "nave"
const FLIGHT_TEX := "res://assets/buildings/nave_vuelo.png"
const RISE := 3000.0                     # px que sube la nave
const ZOOM := 0.6

var camera := Camera2D.new()
var ship: Node2D
var _ground_y := 0.0
var _caption: Label
var _big: Label
var _shake := 0.0
var _add := CanvasItemMaterial.new()


func _ready() -> void:
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	Colony.add_ground(self)
	var colony := Colony.new()
	colony.doors_enabled = false
	add_child(colony)
	var building: Node2D = colony.buildings[SHIP]
	building.visible = false
	ship = Node2D.new()  # la nave que vuela: mismo sitio y tamaño que el edificio
	ship.position = building.position
	colony.add_child(ship)
	var info: Dictionary = colony.meta.buildings[SHIP]
	var spr := Sprite2D.new()
	spr.texture = load(FLIGHT_TEX)
	spr.centered = false
	spr.scale = Vector2(info.size[0], info.size[1]) / spr.texture.get_size()
	spr.position = Vector2(-info.size[0] / 2.0, -info.size[1])
	ship.add_child(spr)
	for n in colony.fx_nodes.get(SHIP, []):  # las luces de la nave suben con ella
		n.reparent(ship)
	_ground_y = ship.position.y
	camera.position = ship.position + Vector2(0, -330)
	camera.zoom = Vector2.ONE * ZOOM
	add_child(camera)
	camera.make_current()
	_build_ui()
	_run()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_caption = Style.label("", 24, Style.WHITE, 6)
	_place(layer, _caption, 60)
	_big = Style.brand_title("", 120, Style.NEON_YELLOW, 14)
	_place(layer, _big, 250)


func _place(layer: CanvasLayer, l: Label, top: float) -> void:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	l.offset_left = -600
	l.offset_right = 600
	l.offset_top = top
	layer.add_child(l)


func _run() -> void:
	var emergency := Final.mood() == "emergency"
	_caption.text = ("Emergency launch! " if emergency else "") + "The crew is on board. Ready for launch!"
	await _wait(2.4)
	for n in ["3", "2", "1"]:
		await _flash(n, 0.8)
	_ignite()
	await _flash("LIFT OFF!", 1.0)
	_caption.text = "Goodbye, Mars!"
	var tw := create_tween()
	tw.tween_property(ship, "position:y", _ground_y - RISE, 5.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(camera, "position:y", camera.position.y - 520, 4.0).set_trans(Tween.TRANS_SINE)
	await _wait(4.6)
	SceneChanger.go_to(Final.EARTH, 1.0)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


## Texto grande que aparece de golpe y se desvanece (cuenta atrás).
func _flash(text: String, s: float) -> void:
	_big.text = text
	_big.pivot_offset = _big.size / 2.0
	_big.scale = Vector2.ONE * 1.4
	_big.modulate.a = 1.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_big, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_big, "modulate:a", 0.0, 0.3).set_delay(s - 0.3)
	await _wait(s)


## Motor encendido: fuego y brillo bajo la nave (suben con ella) y humo que se queda en el suelo.
func _ignite() -> void:
	_shake = 14.0
	var fire := Fx.particles(Fx.PUFF, 40, 0.5, Vector2(0, 1), 18, 260, 420)
	fire.scale_amount_min = 4.0
	fire.scale_amount_max = 7.0
	fire.color_ramp = Fx.ramp(Color(1, 0.95, 0.6, 1), Color(1, 0.35, 0.1, 0))
	fire.material = _add
	fire.preprocess = 0.0
	fire.position = Vector2(0, -20)
	ship.add_child(fire)
	var glow := Sprite2D.new()
	glow.texture = Fx.GLOW
	glow.material = _add
	glow.modulate = Color(1, 0.6, 0.2, 0.9)
	glow.scale = Vector2(5, 3.5)
	glow.position = Vector2(0, 10)
	ship.add_child(glow)
	var smoke := Fx.particles(Fx.PUFF, 60, 3.0, Vector2(0, -0.2), 85, 120, 260, Vector2(0, -20))
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smoke.emission_rect_extents = Vector2(120, 10)
	smoke.scale_amount_min = 6.0
	smoke.scale_amount_max = 11.0
	smoke.color_ramp = Fx.ramp(Color(0.92, 0.85, 0.8, 0.8))
	smoke.preprocess = 0.0
	smoke.position = Vector2(ship.position.x, _ground_y)
	add_child(smoke)
	var tw := create_tween()  # el humo deja de salir cuando la nave ya está arriba
	tw.tween_interval(3.0)
	tw.tween_property(smoke, "emitting", false, 0.0)


func _process(delta: float) -> void:
	_shake = move_toward(_shake, 0.0, delta * 3.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
