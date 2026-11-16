extends RefCounted
## Módulo del autoload Mission: el cultivo de papas del invernadero (Mission.crops).
## Etapas: plantar (1 h) -> regar cada sol (30 min) -> crecer 8 sols -> cosechar (1 h, 24 papas).
## Cada sol seguido sin regar quita rendimiento (-10 %, -25 %, -50 %) y al 4.º el cultivo muere.
## El rendimiento se calcula al cosechar con la peor racha sin regar. Las papas van a la despensa
## (Mission.pantry_meals). Números: data/mission/rules.json -> "crops".
## Un cultivo muerto se queda marchito en las camas hasta que termina su ciclo (los sols de crecer,
## contados desde la siembra); entonces hay que limpiar las camas (clear) para volver a plantar.
##
## Uso desde el invernadero (scripts/interiores/estacion_ares1/):
##   Mission.crops.next_task()       # "plant", "water", "harvest", "clear" o "" (esperar)
##   await Mission.crops.plant()     # al terminar el minijuego de sembrar. Devuelve "" o el motivo
##   await Mission.crops.water()     # al terminar el minijuego de regar
##   await Mission.crops.harvest()   # al terminar el minijuego de cosechar (cuando is_ready())
##   await Mission.crops.clear()     # al terminar de quitar las plantas muertas (cuando can_clear())
##   Mission.crops.stage()           # 0 sana, 1 débil, 2 marchita, 3 muerta (qué dibujar)
## Además mantiene GameState.greenhouse_step (el paso que muestra el invernadero):
##   0 = sembrar, 1 = toca regar hoy, 2 = regado, listo para cosechar o planta muerta en las camas.

const CROP := "potato"

var planted := false           # hay plantas en las camas (vivas o muertas)
var age := 0                   # sols desde la siembra (cuenta siempre, también con la planta muerta)
var growth := 0.0              # sols de crecimiento acumulados
var watered_today := false
var dry_streak := 0            # sols seguidos sin regar (el actual)
var worst_dry_streak := 0      # la peor racha: decide el rendimiento
var dead := false
var damaged := false           # invernadero dañado por una tormenta (no crece hasta repararlo)
var last_harvest := 0          # papas de la última cosecha


func reset() -> void:
	_empty_beds()
	damaged = false
	last_harvest = 0


func _empty_beds() -> void:
	planted = false
	age = 0
	growth = 0.0
	watered_today = false
	dry_streak = 0
	worst_dry_streak = 0
	dead = false
	GameState.greenhouse_step = 0


func rule() -> Dictionary:
	return Mission.rules.crops[CROP]


## Sols que necesita para crecer (el biólogo: más rápido, GameState "crop_speed"). También es lo que
## dura el ciclo: una planta muerta no se puede quitar hasta que pasan.
func grow_sols() -> float:
	return rule().grow_sols / GameState.modifier("crop_speed")


## Hay un cultivo vivo en el invernadero (entonces no se puede apagar).
func is_growing() -> bool:
	return planted and not dead


func is_ready() -> bool:
	return is_growing() and growth >= grow_sols()


func needs_water() -> bool:
	return is_growing() and not watered_today and not is_ready()


## La planta murió y ya terminó su ciclo: se pueden limpiar las camas.
func can_clear() -> bool:
	return planted and dead and age >= grow_sols()


## Sols que faltan para poder limpiar la planta muerta (0 si ya se puede).
func sols_to_clear() -> int:
	return maxi(0, ceili(grow_sols() - age)) if planted and dead else 0


## Sols que faltan para cosechar (0 si ya está lista).
func sols_to_harvest() -> int:
	return maxi(0, ceili(grow_sols() - growth)) if is_growing() else 0


## Lo que toca hacer ahora en el invernadero: "plant", "water", "harvest", "clear" o "" (esperar).
func next_task() -> String:
	if not planted:
		return "plant"
	if dead:
		return "clear" if can_clear() else ""
	if is_ready():
		return "harvest"
	if needs_water():
		return "water"
	return ""


## Progreso del crecimiento (0-1).
func progress() -> float:
	return clampf(growth / grow_sols(), 0.0, 1.0) if planted else 0.0


## Rendimiento (0-1) según la peor racha sin regar (0 si murió).
func yield_ratio() -> float:
	if dead:
		return 0.0
	var pens: Array = rule().dry_penalties
	return 1.0 - float(pens[mini(worst_dry_streak, pens.size() - 1)])


## Papas que daría la cosecha con el rendimiento de ahora (rol incluido).
func expected_harvest() -> int:
	return roundi(rule().harvest * yield_ratio() * GameState.modifier("harvest_yield"))


## Cómo se ve la planta: 0 sana, 1 débil (-10 %), 2 marchita (-25 % o -50 %), 3 muerta.
## Sigue a la peor racha sin regar: regar otra vez no la recupera (el rendimiento perdido no vuelve).
func stage() -> int:
	if dead:
		return 3
	return mini(worst_dry_streak, 2)


# ---------------------------------------------------------------- acciones (corrutinas)

func plant_blocked_reason() -> String:
	if planted and dead:
		if can_clear():
			return "Clear the dry plants from the beds first."
		return "The dead plants stay in the beds until their cycle ends (%d more sols)." % sols_to_clear()
	if planted:
		return "Potatoes are already growing."
	if not Mission.is_on("greenhouse"):
		return "The greenhouse is OFF. Turn it on in the Power Room first."
	if damaged:
		return "The greenhouse was damaged by the storm. Repair it first."
	return ""


func water_blocked_reason() -> String:
	if not planted:
		return "There's nothing planted yet."
	if dead:
		return "These plants are dead. Water can't save them now."
	if is_ready():
		return "The potatoes are ready! Harvest them."
	if watered_today:
		return "The potatoes already have enough water today."
	return ""


func plant(already_played_hours := 0.0) -> String:
	var reason := plant_blocked_reason()
	if reason != "":
		return reason
	_empty_beds()
	planted = true
	GameState.greenhouse_step = 1
	Mission.crops_changed.emit()
	await Mission.run_task("Planting potatoes", rule().plant_hours, "physical", already_played_hours)
	return ""


func water(already_played_hours := 0.0) -> String:
	var reason := water_blocked_reason()
	if reason != "":
		return reason
	watered_today = true
	dry_streak = 0
	GameState.greenhouse_step = 2
	Mission.crops_changed.emit()
	await Mission.run_task("Watering", rule().water_hours, "physical", already_played_hours)
	return ""


## Cosecha: devuelve "" o el motivo. Las papas quedan en `last_harvest` y en la despensa.
func harvest(already_played_hours := 0.0) -> String:
	if not is_ready():
		return "The potatoes aren't ready yet (%d more sols)." % sols_to_harvest()
	last_harvest = expected_harvest()
	Mission.pantry_meals += roundi(last_harvest * Mission.rules.food.meals_per_potato)
	_empty_beds()
	Mission.crops_changed.emit()
	await Mission.run_task("Harvesting", rule().harvest_hours, "physical", already_played_hours)
	Mission.notify("You harvested %d potatoes! They're in the station's pantry." % last_harvest)
	return ""


## Quita las plantas muertas cuando termina su ciclo: las camas quedan listas para sembrar otra vez.
func clear(already_played_hours := 0.0) -> String:
	if not (planted and dead):
		return "There are no dead plants to clear."
	if not can_clear():
		return plant_blocked_reason()
	_empty_beds()
	Mission.crops_changed.emit()
	await Mission.run_task("Clearing the beds", rule().clear_hours, "physical", already_played_hours)
	Mission.notify("The beds are clean. Plant new potatoes and water them every sol!")
	return ""


# ---------------------------------------------------------------- paso del tiempo (lo llama Mission)

func on_new_sol() -> void:
	if not planted:
		return
	age += 1
	if dead:
		if can_clear() and age == ceili(grow_sols()):
			Mission.notify("The dead potato plants finished their cycle. Clear the beds and plant again!")
		Mission.crops_changed.emit()
		return
	if not watered_today and not is_ready():
		dry_streak += 1
		worst_dry_streak = maxi(worst_dry_streak, dry_streak)
		if dry_streak >= rule().dies_after_dry_sols:
			dead = true
			watered_today = false
			GameState.greenhouse_step = 2  # no se puede plantar hasta limpiar las camas
			Mission.notify("The potatoes dried out and died! They stay in the beds until their cycle ends (%d more sols)." % sols_to_clear())
			Mission.crops_changed.emit()
			return
		var lost := int(round((1.0 - yield_ratio()) * 100.0))
		Mission.notify("The potatoes weren't watered yesterday! The harvest will be %d %% smaller." % lost)
	if Mission.is_on("greenhouse") and not damaged:
		var was_ready := is_ready()
		growth += 1.0
		if is_ready() and not was_ready:
			Mission.notify("The potatoes are ready to harvest!")
	watered_today = false
	GameState.greenhouse_step = 2 if is_ready() else 1  # listo para cosechar, o toca regar otra vez
	Mission.crops_changed.emit()
