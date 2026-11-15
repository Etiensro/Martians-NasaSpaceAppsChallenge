extends Node2D
## Interior de un edificio (raíz de scenes/interiores/interior_base.tscn).
## Por ahora es una pantalla provisional; aquí irá la vista tipo novela visual de cada edificio.
## Para un interior nuevo: escena heredada de interior_base.tscn y cambiar `title`.
## E o Esc: salir y volver delante de la puerta.

@export var title := "Interior"


func _ready() -> void:
	$HUD/Titulo.text = title


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode in [KEY_E, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		GameState.leave_building()
