extends RefCounted
## Estilo visual compartido: colores, botones, paneles y textos.
## Uso: const Style := preload("res://scripts/core/style.gd")
## Todo el juego usa la marca NASA Space Apps (ver la sección de abajo): los nombres antiguos
## (NAVY, AMBER, CYAN) apuntan a los colores de la marca para que el código existente siga igual.

const NAVY := Color("07173f")                 # Deep Blue: contorno / fondo de paneles
const NAVY_SOFT := Color("07173f", 0.9)
const AMBER := Color("eafe07")                # Neon Yellow: bordes, botones y acentos
const CYAN := Color("2e96f5")                 # Blue Yonder: A.R.I.A. y detalles
const DUST := Color(0.78, 0.45, 0.25)         # polvo marciano
const DUST_DARK := Color(0.45, 0.22, 0.12)
const WHITE := Color(1, 1, 1)


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
	return s


## Botón principal del juego (marca: Neon Yellow con texto Deep Blue, Overpass Bold).
static func style_button(b: Button, font_size := 24) -> void:
	brand_button(b, true, font_size)


## Texto en Overpass SemiBold con contorno Deep Blue (se lee sobre el mapa y sobre paneles).
static func label(text: String, font_size := 18, color := WHITE, outline := 4) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", body_font(600))
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", NAVY)
	l.add_theme_constant_override("outline_size", outline)
	return l


## Aviso flotante en el mundo ("E: enter ..."), centrado en `center`, oculto al crearse.
## Es grande porque las zonas se ven con la cámara alejada.
static func world_hint(text: String, center: Vector2) -> Label:
	var l := label(text, 48, WHITE, 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(900, 70)
	l.position = center - l.size / 2.0
	l.z_index = 100
	l.visible = false
	return l


# ---------------------------------------------------------------- marca NASA Space Apps
# Guía de marca: https://www.spaceappschallenge.org/brand/
# - Títulos: Fira Sans Black, en mayúsculas, 5 % de espaciado entre letras.
# - Texto y botones: Overpass (Regular / SemiBold / Bold).
# - El texto va sobre Deep Blue, Electric Blue o blanco. Neon Yellow solo para botones y acentos.
# - No usar logos oficiales de NASA; solo el de NASA Space Apps (assets/ui/logo_space_apps.png).

const DEEP_BLUE := Color("07173f")
const ELECTRIC_BLUE := Color("0042a6")
const NEON_BLUE := Color("0960e1")
const BLUE_YONDER := Color("2e96f5")
const NEON_YELLOW := Color("eafe07")
const ROCKET_RED := Color("e43700")
const MARTIAN_RED := Color("8e1100")

const FONT_TITLE := preload("res://assets/fonts/FiraSans-Black.ttf")
const FONT_BODY := preload("res://assets/fonts/Overpass.ttf")  # fuente variable (peso 100-900)
const LOGO_SPACE_APPS := "res://assets/ui/logo_space_apps.png"


## Overpass con el peso indicado (400 Regular, 600 SemiBold, 700 Bold).
static func body_font(weight := 400) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = FONT_BODY
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return f


## Título de marca: Fira Sans Black, mayúsculas y 5 % de espaciado.
## Con `outline` > 0 lleva contorno Deep Blue (para títulos encima del mapa o de la escena).
static func brand_title(text: String, font_size := 60, color := WHITE, outline := 0) -> Label:
	var f := FontVariation.new()
	f.base_font = FONT_TITLE
	f.spacing_glyph = roundi(font_size * 0.05)
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", NAVY)
		l.add_theme_constant_override("outline_size", outline)
	return l


## Texto de marca en Overpass (sin contorno: va sobre fondo azul de la marca).
static func brand_label(text: String, font_size := 20, color := WHITE, weight := 400) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", body_font(weight))
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


## Botón de marca. Principal: Neon Yellow con texto Deep Blue. Secundario: borde blanco.
static func brand_button(b: Button, primary := true, font_size := 24) -> void:
	var fill := NEON_YELLOW if primary else Color(0, 0, 0, 0)
	var edge := NEON_YELLOW if primary else WHITE
	var text := DEEP_BLUE if primary else WHITE
	b.add_theme_stylebox_override("normal", box(fill, edge, 3, 16.0))
	b.add_theme_stylebox_override("hover", box(WHITE, WHITE, 3, 16.0))
	b.add_theme_stylebox_override("pressed", box(WHITE.darkened(0.15), WHITE, 3, 16.0))
	b.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), BLUE_YONDER, 3))
	b.add_theme_stylebox_override("disabled", box(Color(1, 1, 1, 0.15), Color(1, 1, 1, 0.3), 3, 16.0))
	b.add_theme_font_override("font", body_font(700))
	b.add_theme_font_size_override("font_size", font_size)
	for k in ["font_color", "font_focus_color"]:
		b.add_theme_color_override(k, text)
	for k in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, DEEP_BLUE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Degradado de marca: Electric Blue arriba a la izquierda -> Deep Blue abajo a la derecha (45°).
static func brand_gradient(alpha := 1.0) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(ELECTRIC_BLUE, alpha))
	g.set_color(1, Color(DEEP_BLUE, alpha))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(1, 1)
	return t
