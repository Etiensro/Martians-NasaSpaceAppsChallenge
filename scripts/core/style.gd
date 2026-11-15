extends RefCounted
## Estilo visual compartido: colores, botones, paneles y textos.
## Uso: const Style := preload("res://scripts/core/style.gd")

const NAVY := Color(0.047, 0.07, 0.18)        # contorno / fondo de paneles
const NAVY_SOFT := Color(0.047, 0.07, 0.18, 0.88)
const AMBER := Color(1, 0.84, 0.27)           # títulos, bordes, botones
const CYAN := Color(0.37, 0.95, 0.89)         # A.R.I.A.
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


## Texto con contorno azul noche.
static func label(text: String, font_size := 18, color := WHITE, outline := 4) -> Label:
	var l := Label.new()
	l.text = text
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
