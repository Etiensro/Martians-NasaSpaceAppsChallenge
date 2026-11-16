extends RefCounted
## Módulo del autoload Mission: las barras del astronauta (Mission.crew).
##   - hunger    (hambre, 100 = lleno)          baja 6 por sol; cada comida +2 (mín. 5 h entre comidas).
##   - fatigue   (cansancio, 0 = descansado)    +4/h despierto, -9/h dormido.
##   - radiation (radiación, 0 = sin riesgo)    +1/h dentro, +4/h fuera; el chequeo médico la baja 30.
##   - fitness   (condición física, 100 = bien) -15 cada sol sin ejercicio; la sesión de gimnasio +20.
## Cada barra da un multiplicador de duración para las tareas (Mission.task_hours) y, en su límite,
## termina la misión. Los números están en data/mission/rules.json -> "crew".
##
## Uso desde una escena (todas son corrutinas que adelantan el reloj: usar con await):
##   await Mission.crew.sleep(8)            # dormitorio o mini base. Devuelve "" o el motivo si no se puede
##   await Mission.crew.medical_checkup()   # enfermería: 20 EU (0 para el médico) y 4 h
##   Mission.crew.eat()                     # una comida (+2). Devuelve "" o el motivo
##   await Mission.crew.exercise(0.25)      # al terminar la caminadora (0.25 h ya jugadas en tiempo real)

var hunger := 100.0
var fatigue := 0.0
var radiation := 0.0
var fitness := 100.0
var asleep := false            # lo pone Mission mientras dura la actividad "dormir"

var _last_meal_at := -INF       # Mission.hours de la última comida
var _exercised_sol := -1        # último sol con sesión de ejercicio
var _warned := {}               # índice del aviso -> true (para no repetirlo hasta volver a cruzar)


func reset() -> void:
	hunger = _r().hunger.start
	fatigue = _r().fatigue.start
	radiation = _r().radiation.start
	fitness = _r().fitness.start
	asleep = false
	_last_meal_at = -INF
	_exercised_sol = -1
	_warned.clear()


func _r() -> Dictionary:
	return Mission.rules.crew


# ---------------------------------------------------------------- paso del tiempo (lo llama Mission)

## `h` horas de juego en la ubicación actual ("inside" / "outside").
func tick(h: float, location: String) -> void:
	hunger = clampf(hunger - _r().hunger.loss_per_sol / 24.0 * h, 0.0, 100.0)
	var per_hour: float = _r().fatigue.asleep_per_hour if asleep else _r().fatigue.awake_per_hour
	fatigue = clampf(fatigue + per_hour * h, 0.0, 100.0)
	var rad: float = _r().radiation.outside_per_hour if location == "outside" else _r().radiation.inside_per_hour
	radiation = clampf(radiation + rad * h, 0.0, 100.0)
	_check_warnings()


## Empieza un sol nuevo: si el sol que terminó no tuvo ejercicio, baja la condición física.
func on_new_sol(finished_sol: int) -> void:
	if _exercised_sol != finished_sol:
		fitness = clampf(fitness - _r().fitness.loss_per_sol_without_exercise, 0.0, 100.0)
		_check_warnings()


## Motivo por el que la misión debe terminar ahora ("" si todo va bien).
func abandon_reason() -> String:
	if hunger <= _r().hunger.abandon_at_or_below:
		return "hunger"
	if fatigue >= _r().fatigue.abandon_at_or_above:
		return "fatigue"
	if radiation >= _r().radiation.abandon_at_or_above:
		return "radiation"
	return ""


# ---------------------------------------------------------------- penalizaciones

func hunger_multiplier() -> float:
	return Mission.tier(_r().hunger.penalties, hunger)


func fatigue_multiplier() -> float:
	return Mission.tier(_r().fatigue.penalties, fatigue)


func radiation_multiplier() -> float:
	return Mission.tier(_r().radiation.penalties, radiation)


func fitness_multiplier() -> float:
	return Mission.tier(_r().fitness.penalties, fitness)


# ---------------------------------------------------------------- acciones

## Motivo por el que no se puede comer ahora ("" si se puede). Comida: la despensa de la base o,
## durante una expedición, las comidas cargadas en el carro.
func eat_blocked_reason() -> String:
	var wait: float = _last_meal_at + _r().hunger.meal_cooldown_hours - Mission.hours
	if wait > 0.0:
		return "You ate not long ago. Wait %d more hours." % ceili(wait)
	if Mission.expedition.is_away():
		if Mission.expedition.meals_loaded <= 0:
			return "There's no food left in the rover!"
	elif Mission.pantry_meals <= 0:
		return "There's no food left in the station. Harvest potatoes in the greenhouse!"
	return ""


## Come una comida. Devuelve "" o el motivo por el que no se pudo.
func eat() -> String:
	var reason := eat_blocked_reason()
	if reason != "":
		return reason
	if Mission.expedition.is_away():
		Mission.expedition.meals_loaded -= 1
	else:
		Mission.pantry_meals -= 1
	_last_meal_at = Mission.hours
	hunger = clampf(hunger + _r().hunger.per_meal, 0.0, 100.0)
	Mission.crew_changed.emit()
	return ""


## Horas que faltan para poder comer otra vez (0 si ya se puede).
func hours_until_meal() -> float:
	return maxf(0.0, _last_meal_at + _r().hunger.meal_cooldown_hours - Mission.hours)


## Duerme `hours` horas (1-24): el reloj avanza y el cansancio baja 9 por hora. Se duerme bajo techo
## (dormitorio o mini base de la zona), así que cuenta como interior para la radiación. Corrutina.
func sleep(hours: float) -> String:
	hours = clampf(hours, _r().fatigue.sleep_min_hours, _r().fatigue.sleep_max_hours)
	await Mission.run_activity("Sleeping", hours, {"asleep": true, "location": "inside"})
	return ""


func can_exercise() -> bool:
	return _exercised_sol != Mission.sol()


## Sesión de ejercicio (una por sol): +20 de condición física. Las 2 h cuentan como tiempo despierto.
## `already_played_hours`: horas de juego que ya pasaron en tiempo real durante el minijuego.
func exercise(already_played_hours := 0.0) -> String:
	if not can_exercise():
		return "You already trained today. Come back tomorrow!"
	_exercised_sol = Mission.sol()
	fitness = clampf(fitness + _r().fitness.per_session, 0.0, 100.0)
	Mission.crew_changed.emit()
	await Mission.run_activity("Working out", _r().fitness.session_hours - already_played_hours)
	return ""


## Energía que cuesta un chequeo para el rol elegido (el médico no gasta: GameState "medical_energy").
func checkup_energy() -> float:
	return _r().radiation.checkup_energy * GameState.modifier("medical_energy")


## Motivo por el que ahora no se puede hacer el chequeo ("" si se puede).
func checkup_blocked_reason() -> String:
	if Mission.battery < checkup_energy():
		return "Not enough energy for the medical scanner (%d EU)." % checkup_energy()
	return ""


## Chequeo médico en la enfermería: cuesta energía, tarda 4 h (con penalizaciones; el médico se
## recupera más rápido: "health_recovery") y baja la radiación 30. Corrutina; devuelve "" o el motivo.
## `already_played_hours`: horas de juego que ya pasaron durante el minijuego del escáner.
func medical_checkup(already_played_hours := 0.0) -> String:
	var reason := checkup_blocked_reason()
	if reason != "":
		return reason
	Mission.spend(checkup_energy())
	var hours: float = Mission.task_hours(_r().radiation.checkup_hours, "medical") / GameState.modifier("health_recovery")
	await Mission.run_activity("Medical check-up", hours - already_played_hours)
	radiation = clampf(radiation - _r().radiation.checkup_reduction, 0.0, 100.0)
	_check_warnings()
	Mission.crew_changed.emit()
	return ""


# ---------------------------------------------------------------- avisos de A.R.I.A.

func value_of(bar: String) -> float:
	match bar:
		"hunger": return hunger
		"fatigue": return fatigue
		"radiation": return radiation
		"fitness": return fitness
	return 0.0


func _check_warnings() -> void:
	var list: Array = _r().warnings.list
	for i in list.size():
		var w: Array = list[i]
		var v := value_of(w[0])
		var crossed: bool = v <= w[2] if w[1] == "down" else v >= w[2]
		if crossed and not _warned.has(i):
			_warned[i] = true
			# 5.º texto opcional: el aviso durante una expedición (en AP-8 / AP-9 no hay estación ni enfermería)
			Mission.notify(w[4] if w.size() > 4 and Mission.expedition.is_away() else w[3])
		elif not crossed:
			_warned.erase(i)
