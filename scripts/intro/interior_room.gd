extends Node2D
## Interior de la Base Ares 1 visto desde arriba (placeholder dibujado por código).
## Coordenadas pensadas para la pantalla de 1280x720.
## Incluye: suelo de metal, ventanas con la tormenta, mesa con holograma de Marte, 4 cápsulas de
## criosueño con tanques de nitrógeno, pizarrones con fórmulas de Marte, cables, efectos y alarma. A.R.I.A. es el robot (lo coloca base_interior.gd
## en ROBOT_POS, en el suelo arriba de los astronautas).
## Arte final: asigna "room_texture" (1280x720) y el dibujo de fondo se sustituye; las cápsulas
## se siguen dibujando encima hasta que tengan su propio sprite.

@export var room_texture: Texture2D

const Style := preload("res://scripts/core/style.gd")
const Fx := preload("res://scripts/core/fx.gd")
const OUTLINE := Style.NAVY
const FLOOR_A := Color(0.36, 0.38, 0.44)
const FLOOR_B := Color(0.32, 0.34, 0.4)
const WALL := Color(0.2, 0.22, 0.3)
const WALL_LIGHT := Color(0.3, 0.33, 0.42)
const CYAN := Style.CYAN
const DUST := Style.DUST

const ROOM := Rect2(60, 40, 1160, 640)
const FLOOR := Rect2(60, 170, 1160, 510)
const TABLE_POS := Vector2(640, 450)
const ROBOT_POS := Vector2(640, 262)  # A.R.I.A. (el robot), donde antes estaba la pantalla
## Cápsulas de criosueño: 2 a la izquierda y 2 a la derecha.
const POD_POS := [Vector2(190, 200), Vector2(330, 200), Vector2(950, 200), Vector2(1090, 200)]
const POD_SIZE := Vector2(96, 150)

var alarm := false
## 0 = cápsula abierta, 1 = cerrada y congelada (se anima con tween_method).
var pod_frost := [0.0, 0.0, 0.0, 0.0]
var pod_labels := ["", "", "", ""]
var _t := 0.0
## Capa delantera (encima de los astronautas): el cristal helado de las cápsulas ocupadas.
var _front := Node2D.new()


func _ready() -> void:
	_front.z_index = 20
	_front.draw.connect(_draw_pods_front)
	add_child(_front)
	_setup_details()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	_front.queue_redraw()
	_update_details()


## Punto (en el suelo) donde se para un astronauta para entrar en la cápsula i.
func pod_entry(i: int) -> Vector2:
	return POD_POS[i] + Vector2(0, POD_SIZE.y / 2.0 + 40)


## Dónde quedan los pies del astronauta dentro de la cápsula i (de pie, tras el cristal).
func pod_inside(i: int) -> Vector2:
	return POD_POS[i] + Vector2(0, POD_SIZE.y - 26)


func set_pod_frost(value: float, i: int) -> void:
	pod_frost[i] = value


func set_pod_label(i: int, text: String) -> void:
	pod_labels[i] = text


func _draw() -> void:
	var font := ThemeDB.fallback_font
	# Espacio exterior (fuera de la habitación)
	draw_rect(Rect2(-200, -200, 1680, 1120), Color(0.03, 0.03, 0.07))

	if room_texture:
		draw_texture_rect(room_texture, Rect2(0, 0, 1280, 720), false)
	else:
		_draw_room(font)

	if not room_texture:
		_draw_wall_details()
		_draw_floor_details()
	for i in 4:
		_draw_tank(i)
		_draw_pod(i, font)
	_draw_table()
	_draw_alarm_lights()


func _draw_room(font: Font) -> void:
	# Pared superior
	draw_rect(Rect2(ROOM.position, Vector2(ROOM.size.x, 130)), WALL)
	for x in range(int(ROOM.position.x), int(ROOM.end.x), 80):
		draw_line(Vector2(x, ROOM.position.y), Vector2(x, ROOM.position.y + 130), WALL_LIGHT, 2)
	# Ventanas con la tormenta (rachas de polvo animadas)
	for wx in [470.0, 730.0]:
		var w := Rect2(wx, 58, 80, 46)
		draw_rect(w, DUST.darkened(0.25))
		for k in 6:
			var yy := w.position.y + fmod(k * 13.0 + _t * 40.0, w.size.y)
			var xx := w.position.x + fmod(k * 29.0 - _t * 160.0, w.size.x)
			if xx < w.position.x:
				xx += w.size.x
			draw_line(Vector2(xx, yy), Vector2(minf(xx + 24, w.end.x), yy + 4), DUST.lightened(0.25), 2)
		draw_rect(w, OUTLINE, false, 4)

	# Suelo de placas metálicas
	var tile := 64
	for y in range(int(FLOOR.position.y), int(FLOOR.end.y), tile):
		for x in range(int(FLOOR.position.x), int(FLOOR.end.x), tile):
			var odd := (int((x - FLOOR.position.x) / tile) + int((y - FLOOR.position.y) / tile)) % 2 == 1
			var r := Rect2(x, y, tile, tile).intersection(FLOOR)
			draw_rect(r, FLOOR_B if odd else FLOOR_A)
			draw_rect(Rect2(r.position + Vector2(5, 5), Vector2(3, 3)), OUTLINE)
	# Franjas de seguridad en el suelo
	draw_rect(Rect2(FLOOR.position.x, FLOOR.position.y, FLOOR.size.x, 8), Color(1, 0.84, 0.27))

	# Paredes laterales y contorno
	draw_rect(ROOM, OUTLINE, false, 10)


func _draw_pod(i: int, font: Font) -> void:
	var p: Vector2 = POD_POS[i]
	var f: float = pod_frost[i]
	var r := Rect2(p - Vector2(POD_SIZE.x / 2, 0), POD_SIZE)
	draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.35))  # sombra
	draw_rect(r, Color(0.75, 0.78, 0.85))
	var glass := r.grow(-12)
	glass.position.y += 6
	glass.size.y -= 18
	# Cristal: oscuro y vacío si está abierta; azul brillante y helado al cerrarse
	var glow := 0.5 + 0.5 * sin(_t * 2.0 + i)
	draw_rect(glass, Color(0.08, 0.12, 0.18).lerp(Color(0.55, 0.85, 1.0, 1).darkened(0.15 * glow), f))
	draw_rect(glass, OUTLINE, false, 3)
	draw_rect(r, OUTLINE, false, 4)
	# Luz de estado
	draw_circle(Vector2(r.get_center().x, r.end.y - 8), 5, Color(0.4, 1, 0.5) if f < 0.5 else CYAN)


func _glass_rect(i: int) -> Rect2:
	var r := Rect2(POD_POS[i] - Vector2(POD_SIZE.x / 2, 0), POD_SIZE)
	var glass := r.grow(-12)
	glass.position.y += 6
	glass.size.y -= 18
	return glass


## Cristal helado encima del astronauta que duerme: neblina azul, escarcha y brillo.
func _draw_pods_front() -> void:
	for i in 4:
		if pod_labels[i] != "":  # nombre del que duerme (delante de la niebla)
			var r := Rect2(POD_POS[i] - Vector2(POD_SIZE.x / 2, 0), POD_SIZE)
			_front.draw_string(_small_font, Vector2(r.position.x - 20, r.end.y + 26), pod_labels[i],
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 40, 15, Color.WHITE)
		var f: float = pod_frost[i]
		if f <= 0.01:
			continue
		var glass := _glass_rect(i)
		var glow := 0.5 + 0.5 * sin(_t * 2.0 + i)
		_front.draw_rect(glass, Color(0.62, 0.88, 1.0, 0.42 * f))
		# escarcha en las esquinas y cristales de hielo
		for k in 9:
			var fx := glass.position.x + 4 + (k * 23) % int(glass.size.x - 10)
			var fy := glass.position.y + 4 + (k * 37) % int(glass.size.y - 10)
			_front.draw_rect(Rect2(fx, fy, 4 + k % 3 * 2, 4 + k % 3 * 2), Color(1, 1, 1, 0.75 * f))
		for c in [glass.position, Vector2(glass.end.x - 14, glass.position.y)]:
			_front.draw_rect(Rect2(c, Vector2(14, 10)), Color(1, 1, 1, 0.6 * f))
		_front.draw_rect(Rect2(glass.position.x, glass.end.y - 12, glass.size.x, 12), Color(1, 1, 1, 0.55 * f))
		_front.draw_rect(glass.grow(4), Color(0.5, 0.9, 1.0, 0.45 * f * glow), false, 6)
		_front.draw_rect(glass, OUTLINE, false, 3)


func _draw_table() -> void:
	var c := TABLE_POS
	draw_circle(c + Vector2(8, 10), 78, Color(0, 0, 0, 0.3))
	draw_circle(c, 78, Color(0.55, 0.58, 0.66))
	draw_arc(c, 78, 0, TAU, 40, OUTLINE, 5)
	draw_circle(c, 56, Color(0.12, 0.2, 0.26))
	# Holograma de Marte con la tormenta girando
	var h := c + Vector2(0, -6)
	draw_circle(h, 38, Color(0.85, 0.42, 0.22, 0.85))
	draw_circle(h + Vector2(-10, -12), 10, Color(0.95, 0.6, 0.35, 0.8))
	var a := _t * 1.5
	draw_arc(h + Vector2.from_angle(a) * 14, 16, a, a + 4.5, 16, Color(1, 0.9, 0.7, 0.8), 5)
	draw_arc(h, 46, 0, TAU, 40, Color(CYAN, 0.6), 2)


func _draw_alarm_lights() -> void:
	if not alarm:
		return
	var on := fmod(_t, 0.8) < 0.4
	for p in [Vector2(80, 60), Vector2(1200, 60), Vector2(80, 660), Vector2(1200, 660)]:
		draw_circle(p, 16, Color(1, 0.15, 0.1) if on else Color(0.4, 0.05, 0.05))
		if on:
			draw_circle(p, 60, Color(1, 0.1, 0.05, 0.18))


# ---------------------------------------------------------------- detalles del cuarto
# Tanques de nitrógeno líquido junto a cada cápsula (con mangueras), cables en el suelo,
# pizarrones con fórmulas reales de Marte, letrero, tuberías, banco de trabajo y efectos.

## Tanque de N2 de cada cápsula: centro x (a un lado de la cápsula).
const TANK_X := [102.0, 412.0, 868.0, 1176.0]
const TANK_TOP := 228.0
const TANK_SIZE := Vector2(34, 108)
const BOARD_L := Rect2(84, 50, 360, 108)
const BOARD_R := Rect2(836, 50, 360, 108)
## Fórmulas reales de Marte (texto en inglés: lo ve el jugador).
const BOARD_L_LINES := [
	["SOLAR POWER IN A DUST STORM", Color("0042a6")],
	["I0 = 1361 / 1.52² = 589 W/m²", Color("07173f")],
	["I = I0 · e^(-tau)    tau = dust opacity", Color("07173f")],
	["P = efficiency · Area · I", Color("07173f")],
	["Storm: tau = 5  ->  I = 4 W/m² !!", Color("e43700")],
]
const BOARD_R_LINES := [
	["MARS DATA", Color("0042a6")],
	["g = GM / r² = 3.71 m/s²  (38% Earth)", Color("07173f")],
	["1 sol = 24 h 39 min 35 s", Color("07173f")],
	["Air: 610 Pa · 95% CO2 · -63 °C", Color("07173f")],
	["v_esc = sqrt(2GM / r) = 5.03 km/s", Color("07173f")],
]
const LN2_TEMP := "-196 °C"  # nitrógeno líquido

var _mist: Array[CPUParticles2D] = []
var _small_font: FontVariation
var _board_font: FontVariation
var _title_font: FontVariation


func _setup_details() -> void:
	_small_font = Style.body_font(700)
	_board_font = Style.body_font(600)
	_title_font = FontVariation.new()
	_title_font.base_font = Style.FONT_TITLE
	_title_font.spacing_glyph = 2
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in 4:
		# Niebla fría que sale por debajo de la cápsula cuando se congela
		var m := Fx.particles(Fx.PUFF, 14, 2.6, Vector2(0, 1), 70, 8, 22, Vector2(0, -4))
		m.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		m.emission_rect_extents = Vector2(POD_SIZE.x * 0.45, 3)
		m.position = POD_POS[i] + Vector2(0, POD_SIZE.y - 4)
		m.scale_amount_min = 2.5
		m.scale_amount_max = 5.0
		m.scale_amount_curve = Fx.grow(0.6, 1.4)
		m.color_ramp = Fx.ramp(Color(0.85, 0.95, 1.0, 0.35))
		m.emitting = false
		m.z_index = 19  # encima de la gente, debajo del cristal y los nombres
		add_child(m)
		_mist.append(m)
		# Vapor del tanque de nitrógeno (pequeñas bocanadas por la válvula)
		var v := Fx.particles(Fx.PUFF, 5, 1.6, Vector2(0, -1), 25, 10, 22)
		v.position = Vector2(TANK_X[i], TANK_TOP - 12)
		v.scale_amount_min = 1.5
		v.scale_amount_max = 3.0
		v.scale_amount_curve = Fx.grow(0.5, 1.6)
		v.color_ramp = Fx.ramp(Color(0.9, 0.97, 1.0, 0.5))
		v.z_index = 21
		add_child(v)
	# Motas de polvo flotando en el aire de la base
	var motes := Fx.particles(Fx.DUST, 40, 9.0, Vector2(1, -0.2), 40, 4, 12)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.position = FLOOR.get_center()
	motes.emission_rect_extents = FLOOR.size / 2.0
	motes.scale_amount_min = 1.0
	motes.scale_amount_max = 2.0
	motes.color = Color(1, 0.9, 0.75, 0.35)
	motes.z_index = 22
	add_child(motes)


func _update_details() -> void:
	for i in 4:
		_mist[i].emitting = pod_frost[i] > 0.5


func _draw_wall_details() -> void:
	# Tubería a lo largo de la pared, con válvulas
	draw_rect(Rect2(ROOM.position.x, 162, ROOM.size.x, 6), Color(0.45, 0.48, 0.56))
	for x in [300.0, 640.0, 980.0]:
		draw_rect(Rect2(x - 6, 158, 12, 14), Color(0.8, 0.25, 0.2))
	# Pizarrones con fórmulas
	_draw_board(BOARD_L, BOARD_L_LINES, 0)
	_draw_board(BOARD_R, BOARD_R_LINES, 1)
	# Letrero de la bahía de criosueño y rejilla de ventilación (donde estaba la pantalla)
	var sign := Rect2(575, 54, 130, 30)
	draw_rect(sign, Style.NAVY)
	draw_rect(sign, Color(0.5, 0.9, 1.0, 0.6 + 0.2 * sin(_t * 2.0)), false, 2)
	draw_string(_title_font, Vector2(sign.position.x, sign.position.y + 22), "CRYO BAY",
		HORIZONTAL_ALIGNMENT_CENTER, sign.size.x, 18, Color(0.75, 0.95, 1.0))
	var vent := Rect2(590, 96, 100, 52)
	draw_rect(vent, Color(0.16, 0.17, 0.22))
	for k in 6:
		draw_rect(Rect2(vent.position.x + 6, vent.position.y + 6 + k * 8, vent.size.x - 12, 3), Color(0.32, 0.34, 0.42))
	draw_rect(vent, OUTLINE, false, 3)
	# Paneles con luces a los lados de las ventanas
	for px in [452.0, 560.0, 712.0, 820.0]:
		var p := Rect2(px, 64, 10, 76)
		draw_rect(p, Color(0.14, 0.15, 0.2))
		for k in 4:
			var on := fmod(_t * 1.7 + px * 0.01 + k * 0.6, 2.0) < 1.2
			draw_rect(Rect2(p.position.x + 2, p.position.y + 6 + k * 18, 6, 6),
				(Color(0.4, 1, 0.5) if k % 2 == 0 else CYAN) if on else Color(0.1, 0.15, 0.15))


func _draw_board(r: Rect2, lines: Array, side: int) -> void:
	draw_rect(Rect2(r.position + Vector2(4, 5), r.size), Color(0, 0, 0, 0.35))
	draw_rect(r, Color(0.94, 0.95, 0.97))
	draw_rect(r, Color(0.62, 0.65, 0.72), false, 5)
	draw_rect(Rect2(r.position.x + 20, r.end.y, r.size.x - 40, 5), Color(0.55, 0.58, 0.65))  # bandeja
	for k in lines.size():
		var size: int = 15 if k == 0 else 13
		var f: Font = _title_font if k == 0 else _board_font
		draw_string(f, r.position + Vector2(12, 21 + k * 19), lines[k][0], HORIZONTAL_ALIGNMENT_LEFT,
			r.size.x - 20, size, lines[k][1])
	# subrayado del título y dibujos (Marte con su órbita / gráfica de la tormenta)
	draw_line(r.position + Vector2(12, 26), r.position + Vector2(170, 26), Color("0042a6"), 2)
	var c := r.position + Vector2(r.size.x - 34, 24)
	if side == 0:
		var pts := PackedVector2Array()
		for k in 12:
			pts.append(c + Vector2(-18 + k * 3, -6 + 14 * (1.0 - exp(-k * 0.35))))
		draw_polyline(pts, Color("e43700"), 2)
	else:
		draw_arc(c, 14, 0, TAU, 20, Color("0042a6"), 1.5)
		draw_circle(c + Vector2(14, 0), 4, Color("e43700"))
		draw_circle(c, 3, Color(0.95, 0.75, 0.2))


func _draw_tank(i: int) -> void:
	var x: float = TANK_X[i]
	var r := Rect2(x - TANK_SIZE.x / 2, TANK_TOP, TANK_SIZE.x, TANK_SIZE.y)
	draw_rect(Rect2(r.position + Vector2(5, 6), r.size), Color(0, 0, 0, 0.3))
	draw_rect(r, Color(0.86, 0.9, 0.95))
	draw_rect(Rect2(r.position.x, r.position.y + 20, r.size.x, 14), Style.ELECTRIC_BLUE)
	draw_rect(Rect2(r.position.x + 4, r.position.y + 4, 5, r.size.y - 8), Color(1, 1, 1, 0.6))  # brillo
	draw_string(_small_font, Vector2(r.position.x, r.position.y + 31), "N2", HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x, 11, Color.WHITE)
	# escarcha en la base del tanque (siempre está frío)
	draw_rect(Rect2(r.position.x, r.end.y - 14, r.size.x, 14), Color(0.8, 0.95, 1.0, 0.8))
	draw_rect(r, OUTLINE, false, 3)
	# válvula y manómetro
	draw_rect(Rect2(x - 6, TANK_TOP - 12, 12, 12), Color(0.55, 0.58, 0.66))
	draw_rect(Rect2(x - 6, TANK_TOP - 12, 12, 12), OUTLINE, false, 2)
	var g := Vector2(x, TANK_TOP + 58)
	draw_circle(g, 8, Color.WHITE)
	draw_arc(g, 8, 0, TAU, 16, OUTLINE, 2)
	var a: float = -PI * 0.8 + (0.4 + 0.5 * pod_frost[i]) * PI * 0.9 + sin(_t * 3.0 + i) * 0.05
	draw_line(g, g + Vector2.from_angle(a) * 6, Color(0.85, 0.15, 0.1), 2)
	# luz de estado y pantallita con la temperatura
	var led_on := fmod(_t + i * 0.3, 1.0) < 0.5
	draw_circle(Vector2(x, TANK_TOP + 80), 3, CYAN if led_on else Color(0.1, 0.2, 0.25))
	var screen := Rect2(x - 15, TANK_TOP + 88, 30, 12)
	draw_rect(screen, Color(0.03, 0.08, 0.12))
	if pod_frost[i] > 0.5:
		var pts := PackedVector2Array()
		for k in 8:
			var beat := 4.0 if (k + int(_t * 6.0)) % 8 == 3 else 0.0
			pts.append(screen.position + Vector2(2 + k * 3.7, 6 - beat))
		draw_polyline(pts, Color(0.4, 1, 0.5), 1.5)
	# manguera del tanque a la cápsula (curva)
	var pod: Vector2 = POD_POS[i]
	var side := signf(pod.x - x)
	var from := Vector2(x + side * TANK_SIZE.x / 2, TANK_TOP + 46)
	var to := Vector2(pod.x - side * POD_SIZE.x / 2, pod.y + 100)
	var hose := PackedVector2Array()
	for k in 11:
		var t := k / 10.0
		var mid := (from + to) / 2.0 + Vector2(0, 26)
		hose.append(from.lerp(mid, t).lerp(mid.lerp(to, t), t))
	draw_polyline(hose, OUTLINE, 7)
	draw_polyline(hose, Color(0.35, 0.55, 0.85), 4)
	# escarcha en la manguera cuando la cápsula está congelada
	if pod_frost[i] > 0.05:
		for k in range(1, 10, 2):
			draw_circle(hose[k], 3, Color(1, 1, 1, 0.8 * pod_frost[i]))


func _draw_floor_details() -> void:
	# Cables: de cada cápsula al canal del suelo y de ahí a la pared
	var tray_y := 404.0
	for i in 4:
		var pod: Vector2 = POD_POS[i]
		var wall_x := ROOM.position.x + 6 if pod.x < 640 else ROOM.end.x - 6
		for k in 2:
			var dx := -14.0 + k * 10.0
			var pts := PackedVector2Array([
				Vector2(pod.x + dx, pod.y + POD_SIZE.y),
				Vector2(pod.x + dx, tray_y + k * 7),
				Vector2(wall_x, tray_y + k * 7)])
			draw_polyline(pts, OUTLINE, 5)
			draw_polyline(pts, Color(0.95, 0.75, 0.2) if k == 0 else Color(0.25, 0.3, 0.38), 3)
	# Caja de conexiones en cada pared
	for bx in [ROOM.position.x + 6, ROOM.end.x - 34]:
		var b := Rect2(bx, tray_y - 14, 28, 36)
		draw_rect(b, Color(0.42, 0.45, 0.52))
		draw_rect(b, OUTLINE, false, 3)
		draw_circle(b.get_center(), 4, Color(1, 0.84, 0.27) if fmod(_t, 1.4) < 0.7 else Color(0.4, 0.3, 0.1))
	# Franjas de peligro en el suelo frente a cada cápsula
	for i in 4:
		var pod: Vector2 = POD_POS[i]
		for k in 6:
			var s := Rect2(pod.x - POD_SIZE.x / 2 + k * 16, pod.y + POD_SIZE.y + 4, 8, 6)
			draw_rect(s, Color(0.95, 0.75, 0.2))
	# Rejillas de ventilación del suelo
	for v in [Vector2(470, 600), Vector2(810, 600)]:
		var g := Rect2(v - Vector2(36, 16), Vector2(72, 32))
		draw_rect(g, Color(0.2, 0.21, 0.26))
		for k in 5:
			draw_rect(Rect2(g.position.x + 6 + k * 13, g.position.y + 5, 6, g.size.y - 10), Color(0.12, 0.13, 0.17))
		draw_rect(g, OUTLINE, false, 3)
