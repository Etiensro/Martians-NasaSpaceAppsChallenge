extends CanvasLayer
## Limpiar los paneles pequeños de AP-8 / AP-9 (lo abre expedition_site.gd al pulsar E junto a ellos).
## Se ven en grande, llenos de polvo: mantener el clic y mover el ratón quita el polvo con la brocha
## (la misma del campo solar de AP-1: assets/interiores/paneles_solares/campo_solar/field_brush.png).
## Al dejar limpio el 90 % de los paneles se termina solo -> finished(true). Esc o la flecha: finished(false).

signal finished(done: bool)

const Style := preload("res://scripts/core/style.gd")
const Fx := preload("res://scripts/core/fx.gd")
const ExitArrow := preload("res://scripts/core/exit_arrow.gd")
const SCALE := 3.5
const BRUSH := 9          # radio del cepillo en px de la imagen
const GOAL := 0.9         # parte del polvo que hay que quitar
const BRUSH_ART := preload("res://assets/interiores/paneles_solares/campo_solar/field_brush.png")
const BRUSH_ANCHOR := Vector2(14.2, 43.8)  # punto de la brocha que va bajo el ratón (field.json)
const BRUSH_SCALE := 1.4

var clean_texture: Texture2D
var dirty_texture: Texture2D

var _dirty: Image
var _dirty_tex: ImageTexture
var _view: Control
var _is_dust := PackedByteArray()  # 1 = píxel con polvo (donde sucio y limpio son distintos)
var _total := 0
var _left := 0
var _bar: ProgressBar
var _info: Label
var _exit := ExitArrow.new()
var _brushing := false
var _done := false
var _puff: CPUParticles2D
var _brush_sprite := Sprite2D.new()
var _ring := Line2D.new()
var _t := 0.0


func _ready() -> void:
	layer = 20
	var bg := ColorRect.new()
	bg.color = Color(Style.DEEP_BLUE, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var size := clean_texture.get_size() * SCALE
	_view = Control.new()
	_view.position = (Vector2(1280, 720) - size) / 2.0 + Vector2(0, 30)
	_view.size = size
	_view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(_view)
	for t in [clean_texture, null]:
		var r := TextureRect.new()
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.size = size
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if t:
			r.texture = t
		else:
			_dirty = dirty_texture.get_image()
			_dirty.convert(Image.FORMAT_RGBA8)
			_dirty_tex = ImageTexture.create_from_image(_dirty)
			r.texture = _dirty_tex
		_view.add_child(r)
	# dónde hay polvo: los píxeles que cambian entre la imagen sucia y la limpia
	var c := clean_texture.get_image()
	c.convert(Image.FORMAT_RGBA8)
	_is_dust.resize(_dirty.get_width() * _dirty.get_height())
	for y in _dirty.get_height():
		for x in _dirty.get_width():
			var a := _dirty.get_pixel(x, y)
			var b := c.get_pixel(x, y)
			if a.a > 0.5 and absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.25:
				_is_dust[y * _dirty.get_width() + x] = 1
				_total += 1
	_left = _total

	var title := Style.brand_title("CLEAN THE SOLAR PANELS", 40, Style.NEON_YELLOW)
	title.position = Vector2(0, 18)
	title.size = Vector2(1280, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	_info = Style.brand_label("Hold the mouse button and move it to brush the dust away!", 20, Style.WHITE, 700)
	_info.position = Vector2(0, 72)
	_info.size = Vector2(1280, 30)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_info)
	_bar = Style.progress_bar(420, 18)
	_bar.position = Vector2(430, 680)
	add_child(_bar)
	_exit.position = Vector2(1180, 640)
	add_child(_exit)

	_puff = Fx.particles(Fx.DUST, 30, 0.7, Vector2(0, -1), 80, 60, 140, Vector2(0, 200))
	_puff.scale_amount_min = 3.0
	_puff.scale_amount_max = 6.0
	_puff.color_ramp = Fx.ramp(Color(0.85, 0.55, 0.38, 0.9))
	_puff.emitting = false
	_puff.preprocess = 0.0
	add_child(_puff)

	# la brocha sigue al ratón (con un círculo del tamaño de lo que limpia)
	var r := BRUSH * SCALE
	for k in 33:
		_ring.add_point(Vector2(cos(k * TAU / 32.0), sin(k * TAU / 32.0)) * r)
	_ring.width = 2.0
	_ring.default_color = Color(1, 1, 1, 0.5)
	add_child(_ring)
	_brush_sprite.texture = BRUSH_ART
	_brush_sprite.centered = false
	_brush_sprite.offset = -BRUSH_ANCHOR
	_brush_sprite.scale = Vector2.ONE * BRUSH_SCALE
	_brush_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_brush_sprite)


func _process(delta: float) -> void:
	_t += delta
	var m := get_viewport().get_mouse_position()
	var over := Rect2(_view.position, _view.size).has_point(m) and not _done
	Audio.set_loop("panel_cleaning", _brushing and over)
	_brush_sprite.visible = over
	_ring.visible = over
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if over else Input.MOUSE_MODE_VISIBLE
	var wobble := Vector2(sin(_t * 30.0) * 3.0, 0) if _brushing else Vector2.ZERO
	_brush_sprite.position = m + wobble
	_ring.position = m
	_ring.default_color = Color(1, 1, 1, 0.85 if _brushing else 0.45)


func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close(false)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if event.pressed and _exit.hit(event.position):
			_close(false)
			return
		_brushing = event.pressed
		if _brushing:
			_brush(event.position)
	elif event is InputEventMouseMotion:
		_exit.hovered = _exit.hit(event.position)
		if _brushing:
			_brush(event.position)
	if not _brushing:
		_puff.emitting = false


func _brush(screen: Vector2) -> void:
	var p := Vector2i(((screen - _view.position) / SCALE).floor())
	_puff.position = screen
	_puff.emitting = Rect2(Vector2.ZERO, _view.size).has_point(screen - _view.position)
	var changed := false
	for y in range(p.y - BRUSH, p.y + BRUSH + 1):
		for x in range(p.x - BRUSH, p.x + BRUSH + 1):
			if x < 0 or y < 0 or x >= _dirty.get_width() or y >= _dirty.get_height():
				continue
			if Vector2(x - p.x, y - p.y).length() > BRUSH:
				continue
			if _dirty.get_pixel(x, y).a > 0.0:
				_dirty.set_pixel(x, y, Color(0, 0, 0, 0))
				changed = true
				if _is_dust[y * _dirty.get_width() + x] == 1:
					_left -= 1
	if not changed:
		return
	_dirty_tex.update(_dirty)
	var cleaned := 1.0 - float(_left) / maxf(_total, 1.0)
	_bar.value = minf(cleaned / GOAL, 1.0) * 100.0
	if cleaned >= GOAL:
		_finish()


func _finish() -> void:
	_done = true
	_brushing = false
	_puff.emitting = false
	var dirty_view: TextureRect = _view.get_child(1)
	create_tween().tween_property(dirty_view, "modulate:a", 0.0, 0.4)
	_info.text = "Great job! The panels shine again."
	_info.add_theme_color_override("font_color", Style.NEON_YELLOW)
	await get_tree().create_timer(1.4).timeout
	_close(true)


func _close(done: bool) -> void:
	_done = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	finished.emit(done)
	queue_free()
