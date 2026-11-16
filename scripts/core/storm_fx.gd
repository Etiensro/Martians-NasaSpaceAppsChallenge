extends Node
## Animación de la tormenta de polvo en las escenas exteriores (AP-1, AP-8, AP-9 y el mapa general).
## Usa la capa de viento de la intro (scripts/intro/wind_layer.gd) con más o menos fuerza según la
## intensidad de la tormenta (rules.json storms.types.<tipo>.fx): leve se ve el polvo pasar, moderada
## cubre la pantalla y la intensa casi no deja ver. Aparece y desaparece poco a poco al empezar y al
## terminar la tormenta. Uso: add_child(StormFx.new()) en la escena.

const WindLayer := preload("res://scripts/intro/wind_layer.gd")
const FADE := 2.5  # segundos para aparecer / desaparecer

var _wind: WindLayer
var _tw: Tween


func _ready() -> void:
	_wind = WindLayer.new()
	_wind.layer = 30  # encima del mundo y la viñeta, debajo del HUD de la misión (40) y de A.R.I.A. (45)
	add_child(_wind)
	_wind.intensity = 0.0
	_wind.visible = false
	Mission.storm_started.connect(func(_t): _update(true))
	Mission.storm_ended.connect(func(_t): _update(true))
	_update(false)


## Fuerza de la tormenta que hay ahora (0 si no hay).
func strength() -> float:
	return float(Mission.storm_rule().get("fx", 0.6)) if Mission.storm_active() else 0.0


func _update(animate: bool) -> void:
	var target := strength()
	if _tw:
		_tw.kill()
	if target > 0.0:
		_wind.visible = true
	if not animate:
		_wind.intensity = target
		_wind.visible = target > 0.0
		return
	_tw = create_tween()
	_tw.tween_property(_wind, "intensity", target, FADE)
	if target <= 0.0:
		_tw.tween_callback(func(): _wind.visible = false)
