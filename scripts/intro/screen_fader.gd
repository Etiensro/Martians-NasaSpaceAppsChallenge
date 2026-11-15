extends CanvasLayer
## Fundido a/desde negro encima de todo. Uso:
##   await fader.fade_in(1.0)    # de negro a imagen
##   await fader.fade_out(1.0)   # de imagen a negro

var rect := ColorRect.new()


func _init() -> void:
	layer = 100
	rect.color = Color.BLACK
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)


func _ready() -> void:
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_black(on: bool) -> void:
	rect.modulate.a = 1.0 if on else 0.0


func fade_in(duration := 1.0) -> void:
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, duration)
	await tw.finished


func fade_out(duration := 1.0, color := Color.BLACK) -> void:
	rect.color = color
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 1.0, duration)
	await tw.finished
