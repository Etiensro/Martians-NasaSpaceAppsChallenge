extends "res://scripts/colony.gd"
## Zona de investigación AP-8 o AP-9 (nodo "Sitio" de ap8_zone.tscn / ap9_zone.tscn). Solo hay tres cosas:
##   - PANELES PEQUEÑOS (1 módulo): llegan sucios; con E se limpian arrastrando el ratón (zone_panels_clean.gd)
##     -> Mission.expedition.mark_zone_panels_clean(). Dan la energía al taladro (van unidos con un cable).
##   - EXCAVADORA: con E se abre el minijuego del taladro (extraccion_hielo.gd, cada zona distinta). Si los
##     paneles siguen sucios, el aviso dice LOCKED y A.R.I.A. explica por qué (Mission.entry_blocked_reason).
##     Mientras extrae (24 h) se ve una barra encima con el progreso, y al terminar "SAMPLE READY".
##   - EL CARRO: el jugador llega en él. Junto al carro: comer de lo que se cargó, dormir dentro mientras el
##     taladro trabaja y volver directo a Ares 1 con la muestra (zone_rover_panel.gd).
## Una flecha amarilla señala siempre qué toca: paneles -> taladro -> carro.
## La cámara se acerca a estas tres cosas (view_center / view_zoom, los usa fixed_zone.gd).
## Cada zona se ve distinta (efectos y color): AP-8 cráteres, rocas y remolinos de polvo; AP-9 pingos con
## hielo que brilla, neblina fría y escarcha cayendo.
## Posiciones en assets/zones/sites.json (tools/build_sites.py). Efectos de luces y humo: colony.gd.

const SITES := "res://assets/zones/sites.json"
const ICE_DRILL := "res://scenes/interiores/excavadora/minijuegos/extraccion_hielo/extraccion_hielo.tscn"
const ZonePanelsClean := preload("res://scripts/zone_panels_clean.gd")
const ZoneRoverPanel := preload("res://scripts/zone_rover_panel.gd")
const Style := preload("res://scripts/core/style.gd")

@export var site_id := "AP-8"

var site: Dictionary
var _panels: Building
var _panels_clean := false
var _drill: Building
var _drill_bar: ProgressBar
var _drill_label: Label
var _drill_box: Control
var _drill_fx: Array[Node2D] = []
var _panel_glints: Array = []
var _ice_glints: Array = []        # puntos del hielo de los pingos (AP-9) que también destellan
var _arrow: Label                  # flecha que señala el siguiente paso
var _arrow_target := Vector2.INF


func _ready() -> void:
	y_sort_enabled = true
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	site = JSON.parse_string(FileAccess.get_file_as_string(SITES))[site_id]
	meta = {"cell": site.cell, "vehicle": site.vehicle, "spawn": site.spawn}
	_add_panels()
	_add_drill()
	_add_vehicle()
	_vehicle.hint_text = "E: your rover"
	if site_id == "AP-8":
		_craters_look()
	else:
		_pingos_look()
	_add_vignette()
	_glint_loop()
	_arrow = Style.label("▼", 130, Style.NEON_YELLOW, 18)
	_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrow.size = Vector2(200, 160)
	_arrow.z_index = 80
	add_child(_arrow)
	Mission.expedition_changed.connect(_refresh)
	_refresh()


# ---------------------------------------------------------------- paneles pequeños

## Centro y zoom de la cámara (sites.json): solo se ve lo que importa de la zona.
func view_center() -> Vector2:
	return Vector2(site.view[0], site.view[1])


func view_zoom() -> float:
	return site.zoom


func _add_panels() -> void:
	var data: Dictionary = site.panels.duplicate()
	_panels_clean = Mission.expedition.zone_panels_clean
	data.texture = data.texture if _panels_clean else data.dirty_texture
	_panels = Building.new()
	_panels.name = "Paneles"
	_panels.setup(data, meta.cell, player)
	_panels.doors_enabled = doors_enabled
	_panels.door_range = 110.0
	_panels.hint_text = "E: clean the solar panels"
	_panels.hint_height = 300
	_panels.used.connect(_clean_panels)
	add_child(_panels)
	_panel_glints = data.glints
	_glints = _panel_glints if _panels_clean else []
	# luz de las baterías: verde si dan energía, roja si los paneles están sucios
	var at := Vector2(data.door[0], data.door[1]) + Vector2(150, -90)
	_light(at, Color("6bff7a") if _panels_clean else Color("ff3b2f"), 1.4, "blink" if not _panels_clean else "pulse", 1.4)


func _clean_panels() -> void:
	if Mission.expedition.zone_panels_clean:
		Mission.notify("The panels are already clean. Now use the ICE DRILL!")
		return
	var game := ZonePanelsClean.new()
	game.clean_texture = load(site.panels.texture)
	game.dirty_texture = load(site.panels.dirty_texture)
	game.finished.connect(_on_panels_cleaned)
	_set_doors(false)
	player.set_process(false)
	add_child(game)


func _set_doors(on: bool) -> void:
	for b in [_panels, _drill, _vehicle]:
		b.doors_enabled = on and doors_enabled


func _on_panels_cleaned(done: bool) -> void:
	player.set_process(true)
	_set_doors(true)
	if not done:
		return
	Mission.expedition.mark_zone_panels_clean()
	Mission.notify("Panels clean! The drill has power. Go to the ICE DRILL.")
	_panels.set_texture(load(site.panels.texture))  # imagen limpia sin recargar la escena
	_glints = _panel_glints


# ---------------------------------------------------------------- excavadora

func _add_drill() -> void:
	var data: Dictionary = site.excavator.duplicate()
	data.interior = ICE_DRILL
	_drill = Building.new()
	_drill.name = "Excavadora"
	_drill.setup(data, meta.cell, player)
	_drill.doors_enabled = doors_enabled
	_drill.hint_text = "E: use the ICE DRILL"
	add_child(_drill)
	for f in data.fx:
		_add_fx(f)
	# trocitos de hielo y vapor en la broca: solo mientras extrae
	var tip := Vector2(data.drill_tip[0], data.drill_tip[1])
	var ice := Fx.particles(Fx.DUST, 22, 0.8, Vector2(0, -1), 60, 70, 150, Vector2(0, 260))
	_place(ice, tip, 3.0, 6.0, Fx.ramp(Color(0.8, 0.96, 1.0, 1.0), Color(0.55, 0.85, 1.0, 0.0)))
	var steam := Fx.particles(Fx.PUFF, 8, 2.5, Vector2(0, -1), 12, 40, 60, wind * 25.0)
	steam.scale_amount_curve = Fx.grow(0.6, 3.0)
	_place(steam, tip + Vector2(0, -40), 1.5, 2.5, Fx.ramp(Color(1, 1, 1, 0.5)))
	_drill_fx = [ice, steam]
	# cartel con la barra de la muestra encima de la torre
	_drill_box = VBoxContainer.new()
	_drill_box.alignment = BoxContainer.ALIGNMENT_CENTER
	# encima de la torre del taladro (a la derecha de la excavadora): 180 px de ancho ×3
	_drill_box.position = Vector2(data.drill_tip[0] - 180, data.pos[1] - data.size[1] - 110)
	_drill_box.z_index = 70
	_drill_box.scale = Vector2.ONE * 2.0
	_drill_label = Style.label("", 18, Style.WHITE, 6)
	_drill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drill_box.add_child(_drill_label)
	_drill_bar = Style.progress_bar(180, 14)
	_drill_box.add_child(_drill_bar)
	add_child(_drill_box)


func _process(_delta: float) -> void:
	if _arrow_target != Vector2.INF:  # la flecha sube y baja sobre lo que toca
		_arrow.visible = player.visible
		_arrow.position = _arrow_target - Vector2(100, 170) + Vector2(0, sin(Time.get_ticks_msec() / 180.0) * 20.0)
	var ex := Mission.expedition
	if ex.is_extracting():
		_drill_bar.value = ex.extraction_progress() * 100.0
		_drill_label.text = "DRILLING  %d%%  ·  %d h left" % [roundi(_drill_bar.value), ceili(ex.extraction.hours_left)]


func _refresh() -> void:
	var ex := Mission.expedition
	var working := ex.is_extracting()
	for p in _drill_fx:
		p.emitting = working
	_drill_bar.visible = working
	var done := ex.extracted_here or Mission.research.has_sample_of(site_id)
	_drill.doors_enabled = doors_enabled and not done  # con la muestra lista ya no hay nada que hacer aquí
	# flecha: paneles sucios -> taladro -> carro (mientras taladra, el carro: descansar o comer)
	var v: Dictionary = site.vehicle
	if not ex.zone_panels_clean and not done:
		_arrow_target = Vector2(site.panels.door[0], site.panels.door[1] - 150)  # sobre el módulo de los paneles
	elif not working and not done:
		_arrow_target = Vector2(site.excavator.door[0], site.excavator.door[1] - 190)
	else:
		_arrow_target = Vector2(v.pos[0], v.pos[1] - v.size[1] - 20)
	if working:
		_process(0.0)
	elif done:
		_drill_label.text = "SAMPLE READY! Go to your rover"
		_drill_label.add_theme_color_override("font_color", Style.NEON_YELLOW)
	elif not ex.zone_panels_clean:
		_drill_label.text = "NO POWER: clean the panels"
		_drill_label.add_theme_color_override("font_color", Color("ff8a7a"))
	else:
		_drill_label.text = "READY TO DRILL"
		_drill_label.add_theme_color_override("font_color", Style.WHITE)


# ---------------------------------------------------------------- carro

func _add_vehicle_panel() -> void:
	var panel := ZoneRoverPanel.new()
	panel.vehicle = _vehicle
	panel.drive = _drive_away
	add_child(panel)


## Vuelve con el carro directo a Ares 1 (solo con la muestra: si no, A.R.I.A. explica por qué).
## El carro sale por el borde, el reloj avanza las horas del viaje y se llega a AP-1.
func _drive_away() -> void:
	var ex := Mission.expedition
	var why := ex.travel_blocked_reason(ex.home())
	if why != "":
		Mission.notify(why)
		return
	_vehicle.doors_enabled = false
	player.hide()
	player.set_process(false)
	_arrow_target = Vector2.INF
	_arrow.hide()
	var tw := create_tween()
	tw.tween_property(_vehicle, "position:x", _edge_x(), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	why = await ex.travel(ex.home())
	if why != "":
		Mission.notify(why)
		SceneChanger.go_to(GameState.WORLD_MAP)
		return
	GameState.selected_site = ex.home()
	SceneChanger.go_to(GameState.site_scene(ex.home()))


## Fuera de la vista, por el lado del carro (por donde llega y se va).
func _edge_x() -> float:
	var half := 1280.0 / view_zoom() / 2.0
	return view_center().x - half - 300.0 if _vehicle.position.x < view_center().x else view_center().x + half + 300.0


## Llega desde el mapa: el carro entra por el borde y el jugador se baja a su lado.
func arrive() -> void:
	var to := _vehicle.position
	player.hide()
	player.set_process(false)
	_vehicle.doors_enabled = false
	_vehicle.position.x = _edge_x()
	# sigue aunque A.R.I.A. pause el juego para hablar (si no, el carro se queda a medio camino)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_vehicle, "position:x", to.x, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_vehicle, "position:y", to.y - 6, 0.08)
	tw.tween_property(_vehicle, "position:y", to.y, 0.08)
	await tw.finished
	_puffs(to + Vector2(-60 if to.x < view_center().x else 60, -10), Color(0.85, 0.62, 0.48, 0.6), Vector2(-1, -0.3), 10, 1.0, 50.0)
	player.show()
	player.set_process(true)
	_vehicle.doors_enabled = doors_enabled
	if has_node("../Robot"):
		get_node("../Robot").snap_to_target()


# ---------------------------------------------------------------- AP-8: cráteres

func _craters_look() -> void:
	_tint(Color(1.0, 0.9, 0.84))
	_site_wind(Color(0.92, 0.6, 0.42, 0.85), 1.35)  # viento más fuerte y rojizo
	for f in site.features:
		var at := Vector2(f.at[0], f.at[1])
		# polvo que cae suave del borde del cráter
		var p := Fx.particles(Fx.DUST, 14, 2.5, Vector2(0, 1), 40, 10, 30, Vector2(0, 30))
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(f.r[0] * 0.7, 6)
		_place(p, at - Vector2(0, f.r[1] * 0.8), 2.0, 4.0, Fx.ramp(Color(0.8, 0.52, 0.38, 0.8)))
	for i in 2:
		_dust_devil(i)


## Remolino de polvo que cruza la zona despacio, girando.
func _dust_devil(i: int) -> void:
	var devil := Node2D.new()
	devil.z_index = 58
	add_child(devil)
	var p := Fx.particles(Fx.PUFF, 40, 1.6, Vector2(0, -1), 20, 60, 110)
	p.orbit_velocity_min = 1.2
	p.orbit_velocity_max = 1.8
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 30.0
	p.scale_amount_curve = Fx.grow(0.5, 2.2)
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.0
	p.color_ramp = Fx.ramp(Color(0.88, 0.6, 0.44, 0.55))
	devil.add_child(p)
	var size := Vector2(4000, 2200)
	while is_inside_tree():
		var from := Vector2(-200, randf_range(300, size.y - 200)) if i == 0 else Vector2(size.x + 200, randf_range(300, size.y - 200))
		var to := Vector2(size.x + 200 if i == 0 else -200, randf_range(300, size.y - 200))
		devil.position = from
		var tw := create_tween()
		tw.tween_property(devil, "position", to, randf_range(22.0, 32.0))
		await tw.finished
		await get_tree().create_timer(randf_range(3.0, 8.0)).timeout


# ---------------------------------------------------------------- AP-9: pingos de hielo

func _pingos_look() -> void:
	_tint(Color(0.9, 0.95, 1.06))
	_site_wind(Color(0.95, 0.8, 0.72, 0.6), 0.8)  # viento más tranquilo
	for f in site.features:
		var at := Vector2(f.at[0], f.at[1])
		_glow(at, Color("9fe8ff", 0.45), f.r[0] / 60.0, 3.0)  # el hielo brilla
		# vapor frío que sale de las grietas del hielo
		var steam := Fx.particles(Fx.PUFF, 5, 3.0, Vector2(0, -1), 15, 20, 35, wind * 15.0)
		steam.scale_amount_curve = Fx.grow(0.5, 2.5)
		_place(steam, at, 1.2, 2.0, Fx.ramp(Color(0.9, 0.97, 1.0, 0.45)))
		for k in 4:  # destellos sobre el hielo (los usa _glint_loop)
			_ice_glints.append([at.x + randf_range(-f.r[0], f.r[0]) * 0.35, at.y + randf_range(-f.r[1], f.r[1]) * 0.35])
	# neblina fría pegada al suelo y escarcha cayendo
	var mist := Fx.particles(Fx.PUFF, 14, 14.0, Vector2(1, 0), 5, 25, 45)
	mist.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	mist.emission_rect_extents = Vector2(10, 1000)
	mist.position = Vector2(-100, 1100)
	mist.scale_amount_min = 25.0
	mist.scale_amount_max = 40.0
	mist.color = Color(0.85, 0.93, 1.0, 0.09)
	mist.z_index = 61
	add_child(mist)
	var frost := Fx.particles(Fx.DUST, 120, 9.0, Vector2(0.3, 1), 20, 25, 55)
	frost.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	frost.emission_rect_extents = Vector2(2100, 10)
	frost.position = Vector2(2000, -40)
	frost.scale_amount_min = 2.0
	frost.scale_amount_max = 4.0
	frost.color = Color(0.92, 0.97, 1.0, 0.85)
	frost.z_index = 62
	add_child(frost)


# ---------------------------------------------------------------- comunes


## Destellos: en los paneles (si están limpios) y en el hielo de los pingos.
func _glint_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(0.1, 0.35)).timeout
		var pool: Array = _glints + _ice_glints
		if pool.is_empty():
			continue
		var pt: Array = pool.pick_random()
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


## Color de toda la zona (cálido en AP-8, frío en AP-9).
func _tint(c: Color) -> void:
	var m := CanvasModulate.new()
	m.color = c
	add_child(m)


## Viento con polvo como el de AP-1, con color y fuerza propios de la zona.
func _site_wind(color: Color, strength: float) -> void:
	var view := Vector2(4200, 2300)
	for layer in [[Fx.DUST, int(280 * strength), 4.0, 7.0, color, 170.0 * strength],
			[Fx.STREAK, int(45 * strength), 6.0, 9.0, Color(color, color.a * 0.4), 340.0 * strength],
			[Fx.PUFF, 6, 30.0, 45.0, Color(color, 0.1), 260.0 * strength]]:
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
