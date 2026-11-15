extends CanvasLayer
## Autoload "SceneChanger": el ÚNICO lugar donde se cambia de escena.
## Hace un fundido a negro, cambia la escena y vuelve a mostrar la imagen.
##
##   SceneChanger.go_to("res://scenes/world_map.tscn")
##   await SceneChanger.go_to(path, 1.2)   # fundido más lento (p. ej. final de una cinemática)

var _curtain := ColorRect.new()
var _busy := false


func _ready() -> void:
	layer = 100  # encima de cualquier HUD
	_curtain.color = Color.BLACK
	_curtain.modulate.a = 0.0
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_curtain)


func go_to(path: String, duration := 0.35) -> void:
	if _busy:
		return
	_busy = true
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP  # sin clics durante el fundido
	await _fade(1.0, duration)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await _fade(0.0, duration)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _fade(alpha: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_curtain, "modulate:a", alpha, duration)
	await tw.finished
