extends RefCounted
## Módulo del autoload Mission: el cultivo de papas del invernadero (Mission.crops).
## Etapas: plantar (1 h) -> regar cada sol (30 min) -> crecer 8 sols -> cosechar (1 h, 24 papas).
## Cada sol seguido sin regar quita rendimiento (-10 %, -25 %, -50 %) y al 4.º el cultivo muere.
## El rendimiento se calcula al cosechar con la peor racha sin regar. Las papas van a la despensa
## (Mission.pantry_meals). Números: data/mission/rules.json -> "crops".
##
## Uso desde el invernadero (scripts/interiores/estacion_ares1/):
##   await Mission.crops.plant()     # al terminar el minijuego de sembrar. Devuelve "" o el motivo
##   await Mission.crops.water()     # al terminar el minijuego de regar
##   await Mission.crops.harvest()   # cuando is_ready() es true
## Además mantiene GameState.greenhouse_step (el paso que muestra el invernadero):
##   0 = sembrar, 1 = toca regar hoy, 2 = regado (esperar / cosechar cuando esté listo).

const CROP := "potato"

var planted := false
var growth := 0.0              # sols de crecimiento acumulados
var watered_today := false
var dry_streak := 0            # sols seguidos sin regar (el actual)
var worst_dry_streak := 0      # la peor racha: decide el rendimiento
var dead := false
var damaged := false           # invernadero dañado por una tormenta (no crece hasta repararlo)
var last_harvest := 0          # papas de la última cosecha


func reset() -> void:
	planted = false
	growth = 0.0
	watered_today = false
	dry_streak = 0
	worst_dry_streak = 0
	dead = false
	damaged = false
	last_harvest = 0


func rule() -> Dictionary:
	return Mission.rules.crops[CROP]


## Sols que necesita para crecer (el biólogo: más rápido, GameState "crop_speed").
func grow_sols() -> float:
	return rule().grow_sols / GameState.modifier("crop_speed")


## Hay un cultivo vivo en el invernadero (entonces no se puede apagar).
func is_growing() -> bool:
	return planted and not dead


func is_ready() -> bool:
	return is_growing() and growth >= grow_sols()


func needs_water() -> bool:
	return is_growing() and not watered_today and not is_ready()


## Progreso del crecimiento (0-1).
func progress() -> float:
	return clampf(growth / grow_sols(), 0.0, 1.0) if planted else 0.0


## Rendimiento (0-1) según la peor racha sin regar.
func yield_ratio() -> float:
	var pens: Array = rule().dry_penalties
	return 1.0 - float(pens[mini(worst_dry_streak, pens.size() - 1)])


# ---------------------------------------------------------------- acciones (corrutinas)

func plant_blocked_reason() -> String:
	if is_growing():
		return "Potatoes are already growing."
	if not Mission.is_on("greenhouse"):
		return "The greenhouse is OFF. Turn it on in the Power Room first."
	if damaged:
		return "The greenhouse was damaged by the storm. Repair it first."
	return ""


func plant(already_played_hours := 0.0) -> String:
	var reason := plant_blocked_reason()
	if reason != "":
		return reason
	planted = true
	dead = false
	growth = 0.0
	watered_today = false
	dry_streak = 0
	worst_dry_streak = 0
	GameState.greenhouse_step = 1
	Mission.crops_changed.emit()
	await Mission.run_task("Planting potatoes", rule().plant_hours, "physical", already_played_hours)
	return ""


func water(already_played_hours := 0.0) -> String:
	if not is_growing():
		return "There's nothing planted yet."
	if watered_today:
		return "The potatoes already have enough water today."
	watered_today = true
	dry_streak = 0
	GameState.greenhouse_step = 2
	Mission.crops_changed.emit()
	await Mission.run_task("Watering", rule().water_hours, "physical", already_played_hours)
	return ""


## Cosecha: devuelve "" o el motivo. Las papas quedan en `last_harvest` y en la despensa.
func harvest(already_played_hours := 0.0) -> String:
	if not is_ready():
		return "The potatoes aren't ready yet (%d %%)." % int(progress() * 100.0)
	last_harvest = roundi(rule().harvest * yield_ratio() * GameState.modifier("harvest_yield"))
	Mission.pantry_meals += roundi(last_harvest * Mission.rules.food.meals_per_potato)
	planted = false
	GameState.greenhouse_step = 0
	Mission.crops_changed.emit()
	await Mission.run_task("Harvesting", rule().harvest_hours, "physical", already_played_hours)
	Mission.notify("You harvested %d potatoes! They're in the station's pantry." % last_harvest)
	return ""


# ---------------------------------------------------------------- paso del tiempo (lo llama Mission)

func on_new_sol() -> void:
	if not is_growing():
		return
	if not watered_today and not is_ready():
		dry_streak += 1
		worst_dry_streak = maxi(worst_dry_streak, dry_streak)
		if dry_streak >= rule().dies_after_dry_sols:
			dead = true
			planted = false
			GameState.greenhouse_step = 0
			Mission.notify("The potatoes dried out and died. Plant new ones and water them every sol!")
			Mission.crops_changed.emit()
			return
		Mission.notify("The potatoes weren't watered yesterday. They will give less food.")
	if Mission.is_on("greenhouse") and not damaged:
		var was_ready := is_ready()
		growth += 1.0
		if is_ready() and not was_ready:
			Mission.notify("The potatoes are ready to harvest!")
	watered_today = false
	GameState.greenhouse_step = 2 if is_ready() else 1  # listo para cosechar, o toca regar otra vez
	Mission.crops_changed.emit()
