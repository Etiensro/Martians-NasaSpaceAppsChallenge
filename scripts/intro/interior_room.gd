extends Node2D
## Interior de la Base Ares 1 visto desde arriba (placeholder dibujado por código).
## Coordenadas pensadas para la pantalla de 1280x720.
## Incluye: suelo de metal, ventana con la tormenta, consola de A.R.I.A., mesa con holograma
## de Marte, 4 cápsulas de criosueño y luces de alarma.
## Arte final: asigna "room_texture" (1280x720) y el dibujo de fondo se sustituye; las cápsulas
## y la consola se siguen dibujando encima hasta que tengan su propio sprite.

@export var room_texture: Texture2D

const OUTLINE := Color(0.05, 0.07, 0.18)
const FLOOR_A := Color(0.36, 0.38, 0.44)
const FLOOR_B := Color(0.32, 0.34, 0.4)
const WALL := Color(0.2, 0.22, 0.3)
const WALL_LIGHT := Color(0.3, 0.33, 0.42)
const CYAN := Color(0.37, 0.95, 0.89)
const DUST := Color(0.78, 0.45, 0.25)

const ROOM := Rect2(60, 40, 1160, 640)
const FLOOR := Rect2(60, 170, 1160, 510)
const TABLE_POS := Vector2(640, 450)
const ARIA_POS := Vector2(640, 110)
## Cápsulas de criosueño: 2 a la izquierda y 2 a la derecha de la consola.
const POD_POS := [Vector2(190, 200), Vector2(330, 200), Vector2(950, 200), Vector2(1090, 200)]
const POD_SIZE := Vector2(96, 150)

var alarm := false
var aria_talking := false
## 0 = cápsula abierta, 1 = cerrada y congelada (se anima con tween_method).
var pod_frost := [0.0, 0.0, 0.0, 0.0]
var pod_labels := ["", "", "", ""]
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Punto (en el suelo) donde se para un astronauta para entrar en la cápsula i.
func pod_entry(i: int) -> Vector2:
	return POD_POS[i] + Vector2(0, POD_SIZE.y / 2.0 + 40)


func set_pod_frost(value: float, i: int) -> void:
	pod_frost[i] = value


func _draw() -> void:
	var font := ThemeDB.fallback_font
	# Espacio exterior (fuera de la habitación)
	draw_rect(Rect2(-200, -200, 1680, 1120), Color(0.03, 0.03, 0.07))

	if room_texture:
		draw_texture_rect(room_texture, Rect2(0, 0, 1280, 720), false)
	else:
		_draw_room(font)

	_draw_aria(font)
	for i in 4:
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

	# Muebles laterales: plantas (izquierda) y caja de herramientas (derecha)
	for i in 3:
		var p := Vector2(100 + i * 56, 600)
		draw_rect(Rect2(p, Vector2(40, 36)), Color(0.45, 0.3, 0.2))
		draw_circle(p + Vector2(20, -6), 22, Color(0.3, 0.7, 0.35))
		draw_circle(p + Vector2(12, -14), 10, Color(0.45, 0.85, 0.45))
	draw_rect(Rect2(1060, 590, 110, 56), Color(0.8, 0.25, 0.2))
	draw_rect(Rect2(1060, 590, 110, 56), OUTLINE, false, 4)
	draw_rect(Rect2(1095, 578, 40, 14), OUTLINE, false, 4)
	draw_string(font, Vector2(1066, 628), "TOOLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)

	# Paredes laterales y contorno
	draw_rect(ROOM, OUTLINE, false, 10)


func _draw_aria(font: Font) -> void:
	# Consola + pantalla con la "cara" de A.R.I.A.
	var c := ARIA_POS
	draw_rect(Rect2(c + Vector2(-110, 30), Vector2(220, 60)), Color(0.25, 0.27, 0.33))
	for i in 6:
		var on := fmod(_t * 3.0 + i * 0.7, 2.0) < 1.0
		draw_rect(Rect2(c + Vector2(-96 + i * 34, 48), Vector2(20, 12)), CYAN if on else Color(0.1, 0.3, 0.35))
	draw_rect(Rect2(c + Vector2(-110, 30), Vector2(220, 60)), OUTLINE, false, 4)
	var screen := Rect2(c + Vector2(-80, -60), Vector2(160, 90))
	var col := Color(1, 0.3, 0.25) if alarm and fmod(_t, 0.8) < 0.4 else CYAN
	draw_rect(screen, Color(0.03, 0.1, 0.13))
	draw_rect(screen, OUTLINE, false, 6)
	# Ojos
	var blink := fmod(_t, 4.0) < 0.12
	for ex in [-30.0, 30.0]:
		var eye := Rect2(c + Vector2(ex - 9, -38), Vector2(18, 4 if blink else 18))
		draw_rect(eye, col)
	# Boca: onda cuando habla, línea cuando calla
	var pts := PackedVector2Array()
	for k in 9:
		var x := -36.0 + k * 9.0
		var y := sin(_t * 18.0 + k) * 6.0 if aria_talking else 0.0
		pts.append(c + Vector2(x, 2 + y))
	draw_polyline(pts, col, 4)
	draw_string(font, c + Vector2(-80, -70), "A.R.I.A.", HORIZONTAL_ALIGNMENT_CENTER, 160, 18, CYAN)


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
	if f > 0.05:
		# cristales de escarcha
		for k in 5:
			var fx := glass.position.x + 10 + (k * 17) % int(glass.size.x - 16)
			var fy := glass.position.y + 12 + (k * 31) % int(glass.size.y - 20)
			draw_rect(Rect2(fx, fy, 6, 6), Color(1, 1, 1, f * 0.8))
		draw_rect(glass.grow(4), Color(0.5, 0.9, 1.0, 0.35 * f * glow), false, 6)
	draw_rect(glass, OUTLINE, false, 3)
	draw_rect(r, OUTLINE, false, 4)
	# Luz de estado
	draw_circle(Vector2(r.get_center().x, r.end.y - 8), 5, Color(0.4, 1, 0.5) if f < 0.5 else CYAN)
	if pod_labels[i] != "":
		draw_string(font, Vector2(r.position.x - 20, r.end.y + 22), pod_labels[i],
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 40, 15, Color(1, 1, 1, 0.9))


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
