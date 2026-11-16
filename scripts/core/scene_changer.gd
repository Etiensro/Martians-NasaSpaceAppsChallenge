extends CanvasLayer
## Autoload "SceneChanger": el ÚNICO lugar donde se cambia de escena.
## Hace un fundido a negro, cambia la escena y vuelve a mostrar la imagen.
##
##   SceneChanger.go_to("res://scenes/world_map.tscn")
##   await SceneChanger.go_to(path, 1.2)   # fundido más lento (p. ej. final de una cinemática)

var _curtain := ColorRect.new()
var _busy := false
var _target := ""      # escena a la que va el fundido en marcha
var _pending := []     # [ruta, duración] pedida durante un fundido: se hace al terminar


func _ready() -> void:
	layer = 100  # encima de cualquier HUD
	process_mode = Node.PROCESS_MODE_ALWAYS  # el fundido termina aunque el juego esté en pausa
	_curtain.color = Color.BLACK
	_curtain.modulate.a = 0.0
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_curtain)


func go_to(path: String, duration := 0.35) -> void:
	if _busy:
		# Antes se ignoraba, y la escena que lo pidió se quedaba esperando para siempre (p. ej. la
		# estación con Esc mientras aún aparecía tras la intro: ya no respondía a los clics).
		if path != _target:
			_pending = [path, duration]
		return
	_busy = true
	_target = path
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP  # sin clics durante el fundido
	await _fade(1.0, duration)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await _fade(0.0, duration)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	_target = ""
	if not _pending.is_empty():
		var next: Array = _pending
		_pending = []
		go_to(next[0], next[1])


func _fade(alpha: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_curtain, "modulate:a", alpha, duration)
	await tw.finished


## ¿Hay un cambio de escena (fundido) en marcha?
func is_busy() -> bool:
	return _busy
