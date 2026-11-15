extends Node2D
## Mini mundo (interior de un edificio). Por ahora es una pantalla provisional;
## aquí irá la vista tipo novela visual de cada edificio.
## E o Esc: salir y volver delante de la puerta.

@export var title := "Interior"

@onready var title_label: Label = $HUD/Titulo


func _ready() -> void:
	title_label.text = title


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode in [KEY_E, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		var gs := get_node_or_null("/root/GameState")
		var back: String = gs.return_scene if gs and gs.return_scene != "" else "res://scenes/ap1_zone.tscn"
		get_tree().change_scene_to_file(back)
