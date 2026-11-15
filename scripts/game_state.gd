extends Node
## Estado global del juego (autoload "GameState").

## Sitio elegido en el mapa general.
var selected_site := "AP-1"

## Al entrar a un edificio se guarda de dónde venías, para volver al salir.
var return_scene := ""
var return_position := Vector2.INF
