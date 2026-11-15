extends Node2D
## Base Ares 1 vista desde arriba (placeholder dibujado por código).
## Cuando el equipo de arte tenga el PNG, asígnalo a "base_texture" y el dibujo provisional desaparece.
## El centro del nodo (0, 0) es el centro del hábitat principal.

@export var base_texture: Texture2D
@export var texture_scale := 1.0

const OUTLINE := Color(0.05, 0.07, 0.18)
const HULL := Color(0.86, 0.87, 0.9)
const HULL_DARK := Color(0.62, 0.64, 0.7)
const SHADOW := Color(0.25, 0.1, 0.05, 0.35)
const PANEL := Color(0.12, 0.2, 0.45)
const PANEL_LINE := Color(0.35, 0.5, 0.85)
const GLASS_GREEN := Color(0.45, 0.8, 0.55)
const LIGHT := Color(1, 0.84, 0.27)

var _t := 0.0


func _ready() -> void:
	if base_texture:
		var s := Sprite2D.new()
		s.texture = base_texture
		s.scale = Vector2.ONE * texture_scale
		add_child(s)


func _process(delta: float) -> void:
	_t += delta
	if not base_texture:
		queue_redraw()  # luces parpadeantes y antena girando


func _draw() -> void:
	if base_texture:
		return
	var font := ThemeDB.fallback_font

	# --- Sombras (desplazadas hacia abajo-derecha) ---
	for c in [[Vector2.ZERO, 150.0], [Vector2(-330, 30), 95.0], [Vector2(300, 60), 85.0], [Vector2(-20, 300), 80.0]]:
		draw_circle(c[0] + Vector2(18, 18), c[1], SHADOW)

	# --- Pasillos que conectan los módulos ---
	_corridor(Vector2(-330, 30), Vector2.ZERO)
	_corridor(Vector2(300, 60), Vector2.ZERO)
	_corridor(Vector2(-20, 300), Vector2.ZERO)

	# --- Campo de paneles solares (arriba a la derecha): ¡la clave de la historia! ---
	for row in 3:
		for col in 4:
			var p := Vector2(180 + col * 110, -330 + row * 80)
			draw_rect(Rect2(p + Vector2(8, 8), Vector2(96, 60)), SHADOW)
			draw_rect(Rect2(p, Vector2(96, 60)), PANEL)
			for i in range(1, 4):
				draw_line(p + Vector2(i * 24, 0), p + Vector2(i * 24, 60), PANEL_LINE, 2)
			draw_line(p + Vector2(0, 30), p + Vector2(96, 30), PANEL_LINE, 2)
			draw_rect(Rect2(p, Vector2(96, 60)), OUTLINE, false, 3)
	# cable de los paneles a la base
	draw_line(Vector2(220, -90), Vector2(120, -60), OUTLINE, 6)
	draw_line(Vector2(220, -90), Vector2(220, -110), OUTLINE, 6)

	# --- Invernadero (izquierda, cúpula verde) ---
	_dome(Vector2(-330, 30), 95.0, GLASS_GREEN, Color(0.3, 0.6, 0.4))
	for i in 5:
		draw_rect(Rect2(Vector2(-380 + i * 20, 0), Vector2(10, 60)), Color(0.2, 0.5, 0.25))

	# --- Módulo de energía / baterías (derecha) ---
	_dome(Vector2(300, 60), 85.0, HULL, HULL_DARK)
	for i in 3:
		draw_rect(Rect2(Vector2(268 + i * 24, 40), Vector2(16, 40)), Color(0.2, 0.25, 0.3))
		var charge := 0.5 + 0.5 * sin(_t * 2.0 + i)
		draw_rect(Rect2(Vector2(268 + i * 24, 80 - 40 * charge), Vector2(16, 40 * charge)), Color(0.4, 1, 0.5))

	# --- Laboratorio (abajo) ---
	_dome(Vector2(-20, 300), 80.0, HULL, HULL_DARK)
	draw_rect(Rect2(Vector2(-50, 280), Vector2(60, 40)), Color(0.3, 0.75, 0.95, 0.8))

	# --- Hábitat principal (centro) ---
	_dome(Vector2.ZERO, 150.0, HULL, HULL_DARK)
	draw_arc(Vector2.ZERO, 105, 0, TAU, 48, HULL_DARK, 6)
	for i in 8:  # ventanas en anillo
		var a := TAU * i / 8.0
		draw_circle(Vector2.from_angle(a) * 125, 10, Color(0.25, 0.75, 0.95))
		draw_arc(Vector2.from_angle(a) * 125, 10, 0, TAU, 12, OUTLINE, 2)
	draw_string(font, Vector2(-62, 16), "ARES 1", HORIZONTAL_ALIGNMENT_CENTER, 124, 34, OUTLINE)

	# --- Antena parabólica (gira lentamente) ---
	var ant := Vector2(-150, -170)
	draw_circle(ant, 30, HULL)
	draw_arc(ant, 30, 0, TAU, 24, OUTLINE, 3)
	draw_line(ant, ant + Vector2.from_angle(_t * 0.6) * 42, OUTLINE, 4)

	# --- Plataforma de aterrizaje (abajo a la izquierda) ---
	var pad := Vector2(-400, 330)
	draw_circle(pad, 90, Color(0.5, 0.48, 0.47))
	draw_arc(pad, 90, 0, TAU, 32, LIGHT, 5)
	draw_string(font, pad + Vector2(-40, 30), "H", HORIZONTAL_ALIGNMENT_CENTER, 80, 90, LIGHT)

	# --- Luces de posición parpadeantes ---
	var on := fmod(_t, 1.2) < 0.25
	for p in [Vector2(-150, -140), Vector2(150, 0), Vector2(-150, 0), Vector2(0, 150)]:
		draw_circle(p, 7, Color(1, 0.25, 0.2) if on else Color(0.4, 0.1, 0.1))


func _dome(c: Vector2, r: float, fill: Color, rim: Color) -> void:
	draw_circle(c, r, rim)
	draw_circle(c, r - 12, fill)
	draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.25, fill.lightened(0.35))  # brillo
	draw_arc(c, r, 0, TAU, 48, OUTLINE, 4)


func _corridor(a: Vector2, b: Vector2) -> void:
	draw_line(a, b, OUTLINE, 44)
	draw_line(a, b, HULL_DARK, 36)
	draw_line(a, b, HULL, 18)
