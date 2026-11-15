extends Node2D
## Flecha animada de salida (dos chevrones que suben y bajan) para las vistas en primera persona.
## Con el cursor encima (`hovered = true`) se ilumina, crece y aparece "EXIT".
## Uso:
##   var exit := ExitArrow.new(); exit.position = Vector2(640, 650); add_child(exit)
##   if exit.hit(mouse): ...      # ¿el cursor está sobre la flecha?
##   exit.hovered = exit.hit(mouse)

const Style := preload("res://scripts/core/style.gd")
const Fx := preload("res://scripts/core/fx.gd")
const HIT_SIZE := Vector2(120, 90)

var hovered := false:
	set(v):
		if v == hovered:
			return
		hovered = v
		var tw := create_tween().set_parallel()
		tw.tween_property(_label, "modulate:a", 1.0 if v else 0.0, 0.15)
		tw.tween_property(_glow, "modulate:a", 0.8 if v else 0.0, 0.15)
		tw.tween_property(_body, "scale", Vector2.ONE * (1.2 if v else 1.0), 0.15)

var _body := Node2D.new()   # chevrones (se mueve arriba y abajo)
var _glow := Sprite2D.new()
var _label: Label


func _ready() -> void:
	add_child(_body)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.texture = Fx.GLOW
	_glow.material = add
	_glow.scale = Vector2.ONE * 2.2
	_glow.modulate = Color(Style.NEON_YELLOW, 0.0)
	_body.add_child(_glow)
	for k in 2:
		var chev := Polygon2D.new()
		chev.polygon = PackedVector2Array([Vector2(-34, -20), Vector2(-20, -20), Vector2(0, 0),
			Vector2(20, -20), Vector2(34, -20), Vector2(0, 14)])
		chev.position = Vector2(0, -14 + k * 22)
		chev.color = Style.NEON_YELLOW
		var line := Line2D.new()
		line.points = chev.polygon + PackedVector2Array([chev.polygon[0]])
		line.width = 3
		line.default_color = Style.NAVY
		chev.add_child(line)
		_body.add_child(chev)
		var blink := create_tween().set_loops()
		blink.tween_property(chev, "modulate:a", 0.35, 0.45).set_delay(k * 0.2)
		blink.tween_property(chev, "modulate:a", 1.0, 0.45)
	var bob := create_tween().set_loops()
	bob.tween_property(_body, "position:y", 8.0, 0.5).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_body, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_SINE)

	_label = Style.brand_title("EXIT", 30, Style.NEON_YELLOW, 8)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(200, 40)
	_label.position = Vector2(-100, -78)
	_label.modulate.a = 0.0
	_label.z_index = 50
	add_child(_label)


## ¿El punto (en coordenadas del padre) está sobre la flecha?
func hit(p: Vector2) -> bool:
	return Rect2(position - HIT_SIZE / 2.0, HIT_SIZE).has_point(p)
