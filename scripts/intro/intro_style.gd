extends RefCounted
## Estilo visual compartido de la intro (colores, botones, paneles, astronautas teñidos).
## Uso: const Style := preload("res://scripts/intro/intro_style.gd")
## Mismos colores que el HUD del mapa (world_map.tscn): azul noche + ámbar.

const NAVY := Color(0.047, 0.07, 0.18)
const NAVY_SOFT := Color(0.047, 0.07, 0.18, 0.88)
const AMBER := Color(1, 0.84, 0.27)
const CYAN := Color(0.37, 0.95, 0.89)
const DUST := Color(0.78, 0.45, 0.25)
const DUST_DARK := Color(0.45, 0.22, 0.12)
const WHITE := Color(1, 1, 1)

const ASTRO_FRAMES := preload("res://assets/characters/astronaut_frames.tres")
const ASTRO_SHEET := preload("res://assets/characters/astronaut.png")
const SUIT_SHADER := preload("res://scripts/intro/suit_tint.gdshader")
const FRAME := 96  # tamaño de cada cuadro del sprite sheet del astronauta


static func box(bg: Color, border: Color, border_w := 4, pad := 12.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(0)  # esquinas rectas = look pixel art
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_offset = Vector2(4, 4)
	s.shadow_size = 0
	return s


## Botón pixel art: azul noche con borde ámbar; al pasar el ratón se rellena de ámbar.
static func style_button(b: Button, font_size := 24) -> void:
	b.add_theme_stylebox_override("normal", box(NAVY_SOFT, AMBER))
	b.add_theme_stylebox_override("hover", box(AMBER, WHITE))
	b.add_theme_stylebox_override("pressed", box(AMBER.darkened(0.25), WHITE))
	b.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), WHITE, 3))
	b.add_theme_stylebox_override("disabled", box(Color(0.2, 0.2, 0.25, 0.8), Color(0.45, 0.45, 0.5)))
	b.add_theme_color_override("font_color", WHITE)
	b.add_theme_color_override("font_hover_color", NAVY)
	b.add_theme_color_override("font_pressed_color", NAVY)
	b.add_theme_color_override("font_focus_color", WHITE)
	b.add_theme_color_override("font_hover_pressed_color", NAVY)
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.65))
	b.add_theme_font_size_override("font_size", font_size)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func label(text: String, size := 18, color := WHITE, outline := 4) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", NAVY)
	l.add_theme_constant_override("outline_size", outline)
	return l


static func suit_material(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SUIT_SHADER
	m.set_shader_parameter("suit_color", color)
	return m


## Astronauta animado (reutiliza los frames del juego) con el traje del color del rol.
static func make_astronaut(color: Color, scale := 1.4) -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = ASTRO_FRAMES
	a.offset = Vector2(0, -47)  # los pies quedan en la posición del nodo (igual que astronaut.tscn)
	a.scale = Vector2.ONE * scale
	a.material = suit_material(color)
	a.play("idle_down")
	return a


## Un cuadro del sprite sheet como textura (para retratos en la UI).
## row 0 = idle_down, 6 = celebrate.
static func astronaut_frame(row := 0, col := 0) -> AtlasTexture:
	var t := AtlasTexture.new()
	t.atlas = ASTRO_SHEET
	t.region = Rect2(col * FRAME, row * FRAME, FRAME, FRAME)
	return t


## Textura de 1 color (para partículas sin assets).
static func solid_texture(w: int, h: int, color := Color.WHITE) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


## "Bolita" pixelada de polvo (círculo duro, sin suavizado).
static func puff_texture(radius := 6) -> ImageTexture:
	var d := radius * 2
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in d:
		for x in d:
			var dist := Vector2(x - radius + 0.5, y - radius + 0.5).length()
			if dist <= radius:
				img.set_pixel(x, y, Color(1, 1, 1, 1.0 if dist < radius * 0.7 else 0.6))
	return ImageTexture.create_from_image(img)


## Pantalla de A.R.I.A. (la IA de la base) dibujada en pixel art, para retrato del diálogo.
static func aria_portrait() -> ImageTexture:
	var rows := [
		"................",
		".############...",
		".#cccccccccc#...",
		".#c........c#...",
		".#c.oo..oo.c#...",
		".#c.oo..oo.c#...",
		".#c........c#...",
		".#c..mmmm..c#...",
		".#c........c#...",
		".#cccccccccc#...",
		".############...",
		"......##........",
		"....######......",
		"................",
	]
	var pal := {"#": Color(0.55, 0.6, 0.7), "c": Color(0.1, 0.25, 0.3), "o": CYAN, "m": CYAN}
	var img := Image.create(16, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if pal.has(ch):
				img.set_pixel(x + 1, y, pal[ch])
			elif ch == "." and y >= 2 and y <= 9 and x >= 2 and x <= 11:
				img.set_pixel(x + 1, y, Color(0.03, 0.1, 0.13))
	return ImageTexture.create_from_image(img)
