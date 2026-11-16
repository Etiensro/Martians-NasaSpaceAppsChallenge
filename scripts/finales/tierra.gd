extends Node2D
## Final, paso 3: VIAJE Y LLEGADA A LA TIERRA + RESULTADOS (scenes/finales/tierra.tscn).
## La nave cruza el espacio de Marte (se aleja) a la Tierra (se acerca). Al llegar sale la tarjeta final:
## medalla según las zonas investigadas, las 3 zonas, el texto de llegada, la puntuación del documento
## (Mission.final_score) y un consejo para la próxima vez. "BACK TO MENU" empieza una misión nueva.
## PROVISIONAL: Marte, la Tierra, las estrellas y la medalla se dibujan con código hasta tener su arte
## (ver docs/FINALES.md, "Arte que falta"). La nave es la de la colonia (assets/buildings/nave.png).

const Style := preload("res://scripts/core/style.gd")
const Fx := preload("res://scripts/core/fx.gd")
const Final := preload("res://scripts/finales/final.gd")

const MAIN_MENU := "res://scenes/intro/main_menu.tscn"
const SHIP_TEX := "res://assets/buildings/nave.png"
const ZONES := ["AP-1", "AP-8", "AP-9"]
const TRIP := 5.5                         # segundos del viaje

var _stars: Array = []                    # [posición, tamaño, fase]
var _mars := {"pos": Vector2(1040, 520), "r": 150.0}
var _earth := {"pos": Vector2(250, 250), "r": 40.0}
var _ship := Sprite2D.new()
var _trail: CPUParticles2D
var _t := 0.0
var _caption: Label
var _add := CanvasItemMaterial.new()
var _medal_color := Color.WHITE
var _medal_node: Control


func _ready() -> void:
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var rng := RandomNumberGenerator.new()
	rng.seed = 60
	for i in 160:
		_stars.append([Vector2(rng.randf() * 1280, rng.randf() * 720), rng.randf_range(1, 3), rng.randf() * TAU])
	_ship.texture = load(SHIP_TEX)
	_ship.scale = Vector2.ONE * 0.22
	_ship.rotation = deg_to_rad(-62)       # la punta hacia la Tierra
	_ship.position = _mars.pos + Vector2(-120, -110)
	add_child(_ship)
	_trail = Fx.particles(Fx.PUFF, 30, 0.7, Vector2(1, 0.6), 15, 40, 90)  # estela del motor (sigue a la nave)
	_trail.color_ramp = Fx.ramp(Color(1, 0.8, 0.4, 0.9), Color(1, 0.3, 0.1, 0))
	_trail.material = _add
	_trail.scale_amount_min = 1.2
	_trail.scale_amount_max = 2.2
	_trail.preprocess = 0.0
	add_child(_trail)

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_caption = Style.label("On the way home...", 26, Style.WHITE, 6)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_caption.offset_left = -600
	_caption.offset_right = 600
	_caption.offset_top = 40
	layer.add_child(_caption)
	_run(layer)


func _run(layer: CanvasLayer) -> void:
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_ship, "position", Vector2(420, 330), TRIP)
	tw.tween_property(_ship, "scale", Vector2.ONE * 0.14, TRIP)
	tw.tween_method(func(v): _mars.r = v, 150.0, 40.0, TRIP)
	tw.tween_method(func(v): _mars.pos = v, _mars.pos, Vector2(1180, 640), TRIP)
	tw.tween_method(func(v): _earth.r = v, 40.0, 170.0, TRIP)
	tw.tween_method(func(v): _earth.pos = v, _earth.pos, Vector2(330, 330), TRIP)
	await tw.finished
	_caption.text = "Welcome home to Earth!"
	var t2 := create_tween()
	t2.tween_property(_ship, "modulate:a", 0.0, 0.8)
	_trail.emitting = false
	await get_tree().create_timer(1.4).timeout
	var t3 := create_tween()  # la Tierra se aparta a la izquierda para dejar sitio a la tarjeta
	t3.tween_method(func(v): _earth.pos = v, _earth.pos, Vector2(230, 380), 0.8).set_trans(Tween.TRANS_SINE)
	t3.parallel().tween_property(_caption, "modulate:a", 0.0, 0.5)
	await t3.finished
	_results(layer)


# ---------------------------------------------------------------- dibujo (provisional)

func _process(delta: float) -> void:
	_t += delta
	_trail.position = _ship.to_global(Vector2(0, 110))  # bajo los motores (px de la textura)
	if _medal_node:
		_medal_node.queue_redraw()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("050a1f"))
	for s in _stars:
		var a := 0.45 + 0.4 * sin(_t * 2.0 + s[2])
		draw_rect(Rect2(s[0], Vector2.ONE * s[1]), Color(1, 1, 1, a))
	_planet(_mars.pos, _mars.r, Color("c1592b"), Color("e08a4a"), Color("8a3418"), false)
	_planet(_earth.pos, _earth.r, Color("2e7fd8"), Color("63b5ff"), Color("16467f"), true)


## Planeta con sombra a la derecha, brillo arriba a la izquierda y manchas (continentes o cráteres).
func _planet(c: Vector2, r: float, base: Color, light: Color, dark: Color, earth: bool) -> void:
	draw_circle(c, r * 1.12, Color(light, 0.12))  # atmósfera
	draw_circle(c, r, base)
	var spots := [[-0.35, -0.2, 0.32], [0.2, 0.25, 0.26], [0.35, -0.45, 0.18], [-0.15, 0.55, 0.2], [-0.55, 0.3, 0.14]]
	for k in spots.size():
		var sp: Array = spots[k]
		var p := c + Vector2(sp[0], sp[1]) * r
		var col := Color("4caf50") if earth else dark
		if earth and k == 3:
			col = Color("f2f2f2")  # casquete de hielo
		draw_circle(p, r * float(sp[2]), col)
	if earth:  # nubes
		draw_circle(c + Vector2(0.1, -0.05) * r, r * 0.12, Color(1, 1, 1, 0.75))
		draw_circle(c + Vector2(-0.45, 0.1) * r, r * 0.09, Color(1, 1, 1, 0.75))
	draw_circle(c + Vector2(-0.35, -0.35) * r, r * 0.3, Color(light, 0.25))
	# sombra: media luna oscura a la derecha
	var pts := PackedVector2Array()
	for i in 33:
		var ang := -PI / 2 + PI * i / 32.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	for i in 33:
		var ang := PI / 2 - PI * i / 32.0
		pts.append(c + Vector2(cos(ang) * 0.35, sin(ang)) * r)
	draw_colored_polygon(pts, Color(0, 0, 0.08, 0.45))


# ---------------------------------------------------------------- tarjeta final

func _results(layer: CanvasLayer) -> void:
	var info: Dictionary = Final.reason()
	var medal: Dictionary = Final.medal()
	_medal_color = Color(str(medal.color))
	var score: Dictionary = Mission.final_score if not Mission.final_score.is_empty() else Mission.score()

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.box(Style.NAVY_SOFT, _medal_color, 4, 24))
	panel.position = Vector2(470, 24)
	panel.custom_minimum_size = Vector2(780, 0)
	layer.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	col.add_child(head)
	_medal_node = Control.new()
	_medal_node.custom_minimum_size = Vector2(110, 130)
	_medal_node.draw.connect(_draw_medal)
	head.add_child(_medal_node)
	var htext := VBoxContainer.new()
	htext.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(htext)
	htext.add_child(Style.label(str(info.title), 18, Style.BLUE_YONDER, 0))
	htext.add_child(Style.brand_title(str(medal.name), 44, _medal_color))
	var mt := Style.label(str(medal.text), 18, Style.WHITE, 0)
	htext.add_child(mt)

	var zones := HBoxContainer.new()  # las 3 zonas: en color las investigadas, en gris las que faltaron
	zones.add_theme_constant_override("separation", 22)
	zones.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(zones)
	for z in ZONES:
		var done: bool = Mission.research.analysed.has(z)
		var box := VBoxContainer.new()
		var icon := TextureRect.new()
		icon.texture = load("res://assets/world/icon_%s.png" % z)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.modulate = Color.WHITE if done else Color(0.35, 0.35, 0.4, 0.8)
		box.add_child(icon)
		var zl := Style.label(("✓ " if done else "✗ ") + z, 16, Style.NEON_YELLOW if done else Color(1, 1, 1, 0.5), 0)
		zl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(zl)
		zones.add_child(box)

	var arrival := Style.label(Final.fill(str(info.arrival)), 20, Style.WHITE, 0)
	arrival.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(arrival)

	var lines := "Research %d %%  ×10 = %d     Food %d     Rest %d\nEnergy %d     Fitness %d     Sols left %d" % [
		roundi(Mission.research.percent()), roundi(score.research), roundi(score.hunger), roundi(score.rest),
		roundi(score.energy), roundi(score.fitness), roundi(score.sols_left)]
	var detail := Style.label(lines, 17, Color(1, 1, 1, 0.85), 0)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(detail)
	var total := Style.brand_title("SCORE  %d" % score.total, 40, Style.NEON_YELLOW)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(total)

	var tip := Style.label("TIP: " + Final.fill(str(info.tip)), 17, Style.BLUE_YONDER, 0)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(720, 0)
	col.add_child(tip)

	var again := Button.new()
	again.text = "BACK TO MENU"
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	Style.brand_button(again, true, 24)
	again.pressed.connect(_back_to_menu)
	col.add_child(again)

	panel.modulate.a = 0.0
	panel.position.x += 60
	var tw := create_tween().set_parallel()
	tw.tween_property(panel, "modulate:a", 1.0, 0.5)
	tw.tween_property(panel, "position:x", panel.position.x - 60, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	again.grab_focus()


## Medalla provisional: cinta, disco con borde y estrella que brilla.
func _draw_medal() -> void:
	var n := _medal_node
	var c := Vector2(55, 80)
	n.draw_colored_polygon(PackedVector2Array([Vector2(30, 0), Vector2(50, 0), Vector2(62, 50), Vector2(42, 50)]), Style.ELECTRIC_BLUE)
	n.draw_colored_polygon(PackedVector2Array([Vector2(60, 0), Vector2(80, 0), Vector2(68, 50), Vector2(48, 50)]), Style.ROCKET_RED)
	n.draw_circle(c, 44, _medal_color.darkened(0.35))
	n.draw_circle(c, 37, _medal_color)
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI / 2 + TAU * i / 10.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * (22.0 if i % 2 == 0 else 9.0))
	n.draw_colored_polygon(pts, _medal_color.lightened(0.45))
	var a := 0.5 + 0.5 * sin(_t * 3.0)
	n.draw_circle(c + Vector2(-16, -16), 5, Color(1, 1, 1, 0.6 * a))


func _back_to_menu() -> void:
	Mission.reset()
	SceneChanger.go_to(MAIN_MENU)
